import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  Future<void> createBudget(ChoboBudgetRecord budget) async {
    await _db.customInsert(
      '''
      INSERT INTO budgets (
        budget_id,
        account_id,
        month,
        amount,
        alert_threshold_percent,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(budget.budgetId),
        Variable(budget.accountId),
        Variable(budget.month),
        Variable(budget.amount),
        Variable(budget.alertThresholdPercent),
        Variable(budget.createdAt),
        Variable(budget.updatedAt),
      ],
    );
  }

  Future<ChoboBudgetRecord?> getBudget(String budgetId) async {
    final row = await _db.customSelect(
      '''
      SELECT budget_id, account_id, month, amount, alert_threshold_percent,
             created_at, updated_at
      FROM budgets
      WHERE budget_id = ?
      ''',
      variables: <Variable>[Variable(budgetId)],
    ).getSingleOrNull();
    return row == null ? null : ChoboBudgetRecord.fromRow(row);
  }

  Future<ChoboBudgetRecord?> getBudgetByAccountAndMonth(
    String accountId,
    String month,
  ) async {
    final row = await _db.customSelect(
      '''
      SELECT budget_id, account_id, month, amount, alert_threshold_percent,
             created_at, updated_at
      FROM budgets
      WHERE account_id = ? AND month = ?
      ''',
      variables: <Variable>[
        Variable(accountId),
        Variable(month),
      ],
    ).getSingleOrNull();
    return row == null ? null : ChoboBudgetRecord.fromRow(row);
  }

  Future<List<ChoboBudgetRecord>> listBudgetsForMonth(String month) async {
    final rows = await _db.customSelect(
      '''
      SELECT budget_id, account_id, month, amount, alert_threshold_percent,
             created_at, updated_at
      FROM budgets
      WHERE month = ?
      ORDER BY account_id
      ''',
      variables: <Variable>[Variable(month)],
    ).get();
    return rows.map(ChoboBudgetRecord.fromRow).toList(growable: false);
  }

  Future<List<ChoboBudgetRecord>> listBudgetsForAccount(
    String accountId,
  ) async {
    final rows = await _db.customSelect(
      '''
      SELECT budget_id, account_id, month, amount, alert_threshold_percent,
             created_at, updated_at
      FROM budgets
      WHERE account_id = ?
      ORDER BY month DESC
      ''',
      variables: <Variable>[Variable(accountId)],
    ).get();
    return rows.map(ChoboBudgetRecord.fromRow).toList(growable: false);
  }

  Future<int> updateBudget(ChoboBudgetRecord budget,
      {String? expectedUpdatedAt}) async {
    if (expectedUpdatedAt != null) {
      return _db.customUpdate(
        '''
        UPDATE budgets
        SET amount = ?,
            alert_threshold_percent = ?,
            updated_at = ?
        WHERE budget_id = ? AND updated_at = ?
        ''',
        variables: <Variable>[
          Variable(budget.amount),
          Variable(budget.alertThresholdPercent),
          Variable(budget.updatedAt),
          Variable(budget.budgetId),
          Variable(expectedUpdatedAt),
        ],
      );
    }
    return _db.customUpdate(
      '''
      UPDATE budgets
      SET amount = ?,
          alert_threshold_percent = ?,
          updated_at = ?
      WHERE budget_id = ?
      ''',
      variables: <Variable>[
        Variable(budget.amount),
        Variable(budget.alertThresholdPercent),
        Variable(budget.updatedAt),
        Variable(budget.budgetId),
      ],
    );
  }

  Future<int> deleteBudget(String budgetId) {
    return _db.customUpdate(
      'DELETE FROM budgets WHERE budget_id = ?',
      variables: <Variable>[Variable(budgetId)],
    );
  }

  Future<void> upsertBudget(ChoboBudgetRecord budget) async {
    final existing = await getBudgetByAccountAndMonth(
      budget.accountId,
      budget.month,
    );
    if (existing != null) {
      final updated = await updateBudget(
        budget.copyWith(
          budgetId: existing.budgetId,
          createdAt: existing.createdAt,
        ),
        expectedUpdatedAt: existing.updatedAt,
      );
      if (updated == 0) {
        throw ConcurrencyException(
          'Budget was modified by another process. Please retry.',
        );
      }
    } else {
      await createBudget(budget);
    }
  }
}

class ConcurrencyException implements Exception {
  const ConcurrencyException(this.message);
  final String message;

  @override
  String toString() => 'ConcurrencyException: $message';
}
