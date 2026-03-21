import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';
import '../../core/terminology_labels.dart';
import '../../core/terminology_service.dart';

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

  TerminologyService get _termService => ref.read(terminologyServiceProvider);

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
              : Text(_termService.getActionLabel(ActionTerm.save)),
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
                  title: _termService.getSectionLabel(SectionTerm.basicInfo),
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: _termService
                              .getFieldLabel(FieldTerm.transactionDate),
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
                        decoration: InputDecoration(
                          labelText: _termService
                              .getFieldLabel(FieldTerm.transactionType),
                        ),
                        items: _buildTransactionTypeItems(),
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
                        decoration: InputDecoration(
                          labelText:
                              _termService.getFieldLabel(FieldTerm.description),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _counterpartyController,
                        decoration: InputDecoration(
                          labelText: _termService
                              .getFieldLabel(FieldTerm.counterparty),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _externalRefController,
                        decoration: InputDecoration(
                          labelText:
                              _termService.getFieldLabel(FieldTerm.externalRef),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: _termService.getSectionLabel(SectionTerm.entries),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _EditableEntryCard(
                        entryIndex: 0,
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
                        entryIndex: 1,
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

  List<DropdownMenuItem<String>> _buildTransactionTypeItems() {
    return [
      DropdownMenuItem<String>(
        value: 'income',
        child: Text(_termService.getTransactionLabel(TransactionTerm.income)),
      ),
      DropdownMenuItem<String>(
        value: 'expense',
        child: Text(_termService.getTransactionLabel(TransactionTerm.expense)),
      ),
      DropdownMenuItem<String>(
        value: 'transfer',
        child: Text(_termService.getTransactionLabel(TransactionTerm.transfer)),
      ),
      DropdownMenuItem<String>(
        value: 'credit_expense',
        child: Text(
            _termService.getTransactionLabel(TransactionTerm.creditExpense)),
      ),
      DropdownMenuItem<String>(
        value: 'liability_payment',
        child: Text(
            _termService.getTransactionLabel(TransactionTerm.liabilityPayment)),
      ),
    ];
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

class _EditableEntryCard extends ConsumerWidget {
  const _EditableEntryCard({
    super.key,
    required this.entryIndex,
    required this.accounts,
    required this.accountId,
    required this.onAccountChanged,
    required this.direction,
    required this.onDirectionChanged,
    required this.amountController,
    required this.memoController,
  });

  final int entryIndex;
  final List<ChoboAccountRecord> accounts;
  final String? accountId;
  final ValueChanged<String?> onAccountChanged;
  final String direction;
  final ValueChanged<String?> onDirectionChanged;
  final TextEditingController amountController;
  final TextEditingController memoController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              termService.getEntryLabelForIndex(entryIndex),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: accountId,
              decoration: InputDecoration(
                labelText: termService.getFieldLabel(FieldTerm.account),
              ),
              items: accounts.map(
                (account) {
                  final displayName =
                      termService.getStandardAccountName(account.name);
                  return DropdownMenuItem<String>(
                    value: account.accountId,
                    child: Text('$displayName (${account.accountId})'),
                  );
                },
              ).toList(growable: false),
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
              decoration: InputDecoration(
                labelText: termService.getFieldLabel(FieldTerm.direction),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: 'decrease',
                  child: Text(
                      termService.getDirectionLabel(DirectionTerm.decrease)),
                ),
                DropdownMenuItem<String>(
                  value: 'increase',
                  child: Text(
                      termService.getDirectionLabel(DirectionTerm.increase)),
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
              decoration: InputDecoration(
                labelText: termService.getFieldLabel(FieldTerm.amount),
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
              decoration: InputDecoration(
                labelText: termService.getFieldLabel(FieldTerm.memo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
