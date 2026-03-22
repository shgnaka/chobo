import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/ledger_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:chobo/data/service/monthly_summary_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlySummaryService', () {
    test('delegates monthly summary and balance lookups to the ledger repo',
        () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );

      await transactions.createTransaction(
        _sampleTransaction(transactionId: 'txn_001', date: '2026-03-05'),
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

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.month, '2026-03');
      expect(summary.periodLabel, '2026年03月');
      expect(summary.cashOutExpenses, 1200);
      expect(summary.sections, hasLength(5));
      expect(summary.cards.length, greaterThanOrEqualTo(7));
      expect(summary.sections.first.key, 'overview');
      expect(summary.sections.first.cards.first.title, 'Assets');
      expect(summary.sections[2].title, 'Expenses');
      expect(summary.sections[2].cards.single.key, 'Food');
      expect(summary.sections[2].cards.single.title, 'Food');

      final balances = await service.getAccountBalances();
      expect(balances['asset:bank:main'], -1200);
      expect(balances['expense:food'], 1200);
    });

    test('calculates cash-out expenses correctly for direct payments',
        () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );

      await transactions.createTransaction(
        _sampleTransaction(transactionId: 'txn_001', date: '2026-03-05'),
        <ChoboEntryRecord>[
          const ChoboEntryRecord(
            entryId: 'ent_001',
            transactionId: 'txn_001',
            accountId: 'asset:bank:main',
            direction: 'decrease',
            amount: 5000,
          ),
          const ChoboEntryRecord(
            entryId: 'ent_002',
            transactionId: 'txn_001',
            accountId: 'expense:food',
            direction: 'increase',
            amount: 5000,
          ),
        ],
      );

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.cashOutExpenses, 5000);
      expect(summary.accruedExpenses, 0);
    });

    test('calculates accrued expenses for credit card charges', () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'liability:card:main', name: 'Card'),
      );

      await transactions.createTransaction(
        _sampleTransaction(
          transactionId: 'txn_001',
          date: '2026-03-05',
          type: 'credit_expense',
        ),
        <ChoboEntryRecord>[
          const ChoboEntryRecord(
            entryId: 'ent_001',
            transactionId: 'txn_001',
            accountId: 'liability:card:main',
            direction: 'increase',
            amount: 3000,
          ),
          const ChoboEntryRecord(
            entryId: 'ent_002',
            transactionId: 'txn_001',
            accountId: 'expense:food',
            direction: 'increase',
            amount: 3000,
          ),
        ],
      );

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.cashOutExpenses, 0);
      expect(summary.accruedExpenses, 3000);
      expect(summary.liabilityDue, 3000);
    });

    test('calculates card payment when paying credit card bill', () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'liability:card:main', name: 'Card'),
      );

      await transactions.createTransaction(
        _sampleTransaction(
          transactionId: 'txn_credit',
          date: '2026-03-05',
          type: 'credit_expense',
        ),
        <ChoboEntryRecord>[
          const ChoboEntryRecord(
            entryId: 'ent_credit_card',
            transactionId: 'txn_credit',
            accountId: 'liability:card:main',
            direction: 'increase',
            amount: 3000,
          ),
          const ChoboEntryRecord(
            entryId: 'ent_credit_food',
            transactionId: 'txn_credit',
            accountId: 'expense:food',
            direction: 'increase',
            amount: 3000,
          ),
        ],
      );

      await transactions.createTransaction(
        _sampleTransaction(
          transactionId: 'txn_payment',
          date: '2026-03-20',
          type: 'liability_payment',
        ),
        <ChoboEntryRecord>[
          const ChoboEntryRecord(
            entryId: 'ent_payment_bank',
            transactionId: 'txn_payment',
            accountId: 'asset:bank:main',
            direction: 'decrease',
            amount: 3000,
          ),
          const ChoboEntryRecord(
            entryId: 'ent_payment_card',
            transactionId: 'txn_payment',
            accountId: 'liability:card:main',
            direction: 'decrease',
            amount: 3000,
          ),
        ],
      );

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.accruedExpenses, 3000);
      expect(summary.cardPayment, 3000);
      expect(summary.liabilityDue, 0);
    });

    test('calculates net assets delta correctly', () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'liability:card:main', name: 'Card'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'income:salary', name: 'Salary'),
      );

      await transactions.createTransaction(
        _sampleTransaction(
          transactionId: 'txn_salary',
          date: '2026-03-15',
          type: 'income',
        ),
        <ChoboEntryRecord>[
          const ChoboEntryRecord(
            entryId: 'ent_salary_bank',
            transactionId: 'txn_salary',
            accountId: 'asset:bank:main',
            direction: 'increase',
            amount: 300000,
          ),
          const ChoboEntryRecord(
            entryId: 'ent_salary_income',
            transactionId: 'txn_salary',
            accountId: 'income:salary',
            direction: 'increase',
            amount: 300000,
          ),
        ],
      );

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.assetsStart, 0);
      expect(summary.assetsEnd, 300000);
      expect(summary.liabilitiesStart, 0);
      expect(summary.liabilitiesEnd, 0);
      expect(summary.netAssetsStart, 0);
      expect(summary.netAssetsEnd, 300000);
      expect(summary.netAssetsDelta, 300000);
    });

    test('handles month with no transactions', () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'liability:card:main', name: 'Card'),
      );

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.month, '2026-03');
      expect(summary.assetsStart, 0);
      expect(summary.assetsEnd, 0);
      expect(summary.liabilitiesStart, 0);
      expect(summary.liabilitiesEnd, 0);
      expect(summary.cashOutExpenses, 0);
      expect(summary.accruedExpenses, 0);
      expect(summary.liabilityDue, 0);
      expect(summary.cardPayment, 0);
      expect(summary.expenseItems, isEmpty);
      expect(summary.incomeItems, isEmpty);
    });

    test('separates cash-out from accrued expenses correctly', () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:transport', name: 'Transport'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'liability:card:main', name: 'Card'),
      );

      await transactions.createTransaction(
        _sampleTransaction(transactionId: 'txn_cash', date: '2026-03-05'),
        <ChoboEntryRecord>[
          const ChoboEntryRecord(
            entryId: 'ent_cash_bank',
            transactionId: 'txn_cash',
            accountId: 'asset:bank:main',
            direction: 'decrease',
            amount: 1000,
          ),
          const ChoboEntryRecord(
            entryId: 'ent_cash_food',
            transactionId: 'txn_cash',
            accountId: 'expense:food',
            direction: 'increase',
            amount: 1000,
          ),
        ],
      );

      await transactions.createTransaction(
        _sampleTransaction(
          transactionId: 'txn_card',
          date: '2026-03-10',
          type: 'credit_expense',
        ),
        <ChoboEntryRecord>[
          const ChoboEntryRecord(
            entryId: 'ent_card_liability',
            transactionId: 'txn_card',
            accountId: 'liability:card:main',
            direction: 'increase',
            amount: 2000,
          ),
          const ChoboEntryRecord(
            entryId: 'ent_card_transport',
            transactionId: 'txn_card',
            accountId: 'expense:transport',
            direction: 'increase',
            amount: 2000,
          ),
        ],
      );

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.cashOutExpenses, 1000);
      expect(summary.accruedExpenses, 2000);
      expect(summary.expenseItems.length, 2);
    });

    test('sections contain correct keys and structure', () async {
      final db = _openDb();
      addTearDown(db.close);

      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final service = MonthlySummaryService(LedgerRepository(db));

      await accounts.createAccount(
        _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
      );
      await accounts.createAccount(
        _sampleAccount(accountId: 'expense:food', name: 'Food'),
      );

      await transactions.createTransaction(
        _sampleTransaction(transactionId: 'txn_001', date: '2026-03-05'),
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

      final summary = await service.getMonthlySummary('2026-03');
      expect(summary.sections.length, 5);
      expect(summary.sections[0].key, 'overview');
      expect(summary.sections[0].title, 'Overview');
      expect(summary.sections[1].key, 'flow');
      expect(summary.sections[1].title, 'Cash Flow');
      expect(summary.sections[2].key, 'expenses');
      expect(summary.sections[3].key, 'income');
      expect(summary.sections[4].key, 'transfers');

      final flowSection = summary.sections[1];
      expect(flowSection.cards.any((c) => c.key == 'cash_out_expenses'), true);
      expect(flowSection.cards.any((c) => c.key == 'accrued_expenses'), true);
      expect(flowSection.cards.any((c) => c.key == 'liability_due'), true);
      expect(flowSection.cards.any((c) => c.key == 'card_payment'), true);
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
  required String date,
  String type = 'expense',
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: date,
    type: type,
    status: 'posted',
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}
