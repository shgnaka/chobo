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
  final int assetsStart;
  final int assetsEnd;
  final int liabilitiesStart;
  final int liabilitiesEnd;
  final int netAssetsStart;
  final int netAssetsEnd;
  final List<MonthlySummaryCategoryTotalDto> expenseItems;
  final List<MonthlySummaryCategoryTotalDto> incomeItems;
  final List<MonthlySummaryCategoryTotalDto> transferItems;
  final int cashOutExpenses;
  final int accruedExpenses;
  final int liabilityDue;
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
