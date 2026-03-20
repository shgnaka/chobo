import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/ledger_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:chobo/data/service/monthly_summary_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: date,
    type: 'expense',
    status: 'posted',
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}
