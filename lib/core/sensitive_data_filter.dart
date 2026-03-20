class SensitiveDataFilter {
  SensitiveDataFilter._();

  /// Redacts sensitive text by replacing characters with '*'.
  /// For short strings, shows only first and last character.
  static String redactText(String? text) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= 2) return '*' * text.length;
    return '${text[0]}${'*' * (text.length - 2)}${text[text.length - 1]}';
  }

  /// Redacts an amount (integer) by returning a placeholder.
  static String redactAmount(int amount) {
    return '***';
  }

  /// Redacts a memo by truncating to max length and replacing middle.
  static String redactMemo(String? memo, {int maxLength = 20}) {
    if (memo == null || memo.isEmpty) return '';
    if (memo.length <= maxLength) return redactText(memo);
    return '${redactText(memo.substring(0, maxLength))}...';
  }

  /// Returns true if the given string contains sensitive data that should not be logged.
  static bool isSensitive(String? text) {
    if (text == null) return false;
    // TODO: Add more heuristics if needed
    return text.contains(RegExp(r'\d{4,}')) ||
        text.contains(RegExp(r'[a-zA-Z]{10,}'));
  }
}
