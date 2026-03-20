import 'package:flutter/material.dart';

import 'router.dart';

class ChoboApp extends StatelessWidget {
  const ChoboApp({super.key});

  @override
  Widget build(BuildContext context) {
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
    );
  }
}
