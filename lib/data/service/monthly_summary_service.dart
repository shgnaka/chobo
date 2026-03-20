import '../../core/aggregation_cache_policy.dart';
import '../repository/ledger_repository.dart';
import 'monthly_summary_dto.dart';

class MonthlySummaryService {
  MonthlySummaryService(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;
  final AggregationCache _cache = AggregationCache();
  final AggregationCachePolicy _policy = AggregationCachePolicy();

  Future<MonthlySummaryDto> getMonthlySummary(String month) async {
    final cached = _cache.get(month);
    if (cached != null && _policy.isCacheValid(cached.cachedAt)) {
      return cached.summary as MonthlySummaryDto;
    }

    final summary = await _ledgerRepository.calculateMonthlySummary(month);
    final expenseItems = _mapToCategoryItems(summary.expenseTotals);
    final incomeItems = _mapToCategoryItems(summary.incomeTotals);
    final transferItems = _mapToCategoryItems(summary.transferTotals);
    final sections = <MonthlySummarySectionDto>[
      MonthlySummarySectionDto(
        key: 'overview',
        title: 'Overview',
        cards: <MonthlySummaryCardDto>[
          _card(
            key: 'assets_end',
            title: 'Assets',
            value: summary.assetsEnd,
            subtitle: 'Start ${summary.assetsStart}',
            tone: 'positive',
          ),
          _card(
            key: 'liabilities_end',
            title: 'Liabilities',
            value: summary.liabilitiesEnd,
            subtitle: 'Start ${summary.liabilitiesStart}',
            tone: 'negative',
          ),
          _card(
            key: 'net_assets_end',
            title: 'Net assets',
            value: summary.netAssetsEnd,
            subtitle: 'Δ ${summary.netAssetsEnd - summary.netAssetsStart}',
            tone: 'neutral',
          ),
        ],
      ),
      MonthlySummarySectionDto(
        key: 'flow',
        title: 'Cash Flow',
        cards: <MonthlySummaryCardDto>[
          _card(
            key: 'cash_out_expenses',
            title: 'Cash-out expenses',
            value: summary.cashOutExpenses,
            tone: 'negative',
          ),
          _card(
            key: 'accrued_expenses',
            title: 'Accrued expenses',
            value: summary.accruedExpenses,
            tone: 'negative',
          ),
          _card(
            key: 'liability_due',
            title: 'Liability due',
            value: summary.liabilityDue,
            tone: 'negative',
          ),
          _card(
            key: 'card_payment',
            title: 'Card payment',
            value: summary.cardPayment,
            tone: 'positive',
          ),
        ],
      ),
      MonthlySummarySectionDto(
        key: 'expenses',
        title: 'Expenses',
        cards: _mapToCategoryCards(expenseItems, tone: 'negative'),
      ),
      MonthlySummarySectionDto(
        key: 'income',
        title: 'Income',
        cards: _mapToCategoryCards(incomeItems, tone: 'positive'),
      ),
      MonthlySummarySectionDto(
        key: 'transfers',
        title: 'Transfers',
        cards: _mapToCategoryCards(transferItems, tone: 'neutral'),
      ),
    ];
    final cards = sections.expand((section) => section.cards).toList(
          growable: false,
        );
    final dto = MonthlySummaryDto(
      month: summary.month,
      periodLabel: _formatPeriodLabel(summary.month),
      assetsStart: summary.assetsStart,
      assetsEnd: summary.assetsEnd,
      liabilitiesStart: summary.liabilitiesStart,
      liabilitiesEnd: summary.liabilitiesEnd,
      netAssetsStart: summary.netAssetsStart,
      netAssetsEnd: summary.netAssetsEnd,
      expenseItems: expenseItems,
      incomeItems: incomeItems,
      transferItems: transferItems,
      cashOutExpenses: summary.cashOutExpenses,
      accruedExpenses: summary.accruedExpenses,
      liabilityDue: summary.liabilityDue,
      cardPayment: summary.cardPayment,
      sections: sections,
      cards: cards,
    );

    _cache.set(
        month, CachedMonthlySummary(summary: dto, cachedAt: DateTime.now()));

    return dto;
  }

  void invalidateCache({String? month, String? affectedDate}) {
    if (month != null) {
      _cache.invalidate(month);
    } else if (affectedDate != null) {
      _cache.invalidateMonthsAffectedByDate(affectedDate);
    } else {
      _cache.invalidateAll();
    }
  }

  Future<Map<String, int>> getAccountBalances({
    String? asOfDateInclusive,
  }) {
    return _ledgerRepository.calculateAccountBalances(
      asOfDateInclusive: asOfDateInclusive,
    );
  }

  List<MonthlySummaryCategoryTotalDto> _mapToCategoryItems(
    Map<String, int> totals,
  ) {
    final items = totals.entries
        .map(
          (entry) => MonthlySummaryCategoryTotalDto(
            key: entry.key,
            label: _labelForKey(entry.key),
            amount: entry.value,
          ),
        )
        .toList(growable: false);
    items.sort((left, right) {
      final amountCompare = right.amount.compareTo(left.amount);
      if (amountCompare != 0) {
        return amountCompare;
      }
      return left.label.compareTo(right.label);
    });
    return items;
  }

  List<MonthlySummaryCardDto> _mapToCategoryCards(
    List<MonthlySummaryCategoryTotalDto> items, {
    required String tone,
  }) {
    return items
        .map(
          (item) => _card(
            key: item.key,
            title: item.label,
            value: item.amount,
            tone: tone,
          ),
        )
        .toList(growable: false);
  }

  MonthlySummaryCardDto _card({
    required String key,
    required String title,
    required int value,
    String? subtitle,
    String tone = 'neutral',
  }) {
    return MonthlySummaryCardDto(
      key: key,
      title: title,
      value: value,
      subtitle: subtitle,
      tone: tone,
    );
  }

  String _formatPeriodLabel(String month) {
    final parts = month.split('-');
    if (parts.length != 2) {
      return month;
    }
    return '${parts[0]}年${parts[1]}月';
  }

  String _labelForKey(String key) {
    if (key.isEmpty) {
      return key;
    }
    return key[0].toUpperCase() + key.substring(1);
  }
}
