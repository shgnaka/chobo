import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/chobo_providers.dart';
import '../../../data/local_db/chobo_records.dart';

class BudgetEditDialog extends ConsumerStatefulWidget {
  const BudgetEditDialog({
    super.key,
    required this.month,
    this.initialAccountId,
    this.initialAmount,
    this.initialThreshold,
  });

  final String month;
  final String? initialAccountId;
  final int? initialAmount;
  final int? initialThreshold;

  @override
  ConsumerState<BudgetEditDialog> createState() => _BudgetEditDialogState();
}

class _BudgetEditDialogState extends ConsumerState<BudgetEditDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _thresholdController;
  String? _selectedAccountId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount?.toString() ?? '',
    );
    _thresholdController = TextEditingController(
      text: (widget.initialThreshold ?? 80).toString(),
    );
    _selectedAccountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return AlertDialog(
      title:
          Text(widget.initialAccountId == null ? 'Add Budget' : 'Edit Budget'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category'),
            const SizedBox(height: 8),
            accountsAsync.when(
              data: (accounts) {
                final expenseAccounts = accounts
                    .where((a) => a.kind == 'expense' && !a.isArchived)
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select category',
                  ),
                  items: expenseAccounts.map((account) {
                    return DropdownMenuItem(
                      value: account.accountId,
                      child: Text(account.name),
                    );
                  }).toList(),
                  onChanged: widget.initialAccountId != null
                      ? null
                      : (value) {
                          setState(() {
                            _selectedAccountId = value;
                          });
                        },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text('Error: $error'),
            ),
            const SizedBox(height: 16),
            const Text('Budget Amount'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: '¥ ',
                hintText: '0',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            const Text('Alert Threshold'),
            const SizedBox(height: 8),
            TextField(
              controller: _thresholdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: '%',
                hintText: '80',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Alert when spending reaches this percentage of budget',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a budget amount')),
      );
      return;
    }

    final amount = int.tryParse(amountText) ?? 0;
    if (amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget amount must be positive')),
      );
      return;
    }

    final thresholdText = _thresholdController.text.trim();
    final threshold = int.tryParse(thresholdText);
    if (threshold == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid number for threshold')),
      );
      return;
    }
    if (threshold < 0 || threshold > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Threshold must be between 0 and 100')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final now = DateTime.now().toUtc().toIso8601String();

    final existingBudget = await ref
        .read(budgetRepositoryProvider)
        .getBudgetByAccountAndMonth(_selectedAccountId!, widget.month);

    final budgetRecord = ChoboBudgetRecord(
      budgetId: existingBudget?.budgetId ??
          'budget_${DateTime.now().millisecondsSinceEpoch}',
      accountId: _selectedAccountId!,
      month: widget.month,
      amount: amount,
      alertThresholdPercent: threshold,
      createdAt: existingBudget?.createdAt ?? now,
      updatedAt: now,
    );

    if (mounted) {
      Navigator.pop(context, {'record': budgetRecord});
    }
  }
}
