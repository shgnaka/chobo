import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../data/local_db/app_database.dart';
import '../data/local_db/db_key_store.dart';
import '../data/repository/backup_payload_repository.dart';
import 'backup_payload_envelope.dart';
import 'backup_restore_use_case.dart';

class FileTemporaryBackupDatabase implements TemporaryBackupDatabase {
  FileTemporaryBackupDatabase({
    required this.primaryDatabase,
    required this.primaryDatabaseFile,
    required this.encryptionKeyStore,
  });

  final AppDatabase primaryDatabase;
  final File primaryDatabaseFile;
  final DbKeyStore encryptionKeyStore;

  File? _tempDatabaseFile;
  AppDatabase? _tempDatabase;

  @override
  Future<void> importPayload(BackupPayloadEnvelope payload) async {
    // Ensure previous temp database is cleaned up
    await _cleanup();

    // Create temporary file
    final tempDir = await getTemporaryDirectory();
    _tempDatabaseFile = File(
        '${tempDir.path}${Platform.pathSeparator}chobo_restore_temp_${DateTime.now().millisecondsSinceEpoch}.sqlite');

    // Create temporary database with same encryption key
    final encryptionKey = await encryptionKeyStore.loadOrGenerate();
    final keyString = base64Encode(encryptionKey);
    final executor = NativeDatabase.createInBackground(
      _tempDatabaseFile!,
      setup: (database) {
        database.execute("PRAGMA key = '$keyString';");
        database.execute('PRAGMA foreign_keys = ON;');
      },
    );
    _tempDatabase = AppDatabase(executor);

    // Import payload using BackupPayloadRepository
    final repository = BackupPayloadRepository(_tempDatabase!);
    await repository.importPayload(payload);
  }

  @override
  Future<void> replacePrimary() async {
    if (_tempDatabaseFile == null || _tempDatabase == null) {
      throw StateError('No temporary database to replace with');
    }

    // Close both databases
    await primaryDatabase.close();
    await _tempDatabase!.close();

    final backupFile = File('${primaryDatabaseFile.path}.backup');
    final primaryExists = await primaryDatabaseFile.exists();

    try {
      // Rename primary to backup (if exists)
      if (primaryExists) {
        await primaryDatabaseFile.rename(backupFile.path);
      }

      // Rename temp to primary
      await _tempDatabaseFile!.rename(primaryDatabaseFile.path);

      // Success: clean up backup file (optional, keep for safety)
      // Optionally delete backup file after successful rename
      // await backupFile.delete();
    } catch (error) {
      // If rename failed, try to restore primary from backup
      if (primaryExists && await backupFile.exists()) {
        try {
          await backupFile.rename(primaryDatabaseFile.path);
        } catch (_) {
          // If rollback also fails, we're in a bad state
          // Leave backup file in place for manual recovery
        }
      }
      // Clean up temporary file (it still exists)
      if (_tempDatabaseFile != null && await _tempDatabaseFile!.exists()) {
        await _tempDatabaseFile!.delete();
      }
      throw StateError('Failed to replace primary database: $error');
    }

    // Clear references
    _tempDatabase = null;
    _tempDatabaseFile = null;

    // Note: The primary database will be reopened by the app's database accessor.
    // The existing AppDatabase instance is closed; the app should create a new instance.
    // This method assumes that the caller will handle reopening the database.
  }

  Future<void> _cleanup() async {
    if (_tempDatabase != null) {
      await _tempDatabase!.close();
      _tempDatabase = null;
    }
    if (_tempDatabaseFile != null && await _tempDatabaseFile!.exists()) {
      await _tempDatabaseFile!.delete();
      _tempDatabaseFile = null;
    }
  }

  /// Call this when the restore is cancelled or fails to clean up temporary resources.
  Future<void> dispose() async {
    await _cleanup();
  }
}
