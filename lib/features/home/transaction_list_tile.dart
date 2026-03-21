import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';

class TransactionListTile extends ConsumerWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
  });

  final ChoboTransactionRecord transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    final typeLabel = termService.getTransactionLabelForType(transaction.type);
    final statusLabel = termService.getStatusLabelForStatus(transaction.status);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          transaction.description ?? typeLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '${transaction.date} · $statusLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/transactions/${transaction.transactionId}');
        },
      ),
    );
  }
}
