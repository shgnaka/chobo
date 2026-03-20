import 'dart:convert';
import 'dart:typed_data';

import 'package:chobo/chobo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backup recovery flow', () {
    test('keeps the primary database unchanged when restore is cancelled',
        () async {
      final harness = _RestoreHarness();
      harness.authorization.shouldThrow = true;

      await expectLater(() => harness.useCase.restore(harness.backupBytes),
          throwsA(isA<StateError>()));
      expect(harness.temporaryDatabase.imported, isFalse);
      expect(harness.temporaryDatabase.replaced, isFalse);
    });

    test('keeps the primary database unchanged when authentication fails',
        () async {
      final harness = _RestoreHarness();
      harness.authorization.shouldThrow = true;

      await expectLater(() => harness.useCase.restore(harness.backupBytes),
          throwsA(isA<StateError>()));
      expect(harness.temporaryDatabase.imported, isFalse);
      expect(harness.temporaryDatabase.replaced, isFalse);
    });

    test(
        'keeps the primary database unchanged when secure storage is unavailable',
        () async {
      final harness = _RestoreHarness();
      harness.masterKeyStore.shouldThrow = true;

      await expectLater(() => harness.useCase.restore(harness.backupBytes),
          throwsA(isA<StateError>()));
      expect(harness.temporaryDatabase.imported, isFalse);
      expect(harness.temporaryDatabase.replaced, isFalse);
    });

    test('keeps the primary database unchanged when payload validation fails',
        () async {
      final harness = _RestoreHarness();
      harness.payloadValidator.shouldThrow = true;

      await expectLater(() => harness.useCase.restore(harness.backupBytes),
          throwsA(isA<StateError>()));
      expect(harness.temporaryDatabase.imported, isFalse);
      expect(harness.temporaryDatabase.replaced, isFalse);
    });

    test(
        'keeps the primary database unchanged when temporary database import fails',
        () async {
      final harness = _RestoreHarness();
      harness.temporaryDatabase.shouldThrowOnImport = true;

      await expectLater(() => harness.useCase.restore(harness.backupBytes),
          throwsA(isA<StateError>()));
      expect(harness.temporaryDatabase.imported, isFalse);
      expect(harness.temporaryDatabase.replaced, isFalse);
    });

    test(
        'switches to the restored database only after final integrity succeeds',
        () async {
      final harness = _RestoreHarness();

      await harness.useCase.restore(harness.backupBytes);

      expect(harness.temporaryDatabase.imported, isTrue);
      expect(harness.temporaryDatabase.replaced, isTrue);
      expect(harness.payloadValidator.validated, isTrue);
      expect(harness.masterKeyStore.loaded, isTrue);
    });

    test('rejects files whose payload format is unsupported', () async {
      final harness = _RestoreHarness();
      final bytes = Uint8List.fromList(harness.backupBytes);
      _rewriteHeaderField(bytes, 'payload_format', 'json-v9');

      await expectLater(() => harness.useCase.restore(bytes),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects files whose encryption scheme is unsupported', () async {
      final harness = _RestoreHarness();
      final bytes = Uint8List.fromList(harness.backupBytes);
      _rewriteHeaderField(bytes, 'encryption_scheme', 'aes-gcm-v9');

      await expectLater(() => harness.useCase.restore(bytes),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects files whose key wrap scheme is unsupported', () async {
      final harness = _RestoreHarness();
      final bytes = Uint8List.fromList(harness.backupBytes);
      _rewriteHeaderField(bytes, 'key_wrap_scheme', 'os-secure-storage-v9');

      await expectLater(() => harness.useCase.restore(bytes),
          throwsA(isA<BackupFormatException>()));
    });
  });
}

class _RestoreHarness {
  _RestoreHarness() {
    masterKeyStore = _MasterKeyStore();
    payloadValidator = _PayloadValidator();
    temporaryDatabase = _TemporaryDatabase();
    authorization = _Authorization();
    useCase = BackupRestoreUseCase(
      fileCodec: BinaryBackupFileCodec(),
      headerCodec: const BackupHeaderJsonCodec(),
      keyWrapCodec: const OsSecureStorageV1KeyWrapCodec(),
      ciphertextCodec: const AesGcmV1CiphertextCodec(),
      masterKeyStore: masterKeyStore,
      payloadCodec: const BackupPayloadJsonCodec(),
      payloadValidator: payloadValidator,
      temporaryDatabase: temporaryDatabase,
      authorization: authorization,
    );
    backupBytes = _buildBackupBytes();
  }

  late final BackupRestoreUseCase useCase;
  late final _MasterKeyStore masterKeyStore;
  late final _PayloadValidator payloadValidator;
  late final _TemporaryDatabase temporaryDatabase;
  late final _Authorization authorization;
  late final Uint8List backupBytes;
}

class _Authorization implements RestoreAuthorization {
  bool shouldThrow = false;

  @override
  void requireAdditionalAuth() {
    if (shouldThrow) {
      throw StateError('auth cancelled');
    }
  }
}

class _MasterKeyStore implements BackupMasterKeyStore {
  bool shouldThrow = false;
  bool loaded = false;

  @override
  Uint8List load() {
    if (shouldThrow) {
      throw StateError('secure storage unavailable');
    }
    loaded = true;
    return Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  }
}

class _PayloadValidator implements BackupPayloadValidator {
  bool shouldThrow = false;
  bool validated = false;

  @override
  void validate(BackupPayloadEnvelope payload) {
    if (shouldThrow) {
      throw StateError('payload invalid');
    }
    validated = true;
  }
}

class _TemporaryDatabase implements TemporaryBackupDatabase {
  bool shouldThrowOnImport = false;
  bool imported = false;
  bool replaced = false;

  @override
  Future<void> importPayload(BackupPayloadEnvelope payload) async {
    if (shouldThrowOnImport) {
      throw StateError('temporary import failed');
    }
    imported = true;
  }

  @override
  Future<void> replacePrimary() async {
    replaced = true;
  }
}

Uint8List _buildBackupBytes() {
  final headerCodec = const BackupHeaderJsonCodec();
  final payloadCodec = const BackupPayloadJsonCodec();
  final fileCodec = BinaryBackupFileCodec();
  final cipherCodec = const AesGcmV1CiphertextCodec();
  final keyWrapCodec = const OsSecureStorageV1KeyWrapCodec();

  final header = BackupHeader(
    appVersion: '1.0.0',
    schemaVersion: 1,
    createdAt: DateTime.utc(2026, 3, 20),
    encryptionScheme: 'aes-gcm-v1',
    keyWrapScheme: 'os-secure-storage-v1',
    payloadFormat: 'json-v1',
    deviceId: 'device-opaque-001',
  );

  final payload = BackupPayloadEnvelope(
    accounts: <Map<String, Object?>>[
      <String, Object?>{
        'account_id': 'asset:bank:main',
        'kind': 'asset',
        'name': 'Main Bank',
        'parent_account_id': null,
        'is_default': true,
        'is_archived': false,
      },
    ],
    transactions: <Map<String, Object?>>[
      <String, Object?>{
        'transaction_id': 'txn_001',
        'date': '2026-03-20',
        'type': 'expense',
        'status': 'posted',
        'description': 'Lunch',
        'counterparty': 'Cafe',
        'external_ref': null,
      },
    ],
    entries: <Map<String, Object?>>[
      <String, Object?>{
        'entry_id': 'ent_001',
        'transaction_id': 'txn_001',
        'account_id': 'asset:bank:main',
        'direction': 'decrease',
        'amount': 1200,
        'memo': null,
      },
      <String, Object?>{
        'entry_id': 'ent_002',
        'transaction_id': 'txn_001',
        'account_id': 'expense:food',
        'direction': 'increase',
        'amount': 1200,
        'memo': null,
      },
    ],
    periodClosures: const <Map<String, Object?>>[],
    settings: const <Map<String, Object?>>[],
    auditEvents: const <Map<String, Object?>>[],
  );

  final headerBytes = headerCodec.encode(header);
  final aad = <int>[
    ...BinaryBackupFileCodec.magic.codeUnits,
    ..._u16(BinaryBackupFileCodec.formatVersion),
    ...headerBytes,
  ];

  final payloadBytes = payloadCodec.encode(payload);
  final dataKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 2));
  final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i + 3));
  final cipherBox = cipherCodec.encrypt(
    plaintext: payloadBytes,
    dataKey: dataKey,
    nonce: nonce,
    aad: aad,
  );
  final wrappedKey = keyWrapCodec.wrap(
    dataKey: dataKey,
    masterKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
  );

  final envelope = BackupFileEnvelope(
    formatVersion: BinaryBackupFileCodec.formatVersion,
    header: header,
    wrappedKey: wrappedKey,
    nonce: nonce,
    ciphertext: cipherBox.ciphertext,
    authTag: cipherBox.authTag,
    optionalFooter: '',
  );

  return fileCodec.encode(envelope);
}

void _rewriteHeaderField(
  Uint8List backupBytes,
  String field,
  String replacement,
) {
  final data = ByteData.sublistView(backupBytes);
  final headerLength = data.getUint32(10, Endian.little);
  final headerStart = 14;
  final headerBytes =
      backupBytes.sublist(headerStart, headerStart + headerLength);
  final headerJson = utf8.decode(headerBytes);
  final map = Map<String, Object?>.from(
    jsonDecode(headerJson) as Map,
  );
  map[field] = replacement;
  final rewritten = utf8.encode(jsonEncode(map));
  if (rewritten.length != headerLength) {
    throw StateError('Replacement changed header length unexpectedly');
  }
  for (var i = 0; i < rewritten.length; i++) {
    backupBytes[headerStart + i] = rewritten[i];
  }
}

Uint8List _u16(int value) {
  final bytes = ByteData(2)..setUint16(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}
