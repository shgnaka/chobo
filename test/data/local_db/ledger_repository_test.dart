import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/ledger_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LedgerRepository', () {
    test('recalculates balances from posted transactions only', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final ledger = LedgerRepository(db);

      await _seedAccounts(accounts);
      await _seedPostedMarchTransactions(transactions);
      await _seedIgnoredTransactions(transactions);

      final balances = await ledger.calculateAccountBalances();

      expect(balances['asset:bank:main'], 245800);
      expect(balances['asset:bank:savings'], 50000);
      expect(balances['liability:card:main'], 0);
      expect(balances['expense:food'], 1200);
      expect(balances['expense:rent'], 3000);
      expect(balances['income:salary'], 300000);
    });

    test('recalculates balances up to the requested as-of date only', () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final ledger = LedgerRepository(db);

      await _seedAccounts(accounts);
      await _seedPostedMarchTransactions(transactions);
      await _seedPostedAprilTransactions(transactions);
      await _seedIgnoredTransactions(transactions);

      final balances = await ledger.calculateAccountBalances(
        asOfDateInclusive: '2026-03-31',
      );

      expect(balances['asset:bank:main'], 245800);
      expect(balances['asset:bank:savings'], 50000);
      expect(balances['liability:card:main'], 0);
      expect(balances['expense:food'], 1200);
      expect(balances['expense:rent'], 3000);
      expect(balances['income:salary'], 300000);
    });

    test('recalculates monthly summary from posted transactions only',
        () async {
      final db = _openDb();
      addTearDown(db.close);
      final accounts = AccountRepository(db);
      final transactions = TransactionRepository(db);
      final ledger = LedgerRepository(db);

      await _seedAccounts(accounts);
      await _seedPostedMarchTransactions(transactions);
      await _seedPostedAprilTransactions(transactions);
      await _seedIgnoredTransactions(transactions);

      final summary = await ledger.calculateMonthlySummary('2026-03');

      expect(summary.month, '2026-03');
      expect(summary.assetsStart, 0);
      expect(summary.liabilitiesStart, 0);
      expect(summary.assetsEnd, 295800);
      expect(summary.liabilitiesEnd, 0);
      expect(summary.netAssetsStart, 0);
      expect(summary.netAssetsEnd, 295800);
      expect(summary.expenseTotals['food'], 1200);
      expect(summary.expenseTotals['rent'], 3000);
      expect(summary.incomeTotals['salary'], 300000);
      expect(summary.transferTotals['savings'], 50000);
      expect(summary.cashOutExpenses, 1200);
      expect(summary.accruedExpenses, 3000);
      expect(summary.liabilityDue, 0);
      expect(summary.cardPayment, 3000);
      expect(summary.assetsEnd, 295800);
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

Future<void> _seedAccounts(AccountRepository accounts) async {
  await accounts.createAccount(
    _sampleAccount(accountId: 'asset:bank:main', name: 'main'),
  );
  await accounts.createAccount(
    _sampleAccount(accountId: 'asset:bank:savings', name: 'savings'),
  );
  await accounts.createAccount(
    _sampleAccount(accountId: 'expense:food', name: 'food'),
  );
  await accounts.createAccount(
    _sampleAccount(accountId: 'expense:rent', name: 'rent'),
  );
  await accounts.createAccount(
    _sampleAccount(accountId: 'income:salary', name: 'salary'),
  );
  await accounts.createAccount(
    _sampleAccount(accountId: 'liability:card:main', name: 'card'),
  );
}

Future<void> _seedPostedMarchTransactions(
  TransactionRepository transactions,
) async {
  await transactions.createTransaction(
    _sampleTransaction(transactionId: 'txn_expense', date: '2026-03-05'),
    <ChoboEntryRecord>[
      const ChoboEntryRecord(
        entryId: 'ent_expense_cash',
        transactionId: 'txn_expense',
        accountId: 'asset:bank:main',
        direction: 'decrease',
        amount: 1200,
      ),
      const ChoboEntryRecord(
        entryId: 'ent_expense_food',
        transactionId: 'txn_expense',
        accountId: 'expense:food',
        direction: 'increase',
        amount: 1200,
      ),
    ],
  );

  await transactions.createTransaction(
    _sampleTransaction(
        transactionId: 'txn_transfer', date: '2026-03-10', type: 'transfer'),
    <ChoboEntryRecord>[
      const ChoboEntryRecord(
        entryId: 'ent_transfer_cash',
        transactionId: 'txn_transfer',
        accountId: 'asset:bank:main',
        direction: 'decrease',
        amount: 50000,
      ),
      const ChoboEntryRecord(
        entryId: 'ent_transfer_savings',
        transactionId: 'txn_transfer',
        accountId: 'asset:bank:savings',
        direction: 'increase',
        amount: 50000,
      ),
    ],
  );

  await transactions.createTransaction(
    _sampleTransaction(
        transactionId: 'txn_income', date: '2026-03-15', type: 'income'),
    <ChoboEntryRecord>[
      const ChoboEntryRecord(
        entryId: 'ent_income_cash',
        transactionId: 'txn_income',
        accountId: 'asset:bank:main',
        direction: 'increase',
        amount: 300000,
      ),
      const ChoboEntryRecord(
        entryId: 'ent_income_salary',
        transactionId: 'txn_income',
        accountId: 'income:salary',
        direction: 'increase',
        amount: 300000,
      ),
    ],
  );

  await transactions.createTransaction(
    _sampleTransaction(
      transactionId: 'txn_credit',
      date: '2026-03-18',
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
        entryId: 'ent_credit_rent',
        transactionId: 'txn_credit',
        accountId: 'expense:rent',
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
        entryId: 'ent_payment_cash',
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
}

Future<void> _seedIgnoredTransactions(
  TransactionRepository transactions,
) async {
  await transactions.createTransaction(
    _sampleTransaction(
      transactionId: 'txn_pending',
      date: '2026-03-21',
      status: 'pending',
    ),
    <ChoboEntryRecord>[
      const ChoboEntryRecord(
        entryId: 'ent_pending_cash',
        transactionId: 'txn_pending',
        accountId: 'asset:bank:main',
        direction: 'decrease',
        amount: 9999,
      ),
      const ChoboEntryRecord(
        entryId: 'ent_pending_food',
        transactionId: 'txn_pending',
        accountId: 'expense:food',
        direction: 'increase',
        amount: 9999,
      ),
    ],
  );

  await transactions.createTransaction(
    _sampleTransaction(
      transactionId: 'txn_void',
      date: '2026-03-22',
      type: 'transfer',
    ),
    <ChoboEntryRecord>[
      const ChoboEntryRecord(
        entryId: 'ent_void_cash',
        transactionId: 'txn_void',
        accountId: 'asset:bank:main',
        direction: 'decrease',
        amount: 1111,
      ),
      const ChoboEntryRecord(
        entryId: 'ent_void_savings',
        transactionId: 'txn_void',
        accountId: 'asset:bank:savings',
        direction: 'increase',
        amount: 1111,
      ),
    ],
  );
  await transactions.voidTransaction(
    'txn_void',
    updatedAt: '2026-03-22T09:30:00Z',
  );
}

Future<void> _seedPostedAprilTransactions(
  TransactionRepository transactions,
) async {
  await transactions.createTransaction(
    _sampleTransaction(
      transactionId: 'txn_april',
      date: '2026-04-01',
      type: 'expense',
    ),
    <ChoboEntryRecord>[
      const ChoboEntryRecord(
        entryId: 'ent_april_cash',
        transactionId: 'txn_april',
        accountId: 'asset:bank:main',
        direction: 'decrease',
        amount: 99999,
      ),
      const ChoboEntryRecord(
        entryId: 'ent_april_food',
        transactionId: 'txn_april',
        accountId: 'expense:food',
        direction: 'increase',
        amount: 99999,
      ),
    ],
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
  String status = 'posted',
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: date,
    type: type,
    status: status,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}
