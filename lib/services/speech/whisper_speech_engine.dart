import 'dart:async';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../core/session_phase.dart';
import 'confirmed_snapshot.dart';
import 'speech_engine.dart';
import 'whisper_model_controller.dart';
import 'whisper_ports.dart';

/// Offline microphone transcription through the injected Whisper runtime.
///
/// Confirmed plugin text is a cumulative snapshot. Only the new suffix is
/// emitted. Partial text replaces the previous provisional caption.
class WhisperSpeechEngine implements SpeechEngine {
  WhisperSpeechEngine({
    required this._runtime,
    required this._models,
  });

  final WhisperRuntime _runtime;
  final WhisperModelController _models;
  final ConfirmedSnapshot _snapshot = ConfirmedSnapshot();
  final StreamController<SpeechEngineEvent> _events =
      StreamController<SpeechEngineEvent>.broadcast(sync: true);

  WhisperLiveTask? _task;
  StreamSubscription<WhisperCaptionUpdate>? _subscription;
  var _userStopped = false;
  var _disposed = false;
  var _holding = false;
  var _capturing = false;
  var _starting = false;
  var _audioChunks = 0;
  var _audioPeak = 0.0;

  @override
  RecognitionMode get mode => RecognitionMode.whisper;

  @override
  EngineCapabilities get capabilities => EngineCapabilities(
    displayName: AppStrings.whisperMode,
    isDemonstration: false,
    usesMicrophone: _capturing,
    supportsProvisionalText: true,
    supportsPause: false,
    requiresLocalModel: true,
    maySendAudioOffDevice: false,
  );

  @override
  Stream<SpeechEngineEvent> get events => _events.stream;

  @override
  String get diagnostics {
    return 'whisper model=${_models.modelId} file=${_models.fileName} '
        'language=si detectLanguage=false translate=false '
        'chunks=$_audioChunks peak=${_audioPeak.toStringAsFixed(3)}';
  }

  @override
  Future<EngineAvailability> checkAvailability() async {
    await _models.refresh();
    if (!_models.isVerified) {
      return EngineAvailability(
        isAvailable: false,
        message: _models.statusLabel,
      );
    }
    return const EngineAvailability(
      isAvailable: true,
      message: AppStrings.whisperListening,
    );
  }

  @override
  Future<void> start() async {
    if (_disposed || _task != null || _starting) {
      return;
    }
    if (!_models.isVerified) {
      await _models.refresh();
    }
    _userStopped = false;
    _snapshot.reset();
    _starting = true;
    if (!_models.beginUse()) {
      _starting = false;
      _emit(
        SpeechErrorEvent(_models.statusLabel, recoverable: false),
      );
      return;
    }
    _holding = true;
    _emit(
      const SpeechStatusEvent(
        SessionPhase.processing,
        AppStrings.whisperLoading,
      ),
    );
    try {
      final path = _models.verifiedPath;
      if (path == null) {
        throw StateError('Model is not verified');
      }
      final task = await _runtime.startMicrophone(
        WhisperSessionConfig(
          modelPath: path,
          modelId: _models.modelId,
        ),
      );
      if (_disposed || _userStopped) {
        await task.cancel();
        await _releaseHold();
        return;
      }
      _task = task;
      _subscription = task.updates.listen(
        _onUpdate,
        onError: _onTaskError,
      );
      _capturing = true;
      _emit(
        const SpeechStatusEvent(
          SessionPhase.listening,
          AppStrings.whisperListening,
        ),
      );
    } catch (error) {
      await _releaseHold();
      _emit(
        SpeechErrorEvent(
          _messageFor(error),
          recoverable: !_isPermission(error),
        ),
      );
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stop() async {
    _userStopped = true;
    final task = _task;
    _task = null;
    if (task != null) {
      try {
        _onUpdate(await task.stop());
      } catch (error) {
        if (!_disposed) {
          _emit(
            SpeechErrorEvent(_messageFor(error), recoverable: true),
          );
        }
      }
    }
    await _subscription?.cancel();
    _subscription = null;
    _capturing = false;
    await _releaseHold();
  }

  @override
  Future<void> cancel() async {
    _userStopped = true;
    final task = _task;
    _task = null;
    await _subscription?.cancel();
    _subscription = null;
    if (task != null) {
      try {
        await task.cancel();
      } catch (_) {
        // Cancellation is expected to end the stream with an error.
      }
    }
    _capturing = false;
    await _releaseHold();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _userStopped = true;
    await cancel();
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  void _onUpdate(WhisperCaptionUpdate update) {
    if (_disposed) {
      return;
    }
    _audioChunks = update.audioChunks;
    _audioPeak = update.audioPeak;
    final addition = _snapshot.takeAddition(update.confirmedText);
    if (addition != null) {
      _emit(SpeechConfirmedEvent(addition));
    }
    _emit(
      SpeechProvisionalEvent(update.isFinal ? '' : update.partialText),
    );
  }

  void _onTaskError(Object error) {
    if (_disposed || _userStopped) {
      return;
    }
    _capturing = false;
    _emit(
      SpeechErrorEvent(
        _messageFor(error),
        recoverable: !_isPermission(error),
      ),
    );
  }

  Future<void> _releaseHold() async {
    _capturing = false;
    await _runtime.release();
    if (_holding) {
      _holding = false;
      _models.endUse();
    }
  }

  bool _isPermission(Object error) {
    return error.toString().toLowerCase().contains('permission');
  }

  String _messageFor(Object error) {
    if (_isPermission(error)) {
      return AppStrings.microphoneDenied;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('load') || text.contains('model')) {
      return AppStrings.whisperLoadFailed;
    }
    return AppStrings.whisperFailed;
  }

  void _emit(SpeechEngineEvent event) {
    if (_disposed || _events.isClosed) {
      return;
    }
    _events.add(event);
  }
}
