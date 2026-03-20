import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/chobo_providers.dart';
import '../../core/auth_service.dart';
import '../../data/local_db/chobo_records.dart';
import '../../data/repository/settings_repository.dart';

enum AppLockState {
  initial,
  locked,
  unlocked,
  unavailable,
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier({
    required SettingsRepository settingsRepository,
    required AuthService authService,
  })  : _settingsRepository = settingsRepository,
        _authService = authService,
        super(AppLockState.initial);

  final SettingsRepository _settingsRepository;
  final AuthService _authService;

  Future<void> initialize() async {
    final appLockEnabled = await _isAppLockEnabled();
    if (!appLockEnabled) {
      state = AppLockState.unavailable;
      return;
    }

    final biometricAvailable = await _authService.isBiometricAvailable();
    if (!biometricAvailable) {
      state = AppLockState.unavailable;
      return;
    }

    state = AppLockState.locked;
  }

  Future<void> unlock() async {
    if (state == AppLockState.unavailable) {
      return;
    }

    try {
      await _authService.requireAuthentication();
      state = AppLockState.unlocked;
    } catch (e) {
      state = AppLockState.locked;
    }
  }

  void lock() {
    if (state == AppLockState.unavailable) {
      return;
    }
    state = AppLockState.locked;
  }

  Future<bool> _isAppLockEnabled() async {
    final setting = await _settingsRepository.getSetting(
      ChoboAppSettings.appLockEnabled,
    );
    return setting?.settingValue == 'true';
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _settingsRepository.setSetting(
      ChoboSettingRecord(
        settingKey: ChoboAppSettings.appLockEnabled,
        settingValue: enabled.toString(),
      ),
    );

    if (!enabled) {
      state = AppLockState.unavailable;
    } else {
      await initialize();
    }
  }
}

final appLockNotifierProvider =
    StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  return AppLockNotifier(
    settingsRepository: ref.watch(settingsRepositoryProvider),
    authService: ref.watch(authServiceProvider),
  );
});
