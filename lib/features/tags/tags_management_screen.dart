import 'package:chobo/app/chobo_providers.dart';
import 'package:chobo/core/tag_sanitizer.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/widgets/tag_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagsManagementScreen extends ConsumerWidget {
  const TagsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('タグ管理'),
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'タグがありません',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '下のボタンからタグを追加してください',
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
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return _TagListItem(
                tag: tag,
                onDelete: () => _deleteTag(context, ref, tag),
                onEdit: () => _editTag(context, ref, tag),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('エラー: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTagDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('タグ追加'),
      ),
    );
  }

  Future<void> _showAddTagDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _TagInputDialog(
        title: 'タグを追加',
        initialValue: '',
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ref.read(tagRepositoryProvider).createTag(name: result);
        ref.invalidate(tagsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('タグ "$result" を追加しました')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('追加に失敗しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _editTag(
    BuildContext context,
    WidgetRef ref,
    ChoboTagRecord tag,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _TagInputDialog(
        title: 'タグを編集',
        initialValue: tag.name,
      ),
    );

    if (result != null && result.isNotEmpty && result != tag.name) {
      try {
        await ref.read(tagRepositoryProvider).updateTag(
              tag.copyWith(name: result),
            );
        ref.invalidate(tagsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('タグを "$result" に変更しました')),
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

  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    ChoboTagRecord tag,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タグを削除'),
        content:
            Text('タグ "${tag.name}" を削除してもよろしいですか？\nこのタグは関連するすべての取引から削除されます。'),
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
        await ref.read(tagRepositoryProvider).deleteTag(tag.tagId);
        ref.invalidate(tagsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('タグ "${tag.name}" を削除しました')),
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

class _TagListItem extends StatelessWidget {
  const _TagListItem({
    required this.tag,
    required this.onDelete,
    required this.onEdit,
  });

  final ChoboTagRecord tag;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: getTagColor(tag.color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.label, color: Colors.white, size: 20),
      ),
      title: Text(tag.name),
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

class _TagInputDialog extends StatefulWidget {
  const _TagInputDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final String initialValue;

  @override
  State<_TagInputDialog> createState() => _TagInputDialogState();
}

class _TagInputDialogState extends State<_TagInputDialog> {
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
        _errorText = 'タグ名を入力してください';
      } else if (value.length > 50) {
        _errorText = '50文字以内で入力してください';
      } else if (!TagSanitizer.isValid(value)) {
        _errorText = '使用できない文字が含まれています';
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
          labelText: 'タグ名',
          hintText: '例: 食料品, 交通費',
          errorText: _errorText,
          helperText: '50文字まで',
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
