import 'package:sinhala_live_captions/services/speech/voice_typing.dart';

class FakeVoiceTyping implements VoiceTypingClient {
  var calls = 0;
  VoiceTypingOutcome outcome = const VoiceTypingOutcome(
    VoiceTypingStatus.cancelled,
  );

  @override
  Future<VoiceTypingOutcome> recognizeSinhala() async {
    calls += 1;
    return outcome;
  }
}
