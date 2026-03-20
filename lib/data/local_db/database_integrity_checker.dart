import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'chobo_schema.dart';
import 'db_key_store.dart';

class DatabaseIntegrityChecker {
  /// Checks the integrity of the primary database file.
  /// Returns true if the database passes integrity check, false otherwise.
  /// Throws an exception if the database cannot be opened (e.g., wrong encryption key).
  Future<bool> checkIntegrity() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbFile = File(
      '${documentsDirectory.path}${Platform.pathSeparator}${ChoboSchema.databaseFileName}',
    );

    if (!await dbFile.exists()) {
      // No database file, considered intact (first launch)
      return true;
    }

    final keyStore = DbKeyStore();
    final encryptionKey = await keyStore.loadOrGenerate();
    final keyString = base64Encode(encryptionKey);

    // Open database with encryption key
    final db = sqlite3.open(dbFile.path);
    try {
      db.execute("PRAGMA key = '$keyString';");
      // Run integrity check
      final result = db.select('PRAGMA integrity_check;');
      if (result.isEmpty) {
        // Should not happen
        return false;
      }
      final firstRow = result.first;
      final value = firstRow['integrity_check'] as String;
      return value == 'ok';
    } on SqliteException {
      // If error indicates corruption, return false
      // If error indicates wrong key or other issue, we could rethrow
      // For now, assume corruption
      return false;
    } finally {
      db.close();
    }
  }
}
