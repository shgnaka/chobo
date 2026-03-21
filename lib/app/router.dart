import 'package:go_router/go_router.dart';

import '../features/counterparties/counterparties_management_screen.dart';
import '../features/home/home_screen.dart';
import '../features/points/points_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transaction_detail_screen.dart';
import '../features/transactions/transaction_edit_screen.dart';

final GoRouter choboRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/counterparties',
      builder: (context, state) => const CounterpartiesManagementScreen(),
    ),
    GoRoute(
      path: '/points',
      builder: (context, state) => const PointsScreen(),
    ),
    GoRoute(
      path: '/recurring',
      builder: (context, state) => const RecurringScreen(),
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
