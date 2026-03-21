import 'package:chobo/app/chobo_providers.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterpartiesProvider =
    FutureProvider<List<ChoboCounterpartyRecord>>((ref) async {
  return ref.watch(counterpartyRepositoryProvider).listCounterparties();
});

class CounterpartiesManagementScreen extends ConsumerWidget {
  const CounterpartiesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counterpartiesAsync = ref.watch(counterpartiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('相手先管理'),
      ),
      body: counterpartiesAsync.when(
        data: (counterparties) {
          if (counterparties.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '相手先がありません',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '取引編集から相手先を追加してください',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: counterparties.length,
            itemBuilder: (context, index) {
              final counterparty = counterparties[index];
              return _CounterpartyListItem(
                counterparty: counterparty,
                onEdit: () => _editCounterparty(context, ref, counterparty),
                onDelete: () => _deleteCounterparty(context, ref, counterparty),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('エラー: $error'),
        ),
      ),
    );
  }

  Future<void> _editCounterparty(
    BuildContext context,
    WidgetRef ref,
    ChoboCounterpartyRecord counterparty,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CounterpartyInputDialog(
        title: '相手先を編集',
        initialValue: counterparty.rawName,
      ),
    );

    if (result != null && result.isNotEmpty && result != counterparty.rawName) {
      try {
        await ref.read(counterpartyRepositoryProvider).updateCounterparty(
              counterparty.copyWith(rawName: result),
            );
        ref.invalidate(counterpartiesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('相手先を "$result" に変更しました')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新に失敗しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCounterparty(
    BuildContext context,
    WidgetRef ref,
    ChoboCounterpartyRecord counterparty,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('相手先を削除'),
        content: Text(
          '相手先 "${counterparty.rawName}" を削除してもよろしいですか？\n'
          'この変更は関連するすべての取引には影響しません（歴史的記録として保持されます）。',
        ),
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
      try {
        await ref
            .read(counterpartyRepositoryProvider)
            .deleteCounterparty(counterparty.counterpartyId);
        ref.invalidate(counterpartiesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('相手先 "${counterparty.rawName}" を削除しました')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }
}

class _CounterpartyListItem extends StatelessWidget {
  const _CounterpartyListItem({
    required this.counterparty,
    required this.onEdit,
    required this.onDelete,
  });

  final ChoboCounterpartyRecord counterparty;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.business,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(counterparty.rawName),
      subtitle: counterparty.rawName != counterparty.normalizedName
          ? Text(
              counterparty.normalizedName,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CounterpartyInputDialog extends StatefulWidget {
  const _CounterpartyInputDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final String initialValue;

  @override
  State<_CounterpartyInputDialog> createState() =>
      _CounterpartyInputDialogState();
}

class _CounterpartyInputDialogState extends State<_CounterpartyInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    setState(() {
      if (value.isEmpty) {
        _errorText = '相手先名を入力してください';
      } else {
        _errorText = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: '相手先名',
          hintText: '例: スターバックス',
          errorText: _errorText,
        ),
        onChanged: _validate,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _errorText == null && _controller.text.isNotEmpty
              ? _submit
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    if (_errorText == null && _controller.text.isNotEmpty) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }
}
