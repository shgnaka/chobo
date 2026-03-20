import 'dart:typed_data';

import 'package:chobo/chobo.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a decryptable backup from the current database snapshot',
      () async {
    final db = _openDb();
    addTearDown(db.close);

    final accounts = AccountRepository(db);
    final transactions = TransactionRepository(db);
    final service = _makeService(
      db: db,
      masterKey: _masterKey,
    );

    await _seedData(accounts, transactions);

    final backupBytes = await service.createBackup(appVersion: '1.0.0');
    final fileCodec = BinaryBackupFileCodec();
    final envelope = fileCodec.decode(backupBytes);

    expect(envelope.header.appVersion, '1.0.0');
    expect(envelope.header.schemaVersion, 1);
    expect(envelope.header.encryptionScheme, 'aes-gcm-v1');
    expect(envelope.header.keyWrapScheme, 'os-secure-storage-v1');
    expect(envelope.header.payloadFormat, 'json-v1');

    final keyWrapCodec = const OsSecureStorageV1KeyWrapCodec();
    final cipherCodec = const AesGcmV1CiphertextCodec();
    final headerCodec = const BackupHeaderJsonCodec();
    final payloadCodec = const BackupPayloadJsonCodec();

    final dataKey = keyWrapCodec.unwrap(
      wrappedKey: Uint8List.fromList(envelope.wrappedKey),
      masterKey: _masterKey,
    );
    final plaintext = cipherCodec.decrypt(
      ciphertext: Uint8List.fromList(envelope.ciphertext),
      authTag: Uint8List.fromList(envelope.authTag),
      dataKey: dataKey,
      nonce: Uint8List.fromList(envelope.nonce),
      aad: <int>[
        ...BinaryBackupFileCodec.magic.codeUnits,
        ..._u16(BinaryBackupFileCodec.formatVersion),
        ...headerCodec.encode(envelope.header),
      ],
    );
    final payload = payloadCodec.decode(plaintext);

    expect(payload.accounts, hasLength(2));
    expect(payload.transactions, hasLength(1));
    expect(payload.entries, hasLength(2));
  });

  test('restores a backup into a fresh database', () async {
    final sourceDb = _openDb();
    final targetDb = _openDb();
    addTearDown(sourceDb.close);
    addTearDown(targetDb.close);

    final sourceAccounts = AccountRepository(sourceDb);
    final sourceTransactions = TransactionRepository(sourceDb);
    final sourceService = _makeService(
      db: sourceDb,
      masterKey: _masterKey,
    );
    final targetService = _makeService(
      db: targetDb,
      masterKey: _masterKey,
    );

    await _seedData(sourceAccounts, sourceTransactions);
    final backupBytes = await sourceService.createBackup(appVersion: '1.0.0');

    await targetService.restoreBackup(backupBytes);

    expect(await AccountRepository(targetDb).listAccounts(), hasLength(2));
    expect(
        await TransactionRepository(targetDb).listTransactions(), hasLength(1));
    expect(
      (await targetDb
              .customSelect('SELECT COUNT(*) AS count FROM entries')
              .getSingle())
          .read<int>('count'),
      2,
    );
  });
}

BackupService _makeService({
  required AppDatabase db,
  required Uint8List masterKey,
}) {
  return BackupService(
    payloadRepository: BackupPayloadRepository(db),
    loadMasterKey: () async => masterKey,
    requireAdditionalAuth: () async {},
    fileCodec: BinaryBackupFileCodec(),
    headerCodec: const BackupHeaderJsonCodec(),
    keyWrapCodec: const OsSecureStorageV1KeyWrapCodec(),
    ciphertextCodec: const AesGcmV1CiphertextCodec(),
    payloadCodec: const BackupPayloadJsonCodec(),
  );
}

Future<void> _seedData(
  AccountRepository accounts,
  TransactionRepository transactions,
) async {
  await accounts.createAccount(
    _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
  );
  await accounts.createAccount(
    _sampleAccount(accountId: 'expense:food', name: 'Food'),
  );
  await transactions.createTransaction(
    _sampleTransaction(transactionId: 'txn_001'),
    <ChoboEntryRecord>[
      const ChoboEntryRecord(
        entryId: 'ent_001',
        transactionId: 'txn_001',
        accountId: 'asset:bank:main',
        direction: 'decrease',
        amount: 1200,
      ),
      const ChoboEntryRecord(
        entryId: 'ent_002',
        transactionId: 'txn_001',
        accountId: 'expense:food',
        direction: 'increase',
        amount: 1200,
      ),
    ],
  );
}

AppDatabase _openDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (database) {
        database.execute('PRAGMA foreign_keys = ON;');
      },
    ),
  );
}

ChoboAccountRecord _sampleAccount({
  required String accountId,
  required String name,
}) {
  return ChoboAccountRecord(
    accountId: accountId,
    kind: accountId.split(':').first,
    name: name,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}

ChoboTransactionRecord _sampleTransaction({
  required String transactionId,
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: '2026-03-20',
    type: 'expense',
    status: 'posted',
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}

final Uint8List _masterKey =
    Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

Uint8List _u16(int value) {
  final bytes = ByteData(2)..setUint16(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}
