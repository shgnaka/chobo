import 'dart:convert';

import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../repository/recurring_template_repository.dart';

class ForecastService {
  ForecastService(
    this._db,
    this._recurringTemplateRepository,
  );

  final AppDatabase _db;
  final RecurringTemplateRepository _recurringTemplateRepository;

  Future<EndOfMonthForecastDto> getEndOfMonthForecast(String month) async {
    final bounds = _MonthBounds.fromYearMonth(month);

    final currentBalance = await _getCurrentAssetBalance();
    final pendingPayments = await _getPendingTransactions(
      bounds.start,
      bounds.nextMonthStart,
    );
    final upcomingRecurring = await _getUpcomingRecurring(
      bounds.nextMonthStart,
    );
    final billingCycles = await _getAccountBillingCycles();
    final dueDateProjections = await _getDueDateProjections(
      pendingPayments,
      billingCycles,
      bounds,
    );

    final totalPendingExpenses = pendingPayments
        .where((p) => p.isExpense)
        .fold<int>(0, (sum, p) => sum + p.amount);
    final totalPendingIncome = pendingPayments
        .where((p) => p.isIncome)
        .fold<int>(0, (sum, p) => sum + p.amount);

    final totalUpcomingExpenses = upcomingRecurring
        .where((r) => r.isExpense)
        .fold<int>(0, (sum, r) => sum + r.amount);
    final totalUpcomingIncome = upcomingRecurring
        .where((r) => r.isIncome)
        .fold<int>(0, (sum, r) => sum + r.amount);

    final predictedExpenses = totalPendingExpenses + totalUpcomingExpenses;
    final predictedIncome = totalPendingIncome + totalUpcomingIncome;
    final forecastBalance =
        currentBalance + predictedIncome - predictedExpenses;

    final dailyForecasts = await _getDailyForecasts(
      month,
      currentBalance,
      pendingPayments,
      upcomingRecurring,
    );

    return EndOfMonthForecastDto(
      month: month,
      currentBalance: currentBalance,
      pendingExpenses: totalPendingExpenses,
      pendingIncome: totalPendingIncome,
      upcomingRecurringExpenses: totalUpcomingExpenses,
      upcomingRecurringIncome: totalUpcomingIncome,
      predictedExpenses: predictedExpenses,
      predictedIncome: predictedIncome,
      forecastBalance: forecastBalance,
      pendingPayments: pendingPayments,
      upcomingRecurring: upcomingRecurring,
      dailyForecasts: dailyForecasts,
      billingCycles: billingCycles,
      dueDateProjections: dueDateProjections,
    );
  }

  Future<int> _getCurrentAssetBalance() async {
    final rows = await _db.customSelect(
      '''
      SELECT COALESCE(SUM(
        CASE
          WHEN e.direction = 'increase' THEN e.amount
          ELSE -e.amount
        END
      ), 0) AS balance
      FROM entries e
      JOIN transactions t ON t.transaction_id = e.transaction_id
      JOIN accounts a ON a.account_id = e.account_id
      WHERE t.status = 'posted'
        AND a.kind = 'asset'
      ''',
    ).getSingle();

    return rows.read<int>('balance');
  }

  Future<List<PendingPaymentDto>> _getPendingTransactions(
    String startDate,
    String endDate,
  ) async {
    final rows = await _db.customSelect(
      '''
      SELECT t.transaction_id,
             t.date,
             t.due_date,
             t.type,
             t.description,
             e.amount,
             a.name AS account_name,
             a.account_id
      FROM transactions t
      JOIN entries e ON e.transaction_id = t.transaction_id
      JOIN accounts a ON a.account_id = e.account_id
      WHERE t.status = 'pending'
        AND t.date >= ?
        AND t.date < ?
        AND a.kind IN ('expense', 'income')
      ORDER BY t.date, t.transaction_id
      ''',
      variables: <Variable>[
        Variable(startDate),
        Variable(endDate),
      ],
    ).get();

    return rows.map((row) {
      final type = row.read<String>('type');
      final isExpense = ['expense', 'credit_expense'].contains(type);
      final isIncome = type == 'income';
      final desc = row.readNullable<String>('description');

      return PendingPaymentDto(
        transactionId: row.read<String>('transaction_id'),
        date: row.read<String>('date'),
        dueDate: row.readNullable<String>('due_date'),
        description: desc ?? '',
        accountName: row.read<String>('account_name'),
        accountId: row.read<String>('account_id'),
        amount: row.read<int>('amount'),
        isExpense: isExpense,
        isIncome: isIncome,
      );
    }).toList(growable: false);
  }

  Future<List<RecurringPaymentDto>> _getUpcomingRecurring(
    String upToDate,
  ) async {
    final templates = await _recurringTemplateRepository.listTemplates(
      activeOnly: true,
    );

    final upcoming = <RecurringPaymentDto>[];
    final now = DateTime.now();

    for (final template in templates) {
      final occurrences = _generateOccurrences(
        template,
        now,
        DateTime.parse(upToDate),
      );

      for (final date in occurrences) {
        final entries = _parseEntriesTemplate(template.entriesTemplate);
        final totalExpense = entries
            .where((e) => e.isExpense)
            .fold<int>(0, (sum, e) => sum + e.amount);
        final totalIncome = entries
            .where((e) => e.isIncome)
            .fold<int>(0, (sum, e) => sum + e.amount);

        upcoming.add(RecurringPaymentDto(
          templateId: template.templateId,
          name: template.name,
          date: _dateOnly(date),
          type: template.transactionType,
          isExpense: totalExpense > 0,
          isIncome: totalIncome > 0,
          amount: totalExpense > 0 ? totalExpense : totalIncome,
        ));
      }
    }

    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  List<DateTime> _generateOccurrences(
    ChoboRecurringTemplateRecord template,
    DateTime from,
    DateTime to,
  ) {
    final occurrences = <DateTime>[];
    final startDate = DateTime.parse(template.startDate);

    if (startDate.isAfter(to)) return occurrences;

    var current = _nextOccurrence(
        startDate, from, template.frequency, template.intervalValue);

    while (!current.isAfter(to)) {
      if (!current.isBefore(from)) {
        occurrences.add(current);
      }
      current = _nextOccurrence(
          current, from, template.frequency, template.intervalValue);
    }

    return occurrences;
  }

  DateTime _nextOccurrence(
    DateTime last,
    DateTime from,
    String frequency,
    int interval,
  ) {
    switch (frequency) {
      case 'daily':
        return last.add(Duration(days: interval));
      case 'weekly':
        return last.add(Duration(days: 7 * interval));
      case 'monthly':
        return DateTime(last.year, last.month + interval, last.day);
      case 'yearly':
        return DateTime(last.year + interval, last.month, last.day);
      default:
        return last.add(Duration(days: 30));
    }
  }

  List<_EntryTemplateItem> _parseEntriesTemplate(String template) {
    try {
      final List<dynamic> entries = json.decode(template);
      return entries.map((e) {
        return _EntryTemplateItem(
          accountId: e['account_id'] as String,
          direction: e['direction'] as String,
          amount: e['amount'] as int,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DailyForecastDto>> _getDailyForecasts(
    String month,
    int startingBalance,
    List<PendingPaymentDto> pendingPayments,
    List<RecurringPaymentDto> upcomingRecurring,
  ) async {
    final forecasts = <DailyForecastDto>[];
    final pendingByDate = <String, int>{};
    final recurringByDate = <String, int>{};

    for (final p in pendingPayments) {
      final effectiveDate = p.effectiveDate;
      pendingByDate[effectiveDate] =
          (pendingByDate[effectiveDate] ?? 0) + p.amount;
    }

    for (final r in upcomingRecurring) {
      if (r.isExpense) {
        recurringByDate[r.date] = (recurringByDate[r.date] ?? 0) + r.amount;
      }
    }

    final bounds = _MonthBounds.fromYearMonth(month);
    var currentDate = DateTime.now();
    var runningBalance = startingBalance;

    while (currentDate.isBefore(DateTime.parse(bounds.nextMonthStart))) {
      final dateStr = _dateOnly(currentDate);
      final pending = pendingByDate[dateStr] ?? 0;
      final recurring = recurringByDate[dateStr] ?? 0;
      final totalDeduction = pending + recurring;

      runningBalance -= totalDeduction;

      forecasts.add(DailyForecastDto(
        date: dateStr,
        predictedBalance: runningBalance,
        pendingAmount: pending,
        recurringAmount: recurring,
      ));

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return forecasts;
  }

  String _dateOnly(DateTime dateTime) {
    return dateTime.toIso8601String().substring(0, 10);
  }

  Future<List<AccountBillingCycleDto>> _getAccountBillingCycles() async {
    final rows = await _db.customSelect(
      '''
      SELECT account_id, name, billing_day, payment_due_day
      FROM accounts
      WHERE billing_day IS NOT NULL
         OR payment_due_day IS NOT NULL
      ORDER BY account_id
      ''',
    ).get();

    return rows.map((row) {
      return AccountBillingCycleDto(
        accountId: row.read<String>('account_id'),
        accountName: row.read<String>('name'),
        billingDay: row.readNullable<int>('billing_day') ?? 0,
        paymentDueDay: row.readNullable<int>('payment_due_day') ?? 0,
      );
    }).toList(growable: false);
  }

  Future<List<DueDateProjectionDto>> _getDueDateProjections(
    List<PendingPaymentDto> pendingPayments,
    List<AccountBillingCycleDto> billingCycles,
    _MonthBounds bounds,
  ) async {
    final dueDateGroups = <String, List<PendingPaymentDto>>{};

    for (final payment in pendingPayments) {
      final effectiveDate = payment.effectiveDate;
      if (effectiveDate.compareTo(bounds.nextMonthStart) >= 0) {
        dueDateGroups.putIfAbsent(effectiveDate, () => []).add(payment);
      }
    }

    final projections = <DueDateProjectionDto>[];
    final sortedDates = dueDateGroups.keys.toList()..sort();

    for (final date in sortedDates) {
      final payments = dueDateGroups[date]!;
      final expenses = payments.where((p) => p.isExpense).toList();

      if (expenses.isNotEmpty) {
        final accountBalances = <String, int>{};
        final accountCounts = <String, int>{};

        for (final payment in expenses) {
          accountBalances[payment.accountId] =
              (accountBalances[payment.accountId] ?? 0) + payment.amount;
          accountCounts[payment.accountId] =
              (accountCounts[payment.accountId] ?? 0) + 1;
        }

        for (final accountId in accountBalances.keys) {
          final accountName =
              expenses.firstWhere((p) => p.accountId == accountId).accountName;
          final cycle =
              billingCycles.where((c) => c.accountId == accountId).firstOrNull;
          final isPaymentDue = cycle != null && cycle.paymentDueDay > 0
              ? _isPaymentDueDate(date, cycle.paymentDueDay)
              : false;

          projections.add(DueDateProjectionDto(
            accountId: accountId,
            accountName: accountName,
            dueDate: date,
            totalDue: accountBalances[accountId]!,
            paymentCount: accountCounts[accountId]!,
            isPaymentDue: isPaymentDue,
          ));
        }
      }
    }

    return projections;
  }

  bool _isPaymentDueDate(String dueDate, int paymentDueDay) {
    final date = DateTime.parse(dueDate);
    return date.day <= paymentDueDay;
  }
}

class EndOfMonthForecastDto {
  const EndOfMonthForecastDto({
    required this.month,
    required this.currentBalance,
    required this.pendingExpenses,
    required this.pendingIncome,
    required this.upcomingRecurringExpenses,
    required this.upcomingRecurringIncome,
    required this.predictedExpenses,
    required this.predictedIncome,
    required this.forecastBalance,
    required this.pendingPayments,
    required this.upcomingRecurring,
    required this.dailyForecasts,
    required this.billingCycles,
    required this.dueDateProjections,
  });

  final String month;
  final int currentBalance;
  final int pendingExpenses;
  final int pendingIncome;
  final int upcomingRecurringExpenses;
  final int upcomingRecurringIncome;
  final int predictedExpenses;
  final int predictedIncome;
  final int forecastBalance;
  final List<PendingPaymentDto> pendingPayments;
  final List<RecurringPaymentDto> upcomingRecurring;
  final List<DailyForecastDto> dailyForecasts;
  final List<AccountBillingCycleDto> billingCycles;
  final List<DueDateProjectionDto> dueDateProjections;
}

class PendingPaymentDto {
  const PendingPaymentDto({
    required this.transactionId,
    required this.date,
    required this.description,
    required this.accountName,
    required this.accountId,
    required this.amount,
    required this.isExpense,
    required this.isIncome,
    this.dueDate,
  });

  final String transactionId;
  final String date;
  final String? dueDate;
  final String description;
  final String accountName;
  final String accountId;
  final int amount;
  final bool isExpense;
  final bool isIncome;

  String get effectiveDate => dueDate ?? date;
}

class RecurringPaymentDto {
  const RecurringPaymentDto({
    required this.templateId,
    required this.name,
    required this.date,
    required this.type,
    required this.isExpense,
    required this.isIncome,
    required this.amount,
  });

  final String templateId;
  final String name;
  final String date;
  final String type;
  final bool isExpense;
  final bool isIncome;
  final int amount;
}

class DailyForecastDto {
  const DailyForecastDto({
    required this.date,
    required this.predictedBalance,
    required this.pendingAmount,
    required this.recurringAmount,
  });

  final String date;
  final int predictedBalance;
  final int pendingAmount;
  final int recurringAmount;
}

class AccountBillingCycleDto {
  const AccountBillingCycleDto({
    required this.accountId,
    required this.accountName,
    required this.billingDay,
    required this.paymentDueDay,
  });

  final String accountId;
  final String accountName;
  final int billingDay;
  final int paymentDueDay;
}

class DueDateProjectionDto {
  const DueDateProjectionDto({
    required this.accountId,
    required this.accountName,
    required this.dueDate,
    required this.totalDue,
    required this.paymentCount,
    required this.isPaymentDue,
  });

  final String accountId;
  final String accountName;
  final String dueDate;
  final int totalDue;
  final int paymentCount;
  final bool isPaymentDue;
}

class _EntryTemplateItem {
  const _EntryTemplateItem({
    required this.accountId,
    required this.direction,
    required this.amount,
  });

  final String accountId;
  final String direction;
  final int amount;

  bool get isExpense => direction == 'decrease';
  bool get isIncome => direction == 'increase';
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
