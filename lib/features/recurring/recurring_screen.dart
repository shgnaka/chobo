import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';
import '../../data/local_db/chobo_records.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('定期取引'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.repeat, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('定期取引のテンプレートがありません'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddTemplateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('テンプレートを追加'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return _RecurringTemplateCard(
                template: template,
                onTap: () => _showTemplateDetails(context, ref, template),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('読み込みに失敗しました: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTemplateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTemplateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddRecurringTemplateDialog(ref: ref),
    );
  }

  void _showTemplateDetails(
    BuildContext context,
    WidgetRef ref,
    ChoboRecurringTemplateRecord template,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _TemplateDetailsSheet(
        template: template,
        ref: ref,
      ),
    );
  }
}

class _RecurringTemplateCard extends StatelessWidget {
  const _RecurringTemplateCard({
    required this.template,
    required this.onTap,
  });

  final ChoboRecurringTemplateRecord template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _FrequencyChip(
                      frequency: template.frequency,
                      interval: template.intervalValue),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatusBadge(
                    isActive: template.isActive,
                    isExpired: template.isExpired,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatNextDate(
                        template.nextGenerationDate ?? template.startDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNextDate(String date) {
    try {
      final d = DateTime.parse(date);
      return '次回: ${d.month}/${d.day}';
    } catch (_) {
      return '次回: $date';
    }
  }
}

class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({required this.frequency, required this.interval});

  final String frequency;
  final int interval;

  @override
  Widget build(BuildContext context) {
    final label = switch (frequency) {
      'daily' => interval == 1 ? '日次' : '${interval}日ごと',
      'weekly' => interval == 1 ? '週次' : '${interval}週ごと',
      'monthly' => interval == 1 ? '月次' : '${interval}ヶ月ごと',
      'yearly' => interval == 1 ? '年次' : '${interval}年ごと',
      _ => frequency,
    };

    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive, required this.isExpired});

  final bool isActive;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    if (isExpired) {
      return const Chip(
        label: Text('期限切れ'),
        backgroundColor: Colors.grey,
      );
    }
    if (isActive) {
      return const Chip(
        label: Text('有効'),
        backgroundColor: Colors.green,
      );
    }
    return const Chip(
      label: Text('一時停止'),
      backgroundColor: Colors.orange,
    );
  }
}

class _AddRecurringTemplateDialog extends ConsumerStatefulWidget {
  const _AddRecurringTemplateDialog({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_AddRecurringTemplateDialog> createState() =>
      _AddRecurringTemplateDialogState();
}

class _AddRecurringTemplateDialogState
    extends ConsumerState<_AddRecurringTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _transactionType = 'expense';
  String _frequency = 'monthly';
  int _interval = 1;
  DateTime _startDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('定期取引を追加'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  hintText: '例: 家賃',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '名前を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _transactionType,
                decoration: const InputDecoration(labelText: '取引種別'),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('支出')),
                  DropdownMenuItem(value: 'income', child: Text('収入')),
                  DropdownMenuItem(value: 'transfer', child: Text('振替')),
                ],
                onChanged: (value) {
                  setState(() {
                    _transactionType = value ?? 'expense';
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _frequency,
                decoration: const InputDecoration(labelText: '頻度'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('日次')),
                  DropdownMenuItem(value: 'weekly', child: Text('週次')),
                  DropdownMenuItem(value: 'monthly', child: Text('月次')),
                  DropdownMenuItem(value: 'yearly', child: Text('年次')),
                ],
                onChanged: (value) {
                  setState(() {
                    _frequency = value ?? 'monthly';
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('間隔: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _interval,
                    items: List.generate(12, (i) => i + 1)
                        .map((i) =>
                            DropdownMenuItem(value: i, child: Text('$i')))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _interval = value ?? 1;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('追加'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final nowStr = now.toUtc().toIso8601String();
    final template = ChoboRecurringTemplateRecord(
      templateId: 'tmpl_${now.millisecondsSinceEpoch}',
      name: _nameController.text,
      transactionType: _transactionType,
      frequency: _frequency,
      intervalValue: _interval,
      startDate: _startDate.toIso8601String().substring(0, 10),
      nextGenerationDate: _startDate.toIso8601String().substring(0, 10),
      entriesTemplate: '[]',
      isActive: true,
      autoPost: false,
      createdAt: nowStr,
      updatedAt: nowStr,
    );

    final repo = widget.ref.read(recurringTemplateRepositoryProvider);
    await repo.createTemplate(template);
    widget.ref.invalidate(recurringTemplatesProvider);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('定期取引を追加しました')),
      );
    }
  }
}

class _TemplateDetailsSheet extends StatelessWidget {
  const _TemplateDetailsSheet({
    required this.template,
    required this.ref,
  });

  final ChoboRecurringTemplateRecord template;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('ステータス'),
            trailing: template.isActive
                ? const Text('有効', style: TextStyle(color: Colors.green))
                : const Text('一時停止', style: TextStyle(color: Colors.orange)),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('次回生成日'),
            trailing: Text(template.nextGenerationDate ?? template.startDate),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final repo = ref.read(recurringTemplateRepositoryProvider);
                  if (template.isActive) {
                    await repo.pauseTemplate(
                      template.templateId,
                      DateTime.now().toUtc().toIso8601String(),
                    );
                  } else {
                    await repo.resumeTemplate(
                      template.templateId,
                      DateTime.now().toUtc().toIso8601String(),
                    );
                  }
                  ref.invalidate(recurringTemplatesProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: Icon(template.isActive ? Icons.pause : Icons.play_arrow),
                label: Text(template.isActive ? '一時停止' : '再開'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('削除の確認'),
                      content: const Text('このテンプレートを削除しますか？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('キャンセル'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('削除'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final repo = ref.read(recurringTemplateRepositoryProvider);
                    await repo.deleteTemplate(template.templateId);
                    ref.invalidate(recurringTemplatesProvider);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.delete),
                label: const Text('削除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
