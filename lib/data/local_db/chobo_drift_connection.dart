import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'chobo_schema.dart';
import 'db_key_store.dart';

LazyDatabase openChoboLazyDatabase() {
  return LazyDatabase(() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbFile = File(
      '${documentsDirectory.path}${Platform.pathSeparator}${ChoboSchema.databaseFileName}',
    );

    final keyStore = DbKeyStore();
    final encryptionKey = await keyStore.loadOrGenerate();
    final keyString = base64Encode(encryptionKey);

    return NativeDatabase.createInBackground(
      dbFile,
      isolateSetup: () async {
        await _migrateExistingDatabaseIfNecessary(dbFile, keyString);
      },
      setup: (database) {
        // Verify that we're using SQLite3MultipleCiphers
        _debugCheckHasCipher(database);
        // Set encryption key
        database.execute("PRAGMA key = '$keyString';");
        // Additional PRAGMAs for performance
        database.execute('PRAGMA foreign_keys = ON;');
        database.execute('PRAGMA busy_timeout = 5000;');
      },
    );
  });
}

Future<void> _migrateExistingDatabaseIfNecessary(
    File dbFile, String key) async {
  if (!await dbFile.exists()) {
    // No existing database, nothing to migrate
    return;
  }

  // Try to open with encryption key; if it fails, assume it's unencrypted and delete it.
  // Since the app is in development, we can afford to lose unencrypted data.
  try {
    final db = sqlite3.open(dbFile.path);
    db.execute("PRAGMA key = '$key';");
    db.select('SELECT 1;');
    db.close();
    // Database is already encrypted with our key, keep it.
    return;
  } on SqliteException catch (_) {
    // "file is not a database" indicates either unencrypted or wrong key.
    // Since we only have one key, assume unencrypted.
    // Delete the file and let drift create a new encrypted one.
    await dbFile.delete();
  }
}

bool _debugCheckHasCipher(Database database) {
  final result = database.select('PRAGMA cipher;');
  if (result.isEmpty) {
    throw UnsupportedError(
      'This database needs to run with SQLite3MultipleCiphers, but that library is not available!',
    );
  }
  return true;
}
