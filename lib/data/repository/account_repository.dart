import 'package:drift/drift.dart';

import '../../core/audit_event_factory.dart';
import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../local_db/chobo_standard_accounts.dart';

class AccountRepository {
  AccountRepository(
    this._db, {
    AuditEventFactory? auditEventFactory,
  }) : _auditEventFactory = auditEventFactory;

  final AppDatabase _db;
  final AuditEventFactory? _auditEventFactory;

  Future<void> createAccount(ChoboAccountRecord account) async {
    await _db.customInsert(
      '''
      INSERT INTO accounts (
        account_id,
        kind,
        name,
        currency,
        parent_account_id,
        is_default,
        is_archived,
        billing_day,
        payment_due_day,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: _accountVariables(account),
    );

    if (_auditEventFactory != null) {
      await _auditEventFactory.recordAccountCreated(
        accountId: account.accountId,
        name: account.name,
        kind: account.kind,
      );
    }
  }

  Future<void> archiveAccount(
    String accountId, {
    String? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc().toIso8601String();
    final existing = await getAccount(accountId);

    final updated = await _db.customUpdate(
      '''
      UPDATE accounts
      SET is_archived = 1,
          updated_at = ?
      WHERE account_id = ?
      ''',
      variables: <Variable>[
        Variable(now),
        Variable(accountId),
      ],
    );
    if (updated == 0) {
      throw StateError('Account $accountId was not found.');
    }

    if (_auditEventFactory != null && existing != null) {
      await _auditEventFactory.recordAccountArchived(
        accountId: accountId,
        name: existing.name,
      );
    }
  }

  Future<int> restoreDefaultAccounts({
    String? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now().toUtc().toIso8601String();
    var inserted = 0;
    for (final definition in ChoboStandardAccounts.definitions) {
      final existing = await getAccount(definition.accountId);
      if (existing != null) {
        continue;
      }
      await createAccount(
        ChoboAccountRecord(
          accountId: definition.accountId,
          kind: definition.kind,
          name: definition.displayName,
          isDefault: true,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      inserted += 1;
    }
    return inserted;
  }

  Future<ChoboAccountRecord?> getAccount(String accountId) async {
    final row = await _db.customSelect(
      '''
      SELECT account_id, kind, name, currency, parent_account_id, is_default, is_archived,
             billing_day, payment_due_day, created_at, updated_at
      FROM accounts
      WHERE account_id = ?
      ''',
      variables: <Variable>[Variable(accountId)],
    ).getSingleOrNull();
    return row == null ? null : ChoboAccountRecord.fromRow(row);
  }

  Future<List<ChoboAccountRecord>> listAccounts() async {
    final rows = await _db.customSelect(
      '''
      SELECT account_id, kind, name, currency, parent_account_id, is_default, is_archived,
             billing_day, payment_due_day, created_at, updated_at
      FROM accounts
      ORDER BY is_default DESC, name, account_id
      ''',
    ).get();
    return rows.map(ChoboAccountRecord.fromRow).toList(growable: false);
  }

  Future<int> updateAccount(ChoboAccountRecord account) async {
    final existing = await getAccount(account.accountId);
    final changedFields = <String>[];

    if (existing != null) {
      if (existing.name != account.name) changedFields.add('name');
      if (existing.currency != account.currency) changedFields.add('currency');
      if (existing.isArchived != account.isArchived)
        changedFields.add('is_archived');
      if (existing.billingDay != account.billingDay)
        changedFields.add('billing_day');
      if (existing.paymentDueDay != account.paymentDueDay)
        changedFields.add('payment_due_day');
    }

    final result = await _db.transaction(() async {
      if (existing == null) {
        throw StateError('Account ${account.accountId} was not found.');
      }
      if (existing.kind != account.kind &&
          (existing.isDefault || await _hasTransactions(account.accountId))) {
        throw StateError(
          'Account ${account.accountId} kind cannot be changed after transactions exist.',
        );
      }

      return _db.customUpdate(
        '''
        UPDATE accounts
        SET kind = ?,
            name = ?,
            currency = ?,
            parent_account_id = ?,
            is_default = ?,
            is_archived = ?,
            billing_day = ?,
            payment_due_day = ?,
            created_at = ?,
            updated_at = ?
        WHERE account_id = ?
        ''',
        variables: <Variable>[
          Variable(account.kind),
          Variable(account.name),
          Variable(account.currency),
          Variable(account.parentAccountId),
          Variable(account.isDefault ? 1 : 0),
          Variable(account.isArchived ? 1 : 0),
          Variable(account.billingDay),
          Variable(account.paymentDueDay),
          Variable(account.createdAt),
          Variable(account.updatedAt),
          Variable(account.accountId),
        ],
      );
    });

    if (_auditEventFactory != null && changedFields.isNotEmpty) {
      await _auditEventFactory.recordAccountUpdated(
        accountId: account.accountId,
        changedFields: changedFields,
      );
    }

    return result;
  }

  Future<int> deleteAccount(String accountId) {
    return _db.customUpdate(
      'DELETE FROM accounts WHERE account_id = ?',
      variables: <Variable>[Variable(accountId)],
    );
  }

  List<Variable> _accountVariables(ChoboAccountRecord account) {
    return <Variable>[
      Variable(account.accountId),
      Variable(account.kind),
      Variable(account.name),
      Variable(account.currency),
      Variable(account.parentAccountId),
      Variable(account.isDefault ? 1 : 0),
      Variable(account.isArchived ? 1 : 0),
      Variable(account.billingDay),
      Variable(account.paymentDueDay),
      Variable(account.createdAt),
      Variable(account.updatedAt),
    ];
  }

  Future<bool> _hasTransactions(String accountId) async {
    final row = await _db.customSelect(
      '''
      SELECT 1 AS has_transactions
      FROM entries
      WHERE account_id = ?
      LIMIT 1
      ''',
      variables: <Variable>[Variable(accountId)],
    ).getSingleOrNull();
    return row != null;
  }
}
