/// True when [localeId] has the language subtag `si`.
///
/// `si`, `si_LK`, and `si-LK` match. `en_US` and names that merely contain
/// the letters "si" do not.
bool isSinhalaLocale(String localeId) {
  final trimmed = localeId.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final language = trimmed.split(RegExp('[-_]')).first.toLowerCase();
  return language == 'si';
}

/// Picks a Sinhala locale from ids the device actually returned.
///
/// Prefers a Sri Lanka id when several Sinhala locales exist.
/// Returns null when the device did not return one. Nothing is invented.
String? selectSinhalaLocale(Iterable<String> localeIds) {
  final matches = localeIds.where(isSinhalaLocale).toList();
  if (matches.isEmpty) {
    return null;
  }
  matches.sort((a, b) {
    final aLk = a.toLowerCase().contains('lk');
    final bLk = b.toLowerCase().contains('lk');
    if (aLk == bLk) {
      return a.compareTo(b);
    }
    return aLk ? -1 : 1;
  });
  return matches.first;
}
