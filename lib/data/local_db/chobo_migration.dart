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
          case 3:
            await _applyVersion3(migrator);
            break;
          case 4:
            await _applyVersion4(migrator);
            break;
          case 5:
            await _applyVersion5(migrator);
            break;
          case 6:
            await _applyVersion6(migrator);
            break;
          case 7:
            await _applyVersion7(migrator);
            break;
          case 8:
            await _applyVersion8(migrator);
            break;
          case 9:
            await _applyVersion9(migrator);
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

  static Future<void> _applyVersion3(Migrator migrator) async {
    await migrator.database.customInsert(
      '''
      INSERT OR IGNORE INTO settings (setting_key, setting_value)
      VALUES ('app_lock_enabled', 'false'),
             ('lock_mode', 'biometric'),
             ('cache_duration_seconds', '300'),
             ('audit_granularity', 'summary');
      ''',
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 3;',
    );
  }

  static Future<void> _applyVersion4(Migrator migrator) async {
    await migrator.database.customStatement(
      "ALTER TABLE transactions ADD COLUMN original_transaction_id TEXT REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL;",
    );
    await migrator.database.customStatement(
      "ALTER TABLE transactions ADD COLUMN refund_type TEXT CHECK (refund_type IN ('full', 'partial') OR refund_type IS NULL);",
    );
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS points_accounts (
        points_account_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        points_currency TEXT NOT NULL,
        exchange_rate INTEGER NOT NULL DEFAULT 1 CHECK (exchange_rate > 0),
        is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
    );
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS points_transactions (
        points_transaction_id TEXT PRIMARY KEY,
        points_account_id TEXT NOT NULL REFERENCES points_accounts(points_account_id) ON UPDATE CASCADE ON DELETE CASCADE,
        transaction_id TEXT REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL,
        direction TEXT NOT NULL CHECK (direction IN ('earned', 'redeemed', 'expired', 'adjusted')),
        points_amount INTEGER NOT NULL,
        jpy_value INTEGER NOT NULL DEFAULT 0 CHECK (jpy_value >= 0),
        description TEXT,
        occurred_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
      ''',
    );
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS recurring_templates (
        template_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment', 'advance_payment', 'reimbursement')),
        frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
        interval_value INTEGER NOT NULL DEFAULT 1 CHECK (interval_value > 0),
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_generation_date TEXT,
        last_generated_transaction_id TEXT REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL,
        entries_template TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        auto_post INTEGER NOT NULL DEFAULT 0 CHECK (auto_post IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_points_accounts_name ON points_accounts(name);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_points_transactions_points_account_id ON points_transactions(points_account_id);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_points_transactions_transaction_id ON points_transactions(transaction_id);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_points_transactions_created_at ON points_transactions(created_at);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recurring_templates_next_date ON recurring_templates(next_generation_date);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recurring_templates_is_active ON recurring_templates(is_active);',
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 4;',
    );
  }

  static Future<void> _applyVersion5(Migrator migrator) async {
    await migrator.database.customStatement(
      "ALTER TABLE points_transactions ADD COLUMN expiration_date TEXT;",
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 5;',
    );
  }

  static Future<void> _applyVersion6(Migrator migrator) async {
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS tags (
        tag_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(name)
      );
      ''',
    );
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS transaction_tags (
        transaction_id TEXT NOT NULL REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE CASCADE,
        tag_id TEXT NOT NULL REFERENCES tags(tag_id) ON UPDATE CASCADE ON DELETE CASCADE,
        PRIMARY KEY (transaction_id, tag_id)
      );
      ''',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transaction_tags_transaction_id ON transaction_tags(transaction_id);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transaction_tags_tag_id ON transaction_tags(tag_id);',
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 6;',
    );
  }

  static Future<void> _applyVersion7(Migrator migrator) async {
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS counterparties (
        counterparty_id TEXT PRIMARY KEY,
        normalized_name TEXT NOT NULL,
        raw_name TEXT NOT NULL,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(normalized_name)
      );
      ''',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_counterparties_normalized_name ON counterparties(normalized_name);',
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 7;',
    );
  }

  static Future<void> _applyVersion8(Migrator migrator) async {
    await migrator.database.customStatement(
      'ALTER TABLE transactions ADD COLUMN counterparty_id TEXT REFERENCES counterparties(counterparty_id) ON UPDATE CASCADE ON DELETE SET NULL;',
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 8;',
    );
  }

  static Future<void> _applyVersion9(Migrator migrator) async {
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS budgets (
        budget_id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE CASCADE,
        month TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount >= 0),
        alert_threshold_percent INTEGER NOT NULL DEFAULT 80 CHECK (alert_threshold_percent >= 0 AND alert_threshold_percent <= 100),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(account_id, month)
      );
      ''',
    );
    await migrator.database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS budget_alerts (
        alert_id TEXT PRIMARY KEY,
        budget_id TEXT NOT NULL REFERENCES budgets(budget_id) ON UPDATE CASCADE ON DELETE CASCADE,
        triggered_at TEXT NOT NULL,
        actual_amount INTEGER NOT NULL,
        budget_amount INTEGER NOT NULL,
        threshold_percent INTEGER NOT NULL,
        notified INTEGER NOT NULL DEFAULT 0 CHECK (notified IN (0, 1))
      );
      ''',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_budgets_account_id ON budgets(account_id);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_budgets_month ON budgets(month);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_budget_alerts_budget_id ON budget_alerts(budget_id);',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_budget_alerts_triggered_at ON budget_alerts(triggered_at);',
    );
    await migrator.database.customStatement(
      'PRAGMA user_version = 9;',
    );
  }
}
