import 'backup_header.dart';

class BackupFileEnvelope {
  const BackupFileEnvelope({
    required this.formatVersion,
    required this.header,
    required this.wrappedKey,
    required this.nonce,
    required this.ciphertext,
    required this.authTag,
    required this.optionalFooter,
  });

  final int formatVersion;
  final BackupHeader header;
  final List<int> wrappedKey;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> authTag;
  final String optionalFooter;
}
