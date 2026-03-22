import 'package:chobo/data/service/monthly_summary_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';
import 'summary_charts.dart';

final monthlySummaryProvider =
    FutureProvider.family<MonthlySummaryDto, String>((ref, month) async {
  final service = ref.watch(monthlySummaryServiceProvider);
  return service.getMonthlySummary(month);
});

class MonthlySummaryScreen extends ConsumerWidget {
  const MonthlySummaryScreen({
    super.key,
    required this.month,
  });

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlySummaryProvider(month));

    return Scaffold(
      appBar: AppBar(
        title: Text(summaryAsync.valueOrNull?.periodLabel ?? '月次集計'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: summaryAsync.when(
        data: (summary) => _buildContent(context, summary),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('月次集計の読み込みに失敗しました: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, MonthlySummaryDto summary) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildQuickStats(context, summary),
        const Divider(),
        _buildCashFlowSection(context, summary),
        const Divider(),
        _buildExpensesChart(context, summary),
        const Divider(),
        _buildNetAssetsTrend(context, summary),
        const Divider(),
        SummaryCardsSection(sections: summary.sections),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, MonthlySummaryDto summary) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: '総資産',
              value: summary.assetsEnd,
              subtitle:
                  '(${_formatDelta(summary.assetsEnd - summary.assetsStart)})',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '純資産',
              value: summary.netAssetsEnd,
              subtitle: '(${_formatDelta(summary.netAssetsDelta)})',
              color: summary.netAssetsDelta >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowSection(
      BuildContext context, MonthlySummaryDto summary) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'キャッシュフロー',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          CashFlowBarChart(
            cashOutExpenses: summary.cashOutExpenses,
            accruedExpenses: summary.accruedExpenses,
            cardPayment: summary.cardPayment,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FlowLegendItem(
                  color: Colors.red,
                  label: 'Cash-out',
                  value: summary.cashOutExpenses,
                ),
              ),
              Expanded(
                child: _FlowLegendItem(
                  color: Colors.orange,
                  label: 'Accrued',
                  value: summary.accruedExpenses,
                ),
              ),
              Expanded(
                child: _FlowLegendItem(
                  color: Colors.green,
                  label: 'Card Pay',
                  value: summary.cardPayment,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesChart(BuildContext context, MonthlySummaryDto summary) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '支出内訳',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ExpensePieChart(expenseItems: summary.expenseItems),
        ],
      ),
    );
  }

  Widget _buildNetAssetsTrend(BuildContext context, MonthlySummaryDto summary) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '純資産推移',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          NetAssetsTrendChart(
            netAssetsStart: summary.netAssetsStart,
            netAssetsEnd: summary.netAssetsEnd,
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount == 0) return '¥0';
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return isNegative ? '-¥$formatted' : '¥$formatted';
  }

  String _formatDelta(int delta) {
    if (delta == 0) return '±0';
    final isNegative = delta < 0;
    final absDelta = delta.abs();
    final formatted = absDelta.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return isNegative ? '-$formatted' : '+$formatted';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final int value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatAmount(value),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount == 0) return '¥0';
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return isNegative ? '-¥$formatted' : '¥$formatted';
  }
}

class _FlowLegendItem extends StatelessWidget {
  const _FlowLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ${_formatAmount(value)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatAmount(int amount) {
    if (amount == 0) return '¥0';
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return isNegative ? '-¥$formatted' : '¥$formatted';
  }
}
