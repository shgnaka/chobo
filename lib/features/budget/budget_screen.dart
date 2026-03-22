import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/service/budget_service.dart';
import '../../data/service/forecast_service.dart';
import 'widgets/budget_edit_dialog.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/forecast_card.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({
    super.key,
    required this.month,
  });

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(monthlyBudgetProvider(month));
    final forecastAsync = ref.watch(endOfMonthForecastProvider(month));

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatMonthLabel(month)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add budget',
            onPressed: () => _showAddBudgetDialog(context, ref),
          ),
        ],
      ),
      body: budgetAsync.when(
        data: (budget) => _buildContent(context, ref, budget, forecastAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Budget load failed: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MonthlyBudgetDto budget,
    AsyncValue<EndOfMonthForecastDto> forecastAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildOverviewSection(context, budget),
        const Divider(),
        _buildForecastSection(context, forecastAsync),
        const Divider(),
        _buildBudgetCategoriesSection(context, ref, budget),
      ],
    );
  }

  Widget _buildOverviewSection(BuildContext context, MonthlyBudgetDto budget) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Budget',
                  value: budget.totalBudget,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Spent',
                  value: budget.totalActual,
                  color: budget.isOverBudget ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Remaining',
                  value: budget.totalRemaining,
                  color: budget.totalRemaining >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Used',
                  value: budget.percentUsed,
                  suffix: '%',
                  color: budget.percentUsed > 100
                      ? Colors.red
                      : budget.percentUsed > 80
                          ? Colors.orange
                          : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSection(
    BuildContext context,
    AsyncValue<EndOfMonthForecastDto> forecastAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'End of Month Forecast',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          forecastAsync.when(
            data: (forecast) => ForecastCard(forecast: forecast),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text('Forecast load failed: $error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCategoriesSection(
    BuildContext context,
    WidgetRef ref,
    MonthlyBudgetDto budget,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: () => _showAddBudgetDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (budget.categories.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No budgets set. Tap + to add one.'),
              ),
            )
          else
            ...budget.categories.map(
              (comparison) => BudgetProgressCard(
                comparison: comparison,
                onTap: () => _showEditBudgetDialog(
                  context,
                  ref,
                  comparison,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddBudgetDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BudgetEditDialog(month: month),
    );

    if (result != null) {
      try {
        final budgetRecord = result['record'];
        await ref.read(budgetServiceProvider).upsertBudget(budgetRecord);
        ref.invalidate(monthlyBudgetProvider(month));
      } on ConcurrencyException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
  }

  Future<void> _showEditBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    BudgetComparisonDto comparison,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BudgetEditDialog(
        month: month,
        initialAccountId: comparison.accountId,
        initialAmount: comparison.budgetAmount,
        initialThreshold: comparison.alertThreshold,
      ),
    );

    if (result != null) {
      try {
        final budgetRecord = result['record'];
        await ref.read(budgetServiceProvider).upsertBudget(budgetRecord);
        ref.invalidate(monthlyBudgetProvider(month));
      } on ConcurrencyException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
  }

  String _formatMonthLabel(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    return '${parts[0]}年${parts[1]}月 予算';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    this.suffix = '',
    required this.color,
  });

  final String title;
  final int value;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '¥${_formatAmount(value)}$suffix',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount.abs() >= 10000) {
      return '${(amount / 10000).round()}万';
    }
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
