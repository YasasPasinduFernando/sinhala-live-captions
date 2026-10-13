import 'package:speech_to_text/speech_to_text.dart';

import 'device_speech_client.dart';

/// One shared `speech_to_text` 7.5.0 instance.
///
/// `initialize` keeps the first callbacks, so those callbacks forward to the
/// handlers of whichever engine is current.
class SpeechToTextDeviceClient implements DeviceSpeechClient {
  SpeechToTextDeviceClient(this._speech);

  final SpeechToText _speech;

  void Function(String status)? _onStatus;
  void Function(String message, bool permanent)? _onError;
  void Function(String words, bool isFinal)? _onResult;

  @override
  Future<bool> initialize() {
    return _speech.initialize(
      onStatus: (status) => _onStatus?.call(status),
      onError: (error) => _onError?.call(error.errorMsg, error.permanent),
    );
  }

  @override
  Future<bool> hasPermission() => _speech.hasPermission;

  @override
  Future<List<String>> localeIds() async {
    final locales = await _speech.locales();
    return locales.map((locale) => locale.localeId).toList();
  }

  @override
  bool get isListening => _speech.isListening;

  @override
  String get trace => '';

  @override
  void setHandlers({
    required void Function(String status) onStatus,
    required void Function(String message, bool permanent) onError,
    required void Function(String words, bool isFinal) onResult,
  }) {
    _onStatus = onStatus;
    _onError = onError;
    _onResult = onResult;
  }

  @override
  Future<void> listen({
    required String localeId,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) {
    return _speech.listen(
      onResult: (result) {
        _onResult?.call(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        onDevice: false,
        listenMode: ListenMode.dictation,
        localeId: localeId,
        pauseFor: pauseFor,
        listenFor: listenFor,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
