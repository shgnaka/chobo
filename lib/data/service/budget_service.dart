import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../repository/account_repository.dart';
import '../repository/budget_repository.dart';

class BudgetService {
  BudgetService(
    this._budgetRepository,
    this._accountRepository,
    this._db,
  );

  final BudgetRepository _budgetRepository;
  final AccountRepository _accountRepository;
  final AppDatabase _db;

  Future<MonthlyBudgetDto> getMonthlyBudget(String month) async {
    final budgets = await _budgetRepository.listBudgetsForMonth(month);
    final actualSpending = await _getActualSpendingByAccount(month);
    final totalBudget = budgets.fold<int>(0, (sum, b) => sum + b.amount);
    final totalActual = budgets.fold<int>(
      0,
      (sum, b) => sum + (actualSpending[b.accountId] ?? 0),
    );

    return MonthlyBudgetDto(
      month: month,
      totalBudget: totalBudget,
      totalActual: totalActual,
      totalRemaining: totalBudget - totalActual,
      categories: await _buildCategoryComparisons(budgets, actualSpending),
    );
  }

  Future<List<BudgetComparisonDto>> getBudgetComparisons(String month) async {
    final budgets = await _budgetRepository.listBudgetsForMonth(month);
    final actualSpending = await _getActualSpendingByAccount(month);
    return _buildCategoryComparisons(budgets, actualSpending);
  }

  Future<BudgetComparisonDto?> getBudgetComparison(
    String budgetId,
    String month,
  ) async {
    final budget = await _budgetRepository.getBudget(budgetId);
    if (budget == null) return null;
    final actualSpending = await _getActualSpendingByAccount(month);
    final actual = actualSpending[budget.accountId] ?? 0;
    return _buildComparison(budget, actual);
  }

  Future<List<BudgetComparisonDto>> _buildCategoryComparisons(
    List<ChoboBudgetRecord> budgets,
    Map<String, int> actualSpending,
  ) async {
    final accounts = await _accountRepository.listAccounts();
    final accountMap = {for (final a in accounts) a.accountId: a};

    final comparisons = <BudgetComparisonDto>[];
    for (final budget in budgets) {
      final actual = actualSpending[budget.accountId] ?? 0;
      final account = accountMap[budget.accountId];
      comparisons.add(_buildComparison(budget, actual, account?.name));
    }
    return comparisons;
  }

  BudgetComparisonDto _buildComparison(
    ChoboBudgetRecord budget,
    int actual, [
    String? accountName,
  ]) {
    final percentUsed =
        budget.amount > 0 ? (actual * 100 / budget.amount).round() : 0;
    final isOverBudget = actual > budget.amount;
    final isNearLimit = !isOverBudget &&
        budget.amount > 0 &&
        percentUsed >= budget.alertThresholdPercent;

    return BudgetComparisonDto(
      budgetId: budget.budgetId,
      accountId: budget.accountId,
      accountName: accountName ?? budget.accountId,
      month: budget.month,
      budgetAmount: budget.amount,
      actualAmount: actual,
      remaining: budget.amount - actual,
      percentUsed: percentUsed,
      alertThreshold: budget.alertThresholdPercent,
      isOverBudget: isOverBudget,
      isNearLimit: isNearLimit,
    );
  }

  Future<Map<String, int>> _getActualSpendingByAccount(String month) async {
    final bounds = _MonthBounds.fromYearMonth(month);
    final rows = await _db.customSelect(
      '''
      SELECT e.account_id AS account_id,
             e.amount AS amount
      FROM entries e
      JOIN transactions t ON t.transaction_id = e.transaction_id
      JOIN accounts a ON a.account_id = e.account_id
      WHERE t.status = 'posted'
        AND t.date >= ?
        AND t.date < ?
        AND a.kind = 'expense'
      ORDER BY t.date, t.transaction_id, e.entry_id
      ''',
      variables: <Variable>[
        Variable(bounds.start),
        Variable(bounds.nextMonthStart),
      ],
    ).get();

    final result = <String, int>{};
    for (final row in rows) {
      final accountId = row.read<String>('account_id');
      final amount = row.read<int>('amount');
      result[accountId] = (result[accountId] ?? 0) + amount;
    }
    return result;
  }

  Future<void> createBudget(ChoboBudgetRecord budget) {
    return _budgetRepository.createBudget(budget);
  }

  Future<void> updateBudget(ChoboBudgetRecord budget) {
    return _budgetRepository.updateBudget(budget);
  }

  Future<void> upsertBudget(ChoboBudgetRecord budget) {
    return _budgetRepository.upsertBudget(budget);
  }

  Future<void> deleteBudget(String budgetId) {
    return _budgetRepository.deleteBudget(budgetId);
  }

  Future<List<ChoboBudgetRecord>> listBudgetsForMonth(String month) {
    return _budgetRepository.listBudgetsForMonth(month);
  }
}

class MonthlyBudgetDto {
  const MonthlyBudgetDto({
    required this.month,
    required this.totalBudget,
    required this.totalActual,
    required this.totalRemaining,
    required this.categories,
  });

  final String month;
  final int totalBudget;
  final int totalActual;
  final int totalRemaining;
  final List<BudgetComparisonDto> categories;

  int get percentUsed =>
      totalBudget > 0 ? (totalActual * 100 / totalBudget).round() : 0;
  bool get isOverBudget => totalActual > totalBudget;
}

class BudgetComparisonDto {
  const BudgetComparisonDto({
    required this.budgetId,
    required this.accountId,
    required this.accountName,
    required this.month,
    required this.budgetAmount,
    required this.actualAmount,
    required this.remaining,
    required this.percentUsed,
    required this.alertThreshold,
    required this.isOverBudget,
    required this.isNearLimit,
  });

  final String budgetId;
  final String accountId;
  final String accountName;
  final String month;
  final int budgetAmount;
  final int actualAmount;
  final int remaining;
  final int percentUsed;
  final int alertThreshold;
  final bool isOverBudget;
  final bool isNearLimit;
}

class _MonthBounds {
  const _MonthBounds({
    required this.month,
    required this.start,
    required this.end,
    required this.nextMonthStart,
    required this.previousDay,
  });

  final String month;
  final String start;
  final String end;
  final String nextMonthStart;
  final String previousDay;

  factory _MonthBounds.fromYearMonth(String month) {
    final monthStart = DateTime.parse('$month-01');
    final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
    final previousDay = monthStart.subtract(const Duration(days: 1));

    return _MonthBounds(
      month: month,
      start: _dateOnly(monthStart),
      end: _dateOnly(nextMonthStart.subtract(const Duration(days: 1))),
      nextMonthStart: _dateOnly(nextMonthStart),
      previousDay: _dateOnly(previousDay),
    );
  }

  static String _dateOnly(DateTime dateTime) {
    return dateTime.toIso8601String().substring(0, 10);
  }
}
