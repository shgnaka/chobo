import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/auto_backup_manager.dart';
import '../../backup/backup_codec_exceptions.dart';
import '../../app/chobo_providers.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  List<File>? _backups;
  File? _selectedBackup;
  bool _isRestoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final backupService = ref.read(backupServiceProvider);
    final autoBackupManager = AutoBackupManager(backupService: backupService);
    final backups = await autoBackupManager.listBackups();
    if (mounted) {
      setState(() {
        _backups = backups;
      });
    }
  }

  Future<void> _restore() async {
    if (_selectedBackup == null) return;

    setState(() {
      _isRestoring = true;
      _error = null;
    });

    try {
      final backupBytes = await _selectedBackup!.readAsBytes();
      final backupService = ref.read(backupServiceProvider);
      await backupService.restoreBackupWithTemporaryDb(backupBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Restore successful! Restarting app...')),
        );
        // Restart app - in a real app, you'd use a package like restart_app
        // For now, just pop back
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } on BackupFormatException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Invalid backup file: ${e.message}';
          _isRestoring = false;
        });
      }
    } on BackupCryptoException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Decryption failed: ${e.message}';
          _isRestoring = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Restore failed: $e';
          _isRestoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Recovery'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Database Recovery Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your database appears to be corrupted. Please select a backup to restore.',
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Available Backups:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_backups == null)
              const Center(child: CircularProgressIndicator())
            else if (_backups!.isEmpty)
              const Text('No backups available')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _backups!.length,
                  itemBuilder: (context, index) {
                    final backup = _backups![index];
                    final isSelected = backup == _selectedBackup;
                    final name = backup.uri.pathSegments.last;
                    final date = backup.lastModifiedSync();
                    return Card(
                      color: isSelected ? Colors.blue.shade100 : null,
                      child: ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.backup,
                          color: isSelected ? Colors.blue : null,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                        ),
                        onTap: () {
                          setState(() {
                            _selectedBackup = backup;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _selectedBackup != null && !_isRestoring ? _restore : null,
              child: _isRestoring
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore Selected Backup'),
            ),
          ],
        ),
      ),
    );
  }
}
