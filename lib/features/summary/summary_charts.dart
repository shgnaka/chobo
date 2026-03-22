import 'package:chobo/data/service/monthly_summary_dto.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SummaryCardsSection extends StatelessWidget {
  const SummaryCardsSection({
    super.key,
    required this.sections,
  });

  final List<MonthlySummarySectionDto> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: section.cards.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _MetricCard(card: section.cards[index]),
                  );
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.card});

  final MonthlySummaryCardDto card;

  @override
  Widget build(BuildContext context) {
    final color = _toneToColor(card.tone);

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatAmount(card.value),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (card.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              card.subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Color _toneToColor(String tone) {
    switch (tone) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.blue;
    }
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

class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({
    super.key,
    required this.expenseItems,
  });

  final List<MonthlySummaryCategoryTotalDto> expenseItems;

  static const _colors = [
    Color(0xFF6750A4),
    Color(0xFF625B71),
    Color(0xFF7D5260),
    Color(0xFFB3261E),
    Color(0xFFEF6C00),
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFF4E342E),
    Color(0xFF37474F),
    Color(0xFF558B2F),
  ];

  @override
  Widget build(BuildContext context) {
    if (expenseItems.isEmpty) {
      return const Center(child: Text('支出データがありません'));
    }

    final total = expenseItems.fold<int>(0, (sum, item) => sum + item.amount);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _buildSections(total),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(context, total),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(int total) {
    return expenseItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final percentage = (item.amount / total * 100);
      final color = _colors[index % _colors.length];

      return PieChartSectionData(
        color: color,
        value: item.amount.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(BuildContext context, int total) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: expenseItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final color = _colors[index % _colors.length];

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
              '${item.label} (${(item.amount / total * 100).toStringAsFixed(0)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}

class CashFlowBarChart extends StatelessWidget {
  const CashFlowBarChart({
    super.key,
    required this.cashOutExpenses,
    required this.accruedExpenses,
    required this.cardPayment,
  });

  final int cashOutExpenses;
  final int accruedExpenses;
  final int cardPayment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _calculateMaxY(),
          barGroups: _buildBarGroups(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _getBottomTitles,
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _getLeftTitles,
                reservedSize: 50,
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }

  double _calculateMaxY() {
    final max = [cashOutExpenses, accruedExpenses, cardPayment]
        .reduce((a, b) => a > b ? a : b);
    return (max * 1.2).toDouble();
  }

  List<BarChartGroupData> _buildBarGroups() {
    return [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: cashOutExpenses.toDouble(),
            color: Colors.red,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: accruedExpenses.toDouble(),
            color: Colors.orange,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      ),
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(
            toY: cardPayment.toDouble(),
            color: Colors.green,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    const titles = ['Cash-out', 'Accrued', 'Card Pay'];
    final index = value.toInt();
    if (index >= 0 && index < titles.length) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(
          titles[index],
          style: const TextStyle(fontSize: 10),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _getLeftTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        _formatAxisValue(value.toInt()),
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  String _formatAxisValue(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toString();
  }
}

class NetAssetsTrendChart extends StatelessWidget {
  const NetAssetsTrendChart({
    super.key,
    required this.netAssetsStart,
    required this.netAssetsEnd,
  });

  final int netAssetsStart;
  final int netAssetsEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, netAssetsStart.toDouble()),
                FlSpot(1, netAssetsEnd.toDouble()),
              ],
              isCurved: false,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('Start');
                  if (value == 1) return const Text('End');
                  return const SizedBox();
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatAxisValue(value.toInt()),
                    style: const TextStyle(fontSize: 10),
                  );
                },
                reservedSize: 50,
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }

  String _formatAxisValue(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toString();
  }
}
