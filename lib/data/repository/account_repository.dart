import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

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
        parent_account_id,
        is_default,
        is_archived,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: _accountVariables(account),
    );
  }

  Future<ChoboAccountRecord?> getAccount(String accountId) async {
    final row = await _db.customSelect(
      '''
      SELECT account_id, kind, name, parent_account_id, is_default, is_archived,
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
      SELECT account_id, kind, name, parent_account_id, is_default, is_archived,
             created_at, updated_at
      FROM accounts
      ORDER BY is_default DESC, name, account_id
      ''',
    ).get();
    return rows.map(ChoboAccountRecord.fromRow).toList(growable: false);
  }

  Future<int> updateAccount(ChoboAccountRecord account) {
    return _db.customUpdate(
      '''
      UPDATE accounts
      SET kind = ?,
          name = ?,
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
        Variable(account.parentAccountId),
        Variable(account.isDefault ? 1 : 0),
        Variable(account.isArchived ? 1 : 0),
        Variable(account.createdAt),
        Variable(account.updatedAt),
        Variable(account.accountId),
      ],
    );
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
      Variable(account.parentAccountId),
      Variable(account.isDefault ? 1 : 0),
      Variable(account.isArchived ? 1 : 0),
      Variable(account.createdAt),
      Variable(account.updatedAt),
    ];
  }
}
