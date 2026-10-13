import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../core/session_phase.dart';
import 'speech_engine.dart';

/// Owns one caption session and the in-memory transcript.
///
/// Confirmed text is append-only. The same confirmed string is not appended
/// twice in a row. Provisional text is replaced, never concatenated.
/// A user [stop] invalidates later engine events so nothing restarts the session.
class CaptionSessionController extends ChangeNotifier {
  CaptionSessionController({
    required this._engineFactory,
    RecognitionMode initialMode = RecognitionMode.device,
  }) : _mode = initialMode;

  final SpeechEngine Function(RecognitionMode mode) _engineFactory;

  RecognitionMode _mode;
  SessionPhase _phase = SessionPhase.idle;
  String _statusMessage = AppStrings.idle;
  String _provisional = '';
  String? _errorMessage;
  final List<ConfirmedCaption> _confirmed = [];

  SpeechEngine? _engine;
  StreamSubscription<SpeechEngineEvent>? _subscription;
  Future<void> _tail = Future<void>.value();
  var _generation = 0;
  var _userStopped = false;
  var _disposed = false;

  RecognitionMode get mode => _mode;
  SessionPhase get phase => _phase;
  String get statusMessage => _statusMessage;
  String get provisional => _provisional;
  String? get errorMessage => _errorMessage;
  List<ConfirmedCaption> get confirmed => List.unmodifiable(_confirmed);
  bool get isActive => _phase.isActive;
  EngineCapabilities? get capabilities => _engine?.capabilities;

  String get confirmedText => _confirmed.map((caption) => caption.text).join('\n');

  bool get showsDemonstration =>
      _engine?.capabilities.isDemonstration ?? false;

  String get diagnostics => _engine?.diagnostics ?? '';

  /// Runs [action] only after earlier start, stop, and mode changes finish.
  Future<void> _serialized(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> start() {
    return _serialized(_start);
  }

  Future<void> stop() {
    return _serialized(() => _stop(userInitiated: true));
  }

  Future<void> cancel() {
    return _serialized(_cancel);
  }

  /// Stops the active engine before the mode value changes.
  ///
  /// Does not start the newly selected engine.
  Future<void> selectMode(RecognitionMode mode) {
    return _serialized(() async {
      if (_disposed || _mode == mode) {
        return;
      }
      await _stop(userInitiated: true);
      await _releaseEngine();
      _mode = mode;
      _phase = SessionPhase.idle;
      _statusMessage = AppStrings.modeChanged;
      _errorMessage = null;
      _notify();
    });
  }

  void clearCaptions() {
    if (_disposed) {
      return;
    }
    _confirmed.clear();
    _provisional = '';
    if (!_phase.isActive) {
      _statusMessage = AppStrings.cleared;
    }
    _notify();
  }

  Future<void> _start() async {
    if (_disposed || _phase.isActive) {
      return;
    }
    _userStopped = false;
    final generation = ++_generation;
    _phase = SessionPhase.initializing;
    _statusMessage = AppStrings.preparing;
    _errorMessage = null;
    _notify();

    final engine = _engine ?? _engineFactory(_mode);
    _engine = engine;
    try {
      final availability = await engine.checkAvailability();
      if (!_isCurrent(generation)) {
        return;
      }
      if (!availability.isAvailable) {
        _phase = SessionPhase.unavailable;
        _statusMessage = availability.message;
        _errorMessage = availability.message;
        _notify();
        return;
      }
      _subscription = engine.events.listen(
        (event) => _onEvent(event, generation),
        onError: (Object _) => _onEngineFailure(generation),
      );
      await engine.start();
      if (!_isCurrent(generation)) {
        return;
      }
      if (_phase == SessionPhase.initializing &&
          engine.capabilities.isDemonstration) {
        _phase = SessionPhase.listening;
        _statusMessage = AppStrings.demoShowing;
        _notify();
      }
    } catch (_) {
      _onEngineFailure(generation);
    }
  }

  Future<void> _stop({required bool userInitiated}) async {
    if (_disposed) {
      return;
    }
    if (_engine == null) {
      if (userInitiated) {
        _userStopped = true;
      }
      _phase = SessionPhase.idle;
      _statusMessage = AppStrings.stopped;
      _notify();
      return;
    }
    _phase = SessionPhase.stopping;
    _statusMessage = AppStrings.stopped;
    _notify();
    try {
      await _engine?.stop();
    } catch (_) {
      _errorMessage = AppStrings.engineStartFailed;
    }
    if (userInitiated) {
      _userStopped = true;
    }
    final generation = ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    if (_disposed || generation != _generation) {
      return;
    }
    _phase = SessionPhase.completed;
    _statusMessage = AppStrings.stopped;
    _notify();
  }

  Future<void> _cancel() async {
    if (_disposed) {
      return;
    }
    _userStopped = true;
    final generation = ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _engine?.cancel();
    } catch (_) {
      _errorMessage = AppStrings.engineStartFailed;
    }
    if (_disposed || generation != _generation) {
      return;
    }
    _phase = SessionPhase.completed;
    _statusMessage = AppStrings.stopped;
    _notify();
  }

  void _onEvent(SpeechEngineEvent event, int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    // Each case ends the switch. Provisional text is replaced, not appended.
    switch (event) {
      case SpeechStatusEvent(:final phase, :final message):
        if (phase == SessionPhase.stopping && _phase == SessionPhase.completed) {
          return;
        }
        _phase = phase;
        _statusMessage = message;
        break;
      case SpeechProvisionalEvent(:final text):
        _provisional = text;
        break;
      case SpeechConfirmedEvent(:final text):
        _appendConfirmed(text);
        _provisional = '';
        break;
      case SpeechErrorEvent(:final message, :final recoverable):
        _phase = recoverable
            ? SessionPhase.recoverableError
            : SessionPhase.unavailable;
        _statusMessage = message;
        _errorMessage = message;
    }
    _notify();
  }

  void _appendConfirmed(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (_confirmed.isNotEmpty && _confirmed.last.text == trimmed) {
      return;
    }
    _confirmed.add(ConfirmedCaption(trimmed));
  }

  void _onEngineFailure(int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    _phase = SessionPhase.recoverableError;
    _statusMessage = AppStrings.engineStartFailed;
    _errorMessage = AppStrings.engineStartFailed;
    _notify();
  }

  bool _isCurrent(int generation) {
    return !_disposed && !_userStopped && generation == _generation;
  }

  Future<void> _releaseEngine() async {
    await _subscription?.cancel();
    _subscription = null;
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      await engine.dispose();
    }
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      unawaited(engine.dispose());
    }
    super.dispose();
  }
}
