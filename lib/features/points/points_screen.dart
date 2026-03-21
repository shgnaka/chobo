import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chobo_providers.dart';
import '../../data/local_db/chobo_records.dart';

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(pointsAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ポイント'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('ポイント口座がありません'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddPointsAccountDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('ポイント口座を追加'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _PointsAccountCard(
                account: account,
                onTap: () => _showPointsHistory(context, ref, account),
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
        onPressed: () => _showAddPointsAccountDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPointsAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddPointsAccountDialog(ref: ref),
    );
  }

  void _showPointsHistory(
    BuildContext context,
    WidgetRef ref,
    ChoboPointsAccountRecord account,
  ) {
    context.push('/points/${account.pointsAccountId}');
  }
}

class _PointsAccountCard extends ConsumerWidget {
  const _PointsAccountCard({
    required this.account,
    required this.onTap,
  });

  final ChoboPointsAccountRecord account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync =
        ref.watch(pointsBalanceProvider(account.pointsAccountId));

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
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        account.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  if (account.isArchived)
                    const Chip(
                      label: Text('アーカイブ済み'),
                      backgroundColor: Colors.grey,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              balanceAsync.when(
                data: (balance) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '残高',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${balance.availableBalance} ${account.pointsCurrency}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    if (account.exchangeRate != 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(${balance.availableBalance * account.exchangeRate}円相当)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ],
                ),
                loading: () => const SizedBox(
                  height: 24,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => const Text('残高の読み込みに失敗'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPointsAccountDialog extends ConsumerStatefulWidget {
  const _AddPointsAccountDialog({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_AddPointsAccountDialog> createState() =>
      _AddPointsAccountDialogState();
}

class _AddPointsAccountDialogState
    extends ConsumerState<_AddPointsAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currencyController = TextEditingController(text: 'P');
  final _exchangeRateController = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ポイント口座を追加'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名前',
                hintText: '例: T-Point',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '名前を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currencyController,
              decoration: const InputDecoration(
                labelText: '通貨記号',
                hintText: '例: T, R, P',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '通貨記号を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _exchangeRateController,
              decoration: const InputDecoration(
                labelText: '交換レート (1ポイントあたりの円)',
                hintText: '1',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '交換レートを入力してください';
                }
                final rate = int.tryParse(value);
                if (rate == null || rate <= 0) {
                  return '正の数を入力してください';
                }
                return null;
              },
            ),
          ],
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

    final now = DateTime.now().toUtc().toIso8601String();
    final account = ChoboPointsAccountRecord(
      pointsAccountId: 'points:${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text,
      pointsCurrency: _currencyController.text,
      exchangeRate: int.parse(_exchangeRateController.text),
      isDefault: false,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    await widget.ref
        .read(pointsRepositoryProvider)
        .createPointsAccount(account);
    widget.ref.invalidate(pointsAccountsProvider);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
