import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';
import '../../core/terminology_labels.dart';
import '../../widgets/tag_widgets.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionProvider(transactionId));
    final entriesAsync = ref.watch(transactionEntriesProvider(transactionId));
    final decisionAsync = ref.watch(voidDecisionProvider(transactionId));
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: const Text('戻る'),
        ),
        title: const Text('取引詳細'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              context.push('/transactions/$transactionId/edit');
            },
            child: const Text('編集'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionAsync.when(
        data: (transaction) {
          if (transaction == null) {
            return const Center(
              child: Text('取引が見つかりません'),
            );
          }

          final accounts =
              accountsAsync.valueOrNull ?? const <ChoboAccountRecord>[];
          final accountNames = <String, String>{
            for (final account in accounts) account.accountId: account.name,
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                transaction.description ??
                    ref
                        .watch(terminologyServiceProvider)
                        .getTransactionLabelForType(transaction.type),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${transaction.date} · ${ref.watch(terminologyServiceProvider).getStatusLabelForStatus(transaction.status)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _Section(
                title: ref
                    .watch(terminologyServiceProvider)
                    .getSectionLabel(SectionTerm.overview),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _DetailRow(
                        label: ref
                            .watch(terminologyServiceProvider)
                            .getFieldLabel(FieldTerm.transactionDate),
                        value: transaction.date),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: '種別',
                      value: ref
                          .watch(terminologyServiceProvider)
                          .getTransactionLabelForType(transaction.type),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: '状態',
                      value: ref
                          .watch(terminologyServiceProvider)
                          .getStatusLabelForStatus(transaction.status),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: '締め状態',
                      value: ref
                          .watch(terminologyServiceProvider)
                          .getPeriodStateLabel(transaction.periodLockState),
                    ),
                    if (transaction.counterparty != null) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: ref
                            .watch(terminologyServiceProvider)
                            .getFieldLabel(FieldTerm.counterparty),
                        value: transaction.counterparty!,
                      ),
                    ],
                    if (transaction.externalRef != null) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: ref
                            .watch(terminologyServiceProvider)
                            .getFieldLabel(FieldTerm.externalRef),
                        value: transaction.externalRef!,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _TagSection(transactionId: transactionId),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: ref
                    .watch(terminologyServiceProvider)
                    .getSectionLabel(SectionTerm.entries),
                child: entriesAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Text('明細がありません');
                    }

                    return Column(
                      children: entries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final value = entry.value;
                        final termService =
                            ref.watch(terminologyServiceProvider);
                        final accountName = termService.getStandardAccountName(
                            accountNames[value.accountId] ?? value.accountId);

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == entries.length ? 0 : 12,
                          ),
                          child: _EntryCard(
                            entryIndex: index,
                            accountName: accountName,
                            accountId: value.accountId,
                            directionLabel: termService
                                .getDirectionLabelForDirection(value.direction),
                            amountLabel: _signedAmountLabel(
                              value.direction,
                              value.amount,
                            ),
                            amountColor: _amountColor(context, value.direction),
                            memo: value.memo,
                          ),
                        );
                      }).toList(growable: false),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                  error: (error, stackTrace) => const Text(
                    '明細を読み込めませんでした',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: ref
                    .watch(terminologyServiceProvider)
                    .getSectionLabel(SectionTerm.operations),
                child: decisionAsync.when(
                  data: (decision) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(decision.reason),
                        const SizedBox(height: 12),
                        _ActionButtons(
                          voidLabel: decision.isClosedPeriod ? '締め後に取消' : '取消',
                          onDuplicate: () async {
                            await _duplicateTransaction(
                              context: context,
                              ref: ref,
                              transaction: transaction,
                              entries: entriesAsync.valueOrNull ??
                                  const <ChoboEntryRecord>[],
                            );
                          },
                          onCorrection: decision.canApply
                              ? () async {
                                  await _createCorrectionTransaction(
                                    context: context,
                                    ref: ref,
                                    transaction: transaction,
                                    entries: entriesAsync.valueOrNull ??
                                        const <ChoboEntryRecord>[],
                                  );
                                }
                              : null,
                          onVoid: decision.canApply
                              ? () async {
                                  await ref
                                      .read(transactionRepositoryProvider)
                                      .voidTransaction(transactionId);
                                  ref.invalidate(
                                      transactionProvider(transactionId));
                                  ref.invalidate(transactionEntriesProvider(
                                      transactionId));
                                  ref.invalidate(
                                      voidDecisionProvider(transactionId));
                                  ref.invalidate(transactionsProvider);
                                }
                              : null,
                          onRefund: transaction.status == 'posted' &&
                                  !transaction.isRefund
                              ? () =>
                                  _showRefundDialog(context, ref, transaction)
                              : null,
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LinearProgressIndicator(),
                        SizedBox(height: 12),
                        _ActionButtons(
                          voidLabel: '取消',
                          onDuplicate: null,
                          onCorrection: null,
                          onVoid: null,
                          onRefund: null,
                        ),
                      ],
                    ),
                  ),
                  error: (error, stackTrace) => const Text(
                    '取消可否を確認できませんでした。',
                  ),
                ),
              ),
            ],
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

  Future<void> _duplicateTransaction({
    required BuildContext context,
    required WidgetRef ref,
    required ChoboTransactionRecord transaction,
    required List<ChoboEntryRecord> entries,
  }) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('複製できる明細がありません。')),
      );
      return;
    }

    final duplicateId = _generateTransactionId('dup');
    final duplicateTransaction = transaction.copyWith(
      transactionId: duplicateId,
      status: 'posted',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final duplicateEntries = entries.asMap().entries.map((entry) {
      final now = DateTime.now().toUtc().microsecondsSinceEpoch;
      final value = entry.value;
      return value.copyWith(
        entryId: '${duplicateId}_${entry.key}_$now',
        transactionId: duplicateId,
      );
    }).toList(growable: false);

    await ref
        .read(transactionRepositoryProvider)
        .createTransaction(duplicateTransaction, duplicateEntries);
    ref.invalidate(transactionsProvider);
    if (context.mounted) {
      context.push('/transactions/$duplicateId');
    }
  }

  Future<void> _createCorrectionTransaction({
    required BuildContext context,
    required WidgetRef ref,
    required ChoboTransactionRecord transaction,
    required List<ChoboEntryRecord> entries,
  }) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('訂正できる明細がありません。')),
      );
      return;
    }

    await ref
        .read(transactionRepositoryProvider)
        .voidTransaction(transactionId);

    final correctionId = _generateTransactionId('cor');
    final correctionTransaction = transaction.copyWith(
      transactionId: correctionId,
      status: 'posted',
      description: transaction.description == null
          ? '訂正'
          : '訂正: ${transaction.description}',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final correctionEntries = entries.asMap().entries.map((entry) {
      final now = DateTime.now().toUtc().microsecondsSinceEpoch;
      final value = entry.value;
      return value.copyWith(
        entryId: '${correctionId}_${entry.key}_$now',
        transactionId: correctionId,
      );
    }).toList(growable: false);

    await ref
        .read(transactionRepositoryProvider)
        .createCorrectionTransaction(correctionTransaction, correctionEntries);

    ref.invalidate(transactionProvider(transactionId));
    ref.invalidate(transactionEntriesProvider(transactionId));
    ref.invalidate(voidDecisionProvider(transactionId));
    ref.invalidate(transactionsProvider);
    if (context.mounted) {
      context.push('/transactions/$correctionId');
    }
  }

  void _showRefundDialog(
    BuildContext context,
    WidgetRef ref,
    ChoboTransactionRecord transaction,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('返金'),
        content: Text('${transaction.description ?? 'この取引'}を返金しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('返金機能は開発中です'),
                ),
              );
            },
            child: const Text('返金'),
          ),
        ],
      ),
    );
  }

  String _generateTransactionId(String prefix) {
    return '${prefix}_${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({
    super.key,
    required this.voidLabel,
    required this.onDuplicate,
    required this.onCorrection,
    required this.onVoid,
    this.onRefund,
  });

  final String voidLabel;
  final VoidCallback? onDuplicate;
  final VoidCallback? onCorrection;
  final VoidCallback? onVoid;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        OutlinedButton(
          onPressed: onDuplicate,
          child: Text(termService.getActionLabel(ActionTerm.duplicate)),
        ),
        FilledButton.tonal(
          onPressed: onCorrection,
          child: Text(termService.getActionLabel(ActionTerm.correction)),
        ),
        if (onRefund != null)
          FilledButton.tonal(
            onPressed: onRefund,
            child: Text(termService.getActionLabel(ActionTerm.refund)),
          ),
        FilledButton(
          onPressed: onVoid,
          child: Text(voidLabel),
        ),
      ],
    );
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

class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    super.key,
    required this.entryIndex,
    required this.accountName,
    required this.accountId,
    required this.directionLabel,
    required this.amountLabel,
    required this.amountColor,
    this.memo,
  });

  final int entryIndex;
  final String accountName;
  final String accountId;
  final String directionLabel;
  final String amountLabel;
  final Color? amountColor;
  final String? memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final termService = ref.watch(terminologyServiceProvider);
    final displayLabel = termService.getEntryLabelForIndex(entryIndex);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    '${entryIndex + 1}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        accountName,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        accountId,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  amountLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: amountColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Pill(label: displayLabel),
                if (memo != null && memo!.isNotEmpty) _Pill(label: memo!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

String _signedAmountLabel(String direction, int amount) {
  final prefix = direction == 'decrease' ? '-' : '+';
  return '$prefix${_formatAmount(amount)}';
}

String _formatAmount(int amount) {
  final raw = amount.abs().toString();
  return raw.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

Color? _amountColor(BuildContext context, String direction) {
  if (direction == 'decrease') {
    return Theme.of(context).colorScheme.error;
  }
  if (direction == 'increase') {
    return Theme.of(context).colorScheme.primary;
  }
  return null;
}

class _TagSection extends ConsumerWidget {
  const _TagSection({required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(transactionTagsProvider(transactionId));

    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'タグ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TagDisplay(tags: tags),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
