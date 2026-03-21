import '../local_db/chobo_records.dart';
import '../repository/points_repository.dart';

class PointsCalculationService {
  PointsCalculationService(this._pointsRepository);

  final PointsRepository _pointsRepository;

  Future<PointsSummary> getPointsSummary() async {
    final accounts = await _pointsRepository.listPointsAccounts();
    final balances = await _pointsRepository.getAllPointsBalances();

    final accountSummaries = <PointsAccountSummary>[];
    int totalPointsValue = 0;

    for (final account in accounts) {
      final balance = balances[account.pointsAccountId] ??
          ChoboPointsBalanceRecord(
            pointsAccountId: account.pointsAccountId,
            totalEarned: 0,
            totalRedeemed: 0,
            totalExpired: 0,
            totalAdjusted: 0,
            currentBalance: 0,
          );

      final pointsValue =
          await _calculateJpyValue(account, balance.currentBalance);
      totalPointsValue += pointsValue;

      accountSummaries.add(PointsAccountSummary(
        account: account,
        balance: balance,
        jpyValue: pointsValue,
      ));
    }

    return PointsSummary(
      accountSummaries: accountSummaries,
      totalPointsValue: totalPointsValue,
    );
  }

  Future<int> _calculateJpyValue(
    ChoboPointsAccountRecord account,
    int points,
  ) async {
    return (points * account.exchangeRate).round();
  }

  Future<List<PointsExpirationWarning>> checkExpiringPoints({
    required String pointsAccountId,
    required int warningDaysThreshold,
  }) async {
    final warnings = <PointsExpirationWarning>[];

    final expiringPoints = await _pointsRepository.getExpiringPoints(
      pointsAccountId: pointsAccountId,
      daysThreshold: warningDaysThreshold,
    );

    if (expiringPoints.isEmpty) {
      return warnings;
    }

    final totalExpiring = expiringPoints.fold<int>(
      0,
      (sum, t) => sum + t.pointsAmount,
    );

    DateTime earliestExpiration = DateTime.now();
    for (final point in expiringPoints) {
      if (point.expirationDate != null) {
        final expDate = DateTime.parse(point.expirationDate!);
        if (expDate.isBefore(earliestExpiration)) {
          earliestExpiration = expDate;
        }
      }
    }

    warnings.add(PointsExpirationWarning(
      pointsAccountId: pointsAccountId,
      availablePoints: totalExpiring,
      warningDate: earliestExpiration,
    ));

    return warnings;
  }

  Future<int> estimateMonthlyEarning({
    required String pointsAccountId,
    int lookbackMonths = 3,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - lookbackMonths, 1)
        .toUtc()
        .toIso8601String()
        .substring(0, 10);

    final transactions = await _pointsRepository.listPointsTransactions(
      pointsAccountId,
      dateFrom: startDate,
    );

    final earnedTransactions =
        transactions.where((t) => t.direction == 'earned').toList();

    if (earnedTransactions.isEmpty) {
      return 0;
    }

    final totalEarned = earnedTransactions.fold<int>(
      0,
      (sum, t) => sum + t.pointsAmount,
    );

    return (totalEarned / lookbackMonths).round();
  }
}

class PointsSummary {
  const PointsSummary({
    required this.accountSummaries,
    required this.totalPointsValue,
  });

  final List<PointsAccountSummary> accountSummaries;
  final int totalPointsValue;

  int get totalPoints => accountSummaries.fold(
        0,
        (sum, a) => sum + a.balance.currentBalance,
      );

  int get accountCount => accountSummaries.length;
}

class PointsAccountSummary {
  const PointsAccountSummary({
    required this.account,
    required this.balance,
    required this.jpyValue,
  });

  final ChoboPointsAccountRecord account;
  final ChoboPointsBalanceRecord balance;
  final int jpyValue;
}

class PointsExpirationWarning {
  const PointsExpirationWarning({
    required this.pointsAccountId,
    required this.availablePoints,
    required this.warningDate,
  });

  final String pointsAccountId;
  final int availablePoints;
  final DateTime warningDate;
}
