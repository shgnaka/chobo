import 'dart:math';
import 'dart:typed_data';

import '../data/repository/backup_payload_repository.dart';
import 'backup_codec_exceptions.dart';
import 'backup_file_codec.dart';
import 'backup_file_envelope.dart';
import 'backup_header.dart';
import 'backup_payload_envelope.dart';
import 'binary_backup_file_codec.dart';
import 'backup_restore_use_case.dart';

class BackupService {
  BackupService({
    required BackupPayloadRepository payloadRepository,
    required Future<Uint8List> Function() loadMasterKey,
    required Future<void> Function() requireAdditionalAuth,
    required BackupFileCodec fileCodec,
    required BackupHeaderCodec headerCodec,
    required KeyWrapCodec keyWrapCodec,
    required CiphertextCodec ciphertextCodec,
    required BackupPayloadCodec payloadCodec,
    BackupPayloadValidator? payloadValidator,
    DateTime Function()? now,
    String Function()? deviceIdProvider,
  })  : _payloadRepository = payloadRepository,
        _loadMasterKey = loadMasterKey,
        _requireAdditionalAuth = requireAdditionalAuth,
        _fileCodec = fileCodec,
        _headerCodec = headerCodec,
        _keyWrapCodec = keyWrapCodec,
        _ciphertextCodec = ciphertextCodec,
        _payloadCodec = payloadCodec,
        _payloadValidator =
            payloadValidator ?? const BackupPayloadSchemaValidator(),
        _now = now ?? (() => DateTime.now().toUtc()),
        _deviceIdProvider = deviceIdProvider ?? (() => null);

  final BackupPayloadRepository _payloadRepository;
  final Future<Uint8List> Function() _loadMasterKey;
  final Future<void> Function() _requireAdditionalAuth;
  final BackupFileCodec _fileCodec;
  final BackupHeaderCodec _headerCodec;
  final KeyWrapCodec _keyWrapCodec;
  final CiphertextCodec _ciphertextCodec;
  final BackupPayloadCodec _payloadCodec;
  final BackupPayloadValidator _payloadValidator;
  final DateTime Function() _now;
  final String? Function() _deviceIdProvider;

  Future<Uint8List> createBackup({
    required String appVersion,
  }) async {
    await _requireAdditionalAuth();

    final payload = await _payloadRepository.exportPayload();
    _payloadValidator.validate(payload);

    final header = BackupHeader(
      appVersion: appVersion,
      schemaVersion: 1,
      createdAt: _now(),
      encryptionScheme: 'aes-gcm-v1',
      keyWrapScheme: 'os-secure-storage-v1',
      payloadFormat: 'json-v1',
      deviceId: _deviceIdProvider(),
    );

    final masterKey = await _loadMasterKey();
    final dataKey = _randomBytes(32);
    final nonce = _randomBytes(12);
    final headerBytes = _headerCodec.encode(header);
    final aad = <int>[
      ...BinaryBackupFileCodec.magic.codeUnits,
      ..._u16(BinaryBackupFileCodec.formatVersion),
      ...headerBytes,
    ];
    final payloadBytes = _payloadCodec.encode(payload);
    final cipherBox = _ciphertextCodec.encrypt(
      plaintext: payloadBytes,
      dataKey: dataKey,
      nonce: nonce,
      aad: aad,
    );
    final wrappedKey = _keyWrapCodec.wrap(
      dataKey: dataKey,
      masterKey: masterKey,
    );

    return _fileCodec.encode(
      BackupFileEnvelope(
        formatVersion: BinaryBackupFileCodec.formatVersion,
        header: header,
        wrappedKey: wrappedKey,
        nonce: nonce,
        ciphertext: cipherBox.ciphertext,
        authTag: cipherBox.authTag,
        optionalFooter: '',
      ),
    );
  }

  Future<void> restoreBackup(Uint8List backupBytes) async {
    await _requireAdditionalAuth();

    final envelope = _fileCodec.decode(backupBytes);
    _validateSchemes(envelope);

    final masterKey = await _loadMasterKey();
    final dataKey = _keyWrapCodec.unwrap(
      wrappedKey: Uint8List.fromList(envelope.wrappedKey),
      masterKey: masterKey,
    );
    final plaintextBytes = _ciphertextCodec.decrypt(
      ciphertext: Uint8List.fromList(envelope.ciphertext),
      authTag: Uint8List.fromList(envelope.authTag),
      dataKey: dataKey,
      nonce: Uint8List.fromList(envelope.nonce),
      aad: _aadBytes(envelope.header),
    );

    final payload = _payloadCodec.decode(plaintextBytes);
    _payloadValidator.validate(payload);
    await _payloadRepository.importPayload(payload);
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
      ..._headerCodec.encode(header),
    ];
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List _u16(int value) {
    final bytes = ByteData(2)..setUint16(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }
}

class BackupPayloadSchemaValidator implements BackupPayloadValidator {
  const BackupPayloadSchemaValidator();

  @override
  void validate(BackupPayloadEnvelope payload) {
    _validateList(payload.accounts, 'accounts');
    _validateList(payload.transactions, 'transactions');
    _validateList(payload.entries, 'entries');
    _validateList(payload.periodClosures, 'period_closures');
    _validateList(payload.settings, 'settings');
    _validateList(payload.auditEvents, 'audit_events');
  }

  void _validateList(List<Map<String, Object?>> rows, String name) {
    for (final row in rows) {
      if (row.isEmpty) {
        throw FormatException('Empty row in $name');
      }
    }
  }
}
