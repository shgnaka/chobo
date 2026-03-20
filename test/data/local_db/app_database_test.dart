import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/entry_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase', () {
    test('creates the schema on first open', () async {
      final db = _openDb();
      addTearDown(db.close);

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get();

      expect(
        tables.map((row) => row.read<String>('name')).toList(),
        containsAll(<String>[
          'accounts',
          'audit_events',
          'entries',
          'period_closures',
          'settings',
          'transactions',
        ]),
      );
      expect(
        (await db.customSelect('PRAGMA foreign_keys').getSingle())
            .read<bool>('foreign_keys'),
        isTrue,
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
    });

    test('creates the indexes required by the schema document', () async {
      final db = _openDb();
      addTearDown(db.close);

      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' ORDER BY name",
          )
          .get();

      expect(
        indexes.map((row) => row.read<String>('name')).toSet(),
        containsAll(<String>{
          'idx_accounts_parent_account_id',
          'idx_audit_events_created_at',
          'idx_audit_events_target_id',
          'idx_entries_account_id',
          'idx_entries_transaction_id',
          'idx_period_closures_end_date',
          'idx_period_closures_start_date',
          'idx_transactions_date',
          'idx_transactions_status',
          'idx_transactions_type',
        }),
      );
    });

    test('supports CRUD for accounts', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);

      final account = _sampleAccount(
        accountId: 'asset:bank:main',
        name: 'Main Bank',
        isDefault: true,
      );

      await accounts.createAccount(account);

      final fetched = await accounts.getAccount(account.accountId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Main Bank');
      expect(fetched.isDefault, isTrue);

      final updated = _sampleAccount(
        accountId: 'asset:bank:main',
        name: 'Main Checking',
        isArchived: true,
      );
      expect(await accounts.updateAccount(updated), 1);

      final refetched = await accounts.getAccount(account.accountId);
      expect(refetched, isNotNull);
      expect(refetched!.name, 'Main Checking');
      expect(refetched.isArchived, isTrue);

      expect(await accounts.deleteAccount(account.accountId), 1);
      expect(await accounts.getAccount(account.accountId), isNull);
    });

    test('supports CRUD for transaction bundles and entries', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final entryRepo = EntryRepository(db);

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );

      final transaction = _sampleTransaction(
        transactionId: 'txn_001',
        description: 'Lunch',
      );
      final transactionEntries = <ChoboEntryRecord>[
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
      ];

      await transactions.createTransaction(transaction, transactionEntries);

      final fetched =
          await transactions.getTransaction(transaction.transactionId);
      expect(fetched, isNotNull);
      expect(fetched!.description, 'Lunch');
      expect(fetched.status, 'posted');

      final fetchedEntries = await entryRepo.listEntriesForTransaction(
        transaction.transactionId,
      );
      expect(fetchedEntries, hasLength(2));

      final replacementEntries = <ChoboEntryRecord>[
        const ChoboEntryRecord(
          entryId: 'ent_003',
          transactionId: 'txn_001',
          accountId: 'asset:bank:main',
          direction: 'decrease',
          amount: 1300,
        ),
        const ChoboEntryRecord(
          entryId: 'ent_004',
          transactionId: 'txn_001',
          accountId: 'expense:food',
          direction: 'increase',
          amount: 1300,
        ),
      ];
      final updatedTransaction = _sampleTransaction(
        transactionId: 'txn_001',
        description: 'Lunch with coffee',
        updatedAt: '2026-03-20T09:01:00Z',
      );
      expect(
        await transactions.updateTransaction(
            updatedTransaction, replacementEntries),
        1,
      );

      final updatedEntries = await entryRepo.listEntriesForTransaction(
        transaction.transactionId,
      );
      expect(updatedEntries, hasLength(2));
      expect(updatedEntries.first.entryId, 'ent_003');
      expect(await transactions.voidTransaction(transaction.transactionId), 1);
      expect(
          (await transactions.getTransaction(transaction.transactionId))!
              .status,
          'void');
    });

    test('keeps entry level CRUD inside transaction invariants', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final entryRepo = EntryRepository(db);

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

      await entryRepo.createEntry(
        const ChoboEntryRecord(
          entryId: 'ent_003',
          transactionId: 'txn_001',
          accountId: 'expense:food',
          direction: 'increase',
          amount: 50,
        ),
      );
      expect(await entryRepo.getEntry('ent_003'), isNotNull);

      final updatedEntry = ChoboEntryRecord(
        entryId: 'ent_003',
        transactionId: 'txn_001',
        accountId: 'expense:food',
        direction: 'increase',
        amount: 80,
        memo: 'coffee',
      );
      expect(await entryRepo.updateEntry(updatedEntry), 1);
      expect((await entryRepo.getEntry('ent_003'))!.amount, 80);

      expect(await entryRepo.deleteEntry('ent_003'), 1);
      expect(await entryRepo.getEntry('ent_003'), isNull);
      expect(
        () => entryRepo.deleteEntry('ent_001'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects transaction bundles with fewer than two entries', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );

      expect(
        () => transactions.createTransaction(
          _sampleTransaction(transactionId: 'txn_001'),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_001',
              accountId: 'asset:bank:main',
              direction: 'decrease',
              amount: 1200,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
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
  bool isDefault = false,
  bool isArchived = false,
}) {
  return ChoboAccountRecord(
    accountId: accountId,
    kind: accountId.split(':').first,
    name: name,
    isDefault: isDefault,
    isArchived: isArchived,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}

ChoboTransactionRecord _sampleTransaction({
  required String transactionId,
  String description = 'Lunch',
  String updatedAt = '2026-03-20T09:00:00Z',
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: '2026-03-20',
    type: 'expense',
    status: 'posted',
    description: description,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: updatedAt,
  );
}
