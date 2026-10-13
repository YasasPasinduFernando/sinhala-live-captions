import 'dart:async';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../core/session_phase.dart';
import 'device_speech_client.dart';
import 'sinhala_locale.dart';
import 'speech_engine.dart';
import 'voice_typing.dart';

/// Android speech-service adapter.
///
/// Sinhala is used only as `si`. A listed locale keeps live partial text.
/// When the list has no Sinhala locale, or live Sinhala is rejected, one
/// Android voice-typing dialog is opened for `si-LK`. English is not used.
/// The service can end a live session on silence. This adapter may start
/// another live listen after the previous one has finished, and it stops
/// doing that after repeated failures, an explicit stop, or the dialog.
class DeviceSpeechEngine implements SpeechEngine {
  DeviceSpeechEngine({
    required this._client,
    required this._whisperReady,
    this.voiceTyping,
    this.restartDelay = const Duration(milliseconds: 350),
    this.maxConsecutiveFailures = 5,
    this.startTimeout = const Duration(milliseconds: 1500),
  });

  final DeviceSpeechClient _client;
  final bool Function() _whisperReady;
  final VoiceTypingClient? voiceTyping;
  final Duration restartDelay;
  final int maxConsecutiveFailures;
  final Duration startTimeout;

  final StreamController<SpeechEngineEvent> _events =
      StreamController<SpeechEngineEvent>.broadcast(sync: true);

  String? _localeId;
  var _listedSinhala = false;
  var _voiceTypingUsed = false;
  var _blockLiveRestart = false;
  List<String> _localeIds = const [];
  var _initialized = false;
  var _permitted = false;
  var _heardStatus = false;
  Timer? _restartTimer;
  var _userStopped = false;
  var _acceptingFinal = false;
  var _disposed = false;
  var _capturing = false;
  var _listenInFlight = false;
  var _failures = 0;
  String? _committedThisListen;

  @override
  RecognitionMode get mode => RecognitionMode.device;

  @override
  EngineCapabilities get capabilities => EngineCapabilities(
    displayName: AppStrings.deviceMode,
    isDemonstration: false,
    usesMicrophone: _capturing,
    supportsProvisionalText: true,
    supportsPause: false,
    requiresLocalModel: false,
    maySendAudioOffDevice: true,
  );

  @override
  Stream<SpeechEngineEvent> get events => _events.stream;

  @override
  String get diagnostics {
    return 'device init=$_initialized permission=$_permitted '
        'locales=${_localeIds.join(',')}'
        ' selected=${_localeId ?? 'none'} listed=$_listedSinhala '
        'mode=${_voiceTypingUsed ? 'voice-typing' : 'live'} '
        'listening=$_capturing '
        'failures=$_failures '
        '${_client.trace}';
  }

  @override
  Future<EngineAvailability> checkAvailability() async {
    _client.setHandlers(
      onStatus: _onStatus,
      onError: _onError,
      onResult: _onResult,
    );
    _initialized = await _client.initialize();
    if (!_initialized) {
      return const EngineAvailability(
        isAvailable: false,
        message: AppStrings.deviceInitFailed,
      );
    }
    _permitted = await _client.hasPermission();
    if (!_permitted) {
      return const EngineAvailability(
        isAvailable: false,
        message: AppStrings.microphoneDenied,
      );
    }
    _localeIds = await _client.localeIds();
    _localeId = selectSinhalaLocale(_localeIds);
    _listedSinhala = _localeId != null;
    if (_localeId == null && voiceTyping == null && _whisperReady()) {
      return const EngineAvailability(
        isAvailable: false,
        message: AppStrings.sinhalaMissingWhisperReady,
      );
    }
    if (_localeId == null) {
      return const EngineAvailability(
        isAvailable: true,
        message: AppStrings.sinhalaLiveUnlisted,
      );
    }
    return const EngineAvailability(
      isAvailable: true,
      message: AppStrings.deviceListening,
    );
  }

  @override
  Future<void> start() async {
    if (_disposed) {
      return;
    }
    _userStopped = false;
    _failures = 0;
    _voiceTypingUsed = false;
    _blockLiveRestart = false;
    _committedThisListen = null;
    _client.setHandlers(
      onStatus: _onStatus,
      onError: _onError,
      onResult: _onResult,
    );
    if (_localeId == null) {
      _localeId = 'si-LK';
      _listedSinhala = false;
      _emit(
        const SpeechStatusEvent(
          SessionPhase.processing,
          AppStrings.sinhalaLiveUnlisted,
        ),
      );
    }
    await _beginListen();
  }

  @override
  Future<void> stop() async {
    _userStopped = true;
    _restartTimer?.cancel();
    _acceptingFinal = true;
    if (!_disposed && _client.isListening) {
      await _client.stop();
    }
    _acceptingFinal = false;
    _capturing = false;
  }

  @override
  Future<void> cancel() async {
    _userStopped = true;
    _restartTimer?.cancel();
    _capturing = false;
    if (!_disposed && _client.isListening) {
      await _client.cancel();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _userStopped = true;
    _restartTimer?.cancel();
    _capturing = false;
    if (_client.isListening) {
      await _client.cancel();
    }
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  Future<void> _beginListen() async {
    if (_userStopped || _disposed || _listenInFlight || _client.isListening) {
      return;
    }
    final localeId = _localeId;
    if (localeId == null) {
      return;
    }
    _listenInFlight = true;
    _committedThisListen = null;
    _heardStatus = false;
    try {
      await _client.listen(localeId: localeId);
    } catch (_) {
      _noteFailure();
    } finally {
      _listenInFlight = false;
    }
    if (_disposed || _userStopped || _capturing || _heardStatus) {
      return;
    }
    await Future<void>.delayed(startTimeout);
    if (_disposed || _userStopped || _capturing || _heardStatus) {
      return;
    }
    if (await _openVoiceTypingOnce()) {
      return;
    }
    _userStopped = true;
    _capturing = false;
    _emit(
      const SpeechErrorEvent(AppStrings.deviceDidNotStart, recoverable: true),
    );
  }

  void _onStatus(String status) {
    _heardStatus = true;
    if (_disposed || _userStopped) {
      return;
    }
    if (status == 'listening') {
      _restartTimer?.cancel();
      _failures = 0;
      _capturing = true;
      _emit(
        SpeechStatusEvent(
          SessionPhase.listening,
          '${AppStrings.deviceListening} ($_localeId)',
        ),
      );
      return;
    }
    if (status == 'notListening' || status == 'done') {
      _capturing = false;
      _scheduleRestart();
    }
  }

  void _onError(String message, bool permanent) {
    _heardStatus = true;
    if (_disposed || _userStopped) {
      return;
    }
    if (_isLocaleRejected(message)) {
      _capturing = false;
      _restartTimer?.cancel();
      unawaited(_rejectLiveSinhala());
      return;
    }
    final permission = message.contains('error_permission');
    if (permanent || permission) {
      _userStopped = true;
      _restartTimer?.cancel();
      _capturing = false;
      _emit(
        SpeechErrorEvent(
          permission
              ? AppStrings.microphoneDenied
              : AppStrings.deviceServiceMissing,
          recoverable: false,
        ),
      );
      return;
    }
    _noteFailure();
  }

  void _onResult(String words, bool isFinal) {
    if (_disposed || (_userStopped && !_acceptingFinal) || (_userStopped && !isFinal)) {
      return;
    }
    if (!isFinal) {
      _emit(SpeechProvisionalEvent(words));
      return;
    }
    final trimmed = words.trim();
    if (trimmed.isEmpty) {
      _emit(const SpeechProvisionalEvent(''));
      return;
    }
    if (trimmed == _committedThisListen) {
      return;
    }
    _committedThisListen = trimmed;
    _failures = 0;
    _emit(SpeechConfirmedEvent(trimmed));
    _emit(const SpeechProvisionalEvent(''));
  }

  void _noteFailure() {
    _failures += 1;
    if (_failures < maxConsecutiveFailures) {
      return;
    }
    _userStopped = true;
    _restartTimer?.cancel();
    _capturing = false;
    _emit(
      const SpeechErrorEvent(
        AppStrings.deviceRetriesExhausted,
        recoverable: true,
      ),
    );
  }

  bool _isLocaleRejected(String message) {
    final text = message.toLowerCase();
    return text.contains('language_not_supported') ||
        text.contains('language_unavailable') ||
        text.contains('error_language');
  }

  Future<void> _rejectLiveSinhala() async {
    if (await _openVoiceTypingOnce()) {
      return;
    }
    if (_disposed || _userStopped) {
      return;
    }
    _userStopped = true;
    _emit(
      const SpeechErrorEvent(AppStrings.sinhalaLiveRejected, recoverable: true),
    );
  }

  /// Opens the Sinhala voice-typing dialog once for this Start press.
  ///
  /// Returns false when no dialog client is installed. A second call in the
  /// same session does nothing.
  Future<bool> _openVoiceTypingOnce() async {
    if (_disposed || voiceTyping == null) {
      return false;
    }
    if (_voiceTypingUsed) {
      return true;
    }
    _voiceTypingUsed = true;
    _blockLiveRestart = true;
    _restartTimer?.cancel();
    if (_client.isListening) {
      await _client.cancel();
    }
    _capturing = false;
    _emit(
      const SpeechStatusEvent(
        SessionPhase.processing,
        AppStrings.voiceTypingOpening,
      ),
    );
    final outcome = await voiceTyping!.recognizeSinhala();
    if (_disposed || _userStopped) {
      return true;
    }
    switch (outcome.status) {
      case VoiceTypingStatus.text:
        _emit(SpeechConfirmedEvent(outcome.text));
        _emit(
          const SpeechStatusEvent(
            SessionPhase.completed,
            AppStrings.voiceTypingFinished,
          ),
        );
      case VoiceTypingStatus.cancelled:
      case VoiceTypingStatus.empty:
        _emit(
          const SpeechStatusEvent(
            SessionPhase.completed,
            AppStrings.voiceTypingEmpty,
          ),
        );
      case VoiceTypingStatus.permission:
        _emit(
          const SpeechErrorEvent(
            AppStrings.microphoneDenied,
            recoverable: false,
          ),
        );
      case VoiceTypingStatus.unavailable:
      case VoiceTypingStatus.busy:
      case VoiceTypingStatus.failure:
        _emit(
          const SpeechErrorEvent(
            AppStrings.voiceTypingUnavailable,
            recoverable: true,
          ),
        );
    }
    return true;
  }

  void _scheduleRestart() {
    if (_userStopped ||
        _disposed ||
        _blockLiveRestart ||
        _voiceTypingUsed ||
        _failures >= maxConsecutiveFailures) {
      return;
    }
    if (_restartTimer?.isActive ?? false) {
      return;
    }
    _restartTimer = Timer(restartDelay, () {
      unawaited(_beginListen());
    });
  }

  void _emit(SpeechEngineEvent event) {
    if (_disposed || _events.isClosed) {
      return;
    }
    _events.add(event);
  }
}
