import '../local_db/chobo_records.dart';
import '../repository/budget_alert_repository.dart';
import '../repository/budget_repository.dart';
import 'budget_service.dart';
import 'notification_service.dart';

class BudgetAlertService {
  BudgetAlertService(
    this._budgetAlertRepository,
    this._budgetRepository,
    this._budgetService,
    this._notificationService,
  );

  final BudgetAlertRepository _budgetAlertRepository;
  final BudgetRepository _budgetRepository;
  final BudgetService _budgetService;
  final NotificationService _notificationService;

  static const _alertCooldownHours = 24;

  Future<List<BudgetAlertDto>> checkBudgetAlerts(String month) async {
    final triggeredAlerts = <BudgetAlertDto>[];
    final budgets = await _budgetRepository.listBudgetsForMonth(month);

    for (final budget in budgets) {
      final comparison = await _budgetService.getBudgetComparison(
        budget.budgetId,
        month,
      );

      if (comparison == null) continue;

      if (comparison.isOverBudget) {
        final shouldTrigger = await _shouldTriggerAlert(budget.budgetId);
        if (shouldTrigger) {
          final alert = await _createAlert(
            budget,
            comparison.actualAmount,
            isThreshold: false,
          );
          triggeredAlerts.add(alert);
        }
      } else if (comparison.isNearLimit) {
        final shouldTrigger = await _shouldTriggerAlert(budget.budgetId);
        if (shouldTrigger) {
          final alert = await _createAlert(
            budget,
            comparison.actualAmount,
            isThreshold: true,
          );
          triggeredAlerts.add(alert);
        }
      }
    }

    return triggeredAlerts;
  }

  Future<List<BudgetAlertDto>> checkAndNotifyAlerts(String month) async {
    final triggeredAlerts = await checkBudgetAlerts(month);

    for (final alert in triggeredAlerts) {
      await _notificationService.showBudgetAlert(alert);
    }

    return triggeredAlerts;
  }

  Future<bool> _shouldTriggerAlert(String budgetId) async {
    final cooldownStart = DateTime.now()
        .subtract(const Duration(hours: _alertCooldownHours))
        .toUtc()
        .toIso8601String();

    return !(await _budgetAlertRepository.hasRecentAlertForBudget(
      budgetId,
      cooldownStart,
    ));
  }

  Future<BudgetAlertDto> _createAlert(
    ChoboBudgetRecord budget,
    int actualAmount, {
    required bool isThreshold,
  }) async {
    final alertRecord = ChoboBudgetAlertRecord(
      alertId: _generateId(),
      budgetId: budget.budgetId,
      triggeredAt: DateTime.now().toUtc().toIso8601String(),
      actualAmount: actualAmount,
      budgetAmount: budget.amount,
      thresholdPercent: budget.alertThresholdPercent,
      notified: false,
    );

    await _budgetAlertRepository.createAlert(alertRecord);

    return BudgetAlertDto(
      alertId: alertRecord.alertId,
      budgetId: budget.budgetId,
      accountId: budget.accountId,
      month: budget.month,
      actualAmount: actualAmount,
      budgetAmount: budget.amount,
      thresholdPercent: budget.alertThresholdPercent,
      percentUsed:
          budget.amount > 0 ? (actualAmount * 100 / budget.amount).round() : 0,
      triggeredAt: alertRecord.triggeredAt,
      isThreshold: isThreshold,
    );
  }

  Future<List<ChoboBudgetAlertRecord>> getRecentAlerts({
    int limit = 20,
  }) {
    return _budgetAlertRepository.listRecentAlerts(limit: limit);
  }

  Future<List<ChoboBudgetAlertRecord>> getAlertsForBudget(
    String budgetId, {
    int limit = 10,
  }) {
    return _budgetAlertRepository.listAlertsForBudget(
      budgetId,
      limit: limit,
    );
  }

  Future<void> dismissAlert(String alertId) async {
    await _budgetAlertRepository.markAsNotified(alertId);
  }

  String _generateId() {
    return 'alert_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class BudgetAlertDto {
  const BudgetAlertDto({
    required this.alertId,
    required this.budgetId,
    required this.accountId,
    required this.month,
    required this.actualAmount,
    required this.budgetAmount,
    required this.thresholdPercent,
    required this.percentUsed,
    required this.triggeredAt,
    required this.isThreshold,
  });

  final String alertId;
  final String budgetId;
  final String accountId;
  final String month;
  final int actualAmount;
  final int budgetAmount;
  final int thresholdPercent;
  final int percentUsed;
  final String triggeredAt;
  final bool isThreshold;

  int get overspentAmount => actualAmount - budgetAmount;
}
