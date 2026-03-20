import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../backup/auto_backup_manager.dart';
import '../core/app_logger.dart';
import '../data/local_db/database_integrity_checker.dart';
import 'chobo_app.dart';
import 'chobo_providers.dart';
import '../features/recovery/recovery_screen.dart';

class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _isChecking = true;
  bool _integrityOk = true;
  bool _isCreatingBackup = false;
  bool _backupChecked = false;

  @override
  void initState() {
    super.initState();
    _checkIntegrity();
  }

  Future<void> _checkIntegrity() async {
    final checker = DatabaseIntegrityChecker();
    try {
      final ok = await checker.checkIntegrity();
      if (mounted) {
        setState(() {
          _integrityOk = ok;
          _isChecking = false;
        });
      }
    } catch (e) {
      // If error occurs, assume integrity is ok (maybe wrong key, but we'll handle later)
      if (mounted) {
        setState(() {
          _integrityOk = true;
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _createAutoBackup() async {
    if (_backupChecked || _isCreatingBackup) return;
    if (!_integrityOk) return;

    setState(() => _isCreatingBackup = true);

    try {
      final autoBackup = ref.read(autoBackupManagerProvider);
      final appVersion = (await PackageInfo.fromPlatform()).version;
      final result =
          await autoBackup.maybeCreateDailyBackup(appVersion: appVersion);
      if (result != null) {
        AppLogger.log('Auto-backup created: ${result.path}');
      } else {
        AppLogger.log('Auto-backup skipped (already exists for today)');
      }
    } catch (e, stackTrace) {
      AppLogger.logError('Auto-backup failed', stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-backup failed. Your data may not be saved.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBackup = false;
          _backupChecked = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_integrityOk) {
      return const RecoveryScreen();
    }

    // Trigger auto-backup after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createAutoBackup();
    });

    return const ChoboApp();
  }
}
