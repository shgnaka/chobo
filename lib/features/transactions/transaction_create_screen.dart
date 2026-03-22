import 'package:chobo/app/chobo_providers.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/service/template_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/terminology_labels.dart';
import '../../widgets/counterparty_widgets.dart';
import '../../widgets/tag_widgets.dart';
import '../common/autocomplete_text_field.dart';

class TransactionCreateScreen extends ConsumerStatefulWidget {
  const TransactionCreateScreen({
    super.key,
    this.templateId,
  });

  final String? templateId;

  @override
  ConsumerState<TransactionCreateScreen> createState() =>
      _TransactionCreateScreenState();
}

class _TransactionCreateScreenState
    extends ConsumerState<TransactionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final List<TextEditingController> _amountControllers =
      <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _memoControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  List<String?> _selectedAccountIds = <String?>[null, null];
  List<String> _selectedDirections = <String>['decrease', 'increase'];
  List<String> _selectedTagIds = [];
  ChoboCounterpartyRecord? _selectedCounterparty;
  bool _saving = false;
  String _selectedType = 'expense';
  TransactionTemplate? _selectedTemplate;

  TerminologyService get _termService => ref.read(terminologyServiceProvider);

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
    if (widget.templateId != null) {
      _loadTemplate(widget.templateId!);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    for (final controller in _amountControllers) {
      controller.dispose();
    }
    for (final controller in _memoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplate(String templateId) async {
    final template =
        await ref.read(templateServiceProvider).getTemplate(templateId);
    if (template != null && mounted) {
      setState(() {
        _selectedTemplate = template;
        _selectedType = template.transactionType;
        _descriptionController.text = template.defaultDescription ?? '';
        _applyTemplateEntries(template);
      });
    }
  }

  void _applyTemplateEntries(TransactionTemplate template) {
    final maxEntries = _selectedAccountIds.length;
    for (int i = 0; i < template.entries.length && i < maxEntries; i++) {
      final entry = template.entries[i];
      _selectedAccountIds[i] = entry.accountId;
      _selectedDirections[i] = entry.direction;
      _memoControllers[i].text = entry.memo ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final templatesAsync = ref.watch(_suggestedTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新規取引'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: () => _showTemplateSelector(context, templatesAsync),
            tooltip: 'テンプレートを選択',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _saving ? null : () => _save(context),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_termService.getActionLabel(ActionTerm.save)),
        ),
      ),
      body: accountsAsync.when(
        data: (accounts) => _buildForm(accounts, templatesAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }

  Widget _buildForm(
    List<ChoboAccountRecord> accounts,
    AsyncValue<List<TransactionTemplate>> templatesAsync,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (_selectedTemplate != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'テンプレート: ${_selectedTemplate!.name}',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedTemplate = null;
                          _selectedAccountIds = [null, null];
                          _selectedDirections = ['decrease', 'increase'];
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          _Section(
            title: _termService.getSectionLabel(SectionTerm.basicInfo),
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText:
                        _termService.getFieldLabel(FieldTerm.transactionDate),
                    hintText: '2026-03-22',
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
                    labelText:
                        _termService.getFieldLabel(FieldTerm.transactionType),
                  ),
                  items: _buildTransactionTypeItems(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedType = value;
                      _updateDirectionsForType(value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                AutocompleteTextField(
                  fieldType: SelectionFieldType.description,
                  transactionType: _selectedType,
                  placeholder:
                      _termService.getFieldLabel(FieldTerm.description),
                  initialValue: _descriptionController.text,
                  suggestionService: ref.watch(suggestionServiceProvider),
                  onSelected: (value) {
                    _descriptionController.text = value;
                  },
                ),
                const SizedBox(height: 16),
                CounterpartyAutocomplete(
                  controller: _counterpartyController,
                  onSelected: (counterparty) {
                    setState(() {
                      _selectedCounterparty = counterparty;
                    });
                  },
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
                _EntryCard(
                  entryIndex: 0,
                  accounts: accounts,
                  accountId: _selectedAccountIds[0],
                  onAccountChanged: (value) {
                    setState(() {
                      _selectedAccountIds[0] = value;
                    });
                    if (value != null && _selectedTemplate == null) {
                      _recordSelection(SelectionFieldType.account, value);
                    }
                  },
                  direction: _selectedDirections[0],
                  onDirectionChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedDirections[0] = value;
                    });
                  },
                  amountController: _amountControllers[0],
                  memoController: _memoControllers[0],
                ),
                const SizedBox(height: 12),
                _EntryCard(
                  entryIndex: 1,
                  accounts: accounts,
                  accountId: _selectedAccountIds[1],
                  onAccountChanged: (value) {
                    setState(() {
                      _selectedAccountIds[1] = value;
                    });
                    if (value != null && _selectedTemplate == null) {
                      _recordSelection(SelectionFieldType.account, value);
                    }
                  },
                  direction: _selectedDirections[1],
                  onDirectionChanged: (value) {
                    if (value == null) return;
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
          const SizedBox(height: 16),
          _Section(
            title: 'タグ',
            child: TagSelector(
              transactionId: null,
              selectedTagIds: _selectedTagIds,
              onTagsChanged: (tagIds) {
                setState(() {
                  _selectedTagIds = tagIds;
                });
              },
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  void _updateDirectionsForType(String type) {
    switch (type) {
      case 'income':
        _selectedDirections = ['increase', 'increase'];
        break;
      case 'expense':
        _selectedDirections = ['decrease', 'increase'];
        break;
      case 'transfer':
        _selectedDirections = ['decrease', 'increase'];
        break;
      case 'credit_expense':
        _selectedDirections = ['increase', 'increase'];
        break;
      case 'liability_payment':
        _selectedDirections = ['decrease', 'decrease'];
        break;
      case 'advance_payment':
        _selectedDirections = ['decrease', 'increase'];
        break;
      case 'reimbursement':
        _selectedDirections = ['increase', 'increase'];
        break;
    }
  }

  void _recordSelection(SelectionFieldType fieldType, String value) {
    ref.read(suggestionServiceProvider).recordSelection(
          fieldType: fieldType,
          value: value,
          transactionType: _selectedType,
        );
  }

  void _showTemplateSelector(
    BuildContext context,
    AsyncValue<List<TransactionTemplate>> templatesAsync,
  ) {
    templatesAsync.when(
      data: (templates) {
        showModalBottomSheet(
          context: context,
          builder: (context) => _TemplateSelectorSheet(
            templates: templates,
            onSelected: (template) {
              Navigator.pop(context);
              setState(() {
                _selectedTemplate = template;
                _selectedType = template.transactionType;
                _descriptionController.text = template.defaultDescription ?? '';
                _applyTemplateEntries(template);
              });
            },
          ),
        );
      },
      loading: () {},
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('テンプレートの読み込みに失敗: $e')),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
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
      final counterpartyText = _counterpartyController.text.trim();
      if (counterpartyText.isNotEmpty && _selectedCounterparty == null) {
        _selectedCounterparty = await ref
            .read(counterpartyRepositoryProvider)
            .getOrCreateCounterparty(rawName: counterpartyText);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final transactionId =
          'txn_${DateTime.now().toUtc().microsecondsSinceEpoch}';

      final transaction = ChoboTransactionRecord(
        transactionId: transactionId,
        date: _dateController.text.trim(),
        type: _selectedType,
        status: 'posted',
        description: _emptyToNull(_descriptionController.text),
        counterparty: _emptyToNull(_counterpartyController.text),
        counterpartyId: _selectedCounterparty?.counterpartyId,
        createdAt: now,
        updatedAt: now,
      );

      final entries = <ChoboEntryRecord>[
        _buildEntry(
          transactionId: transactionId,
          index: 0,
          accountId: _selectedAccountIds[0]!,
          direction: _selectedDirections[0],
          amountText: _amountControllers[0].text,
          memoText: _memoControllers[0].text,
        ),
        _buildEntry(
          transactionId: transactionId,
          index: 1,
          accountId: _selectedAccountIds[1]!,
          direction: _selectedDirections[1],
          amountText: _amountControllers[1].text,
          memoText: _memoControllers[1].text,
        ),
      ];

      await ref
          .read(transactionRepositoryProvider)
          .createTransaction(transaction, entries);

      if (_selectedTagIds.isNotEmpty) {
        await ref.read(tagRepositoryProvider).setTransactionTags(
              transactionId: transactionId,
              tagIds: _selectedTagIds,
            );
      }

      if (_selectedCounterparty != null) {
        _recordSelection(
          SelectionFieldType.counterparty,
          _selectedCounterparty!.rawName,
        );
      }
      if (_descriptionController.text.isNotEmpty) {
        _recordSelection(
          SelectionFieldType.description,
          _descriptionController.text,
        );
      }

      if (_selectedTemplate != null) {
        await ref
            .read(templateServiceProvider)
            .applyTemplate(_selectedTemplate!.templateId);
      }

      ref.invalidate(transactionsProvider);
      if (context.mounted) {
        context.pop();
      }
    } catch (error) {
      if (!context.mounted) return;
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

  ChoboEntryRecord _buildEntry({
    required String transactionId,
    required int index,
    required String accountId,
    required String direction,
    required String amountText,
    required String memoText,
  }) {
    final amount = int.tryParse(amountText.trim()) ?? 0;
    return ChoboEntryRecord(
      entryId: '${transactionId}_$index',
      transactionId: transactionId,
      accountId: accountId,
      direction: direction,
      amount: amount,
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
      DropdownMenuItem<String>(
        value: 'advance_payment',
        child: Text(
            _termService.getTransactionLabel(TransactionTerm.advancePayment)),
      ),
      DropdownMenuItem<String>(
        value: 'reimbursement',
        child: Text(
            _termService.getTransactionLabel(TransactionTerm.reimbursement)),
      ),
    ];
  }
}

final _suggestedTemplatesProvider =
    FutureProvider<List<TransactionTemplate>>((ref) async {
  return ref.watch(templateServiceProvider).listTemplates();
});

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

class _EntryCard extends ConsumerWidget {
  const _EntryCard({
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

class _TemplateSelectorSheet extends StatelessWidget {
  const _TemplateSelectorSheet({
    required this.templates,
    required this.onSelected,
  });

  final List<TransactionTemplate> templates;
  final void Function(TransactionTemplate) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'テンプレートを選択',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        if (templates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('テンプレートがありません'),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(template.name),
                  subtitle: Text(_typeLabel(template.transactionType)),
                  trailing: Text(
                    '${template.usageCount}回使用',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => onSelected(template),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'income' => '収入',
      'expense' => '支出',
      'transfer' => '振替',
      'credit_expense' => '請求',
      'liability_payment' => '支払',
      'advance_payment' => '立替',
      'reimbursement' => '精算',
      _ => type,
    };
  }
}
