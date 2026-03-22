import 'package:chobo/data/local_db/chobo_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChoboSchema', () {
    test('declares the first schema version', () {
      expect(ChoboSchema.schemaVersion, 11);
    });

    test('includes the core tables required by the backup payload', () {
      expect(
        ChoboSchema.createStatements,
        hasLength(16),
      );
      final combinedStatements = ChoboSchema.createStatements.join('\n');
      expect(
          combinedStatements, contains('CREATE TABLE IF NOT EXISTS accounts'));
      expect(combinedStatements,
          contains('CREATE TABLE IF NOT EXISTS transactions'));
      expect(
          combinedStatements, contains('CREATE TABLE IF NOT EXISTS entries'));
      expect(combinedStatements,
          contains('CREATE TABLE IF NOT EXISTS period_closures'));
      expect(
          combinedStatements, contains('CREATE TABLE IF NOT EXISTS settings'));
      expect(combinedStatements,
          contains('CREATE TABLE IF NOT EXISTS audit_events'));
      expect(combinedStatements,
          contains('CREATE TABLE IF NOT EXISTS points_accounts'));
      expect(combinedStatements,
          contains('CREATE TABLE IF NOT EXISTS points_transactions'));
      expect(combinedStatements,
          contains('CREATE TABLE IF NOT EXISTS recurring_templates'));
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
          "type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment', 'advance_payment', 'reimbursement'))",
        ),
      );
      expect(
        statements,
        contains(
            "status TEXT NOT NULL CHECK (status IN ('posted', 'pending', 'void'))"),
      );
      expect(
        statements,
        contains(
            "direction TEXT NOT NULL CHECK (direction IN ('increase', 'decrease'))"),
      );
    });

    test('includes due_date column for transactions', () {
      final statements = ChoboSchema.createStatements.join('\n');

      expect(
        statements,
        contains('due_date TEXT'),
      );
    });

    test('includes billing_day and payment_due_day columns for accounts', () {
      final statements = ChoboSchema.createStatements.join('\n');

      expect(
        statements,
        contains('billing_day INTEGER'),
      );
      expect(
        statements,
        contains('payment_due_day INTEGER'),
      );
    });
  });
}
