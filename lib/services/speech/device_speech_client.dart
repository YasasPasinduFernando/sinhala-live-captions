/// Narrow port over the device speech recognizer.
///
/// Production uses one `SpeechToText` instance. Tests use a fake so unit
/// tests never open a microphone.
abstract class DeviceSpeechClient {
  Future<bool> initialize();

  Future<bool> hasPermission();

  Future<List<String>> localeIds();

  bool get isListening;

  void setHandlers({
    required void Function(String status) onStatus,
    required void Function(String message, bool permanent) onError,
    required void Function(String words, bool isFinal) onResult,
  });

  Future<void> listen({
    required String localeId,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  });

  Future<void> stop();

  Future<void> cancel();

  /// Extra runtime detail. Empty for clients that have nothing to add.
  String get trace => '';
}
