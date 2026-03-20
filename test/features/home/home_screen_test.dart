import 'package:chobo/app/chobo_providers.dart';
import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:chobo/features/home/home_screen.dart';
import 'package:chobo/features/transactions/transaction_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows the transaction list without the void button',
      (tester) async {
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
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('navigates to the transaction detail screen', (tester) async {
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
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/transactions/:transactionId',
                builder: (context, state) {
                  return TransactionDetailScreen(
                    transactionId: state.pathParameters['transactionId']!,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.text('取引詳細'), findsOneWidget);
    expect(find.text('戻る'), findsOneWidget);
    expect(find.text('編集'), findsOneWidget);
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
