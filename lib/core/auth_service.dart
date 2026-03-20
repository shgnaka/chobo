import 'package:local_auth/local_auth.dart';

class AuthService {
  AuthService({
    LocalAuthentication? localAuthentication,
    this.localizedReason = 'Please authenticate to proceed.',
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;
  final String localizedReason;

  Future<void> requireAuthentication() async {
    final authenticated = await _localAuthentication.authenticate(
      localizedReason: localizedReason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    if (!authenticated) {
      throw StateError('Authentication failed');
    }
  }

  Future<bool> isBiometricAvailable() async {
    final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
    if (canCheckBiometrics) {
      final availableBiometrics =
          await _localAuthentication.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    }
    return false;
  }
}
