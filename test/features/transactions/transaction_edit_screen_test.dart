import 'package:chobo/app/chobo_providers.dart';
import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:chobo/features/transactions/transaction_detail_screen.dart';
import 'package:chobo/features/transactions/transaction_edit_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('edits a transaction through the detail screen', (tester) async {
    final db = _openDb();
    addTearDown(db.close);
    final accounts = AccountRepository(db);
    final transactions = TransactionRepository(db);

    await accounts.createAccount(
      _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
    );
    await accounts.createAccount(
      _sampleAccount(accountId: 'expense:food', name: 'Food'),
    );
    await transactions.createTransaction(
      _sampleTransaction(transactionId: 'txn_001'),
      <ChoboEntryRecord>[
        const ChoboEntryRecord(
          entryId: 'ent_001',
          transactionId: 'txn_001',
          accountId: 'asset:bank:main',
          direction: 'decrease',
          amount: 1200,
        ),
        const ChoboEntryRecord(
          entryId: 'ent_002',
          transactionId: 'txn_001',
          accountId: 'expense:food',
          direction: 'increase',
          amount: 1200,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/transactions/txn_001',
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/transactions/:transactionId',
                builder: (context, state) {
                  return TransactionDetailScreen(
                    transactionId: state.pathParameters['transactionId']!,
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      return TransactionEditScreen(
                        transactionId: state.pathParameters['transactionId']!,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '2026-03-21');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dinner');
    await tester.enterText(find.byType(TextFormField).at(4), '1300');
    await tester.enterText(find.byType(TextFormField).at(6), '1300');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsOneWidget);

    final updated = await transactions.getTransaction('txn_001');
    expect(updated == null, isFalse);
    expect(updated!.date, '2026-03-21');
    expect(updated.description, 'Dinner');
    expect(updated.type, 'expense');

    final updatedEntries = await db.customSelect(
      '''
          SELECT account_id, direction, amount
          FROM entries
          WHERE transaction_id = ?
          ORDER BY entry_id
          ''',
      variables: <Variable>[Variable('txn_001')],
    ).get();
    expect(updatedEntries[0].read<int>('amount'), 1300);
    expect(updatedEntries[1].read<int>('amount'), 1300);
  });

  testWidgets('shows save boundaries for closed transactions', (tester) async {
    final db = _openDb();
    addTearDown(db.close);
    final accounts = AccountRepository(db);
    final transactions = TransactionRepository(db);

    await accounts.createAccount(
      _sampleAccount(accountId: 'asset:bank:main', name: 'Main Bank'),
    );
    await accounts.createAccount(
      _sampleAccount(accountId: 'expense:food', name: 'Food'),
    );
    await db.customInsert(
      '''
      INSERT INTO period_closures (
        closure_id,
        start_date,
        end_date,
        closed_at,
        note
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable('closure_001'),
        Variable('2026-03-01'),
        Variable('2026-03-31'),
        Variable('2026-04-01T00:00:00Z'),
        Variable('march close'),
      ],
    );
    await transactions.createTransaction(
      _sampleTransaction(transactionId: 'txn_002'),
      <ChoboEntryRecord>[
        const ChoboEntryRecord(
          entryId: 'ent_003',
          transactionId: 'txn_002',
          accountId: 'asset:bank:main',
          direction: 'decrease',
          amount: 1200,
        ),
        const ChoboEntryRecord(
          entryId: 'ent_004',
          transactionId: 'txn_002',
          accountId: 'expense:food',
          direction: 'increase',
          amount: 1200,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/transactions/txn_002/edit',
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/transactions/:transactionId',
                builder: (context, state) {
                  return TransactionDetailScreen(
                    transactionId: state.pathParameters['transactionId']!,
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      return TransactionEditScreen(
                        transactionId: state.pathParameters['transactionId']!,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('保存制約'), findsOneWidget);
    expect(
      find.text('締め済み期間の取引は直接編集できません。訂正取引を作成してください。'),
      findsOneWidget,
    );

    final saveButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '保存'));
    expect(saveButton.onPressed, null);
  });
}

AppDatabase _openDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (database) {
        database.execute('PRAGMA foreign_keys = ON;');
      },
    ),
  );
}

ChoboAccountRecord _sampleAccount({
  required String accountId,
  required String name,
}) {
  return ChoboAccountRecord(
    accountId: accountId,
    kind: accountId.split(':').first,
    name: name,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}

ChoboTransactionRecord _sampleTransaction({
  required String transactionId,
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: '2026-03-20',
    type: 'expense',
    status: 'posted',
    description: 'Lunch',
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}
