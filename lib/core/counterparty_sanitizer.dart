class CounterpartySanitizer {
  CounterpartySanitizer._();

  static String normalize(String input) {
    final trimmed = input.trim().toLowerCase();
    final normalized =
        trimmed.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^\w]'), '');
    return normalized;
  }

  static String displayName(String rawName) {
    return rawName.trim();
  }
}
