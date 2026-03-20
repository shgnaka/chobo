import 'package:chobo/data/local_db/chobo_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChoboSchema', () {
    test('declares the first schema version', () {
      expect(ChoboSchema.schemaVersion, 1);
    });

    test('includes the core tables required by the backup payload', () {
      expect(
        ChoboSchema.createStatements,
        hasLength(6),
      );
      expect(
        ChoboSchema.createStatements.join('\n'),
        allOf(
          contains('CREATE TABLE IF NOT EXISTS accounts'),
          contains('CREATE TABLE IF NOT EXISTS transactions'),
          contains('CREATE TABLE IF NOT EXISTS entries'),
          contains('CREATE TABLE IF NOT EXISTS period_closures'),
          contains('CREATE TABLE IF NOT EXISTS settings'),
          contains('CREATE TABLE IF NOT EXISTS audit_events'),
        ),
      );
    });

    test('keeps the foreign-key relationships that the domain depends on', () {
      final statements = ChoboSchema.createStatements.join('\n');

      expect(
        statements,
        contains(
          'parent_account_id TEXT REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE SET NULL',
        ),
      );
      expect(
        statements,
        contains(
          'transaction_id TEXT NOT NULL REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE CASCADE',
        ),
      );
      expect(
        statements,
        contains(
          'account_id TEXT NOT NULL REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE RESTRICT',
        ),
      );
    });

    test('keeps the core transaction enums aligned with the spec', () {
      final statements = ChoboSchema.createStatements.join('\n');

      expect(
        statements,
        contains(
          "kind TEXT NOT NULL CHECK (kind IN ('asset', 'liability', 'income', 'expense', 'equity'))",
        ),
      );
      expect(
        statements,
        contains(
          "type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment'))",
        ),
      );
      expect(
        statements,
        contains("status TEXT NOT NULL CHECK (status IN ('posted', 'pending', 'void'))"),
      );
      expect(
        statements,
        contains("direction TEXT NOT NULL CHECK (direction IN ('increase', 'decrease'))"),
      );
    });
  });
}
