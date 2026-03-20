import 'package:drift/drift.dart';

import 'chobo_drift_connection.dart';
import 'chobo_migration.dart';
import 'chobo_schema.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? openChoboLazyDatabase()) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => ChoboSchema.schemaVersion;

  @override
  List<TableInfo<Table, DataClass>> get allTables =>
      const <TableInfo<Table, DataClass>>[];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities =>
      const <DatabaseSchemaEntity>[];

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: ChoboMigration.onCreate,
      onUpgrade: ChoboMigration.onUpgrade,
    );
  }
}
