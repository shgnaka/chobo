import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';

class TransactionEditScreen extends ConsumerStatefulWidget {
  const TransactionEditScreen({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<TransactionEditScreen> createState() =>
      _TransactionEditScreenState();
}

class _TransactionEditScreenState extends ConsumerState<TransactionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _externalRefController = TextEditingController();
  final List<TextEditingController> _amountControllers =
      <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _memoControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  final List<String?> _selectedAccountIds = <String?>[null, null];
  final List<String> _selectedDirections = <String>['decrease', 'increase'];
  final List<String> _originalEntryIds = <String>[];
  bool _initialised = false;
  bool _saving = false;
  String _selectedType = 'expense';

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _externalRefController.dispose();
    for (final controller in _amountControllers) {
      controller.dispose();
    }
    for (final controller in _memoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionAsync =
        ref.watch(transactionProvider(widget.transactionId));
    final entriesAsync =
        ref.watch(transactionEntriesProvider(widget.transactionId));
    final accountsAsync = ref.watch(accountsProvider);
    final saveDecisionAsync =
        ref.watch(transactionSaveDecisionProvider(widget.transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('取引編集'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _saving || saveDecisionAsync.valueOrNull?.canApply != true
              ? null
              : () async {
                  await _save(
                    context,
                    transactionAsync.valueOrNull,
                    entriesAsync.valueOrNull,
                  );
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ),
      body: transactionAsync.when(
        data: (transaction) {
          if (transaction == null) {
            return const Center(
              child: Text('取引が見つかりません'),
            );
          }

          final accounts = accountsAsync.valueOrNull;
          final entries = entriesAsync.valueOrNull;
          if (accounts == null || entries == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (entries.length != 2) {
            return const Center(
              child: Text('編集できるのは2件の明細を持つ取引だけです。'),
            );
          }

          final saveDecision = saveDecisionAsync.valueOrNull;

          if (!_initialised) {
            _initialised = true;
            _dateController.text = transaction.date;
            _descriptionController.text = transaction.description ?? '';
            _counterpartyController.text = transaction.counterparty ?? '';
            _externalRefController.text = transaction.externalRef ?? '';
            _selectedType = transaction.type;
            _originalEntryIds
              ..clear()
              ..addAll(entries.map((entry) => entry.entryId));
            for (var i = 0; i < 2; i++) {
              _selectedAccountIds[i] = entries[i].accountId;
              _selectedDirections[i] = entries[i].direction;
              _amountControllers[i].text = entries[i].amount.toString();
              _memoControllers[i].text = entries[i].memo ?? '';
            }
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (saveDecision != null && !saveDecision.canApply) ...[
                  _Section(
                    title: '保存制約',
                    child: Text(saveDecision.reason),
                  ),
                  const SizedBox(height: 16),
                ],
                _Section(
                  title: '基本情報',
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: '取引日',
                          hintText: '2026-03-20',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return '取引日を入力してください。';
                          }
                          if (!_looksLikeIsoDate(text)) {
                            return 'YYYY-MM-DD 形式で入力してください。';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: '取引種別',
                        ),
                        items: _transactionTypeOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.value,
                                child: Text(option.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: '説明',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _counterpartyController,
                        decoration: const InputDecoration(
                          labelText: '相手先',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _externalRefController,
                        decoration: const InputDecoration(
                          labelText: '外部参照',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: '明細',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _EditableEntryCard(
                        label: '明細 1',
                        accounts: accounts,
                        accountId: _selectedAccountIds[0],
                        onAccountChanged: (value) {
                          setState(() {
                            _selectedAccountIds[0] = value;
                          });
                        },
                        direction: _selectedDirections[0],
                        onDirectionChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedDirections[0] = value;
                          });
                        },
                        amountController: _amountControllers[0],
                        memoController: _memoControllers[0],
                      ),
                      const SizedBox(height: 12),
                      _EditableEntryCard(
                        label: '明細 2',
                        accounts: accounts,
                        accountId: _selectedAccountIds[1],
                        onAccountChanged: (value) {
                          setState(() {
                            _selectedAccountIds[1] = value;
                          });
                        },
                        direction: _selectedDirections[1],
                        onDirectionChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedDirections[1] = value;
                          });
                        },
                        amountController: _amountControllers[1],
                        memoController: _memoControllers[1],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 88),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Text('取引を読み込めませんでした'),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    ChoboTransactionRecord? transaction,
    List<ChoboEntryRecord>? entries,
  ) async {
    if (transaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取引を読み込めませんでした。')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final currentEntries = entries;
    if (currentEntries == null || currentEntries.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('明細を読み込めませんでした。')),
      );
      return;
    }
    if (_selectedAccountIds.any((value) => value == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('明細の口座を選択してください。')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final updatedTransaction = transaction.copyWith(
        date: _dateController.text.trim(),
        type: _selectedType,
        description: _emptyToNull(_descriptionController.text),
        counterparty: _emptyToNull(_counterpartyController.text),
        externalRef: _emptyToNull(_externalRefController.text),
        updatedAt: now,
      );
      final editedEntries = <ChoboEntryRecord>[
        _buildEditedEntry(
          original: currentEntries[0],
          entryId: _originalEntryIds[0],
          accountId: _selectedAccountIds[0]!,
          direction: _selectedDirections[0],
          amountText: _amountControllers[0].text,
          memoText: _memoControllers[0].text,
        ),
        _buildEditedEntry(
          original: currentEntries[1],
          entryId: _originalEntryIds[1],
          accountId: _selectedAccountIds[1]!,
          direction: _selectedDirections[1],
          amountText: _amountControllers[1].text,
          memoText: _memoControllers[1].text,
        ),
      ];

      await ref
          .read(transactionRepositoryProvider)
          .updateTransaction(updatedTransaction, editedEntries);
      ref.invalidate(transactionProvider(widget.transactionId));
      ref.invalidate(transactionEntriesProvider(widget.transactionId));
      ref.invalidate(voidDecisionProvider(widget.transactionId));
      ref.invalidate(transactionsProvider);
      if (context.mounted) {
        context.pop();
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  ChoboEntryRecord _buildEditedEntry({
    required ChoboEntryRecord original,
    required String entryId,
    required String accountId,
    required String direction,
    required String amountText,
    required String memoText,
  }) {
    final amount = int.tryParse(amountText.trim());
    return original.copyWith(
      entryId: entryId,
      accountId: accountId,
      direction: direction,
      amount: amount ?? original.amount,
      memo: _emptyToNull(memoText),
    );
  }

  bool _looksLikeIsoDate(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EditableEntryCard extends StatelessWidget {
  const _EditableEntryCard({
    required this.label,
    required this.accounts,
    required this.accountId,
    required this.onAccountChanged,
    required this.direction,
    required this.onDirectionChanged,
    required this.amountController,
    required this.memoController,
  });

  final String label;
  final List<ChoboAccountRecord> accounts;
  final String? accountId;
  final ValueChanged<String?> onAccountChanged;
  final String direction;
  final ValueChanged<String?> onDirectionChanged;
  final TextEditingController amountController;
  final TextEditingController memoController;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: accountId,
              decoration: const InputDecoration(
                labelText: '口座',
              ),
              items: accounts
                  .map(
                    (account) => DropdownMenuItem<String>(
                      value: account.accountId,
                      child: Text('${account.name} (${account.accountId})'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onAccountChanged,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '口座を選択してください。';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: direction,
              decoration: const InputDecoration(
                labelText: '方向',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'decrease',
                  child: Text('減少'),
                ),
                DropdownMenuItem<String>(
                  value: 'increase',
                  child: Text('増加'),
                ),
              ],
              onChanged: onDirectionChanged,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '方向を選択してください。';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金額',
              ),
              validator: (value) {
                final amount = int.tryParse(value?.trim() ?? '');
                if (amount == null || amount <= 0) {
                  return '1以上の金額を入力してください。';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: memoController,
              decoration: const InputDecoration(
                labelText: 'メモ',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTypeOption {
  const _TransactionTypeOption(this.value, this.label);

  final String value;
  final String label;
}

const List<_TransactionTypeOption> _transactionTypeOptions =
    <_TransactionTypeOption>[
  _TransactionTypeOption('income', '収入'),
  _TransactionTypeOption('expense', '支出'),
  _TransactionTypeOption('transfer', '振替'),
  _TransactionTypeOption('credit_expense', 'カード支出'),
  _TransactionTypeOption('liability_payment', '負債返済'),
];
