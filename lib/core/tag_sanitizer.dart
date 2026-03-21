class TagSanitizer {
  TagSanitizer._();

  static const int maxLength = 50;
  static final _validPattern = RegExp(r'^[^\x00-\x1F\x7F]+$');

  static String? sanitize(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > maxLength) return null;
    if (!_validPattern.hasMatch(trimmed)) return null;
    return trimmed;
  }

  static bool isValid(String? input) {
    return sanitize(input) != null;
  }
}
