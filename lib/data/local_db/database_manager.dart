import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../backup/file_temporary_backup_database.dart';
import '../local_db/app_database.dart';
import '../local_db/chobo_schema.dart';
import '../local_db/db_key_store.dart';

class DatabaseManager extends StateNotifier<AppDatabase> {
  DatabaseManager() : super(AppDatabase());

  /// Returns the primary database file.
  Future<File> get primaryDatabaseFile async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return File(
      '${documentsDirectory.path}${Platform.pathSeparator}${ChoboSchema.databaseFileName}',
    );
  }

  /// Returns the encryption key store.
  DbKeyStore get encryptionKeyStore => DbKeyStore();

  /// Creates a FileTemporaryBackupDatabase configured with current database.
  Future<FileTemporaryBackupDatabase> createTemporaryBackupDatabase() async {
    final currentDb = state;
    final file = await primaryDatabaseFile;
    final keyStore = encryptionKeyStore;

    return FileTemporaryBackupDatabase(
      primaryDatabase: currentDb,
      primaryDatabaseFile: file,
      encryptionKeyStore: keyStore,
    );
  }

  /// Closes the current database and creates a new one.
  /// This is called after successful file rename.
  Future<void> replaceDatabase() async {
    try {
      await state.close();
    } catch (_) {
      // Database may already be closed; ignore
    }
    state = AppDatabase();
  }
}

final databaseManagerProvider =
    StateNotifierProvider<DatabaseManager, AppDatabase>((ref) {
  return DatabaseManager();
});
