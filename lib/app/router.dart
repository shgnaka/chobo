import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/transactions/transaction_detail_screen.dart';
import '../features/transactions/transaction_edit_screen.dart';

final GoRouter choboRouter = GoRouter(
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
);
