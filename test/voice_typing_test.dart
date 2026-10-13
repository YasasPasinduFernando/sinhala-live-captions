import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_live_captions/services/speech/voice_typing.dart';

void main() {
  test('voice typing maps text, empty, cancel, and errors', () {
    expect(
      VoiceTypingOutcome.fromMap({
        'status': 'text',
        'text': ' මගේ නම යසස් ',
      }).text,
      'මගේ නම යසස්',
    );
    expect(
      VoiceTypingOutcome.fromMap({'status': 'text', 'text': '  '}).status,
      VoiceTypingStatus.empty,
    );
    expect(
      VoiceTypingOutcome.fromMap({'status': 'cancelled'}).status,
      VoiceTypingStatus.cancelled,
    );
    expect(
      VoiceTypingOutcome.fromMap({'status': 'empty'}).status,
      VoiceTypingStatus.empty,
    );
    expect(
      VoiceTypingOutcome.fromMap({'status': 'unavailable'}).status,
      VoiceTypingStatus.unavailable,
    );
    expect(
      VoiceTypingOutcome.fromMap({'status': 'permission'}).status,
      VoiceTypingStatus.permission,
    );
    expect(
      VoiceTypingOutcome.fromMap(null).status,
      VoiceTypingStatus.failure,
    );
  });
}
