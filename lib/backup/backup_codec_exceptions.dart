class BackupCodecException implements Exception {
  BackupCodecException(this.message);

  final String message;

  @override
  String toString() => 'BackupCodecException: $message';
}

class BackupFormatException extends BackupCodecException {
  BackupFormatException(super.message);
}

class BackupCryptoException extends BackupCodecException {
  BackupCryptoException(super.message);
}
