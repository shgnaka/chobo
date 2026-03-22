class MonthlySummaryDto {
  MonthlySummaryDto({
    required this.month,
    required this.periodLabel,
    required this.assetsStart,
    required this.assetsEnd,
    required this.liabilitiesStart,
    required this.liabilitiesEnd,
    required this.netAssetsStart,
    required this.netAssetsEnd,
    required this.expenseItems,
    required this.incomeItems,
    required this.transferItems,
    required this.cashOutExpenses,
    required this.accruedExpenses,
    required this.liabilityDue,
    required this.cardPayment,
    required List<MonthlySummarySectionDto> sections,
    required List<MonthlySummaryCardDto> cards,
  })  : sections = List<MonthlySummarySectionDto>.unmodifiable(sections),
        cards = List<MonthlySummaryCardDto>.unmodifiable(cards);

  final String month;
  final String periodLabel;

  /// Total assets at the start of the month (day 1).
  final int assetsStart;

  /// Total assets at the end of the month.
  final int assetsEnd;

  /// Total liabilities at the start of the month (day 1).
  final int liabilitiesStart;

  /// Total liabilities at the end of the month.
  /// Includes credit card balances and other payables.
  final int liabilitiesEnd;

  /// Net assets at month start: assetsStart - liabilitiesStart.
  final int netAssetsStart;

  /// Net assets at month end: assetsEnd - liabilitiesEnd.
  final int netAssetsEnd;

  final List<MonthlySummaryCategoryTotalDto> expenseItems;
  final List<MonthlySummaryCategoryTotalDto> incomeItems;
  final List<MonthlySummaryCategoryTotalDto> transferItems;

  /// Expenses paid directly from asset accounts (cash/bank outflows).
  /// Formula: expense transactions where offsetting entry decreases an asset.
  /// NOTE: Card charges are NOT included here (see accruedExpenses).
  final int cashOutExpenses;

  /// Credit card charges not yet paid to the card company.
  /// Formula: credit_expense transactions.
  /// These become cash-out when the card bill is paid.
  final int accruedExpenses;

  /// Total unpaid liability balance at month end.
  /// Formula: sum of all liability account balances.
  /// Represents the amount needed to settle all liabilities.
  final int liabilityDue;

  /// Amount paid to reduce liability accounts (e.g., credit card payment).
  /// Formula: liability_payment transactions.
  final int cardPayment;

  final List<MonthlySummarySectionDto> sections;
  final List<MonthlySummaryCardDto> cards;

  int get netAssetsDelta => netAssetsEnd - netAssetsStart;
}

class MonthlySummaryCategoryTotalDto {
  const MonthlySummaryCategoryTotalDto({
    required this.key,
    required this.label,
    required this.amount,
  });

  final String key;
  final String label;
  final int amount;
}

class MonthlySummarySectionDto {
  const MonthlySummarySectionDto({
    required this.key,
    required this.title,
    required this.cards,
  });

  final String key;
  final String title;
  final List<MonthlySummaryCardDto> cards;
}

class MonthlySummaryCardDto {
  const MonthlySummaryCardDto({
    required this.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.tone = 'neutral',
  });

  final String key;
  final String title;
  final int value;
  final String? subtitle;
  final String tone;
}
