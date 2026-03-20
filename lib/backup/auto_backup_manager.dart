import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_service.dart';

class AutoBackupManager {
  AutoBackupManager({
    required this.backupService,
    this.maxGenerations = 7,
  });

  final BackupService backupService;
  final int maxGenerations;

  Directory? _backupDirectory;

  Future<Directory> get backupDirectory async {
    if (_backupDirectory != null) return _backupDirectory!;
    final documentsDir = await getApplicationDocumentsDirectory();
    _backupDirectory =
        Directory('${documentsDir.path}${Platform.pathSeparator}backups');
    if (!await _backupDirectory!.exists()) {
      await _backupDirectory!.create(recursive: true);
    }
    return _backupDirectory!;
  }

  /// Creates an auto-backup if none exists for today.
  /// Returns the file created, or null if backup already exists.
  Future<File?> maybeCreateDailyBackup({required String appVersion}) async {
    final directory = await backupDirectory;
    final today =
        DateTime.now().toUtc().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final existing = await _findBackupForDate(today);
    if (existing != null) {
      return null;
    }

    final backupBytes =
        await backupService.createBackup(appVersion: appVersion);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'auto_backup_${today}_$timestamp.cho';
    final tempFile =
        File('${directory.path}${Platform.pathSeparator}$filename.tmp');
    final finalFile =
        File('${directory.path}${Platform.pathSeparator}$filename');

    try {
      await tempFile.writeAsBytes(backupBytes);
      await tempFile.rename(finalFile.path);
    } catch (error) {
      // If rename fails, maybe another process already created the file.
      // Clean up temp file and return null.
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      // Check again if file now exists (maybe created by another process)
      final nowExisting = await _findBackupForDate(today);
      if (nowExisting != null) {
        return null;
      }
      // Re-throw if it's a different error
      rethrow;
    }

    // Prune old backups
    await pruneOldBackups();

    return finalFile;
  }

  Future<File?> _findBackupForDate(String date) async {
    final directory = await backupDirectory;
    if (!await directory.exists()) return null;
    final files =
        await directory.list().where((f) => f is File).cast<File>().toList();
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (name.contains(date)) {
        return file;
      }
    }
    return null;
  }

  /// Deletes old backups, keeping only [maxGenerations] most recent.
  Future<void> pruneOldBackups() async {
    final directory = await backupDirectory;
    if (!await directory.exists()) return;
    final files =
        await directory.list().where((f) => f is File).cast<File>().toList();
    if (files.length <= maxGenerations) return;

    // Sort by modification time descending (newest first)
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (var i = maxGenerations; i < files.length; i++) {
      await files[i].delete();
    }
  }

  /// Returns list of backup files sorted by modification time (newest first).
  Future<List<File>> listBackups() async {
    final directory = await backupDirectory;
    if (!await directory.exists()) return [];
    final files =
        await directory.list().where((f) => f is File).cast<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Restores the most recent backup.
  Future<void> restoreLatestBackup() async {
    final backups = await listBackups();
    if (backups.isEmpty) {
      throw StateError('No backups available');
    }
    final latest = backups.first;
    final bytes = await latest.readAsBytes();
    await backupService.restoreBackup(bytes);
  }
}
