import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../local_db/chobo_standard_accounts.dart';

class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

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
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: _accountVariables(account),
    );
  }

  Future<void> archiveAccount(
    String accountId, {
    String? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc().toIso8601String();
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
             created_at, updated_at
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
             created_at, updated_at
      FROM accounts
      ORDER BY is_default DESC, name, account_id
      ''',
    ).get();
    return rows.map(ChoboAccountRecord.fromRow).toList(growable: false);
  }

  Future<int> updateAccount(ChoboAccountRecord account) {
    return _db.transaction(() async {
      final existing = await getAccount(account.accountId);
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
          Variable(account.createdAt),
          Variable(account.updatedAt),
          Variable(account.accountId),
        ],
      );
    });
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
