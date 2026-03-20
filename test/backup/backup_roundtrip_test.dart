import 'dart:typed_data';

import 'package:chobo/chobo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backup round-trip', () {
    test('round-trips the smallest valid dataset', () {
      final result = _roundTrip(_smallPayload());

      expect(result.accounts, hasLength(1));
      expect(result.transactions, hasLength(1));
      expect(result.entries, hasLength(2));
      expect(result.periodClosures, isEmpty);
      expect(result.settings, isEmpty);
      expect(result.auditEvents, isEmpty);
    });

    test('round-trips a standard household dataset', () {
      final result = _roundTrip(_standardPayload());

      expect(result.accounts, hasLength(2));
      expect(result.transactions, hasLength(2));
      expect(result.entries, hasLength(4));
      expect(result.auditEvents, hasLength(1));
    });

    test('round-trips a dataset that includes closures and audits', () {
      final result = _roundTrip(_closedPayload());

      expect(result.periodClosures, hasLength(1));
      expect(result.auditEvents, hasLength(2));
      expect(result.entries, hasLength(2));
    });

    test('rejects ciphertexts with tampered auth tags', () {
      final fixture = _makeFixture(_smallPayload());
      final tampered = Uint8List.fromList(fixture.envelope.ciphertext);
      expect(
        () => fixture.cipherCodec.decrypt(
          ciphertext: tampered,
          authTag: Uint8List.fromList(<int>[
            ...fixture.envelope.authTag.sublist(0, 15),
            fixture.envelope.authTag[15] ^ 0x01,
          ]),
          dataKey: fixture.dataKey,
          nonce: Uint8List.fromList(fixture.envelope.nonce),
          aad: fixture.aad,
        ),
        throwsA(isA<BackupCryptoException>()),
      );
    });

    test('rejects wrapped keys that cannot be unwrapped', () {
      final fixture = _makeFixture(_smallPayload());
      final tampered = Uint8List.fromList(fixture.envelope.wrappedKey);
      tampered[5] ^= 0x01;

      expect(
        () => fixture.keyWrapCodec.unwrap(
          wrappedKey: tampered,
          masterKey: fixture.masterKey,
        ),
        throwsA(isA<BackupCryptoException>()),
      );
    });

    test('rejects payloads with invalid JSON', () {
      final payloadCodec = const BackupPayloadJsonCodec();

      expect(
        () => payloadCodec.decode(Uint8List.fromList('<not-json>'.codeUnits)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

BackupPayloadEnvelope _roundTrip(BackupPayloadEnvelope payload) {
  final fixture = _makeFixture(payload);
  final fileBytes = fixture.fileCodec.encode(fixture.envelope);
  final decodedEnvelope = fixture.fileCodec.decode(fileBytes);
  final masterKey = fixture.masterKey;
  final dataKey = fixture.keyWrapCodec.unwrap(
    wrappedKey: Uint8List.fromList(decodedEnvelope.wrappedKey),
    masterKey: masterKey,
  );
  final plaintext = fixture.cipherCodec.decrypt(
    ciphertext: Uint8List.fromList(decodedEnvelope.ciphertext),
    authTag: Uint8List.fromList(decodedEnvelope.authTag),
    dataKey: dataKey,
    nonce: Uint8List.fromList(decodedEnvelope.nonce),
    aad: fixture.aad,
  );
  return fixture.payloadCodec.decode(plaintext);
}

_RoundTripFixture _makeFixture(BackupPayloadEnvelope payload) {
  final headerCodec = BackupHeaderJsonCodec();
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
  final headerBytes = headerCodec.encode(header);
  final aad = <int>[
    ...BinaryBackupFileCodec.magic.codeUnits,
    ..._u16(BinaryBackupFileCodec.formatVersion),
    ...headerBytes,
  ];

  final masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  final dataKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 2));
  final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i + 3));
  final payloadBytes = payloadCodec.encode(payload);
  final cipherBox = cipherCodec.encrypt(
    plaintext: payloadBytes,
    dataKey: dataKey,
    nonce: nonce,
    aad: aad,
  );
  final wrappedKey = keyWrapCodec.wrap(
    dataKey: dataKey,
    masterKey: masterKey,
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

  return _RoundTripFixture(
    headerCodec: headerCodec,
    payloadCodec: payloadCodec,
    fileCodec: fileCodec,
    cipherCodec: cipherCodec,
    keyWrapCodec: keyWrapCodec,
    masterKey: masterKey,
    dataKey: dataKey,
    aad: aad,
    envelope: envelope,
    payload: payload,
  );
}

BackupPayloadEnvelope _smallPayload() {
  return BackupPayloadEnvelope(
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
}

BackupPayloadEnvelope _standardPayload() {
  return BackupPayloadEnvelope(
    accounts: <Map<String, Object?>>[
      <String, Object?>{
        'account_id': 'asset:bank:main',
        'kind': 'asset',
        'name': 'Main Bank',
        'parent_account_id': null,
        'is_default': true,
        'is_archived': false,
      },
      <String, Object?>{
        'account_id': 'expense:food',
        'kind': 'expense',
        'name': 'Food',
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
      <String, Object?>{
        'transaction_id': 'txn_002',
        'date': '2026-03-21',
        'type': 'income',
        'status': 'posted',
        'description': 'Salary',
        'counterparty': 'Employer',
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
      <String, Object?>{
        'entry_id': 'ent_003',
        'transaction_id': 'txn_002',
        'account_id': 'income:salary',
        'direction': 'increase',
        'amount': 300000,
        'memo': null,
      },
      <String, Object?>{
        'entry_id': 'ent_004',
        'transaction_id': 'txn_002',
        'account_id': 'asset:bank:main',
        'direction': 'increase',
        'amount': 300000,
        'memo': null,
      },
    ],
    periodClosures: const <Map<String, Object?>>[],
    settings: const <Map<String, Object?>>[],
    auditEvents: <Map<String, Object?>>[
      <String, Object?>{'event_type': 'backup_created'},
    ],
  );
}

BackupPayloadEnvelope _closedPayload() {
  return BackupPayloadEnvelope(
    accounts: _smallPayload().accounts,
    transactions: _smallPayload().transactions,
    entries: _smallPayload().entries,
    periodClosures: <Map<String, Object?>>[
      <String, Object?>{
        'closure_id': 'clo_001',
        'start_date': '2026-03-01',
        'end_date': '2026-03-15',
        'closed_at': '2026-03-16T00:00:00Z',
        'note': 'March first half',
      },
    ],
    settings: const <Map<String, Object?>>[],
    auditEvents: <Map<String, Object?>>[
      <String, Object?>{'event_type': 'backup_created'},
      <String, Object?>{'event_type': 'period_closed'},
    ],
  );
}

class _RoundTripFixture {
  const _RoundTripFixture({
    required this.headerCodec,
    required this.payloadCodec,
    required this.fileCodec,
    required this.cipherCodec,
    required this.keyWrapCodec,
    required this.masterKey,
    required this.dataKey,
    required this.aad,
    required this.envelope,
    required this.payload,
  });

  final BackupHeaderJsonCodec headerCodec;
  final BackupPayloadJsonCodec payloadCodec;
  final BinaryBackupFileCodec fileCodec;
  final AesGcmV1CiphertextCodec cipherCodec;
  final OsSecureStorageV1KeyWrapCodec keyWrapCodec;
  final Uint8List masterKey;
  final Uint8List dataKey;
  final List<int> aad;
  final BackupFileEnvelope envelope;
  final BackupPayloadEnvelope payload;
}

Uint8List _u16(int value) {
  final bytes = ByteData(2)..setUint16(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}
