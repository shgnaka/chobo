import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/entry_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionRepository', () {
    test('uses the dedicated void path instead of direct void saves', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final entries = EntryRepository(db);

      await _seedBasicAccounts(accounts);

      await expectLater(
        transactions.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_void',
            status: 'void',
          ),
          _sampleExpenseEntries(
            transactionId: 'txn_void',
            amount: 1200,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      await transactions.createTransaction(
        _sampleTransaction(transactionId: 'txn_001'),
        _sampleExpenseEntries(transactionId: 'txn_001', amount: 1200),
      );

      expect(
        await transactions.voidTransaction(
          'txn_001',
          updatedAt: '2026-03-20T09:10:00Z',
        ),
        1,
      );

      final voided = await transactions.getTransaction('txn_001');
      expect(voided, isA<ChoboTransactionRecord>());
      expect(voided!.status, 'void');

      final voidedEntries = await entries.listEntriesForTransaction('txn_001');
      expect(voidedEntries, hasLength(2));
    });

    test('rejects direct edits when the transaction date is closed', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);

      await _seedBasicAccounts(accounts);
      await db.customInsert(
        '''
        INSERT INTO period_closures (
          closure_id,
          start_date,
          end_date,
          closed_at,
          note
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        variables: <Variable>[
          Variable('closure_001'),
          Variable('2026-03-01'),
          Variable('2026-03-31'),
          Variable('2026-04-01T00:00:00Z'),
          Variable('march close'),
        ],
      );

      await transactions.createTransaction(
        _sampleTransaction(
          transactionId: 'txn_002',
          date: '2026-03-20',
        ),
        _sampleExpenseEntries(transactionId: 'txn_002', amount: 1200),
      );

      await expectLater(
        transactions.updateTransaction(
          _sampleTransaction(
            transactionId: 'txn_002',
            date: '2026-03-20',
            description: 'edited after close',
            updatedAt: '2026-04-02T00:00:00Z',
          ),
          _sampleExpenseEntries(transactionId: 'txn_002', amount: 1200),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('reports whether a transaction can be updated directly', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);

      await _seedBasicAccounts(accounts);

      await transactions.createTransaction(
        _sampleTransaction(transactionId: 'txn_004'),
        _sampleExpenseEntries(transactionId: 'txn_004', amount: 1200),
      );

      final editable = await transactions.canUpdateTransaction('txn_004');
      expect(editable.canApply, isTrue);
      expect(editable.reason, '未締め期間の取引です。直接編集できます。');

      await db.customInsert(
        '''
        INSERT INTO period_closures (
          closure_id,
          start_date,
          end_date,
          closed_at,
          note
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        variables: <Variable>[
          Variable('closure_004'),
          Variable('2026-03-01'),
          Variable('2026-03-31'),
          Variable('2026-04-01T00:00:00Z'),
          Variable('march close'),
        ],
      );

      final closed = await transactions.canUpdateTransaction('txn_004');
      expect(closed.canApply, isFalse);
      expect(closed.isClosedPeriod, isTrue);
      expect(
        closed.reason,
        '締め済み期間の取引は直接編集できません。訂正取引を作成してください。',
      );

      await transactions.voidTransaction('txn_004');
      final voided = await transactions.canUpdateTransaction('txn_004');
      expect(voided.canApply, isFalse);
      expect(voided.reason, '取消済みの取引は直接編集できません。訂正取引を作成してください。');
    });

    test('reports closed period applicability for voiding', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);

      await _seedBasicAccounts(accounts);
      await db.customInsert(
        '''
        INSERT INTO period_closures (
          closure_id,
          start_date,
          end_date,
          closed_at,
          note
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        variables: <Variable>[
          Variable('closure_002'),
          Variable('2026-03-01'),
          Variable('2026-03-31'),
          Variable('2026-04-01T00:00:00Z'),
          Variable('march close'),
        ],
      );

      await transactions.createTransaction(
        _sampleTransaction(
          transactionId: 'txn_003',
          date: '2026-03-20',
        ),
        _sampleExpenseEntries(transactionId: 'txn_003', amount: 1200),
      );

      final decision = await transactions.canVoidTransaction('txn_003');
      expect(decision.canApply, isTrue);
      expect(decision.isClosedPeriod, isTrue);
      expect(decision.reason, '締め済み期間の取引ですが、取消できます。');

      expect(await transactions.voidTransaction('txn_003'), 1);
      expect((await transactions.getTransaction('txn_003'))!.status, 'void');
    });

    test('creates a correction transaction as a fresh posted bundle', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);

      await _seedBasicAccounts(accounts);

      await transactions.createTransaction(
        _sampleTransaction(transactionId: 'txn_003'),
        _sampleExpenseEntries(transactionId: 'txn_003', amount: 500),
      );

      await transactions.voidTransaction(
        'txn_003',
        updatedAt: '2026-03-20T09:10:00Z',
      );

      await transactions.createCorrectionTransaction(
        _sampleTransaction(
          transactionId: 'txn_004',
          description: 'corrected lunch',
        ),
        _sampleExpenseEntries(transactionId: 'txn_004', amount: 500),
      );

      final correction = await transactions.getTransaction('txn_004');
      expect(correction, isA<ChoboTransactionRecord>());
      expect(correction!.status, 'posted');
    });

    group('advance_payment transactions', () {
      test('creates an advance_payment transaction between two assets',
          () async {
        final db = _openDb();
        addTearDown(db.close);
        final accounts = AccountRepository(db);
        final transactions = TransactionRepository(db);

        await accounts.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          name: 'Main Bank',
        ));
        await accounts.createAccount(_sampleAccount(
          accountId: 'asset:receivable',
          name: 'Receivable',
        ));

        await transactions.createTransaction(
          _sampleAdvancePaymentTransaction(transactionId: 'txn_adv_001'),
          _sampleAdvancePaymentEntries(
              transactionId: 'txn_adv_001', amount: 5000),
        );

        final txn = await transactions.getTransaction('txn_adv_001');
        expect(txn != null, isTrue);
        expect(txn!.type, 'advance_payment');
        expect(txn.status, 'posted');
      });

      test('rejects advance_payment with same account', () async {
        final db = _openDb();
        addTearDown(db.close);
        final accounts = AccountRepository(db);
        final transactions = TransactionRepository(db);

        await accounts.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          name: 'Main Bank',
        ));

        await expectLater(
          transactions.createTransaction(
            _sampleAdvancePaymentTransaction(transactionId: 'txn_adv_002'),
            [
              ChoboEntryRecord(
                entryId: 'ent_adv_1',
                transactionId: 'txn_adv_002',
                accountId: 'asset:bank:main',
                direction: 'decrease',
                amount: 1000,
              ),
              ChoboEntryRecord(
                entryId: 'ent_adv_2',
                transactionId: 'txn_adv_002',
                accountId: 'asset:bank:main',
                direction: 'increase',
                amount: 1000,
              ),
            ],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('reimbursement transactions', () {
      test('creates a reimbursement transaction from asset to income',
          () async {
        final db = _openDb();
        addTearDown(db.close);
        final accounts = AccountRepository(db);
        final transactions = TransactionRepository(db);

        await accounts.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          name: 'Main Bank',
        ));
        await accounts.createAccount(_sampleAccount(
          accountId: 'income:side_job',
          name: 'Side Job',
        ));

        await transactions.createTransaction(
          _sampleReimbursementTransaction(transactionId: 'txn_reimb_001'),
          _sampleReimbursementEntries(
              transactionId: 'txn_reimb_001', amount: 10000),
        );

        final txn = await transactions.getTransaction('txn_reimb_001');
        expect(txn != null, isTrue);
        expect(txn!.type, 'reimbursement');
        expect(txn.status, 'posted');
      });

      test('rejects reimbursement with expense account', () async {
        final db = _openDb();
        addTearDown(db.close);
        final accounts = AccountRepository(db);
        final transactions = TransactionRepository(db);

        await accounts.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          name: 'Main Bank',
        ));
        await accounts.createAccount(_sampleAccount(
          accountId: 'expense:food',
          name: 'Food',
        ));

        await expectLater(
          transactions.createTransaction(
            _sampleReimbursementTransaction(transactionId: 'txn_reimb_002'),
            [
              ChoboEntryRecord(
                entryId: 'ent_reimb_1',
                transactionId: 'txn_reimb_002',
                accountId: 'asset:bank:main',
                direction: 'increase',
                amount: 2000,
              ),
              ChoboEntryRecord(
                entryId: 'ent_reimb_2',
                transactionId: 'txn_reimb_002',
                accountId: 'expense:food',
                direction: 'increase',
                amount: 2000,
              ),
            ],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
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

Future<void> _seedBasicAccounts(AccountRepository accounts) async {
  await accounts.createAccount(
    _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
  );
  await accounts.createAccount(
    _sampleAccount(accountId: 'expense:food', name: 'Food'),
  );
}

List<ChoboEntryRecord> _sampleExpenseEntries({
  required String transactionId,
  required int amount,
}) {
  return <ChoboEntryRecord>[
    ChoboEntryRecord(
      entryId: '${transactionId}_asset',
      transactionId: transactionId,
      accountId: 'asset:bank:main',
      direction: 'decrease',
      amount: amount,
    ),
    ChoboEntryRecord(
      entryId: '${transactionId}_expense',
      transactionId: transactionId,
      accountId: 'expense:food',
      direction: 'increase',
      amount: amount,
    ),
  ];
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
  String date = '2026-03-20',
  String status = 'posted',
  String description = 'Lunch',
  String updatedAt = '2026-03-20T09:00:00Z',
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: date,
    type: 'expense',
    status: status,
    description: description,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: updatedAt,
  );
}

ChoboTransactionRecord _sampleAdvancePaymentTransaction({
  required String transactionId,
  String date = '2026-03-20',
  String status = 'posted',
  String description = 'Advance payment',
  String updatedAt = '2026-03-20T09:00:00Z',
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: date,
    type: 'advance_payment',
    status: status,
    description: description,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: updatedAt,
  );
}

List<ChoboEntryRecord> _sampleAdvancePaymentEntries({
  required String transactionId,
  required int amount,
}) {
  return <ChoboEntryRecord>[
    ChoboEntryRecord(
      entryId: '${transactionId}_from',
      transactionId: transactionId,
      accountId: 'asset:bank:main',
      direction: 'decrease',
      amount: amount,
    ),
    ChoboEntryRecord(
      entryId: '${transactionId}_to',
      transactionId: transactionId,
      accountId: 'asset:receivable',
      direction: 'increase',
      amount: amount,
    ),
  ];
}

ChoboTransactionRecord _sampleReimbursementTransaction({
  required String transactionId,
  String date = '2026-03-20',
  String status = 'posted',
  String description = 'Reimbursement',
  String updatedAt = '2026-03-20T09:00:00Z',
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: date,
    type: 'reimbursement',
    status: status,
    description: description,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: updatedAt,
  );
}

List<ChoboEntryRecord> _sampleReimbursementEntries({
  required String transactionId,
  required int amount,
}) {
  return <ChoboEntryRecord>[
    ChoboEntryRecord(
      entryId: '${transactionId}_asset',
      transactionId: transactionId,
      accountId: 'asset:bank:main',
      direction: 'increase',
      amount: amount,
    ),
    ChoboEntryRecord(
      entryId: '${transactionId}_income',
      transactionId: transactionId,
      accountId: 'income:side_job',
      direction: 'increase',
      amount: amount,
    ),
  ];
}
