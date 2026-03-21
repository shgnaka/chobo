import 'package:chobo/app/chobo_providers.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Color getTagColor(String? color) {
  if (color != null && color.isNotEmpty) {
    try {
      final colorValue = int.parse(color.replaceFirst('#', ''), radix: 16);
      return Color(0xFF000000 | colorValue);
    } catch (_) {}
  }
  return Colors.blue;
}

final transactionTagsProvider =
    FutureProvider.family<List<ChoboTagRecord>, String>(
        (ref, transactionId) async {
  return ref.watch(tagRepositoryProvider).getTagsForTransaction(transactionId);
});

class TagSelector extends ConsumerStatefulWidget {
  const TagSelector({
    super.key,
    required this.transactionId,
    required this.selectedTagIds,
    required this.onTagsChanged,
  });

  final String transactionId;
  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onTagsChanged;

  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);

    return tagsAsync.when(
      data: (allTags) {
        if (allTags.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'タグがありません。「タグ管理」から追加してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allTags.map((tag) {
            final isSelected = widget.selectedTagIds.contains(tag.tagId);
            return FilterChip(
              label: Text(tag.name),
              selected: isSelected,
              onSelected: (selected) {
                final newSelection = List<String>.from(widget.selectedTagIds);
                if (selected) {
                  newSelection.add(tag.tagId);
                } else {
                  newSelection.remove(tag.tagId);
                }
                widget.onTagsChanged(newSelection);
              },
              avatar: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: getTagColor(tag.color),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('タグの読み込みに失敗しました'),
      ),
    );
  }
}

class TagDisplay extends StatelessWidget {
  const TagDisplay({
    super.key,
    required this.tags,
    this.maxDisplay = 3,
  });

  final List<ChoboTagRecord> tags;
  final int maxDisplay;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayTags = tags.take(maxDisplay).toList();
    final remaining = tags.length - maxDisplay;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayTags.map((tag) => _TagChip(tag: tag)),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remaining',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final ChoboTagRecord tag;

  @override
  Widget build(BuildContext context) {
    final tagColor = getTagColor(tag.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tagColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        tag.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tagColor,
            ),
      ),
    );
  }
}
