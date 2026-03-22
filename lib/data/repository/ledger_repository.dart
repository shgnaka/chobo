import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  Future<Map<String, int>> calculateAccountBalances({
    String? asOfDateInclusive,
  }) async {
    final rows = await _accountBalanceRows(
      asOfDateInclusive: asOfDateInclusive,
    );
    return <String, int>{
      for (final row in rows) row.accountId: row.balance,
    };
  }

  Future<ChoboMonthlySummaryRecord> calculateMonthlySummary(
    String month,
  ) async {
    final bounds = _MonthBounds.fromYearMonth(month);
    final startSnapshot = await _accountBalanceRows(
      asOfDateInclusive: bounds.previousDay,
    );
    final endSnapshot = await _accountBalanceRows(
      asOfDateInclusive: bounds.end,
    );
    final flowRows = await _monthlyFlowRows(
      startInclusive: bounds.start,
      endExclusive: bounds.nextMonthStart,
    );

    final assetsStart = _sumByKind(startSnapshot, 'asset');
    final liabilitiesStart = _sumByKind(startSnapshot, 'liability');
    final assetsEnd = _sumByKind(endSnapshot, 'asset');
    final liabilitiesEnd = _sumByKind(endSnapshot, 'liability');

    final expenseTotals = <String, int>{};
    final incomeTotals = <String, int>{};
    final transferTotals = <String, int>{};
    var cashOutExpenses = 0;
    var accruedExpenses = 0;
    var cardPayment = 0;

    for (final row in flowRows) {
      final transactionType = row.transactionType;
      final accountKind = row.accountKind;
      final accountName = row.accountName;
      final direction = row.direction;
      final amount = row.amount;

      if (accountKind == 'expense') {
        _addTotal(expenseTotals, accountName, amount);
      } else if (accountKind == 'income') {
        _addTotal(incomeTotals, accountName, amount);
      }

      if (transactionType == 'transfer' &&
          accountKind == 'asset' &&
          direction == 'increase') {
        _addTotal(transferTotals, accountName, amount);
      }

      // cashOutExpenses: Direct payments from asset accounts.
      // Example: Paying groceries with bank debit card.
      // Formula: expense transaction + asset account decreased.
      // NOTE: This is NOT credit card charges (see accruedExpenses).
      if (transactionType == 'expense' &&
          accountKind == 'asset' &&
          direction == 'decrease') {
        cashOutExpenses += amount;
      }

      // accruedExpenses: Credit card charges (unpaid at month end).
      // These will become cash-out when card bill is paid.
      // Formula: credit_expense transaction.
      if (transactionType == 'credit_expense' && accountKind == 'expense') {
        accruedExpenses += amount;
      }

      // cardPayment: Paying off credit card balance.
      // Formula: liability_payment transaction + liability account decreased.
      if (transactionType == 'liability_payment' &&
          accountKind == 'liability' &&
          direction == 'decrease') {
        cardPayment += amount;
      }
    }

    return ChoboMonthlySummaryRecord(
      month: bounds.month,
      assetsStart: assetsStart,
      assetsEnd: assetsEnd,
      liabilitiesStart: liabilitiesStart,
      liabilitiesEnd: liabilitiesEnd,
      netAssetsStart: assetsStart - liabilitiesStart,
      netAssetsEnd: assetsEnd - liabilitiesEnd,
      expenseTotals: expenseTotals,
      incomeTotals: incomeTotals,
      transferTotals: transferTotals,
      cashOutExpenses: cashOutExpenses,
      accruedExpenses: accruedExpenses,
      liabilityDue: liabilitiesEnd,
      cardPayment: cardPayment,
    );
  }

  Future<List<_AccountBalanceRow>> _accountBalanceRows({
    String? asOfDateInclusive,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT a.account_id AS account_id,
             a.kind AS kind,
             a.name AS name,
             COALESCE(SUM(
               CASE
                 WHEN t.status = 'posted'
                      AND (? IS NULL OR t.date <= ?)
                 THEN CASE
                        WHEN e.direction = 'increase' THEN e.amount
                        ELSE -e.amount
                      END
                 ELSE 0
               END
             ), 0) AS balance
      FROM accounts a
      LEFT JOIN entries e ON e.account_id = a.account_id
      LEFT JOIN transactions t ON t.transaction_id = e.transaction_id
      GROUP BY a.account_id, a.kind, a.name
      ORDER BY a.account_id
      ''',
      variables: <Variable>[
        Variable(asOfDateInclusive),
        Variable(asOfDateInclusive),
      ],
    ).get();

    return rows
        .map(
          (row) => _AccountBalanceRow(
            accountId: row.read<String>('account_id'),
            kind: row.read<String>('kind'),
            name: row.read<String>('name'),
            balance: row.read<int>('balance'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<_MonthlyFlowRow>> _monthlyFlowRows({
    required String startInclusive,
    required String endExclusive,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT t.type AS transaction_type,
             a.kind AS account_kind,
             a.name AS account_name,
             e.direction AS direction,
             e.amount AS amount
      FROM entries e
      JOIN transactions t ON t.transaction_id = e.transaction_id
      JOIN accounts a ON a.account_id = e.account_id
      WHERE t.status = 'posted'
        AND t.date >= ?
        AND t.date < ?
      ORDER BY t.date, t.transaction_id, e.entry_id
      ''',
      variables: <Variable>[
        Variable(startInclusive),
        Variable(endExclusive),
      ],
    ).get();

    return rows
        .map(
          (row) => _MonthlyFlowRow(
            transactionType: row.read<String>('transaction_type'),
            accountKind: row.read<String>('account_kind'),
            accountName: row.read<String>('account_name'),
            direction: row.read<String>('direction'),
            amount: row.read<int>('amount'),
          ),
        )
        .toList(growable: false);
  }

  int _sumByKind(List<_AccountBalanceRow> rows, String kind) {
    return rows
        .where((row) => row.kind == kind)
        .fold<int>(0, (sum, row) => sum + row.balance);
  }

  void _addTotal(Map<String, int> totals, String key, int amount) {
    totals[key] = (totals[key] ?? 0) + amount;
  }
}

class _AccountBalanceRow {
  const _AccountBalanceRow({
    required this.accountId,
    required this.kind,
    required this.name,
    required this.balance,
  });

  final String accountId;
  final String kind;
  final String name;
  final int balance;
}

class _MonthlyFlowRow {
  const _MonthlyFlowRow({
    required this.transactionType,
    required this.accountKind,
    required this.accountName,
    required this.direction,
    required this.amount,
  });

  final String transactionType;
  final String accountKind;
  final String accountName;
  final String direction;
  final int amount;
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
