import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';

final GoRouter choboRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
