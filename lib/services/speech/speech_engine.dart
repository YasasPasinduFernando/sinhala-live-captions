import '../../core/recognition_mode.dart';
import '../../core/session_phase.dart';

/// What an engine can actually do.
///
/// Device recognition and Whisper are not the same. This type records the
/// differences instead of pretending both can pause, stream, or stay offline.
class EngineCapabilities {
  const EngineCapabilities({
    required this.displayName,
    required this.isDemonstration,
    required this.usesMicrophone,
    required this.supportsProvisionalText,
    required this.supportsPause,
    required this.requiresLocalModel,
    required this.maySendAudioOffDevice,
  });

  final String displayName;

  /// True when captions are sample text, not recognized speech.
  final bool isDemonstration;

  /// True only when this process is capturing the microphone.
  final bool usesMicrophone;

  /// True when partial text can change before it is confirmed.
  final bool supportsProvisionalText;

  /// Neither engine in this app promises pause. Kept explicit for later adapters.
  final bool supportsPause;

  /// Whisper needs a downloaded model. The device recognizer does not.
  final bool requiresLocalModel;

  /// Device recognition may leave the phone. Whisper audio stays on device
  /// after the model is local.
  final bool maySendAudioOffDevice;
}

/// Result of asking an engine whether a session may start.
class EngineAvailability {
  const EngineAvailability({required this.isAvailable, required this.message});

  final bool isAvailable;
  final String message;
}

/// One finalized piece of caption text.
///
/// Adapters must send a new segment, not the entire rolling transcript,
/// unless that entire transcript is the segment for this session.
class ConfirmedCaption {
  const ConfirmedCaption(this.text);

  final String text;
}

/// Events produced by a [SpeechEngine].
///
/// A confirmed value is one new segment. A provisional value replaces the
/// previous provisional value. Engines that only have a cumulative string
/// must split that string before emitting it.
sealed class SpeechEngineEvent {
  const SpeechEngineEvent();
}

class SpeechStatusEvent extends SpeechEngineEvent {
  const SpeechStatusEvent(this.phase, this.message);

  final SessionPhase phase;
  final String message;
}

class SpeechProvisionalEvent extends SpeechEngineEvent {
  const SpeechProvisionalEvent(this.text);

  final String text;
}

class SpeechConfirmedEvent extends SpeechEngineEvent {
  const SpeechConfirmedEvent(this.text);

  final String text;
}

class SpeechErrorEvent extends SpeechEngineEvent {
  const SpeechErrorEvent(this.message, {required this.recoverable});

  final String message;
  final bool recoverable;
}

/// Common contract for a caption engine.
///
/// Implementations must not start the microphone until [start] is called.
/// [stop] is a user stop: the engine must not restart itself afterwards.
/// [cancel] drops in-flight work and also must not restart.
abstract class SpeechEngine {
  RecognitionMode get mode;

  EngineCapabilities get capabilities;

  Future<EngineAvailability> checkAvailability();

  Stream<SpeechEngineEvent> get events;

  Future<void> start();

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();

  /// Non-sensitive session details for a debug build. Empty by default.
  String get diagnostics => '';
}
