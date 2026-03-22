import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';
import 'transaction_list_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHOBO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          const _QuickActionsBar(),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(
                    child: Text('取引がまだありません'),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Text(
                      '取引一覧',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...transactions.map(
                      (transaction) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TransactionListTile(transaction: transaction),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Text('取引の読み込みに失敗しました'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.stars,
              label: 'ポイント',
              onTap: () => context.push('/points'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.bar_chart,
              label: '月次',
              onTap: () => context.push('/summary/$month'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.repeat,
              label: '定期',
              onTap: () => context.push('/recurring'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
