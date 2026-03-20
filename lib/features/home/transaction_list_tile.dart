import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
  });

  final ChoboTransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          transaction.description ?? transaction.type,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '${transaction.date} · ${transaction.status}',
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
