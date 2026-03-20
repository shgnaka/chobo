import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/lock/app_lock_screen.dart';
import '../features/lock/app_lock_state.dart';
import 'router.dart';

class ChoboApp extends ConsumerStatefulWidget {
  const ChoboApp({super.key});

  @override
  ConsumerState<ChoboApp> createState() => _ChoboAppState();
}

class _ChoboAppState extends ConsumerState<ChoboApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeLock() async {
    await ref.read(appLockNotifierProvider.notifier).initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final lockState = ref.read(appLockNotifierProvider);
      if (lockState == AppLockState.locked) {
        ref.read(appLockNotifierProvider.notifier).unlock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockNotifierProvider);

    if (lockState == AppLockState.locked) {
      return MaterialApp(
        title: 'CHOBO',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1F6FEB),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const AppLockScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp.router(
      title: 'CHOBO',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6FEB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: choboRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
