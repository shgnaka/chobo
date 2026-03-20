import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'chobo_schema.dart';

LazyDatabase openChoboLazyDatabase() {
  return LazyDatabase(() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbFile = File(
      '${documentsDirectory.path}${Platform.pathSeparator}${ChoboSchema.databaseFileName}',
    );
    return NativeDatabase.createInBackground(
      dbFile,
      setup: (database) {
        database.execute('PRAGMA foreign_keys = ON;');
        database.execute('PRAGMA busy_timeout = 5000;');
      },
    );
  });
}
