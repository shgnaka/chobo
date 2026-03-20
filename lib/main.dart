import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_initializer.dart';

void main() {
  runApp(const ProviderScope(child: AppInitializer()));
}
