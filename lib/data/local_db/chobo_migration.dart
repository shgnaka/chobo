import 'package:drift/drift.dart';

import 'chobo_schema.dart';

class ChoboMigration {
  ChoboMigration._();

  static Future<void> onCreate(Migrator migrator) async {
    await migrator.database.transaction(() async {
      await _applyVersion1(migrator);
    });
  }

  static Future<void> onUpgrade(
    Migrator migrator,
    int from,
    int to,
  ) async {
    if (from > to) {
      throw ArgumentError.value(from, 'from', 'must not be greater than to');
    }
    if (from == to) {
      return;
    }

    await migrator.database.transaction(() async {
      for (final version in plannedVersions(from, to)) {
        switch (version) {
          case 1:
            await _applyVersion1(migrator);
            break;
          case 2:
            await _applyVersion2(migrator);
            break;
          default:
            throw UnsupportedError(
              'Schema migration to v$version is not implemented yet.',
            );
        }
      }
    });
  }

  static List<int> plannedVersions(int from, int to) {
    if (from > to) {
      throw ArgumentError.value(from, 'from', 'must not be greater than to');
    }
    if (from == to) {
      return const <int>[];
    }

    return <int>[
      for (var version = from + 1; version <= to; version++) version
    ];
  }

  static Future<void> _applyVersion1(Migrator migrator) async {
    for (final statement in ChoboSchema.createAllStatements) {
      await migrator.database.customStatement(statement);
    }
    await migrator.database.customStatement(
      'PRAGMA user_version = ${ChoboSchema.schemaVersion};',
    );
  }

  static Future<void> _applyVersion2(Migrator migrator) async {
    await migrator.database.customStatement(
      "ALTER TABLE accounts ADD COLUMN currency TEXT NOT NULL DEFAULT 'JPY';",
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 2;',
    );
  }
}
