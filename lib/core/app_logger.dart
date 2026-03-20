import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void log(String message) {
    // TODO: In production, consider using a proper logging package.
    // For now, just print with a prefix.
    // Filter sensitive data from the message.
    final filtered = _filterSensitiveData(message);
    debugPrint('[CHOBO] $filtered');
  }

  static void logError(String error, [StackTrace? stackTrace]) {
    debugPrint('[CHOBO ERROR] $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static String _filterSensitiveData(String message) {
    // Simple heuristic: replace numbers longer than 3 digits and long words.
    // This is a basic implementation; in a real app, you'd want more precise filtering.
    final numberPattern = RegExp(r'\b\d{4,}\b');
    final wordPattern = RegExp(r'\b[a-zA-Z]{10,}\b');
    var filtered = message.replaceAll(numberPattern, '***');
    filtered = filtered.replaceAll(wordPattern, '***');
    return filtered;
  }
}
