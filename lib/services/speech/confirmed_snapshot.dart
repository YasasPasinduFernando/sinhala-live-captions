/// Turns a cumulative confirmed-text snapshot into new caption segments.
///
/// `whisper_cpp_flutter_plus` 0.5.1 documents `confirmedText` as text that
/// later updates preserve. Emitting the whole snapshot each time would
/// duplicate earlier words in [CaptionSessionController].
class ConfirmedSnapshot {
  String _accepted = '';

  String? takeAddition(String snapshot) {
    if (snapshot.isEmpty || snapshot == _accepted) {
      return null;
    }
    if (_accepted.isNotEmpty && snapshot.startsWith(_accepted)) {
      final addition = snapshot.substring(_accepted.length).trim();
      _accepted = snapshot;
      return addition.isEmpty ? null : addition;
    }
    if (_accepted.isEmpty) {
      _accepted = snapshot;
      final trimmed = snapshot.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    _accepted = snapshot;
    return null;
  }

  void reset() {
    _accepted = '';
  }
}
