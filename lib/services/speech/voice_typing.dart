import 'package:flutter/services.dart';

/// Result of one Android voice-typing dialog.
///
/// The dialog is final text only. It is not the live caption stream.
enum VoiceTypingStatus {
  text,
  cancelled,
  empty,
  unavailable,
  permission,
  busy,
  failure,
}

class VoiceTypingOutcome {
  const VoiceTypingOutcome(this.status, {this.text = ''});

  final VoiceTypingStatus status;
  final String text;

  static VoiceTypingOutcome fromMap(Map<Object?, Object?>? raw) {
    final text = (raw?['text'] as String?)?.trim() ?? '';
    return switch (raw?['status']) {
      'text' when text.isNotEmpty => VoiceTypingOutcome(
        VoiceTypingStatus.text,
        text: text,
      ),
      'text' || 'empty' => const VoiceTypingOutcome(VoiceTypingStatus.empty),
      'cancelled' => const VoiceTypingOutcome(VoiceTypingStatus.cancelled),
      'unavailable' => const VoiceTypingOutcome(
        VoiceTypingStatus.unavailable,
      ),
      'permission' => const VoiceTypingOutcome(VoiceTypingStatus.permission),
      'busy' => const VoiceTypingOutcome(VoiceTypingStatus.busy),
      _ => const VoiceTypingOutcome(VoiceTypingStatus.failure),
    };
  }
}

/// Opens the system speech dialog for Sinhala only.
abstract class VoiceTypingClient {
  Future<VoiceTypingOutcome> recognizeSinhala();
}

/// Android `RecognizerIntent` dialog. The native side always requests `si-LK`.
class PlatformVoiceTypingClient implements VoiceTypingClient {
  PlatformVoiceTypingClient({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.sinhalacaptions/voice_typing');

  final MethodChannel _channel;

  @override
  Future<VoiceTypingOutcome> recognizeSinhala() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('recognize');
      if (raw is Map) {
        return VoiceTypingOutcome.fromMap(raw);
      }
      return const VoiceTypingOutcome(VoiceTypingStatus.failure);
    } on PlatformException {
      return const VoiceTypingOutcome(VoiceTypingStatus.failure);
    } on MissingPluginException {
      return const VoiceTypingOutcome(VoiceTypingStatus.unavailable);
    }
  }
}
