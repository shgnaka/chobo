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
             t.type,
             t.description,
             e.amount,
             a.name AS account_name
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
        description: desc ?? '',
        accountName: row.read<String>('account_name'),
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
      pendingByDate[p.date] = (pendingByDate[p.date] ?? 0) + p.amount;
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
}

class PendingPaymentDto {
  const PendingPaymentDto({
    required this.transactionId,
    required this.date,
    required this.description,
    required this.accountName,
    required this.amount,
    required this.isExpense,
    required this.isIncome,
  });

  final String transactionId;
  final String date;
  final String description;
  final String accountName;
  final int amount;
  final bool isExpense;
  final bool isIncome;
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
