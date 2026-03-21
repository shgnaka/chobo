import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/chobo_providers.dart';
import '../../data/local_db/chobo_records.dart';
import '../../features/lock/app_lock_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;
  bool _appLockEnabled = false;
  bool _biometricAvailable = false;
  int _cacheDurationSeconds = ChoboAppSettings.defaultCacheDurationSeconds;
  bool _isAdvancedTerminology = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final authService = ref.read(authServiceProvider);

    final appLockSetting =
        await settingsRepo.getSetting(ChoboAppSettings.appLockEnabled);
    final cacheSetting =
        await settingsRepo.getSetting(ChoboAppSettings.cacheDurationSeconds);
    final terminologySetting =
        await settingsRepo.getSetting(ChoboAppSettings.terminologyMode);
    final biometricAvailable = await authService.isBiometricAvailable();

    if (mounted) {
      setState(() {
        _appLockEnabled = appLockSetting?.settingValue == 'true';
        _biometricAvailable = biometricAvailable;
        _cacheDurationSeconds =
            int.tryParse(cacheSetting?.settingValue ?? '') ??
                ChoboAppSettings.defaultCacheDurationSeconds;
        _isAdvancedTerminology = terminologySetting?.settingValue ==
            ChoboAppSettings.terminologyModeAdvanced;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value && !_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Biometric authentication is not available on this device.'),
        ),
      );
      return;
    }

    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.setSetting(
      ChoboSettingRecord(
        settingKey: ChoboAppSettings.appLockEnabled,
        settingValue: value.toString(),
      ),
    );

    final appLockNotifier = ref.read(appLockNotifierProvider.notifier);
    await appLockNotifier.setAppLockEnabled(value);

    if (mounted) {
      setState(() {
        _appLockEnabled = value;
      });
    }
  }

  Future<void> _updateCacheDuration(int seconds) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.setSetting(
      ChoboSettingRecord(
        settingKey: ChoboAppSettings.cacheDurationSeconds,
        settingValue: seconds.toString(),
      ),
    );

    if (mounted) {
      setState(() {
        _cacheDurationSeconds = seconds;
      });
    }
  }

  Future<void> _toggleTerminologyMode(bool advanced) async {
    final mode = advanced
        ? ChoboAppSettings.terminologyModeAdvanced
        : ChoboAppSettings.terminologyModeBasic;

    final notifier = ref.read(terminologyModeProvider.notifier);
    await notifier.setMode(mode);

    if (mounted) {
      setState(() {
        _isAdvancedTerminology = advanced;
      });
    }
  }

  String _formatCacheDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    }
    final minutes = seconds ~/ 60;
    return '$minutes minute${minutes > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Security'),
          SwitchListTile(
            title: const Text('App Lock'),
            subtitle: Text(
              _biometricAvailable
                  ? 'Require biometric authentication to unlock'
                  : 'Biometric authentication not available',
            ),
            value: _appLockEnabled,
            onChanged: _biometricAvailable ? _toggleAppLock : null,
          ),
          const Divider(),
          const _SectionHeader(title: 'Performance'),
          ListTile(
            title: const Text('Cache Duration'),
            subtitle: Text(
              'Summary data cached for ${_formatCacheDuration(_cacheDurationSeconds)}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('1 min'),
                Expanded(
                  child: Slider(
                    value: _cacheDurationSeconds.toDouble(),
                    min: 60,
                    max: 900,
                    divisions: 14,
                    label: _formatCacheDuration(_cacheDurationSeconds),
                    onChanged: (value) {
                      _updateCacheDuration(value.round());
                    },
                  ),
                ),
                const Text('15 min'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const _SectionHeader(title: 'Display'),
          SwitchListTile(
            title: const Text('Show Accounting Terminology'),
            subtitle: const Text(
              'Display terms like 借方/貸方 instead of 入/出',
            ),
            value: _isAdvancedTerminology,
            onChanged: _toggleTerminologyMode,
          ),
          const Divider(),
          const _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
