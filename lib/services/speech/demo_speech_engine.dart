import 'dart:async';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../core/session_phase.dart';
import 'speech_engine.dart';

/// Sample-text engine for the UI and widget tests.
///
/// It never opens the microphone. Every caption is prefixed so it cannot be
/// mistaken for recognized speech.
class DemoSpeechEngine implements SpeechEngine {
  DemoSpeechEngine({
    required this.mode,
    this.available = true,
    this.failOnStart = false,
    this.stepDelay = const Duration(milliseconds: 40),
  });

  @override
  final RecognitionMode mode;

  /// When false, [checkAvailability] reports the engine as unavailable.
  final bool available;

  /// When true, [start] reports a recoverable error and emits no captions.
  final bool failOnStart;

  final Duration stepDelay;

  final StreamController<SpeechEngineEvent> _events =
      StreamController<SpeechEngineEvent>.broadcast(sync: true);

  Timer? _provisionalTimer;
  Timer? _confirmedTimer;
  var _stopped = false;
  var _disposed = false;

  @override
  String get diagnostics => '';

  @override
  EngineCapabilities get capabilities => EngineCapabilities(
    displayName: mode == RecognitionMode.whisper
        ? AppStrings.whisperMode
        : AppStrings.deviceMode,
    isDemonstration: true,
    usesMicrophone: false,
    supportsProvisionalText: true,
    supportsPause: false,
    requiresLocalModel: mode == RecognitionMode.whisper,
    maySendAudioOffDevice: false,
  );

  @override
  Stream<SpeechEngineEvent> get events => _events.stream;

  @override
  Future<EngineAvailability> checkAvailability() async {
    if (!available) {
      return const EngineAvailability(
        isAvailable: false,
        message: AppStrings.engineUnavailable,
      );
    }
    return const EngineAvailability(
      isAvailable: true,
      message: AppStrings.demoBanner,
    );
  }

  @override
  Future<void> start() async {
    _stopped = false;
    if (failOnStart) {
      _emit(
        const SpeechErrorEvent(AppStrings.engineStartFailed, recoverable: true),
      );
      return;
    }
    _emit(
      const SpeechStatusEvent(
        SessionPhase.initializing,
        AppStrings.demoPreparing,
      ),
    );
    _provisionalTimer = Timer(stepDelay, () {
      if (_stopped || _disposed) {
        return;
      }
      _emit(const SpeechProvisionalEvent(AppStrings.demoProvisional));
      _emit(
        const SpeechStatusEvent(SessionPhase.listening, AppStrings.demoShowing),
      );
    });
    _confirmedTimer = Timer(stepDelay * 2, () {
      if (_stopped || _disposed) {
        return;
      }
      _emit(const SpeechConfirmedEvent(AppStrings.demoConfirmed));
      _emit(const SpeechProvisionalEvent(''));
      _emit(
        const SpeechStatusEvent(SessionPhase.completed, AppStrings.demoFinished),
      );
    });
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _cancelTimers();
    _emit(const SpeechStatusEvent(SessionPhase.stopping, AppStrings.stopped));
    _emit(const SpeechStatusEvent(SessionPhase.completed, AppStrings.stopped));
  }

  @override
  Future<void> cancel() async {
    _stopped = true;
    _cancelTimers();
    _emit(const SpeechStatusEvent(SessionPhase.completed, AppStrings.stopped));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _stopped = true;
    _cancelTimers();
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  void _cancelTimers() {
    _provisionalTimer?.cancel();
    _confirmedTimer?.cancel();
    _provisionalTimer = null;
    _confirmedTimer = null;
  }

  void _emit(SpeechEngineEvent event) {
    if (_disposed || _events.isClosed) {
      return;
    }
    _events.add(event);
  }
}
