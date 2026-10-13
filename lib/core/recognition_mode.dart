/// How the user wants speech turned into captions.
///
/// The two modes do not share pause, locale, or streaming behavior.
/// Device recognition is session-based and may use a network service.
/// Offline Whisper runs on the phone after a model is installed.
enum RecognitionMode {
  /// Android speech recognizer exposed later through `speech_to_text`.
  device,

  /// On-device multilingual Whisper, not connected in this phase.
  whisper,
}
