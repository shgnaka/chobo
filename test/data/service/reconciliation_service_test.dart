import 'package:chobo/chobo.dart';
import 'package:chobo/core/audit_event_factory.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records reconciliation results as audit events', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    addTearDown(db.close);

    final accounts = AccountRepository(db);
    final transactions = TransactionRepository(db);
    final audits = AuditEventRepository(db);
    final auditFactory = AuditEventFactory(audits);
    final service = ReconciliationService(
      ledgerRepository: LedgerRepository(db),
      auditEventFactory: auditFactory,
      now: () => '2026-03-20T12:00:00Z',
    );

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

    final result = await service.completeReconciliation(
      accountId: 'asset:bank:main',
      actualBalance: -1200,
    );

    expect(result.accountId, 'asset:bank:main');
    expect(result.bookBalance, -1200);
    expect(result.actualBalance, -1200);
    expect(result.difference, 0);
    expect(result.isBalanced, isTrue);

    final events = await audits.listEvents(targetId: 'asset:bank:main');
    expect(events, hasLength(1));
    expect(events.single.eventType, 'account_reconciled');
  });
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
