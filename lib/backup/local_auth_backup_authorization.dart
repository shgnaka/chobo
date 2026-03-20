import 'package:local_auth/local_auth.dart';

class LocalAuthBackupAuthorization {
  LocalAuthBackupAuthorization({
    LocalAuthentication? localAuthentication,
    this.localizedReason = 'Please authenticate to create or restore a backup.',
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;
  final String localizedReason;

  Future<void> requireAdditionalAuth() async {
    final authenticated = await _localAuthentication.authenticate(
      localizedReason: localizedReason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    if (!authenticated) {
      throw StateError('Backup authorization failed');
    }
  }
}
