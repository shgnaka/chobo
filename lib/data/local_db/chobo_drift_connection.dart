import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

LazyDatabase openChoboLazyDatabase() {
  return LazyDatabase(() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbFile = File(
      '${documentsDirectory.path}${Platform.pathSeparator}chobo.sqlite',
    );
    return NativeDatabase.createInBackground(dbFile);
  });
}
