import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountRepository', () {
    test('restores missing standard accounts without overwriting existing ones',
        () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);

      await accounts.createAccount(
        _sampleAccount(
          accountId: 'asset:cash',
          kind: 'asset',
          name: 'Pocket Cash',
          isDefault: true,
        ),
      );

      final inserted = await accounts.restoreDefaultAccounts(
        timestamp: '2026-03-20T09:00:00Z',
      );
      expect(inserted, greaterThan(0));

      final cash = await accounts.getAccount('asset:cash');
      expect(cash, isNotNull);
      expect(cash!.name, 'Pocket Cash');
      expect(cash.kind, 'asset');
      expect(cash.isDefault, isTrue);

      final bank = await accounts.getAccount('asset:bank:main');
      expect(bank, isNotNull);
      expect(bank!.isDefault, isTrue);
      expect(bank.name, 'Main Bank');
    });

    test('archives an account in place', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);

      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );

      await accounts.archiveAccount(
        'expense:food',
        updatedAt: '2026-03-20T10:00:00Z',
      );

      final archived = await accounts.getAccount('expense:food');
      expect(archived, isNotNull);
      expect(archived!.isArchived, isTrue);
      expect(archived.updatedAt, '2026-03-20T10:00:00Z');
    });

    test('rejects kind changes after the account is used in entries', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);

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

      await expectLater(
        accounts.updateAccount(
          _sampleAccount(
            accountId: 'asset:bank:main',
            kind: 'liability',
            name: 'Main Bank',
          ),
        ),
        throwsA(isA<StateError>()),
      );
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
  String? kind,
  bool isDefault = false,
}) {
  return ChoboAccountRecord(
    accountId: accountId,
    kind: kind ?? accountId.split(':').first,
    name: name,
    isDefault: isDefault,
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
