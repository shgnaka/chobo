import 'package:chobo/chobo.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Operational repositories', () {
    test('exports and reimports a backup payload snapshot', () async {
      final sourceDb = _openDb();
      final targetDb = _openDb();
      addTearDown(sourceDb.close);
      addTearDown(targetDb.close);

      final accounts = AccountRepository(sourceDb);
      final transactions = TransactionRepository(sourceDb);
      final closures = ClosureRepository(sourceDb);
      final settings = SettingsRepository(sourceDb);
      final audits = AuditEventRepository(sourceDb);
      final backup = BackupPayloadRepository(sourceDb);

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
      await closures.createClosure(
        const ChoboClosureRecord(
          closureId: 'closure_001',
          startDate: '2026-03-01',
          endDate: '2026-03-31',
          closedAt: '2026-04-01T00:00:00Z',
          note: 'march close',
        ),
      );
      await settings.setSetting(
        const ChoboSettingRecord(
          settingKey: 'last_backup_at',
          settingValue: '2026-03-20T09:30:00Z',
        ),
      );
      await audits.recordJsonEvent(
        auditEventId: 'audit_001',
        eventType: 'account_created',
        targetId: 'asset:bank:main',
        payload: <String, Object?>{'account_id': 'asset:bank:main'},
        createdAt: '2026-03-20T09:00:00Z',
      );

      final payload = await backup.exportPayload();
      expect(payload.accounts, hasLength(2));
      expect(payload.transactions, hasLength(1));
      expect(payload.entries, hasLength(2));
      expect(payload.periodClosures, hasLength(1));
      expect(payload.settings, hasLength(1));
      expect(payload.auditEvents, hasLength(1));

      await BackupPayloadRepository(targetDb).importPayload(payload);

      expect(await AccountRepository(targetDb).listAccounts(), hasLength(2));
      expect(await TransactionRepository(targetDb).listTransactions(),
          hasLength(1));
      expect(await ClosureRepository(targetDb).listClosures(), hasLength(1));
      expect(await SettingsRepository(targetDb).listSettings(), hasLength(1));
      expect(await AuditEventRepository(targetDb).listEvents(), hasLength(1));
    });
  });
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
