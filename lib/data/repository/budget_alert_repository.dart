import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class BudgetAlertRepository {
  BudgetAlertRepository(this._db);

  final AppDatabase _db;

  Future<void> createAlert(ChoboBudgetAlertRecord alert) async {
    await _db.customInsert(
      '''
      INSERT INTO budget_alerts (
        alert_id,
        budget_id,
        triggered_at,
        actual_amount,
        budget_amount,
        threshold_percent,
        notified
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(alert.alertId),
        Variable(alert.budgetId),
        Variable(alert.triggeredAt),
        Variable(alert.actualAmount),
        Variable(alert.budgetAmount),
        Variable(alert.thresholdPercent),
        Variable(alert.notified ? 1 : 0),
      ],
    );
  }

  Future<List<ChoboBudgetAlertRecord>> listAlertsForBudget(
    String budgetId, {
    int limit = 10,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT alert_id, budget_id, triggered_at, actual_amount,
             budget_amount, threshold_percent, notified
      FROM budget_alerts
      WHERE budget_id = ?
      ORDER BY triggered_at DESC
      LIMIT ?
      ''',
      variables: <Variable>[
        Variable(budgetId),
        Variable(limit),
      ],
    ).get();
    return rows.map(ChoboBudgetAlertRecord.fromRow).toList(growable: false);
  }

  Future<List<ChoboBudgetAlertRecord>> listRecentAlerts({
    int limit = 20,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT alert_id, budget_id, triggered_at, actual_amount,
             budget_amount, threshold_percent, notified
      FROM budget_alerts
      ORDER BY triggered_at DESC
      LIMIT ?
      ''',
      variables: <Variable>[Variable(limit)],
    ).get();
    return rows.map(ChoboBudgetAlertRecord.fromRow).toList(growable: false);
  }

  Future<List<ChoboBudgetAlertRecord>> listUnnotifiedAlerts() async {
    final rows = await _db.customSelect(
      '''
      SELECT alert_id, budget_id, triggered_at, actual_amount,
             budget_amount, threshold_percent, notified
      FROM budget_alerts
      WHERE notified = 0
      ORDER BY triggered_at DESC
      ''',
    ).get();
    return rows.map(ChoboBudgetAlertRecord.fromRow).toList(growable: false);
  }

  Future<int> markAsNotified(String alertId) async {
    return _db.customUpdate(
      'UPDATE budget_alerts SET notified = 1 WHERE alert_id = ?',
      variables: <Variable>[Variable(alertId)],
    );
  }

  Future<int> markAllAsNotified(List<String> alertIds) async {
    if (alertIds.isEmpty) return 0;

    final placeholders = alertIds.map((_) => '?').join(',');
    return _db.customUpdate(
      'UPDATE budget_alerts SET notified = 1 WHERE alert_id IN ($placeholders)',
      variables: alertIds.map((id) => Variable(id)).toList(),
    );
  }

  Future<bool> hasRecentAlertForBudget(String budgetId, String since) async {
    final row = await _db.customSelect(
      '''
      SELECT 1 AS has_alert
      FROM budget_alerts
      WHERE budget_id = ? AND triggered_at >= ?
      LIMIT 1
      ''',
      variables: <Variable>[
        Variable(budgetId),
        Variable(since),
      ],
    ).getSingleOrNull();
    return row != null;
  }

  Future<int> deleteAlert(String alertId) {
    return _db.customUpdate(
      'DELETE FROM budget_alerts WHERE alert_id = ?',
      variables: <Variable>[Variable(alertId)],
    );
  }

  Future<int> deleteAlertsForBudget(String budgetId) {
    return _db.customUpdate(
      'DELETE FROM budget_alerts WHERE budget_id = ?',
      variables: <Variable>[Variable(budgetId)],
    );
  }
}
