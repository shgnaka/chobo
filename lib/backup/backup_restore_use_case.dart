import 'dart:typed_data';

import 'aes_gcm_v1_ciphertext_codec.dart';
import 'backup_codec_exceptions.dart';
import 'backup_file_codec.dart';
import 'backup_file_envelope.dart';
import 'backup_header.dart';
import 'backup_payload_envelope.dart';
import 'binary_backup_file_codec.dart';

abstract class BackupMasterKeyStore {
  Uint8List load();
}

abstract class BackupPayloadValidator {
  void validate(BackupPayloadEnvelope payload);
}

abstract class TemporaryBackupDatabase {
  void importPayload(BackupPayloadEnvelope payload);

  void replacePrimary();
}

abstract class RestoreAuthorization {
  void requireAdditionalAuth();
}

class BackupRestoreUseCase {
  BackupRestoreUseCase({
    required this.fileCodec,
    required this.headerCodec,
    required this.keyWrapCodec,
    required this.ciphertextCodec,
    required this.masterKeyStore,
    required this.payloadCodec,
    required this.payloadValidator,
    required this.temporaryDatabase,
    required this.authorization,
  });

  final BackupFileCodec fileCodec;
  final BackupHeaderCodec headerCodec;
  final KeyWrapCodec keyWrapCodec;
  final CiphertextCodec ciphertextCodec;
  final BackupMasterKeyStore masterKeyStore;
  final BackupPayloadCodec payloadCodec;
  final BackupPayloadValidator payloadValidator;
  final TemporaryBackupDatabase temporaryDatabase;
  final RestoreAuthorization authorization;

  void restore(Uint8List backupBytes) {
    authorization.requireAdditionalAuth();

    final envelope = fileCodec.decode(backupBytes);
    _validateSchemes(envelope);

    final masterKey = masterKeyStore.load();
    final dataKey = keyWrapCodec.unwrap(
      wrappedKey: Uint8List.fromList(envelope.wrappedKey),
      masterKey: masterKey,
    );
    final plaintextBytes = ciphertextCodec.decrypt(
      ciphertext: Uint8List.fromList(envelope.ciphertext),
      authTag: Uint8List.fromList(envelope.authTag),
      dataKey: dataKey,
      nonce: Uint8List.fromList(envelope.nonce),
      aad: _aadBytes(envelope.header),
    );

    final payload = payloadCodec.decode(plaintextBytes);
    payloadValidator.validate(payload);
    temporaryDatabase.importPayload(payload);
    temporaryDatabase.replacePrimary();
  }

  void _validateSchemes(BackupFileEnvelope envelope) {
    final header = envelope.header;
    if (envelope.formatVersion != BinaryBackupFileCodec.formatVersion) {
      throw BackupFormatException('Unsupported backup format version');
    }
    if (header.encryptionScheme != 'aes-gcm-v1') {
      throw BackupFormatException('Unsupported encryption scheme');
    }
    if (header.keyWrapScheme != 'os-secure-storage-v1') {
      throw BackupFormatException('Unsupported key wrap scheme');
    }
    if (header.payloadFormat != 'json-v1') {
      throw BackupFormatException('Unsupported payload format');
    }
  }

  List<int> _aadBytes(BackupHeader header) {
    return <int>[
      ...BinaryBackupFileCodec.magic.codeUnits,
      ..._u16(BinaryBackupFileCodec.formatVersion),
      ...headerCodec.encode(header),
    ];
  }

  List<int> _u16(int value) {
    final bytes = ByteData(2)..setUint16(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }
}
