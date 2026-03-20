import 'package:chobo/data/local_db/chobo_migration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChoboMigration', () {
    test('plans incremental versions', () {
      expect(ChoboMigration.plannedVersions(0, 1), <int>[1]);
      expect(ChoboMigration.plannedVersions(1, 1), isEmpty);
      expect(ChoboMigration.plannedVersions(1, 3), <int>[2, 3]);
    });

    test('rejects a downgrade plan', () {
      expect(
        () => ChoboMigration.plannedVersions(2, 1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
