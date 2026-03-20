class ChoboSchema {
  ChoboSchema._();

  static const int schemaVersion = 1;

  static const String databaseFileName = 'chobo.sqlite';

  static const String accountsTable = 'accounts';
  static const String transactionsTable = 'transactions';
  static const String entriesTable = 'entries';
  static const String periodClosuresTable = 'period_closures';
  static const String settingsTable = 'settings';
  static const String auditEventsTable = 'audit_events';

  static const List<String> createStatements = <String>[
    _createAccountsTable,
    _createTransactionsTable,
    _createEntriesTable,
    _createPeriodClosuresTable,
    _createSettingsTable,
    _createAuditEventsTable,
  ];

  static const List<String> createIndexStatements = <String>[
    'CREATE INDEX IF NOT EXISTS idx_accounts_parent_account_id ON accounts(parent_account_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);',
    'CREATE INDEX IF NOT EXISTS idx_entries_transaction_id ON entries(transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_entries_account_id ON entries(account_id);',
    'CREATE INDEX IF NOT EXISTS idx_period_closures_start_date ON period_closures(start_date);',
    'CREATE INDEX IF NOT EXISTS idx_period_closures_end_date ON period_closures(end_date);',
    'CREATE INDEX IF NOT EXISTS idx_audit_events_created_at ON audit_events(created_at);',
    'CREATE INDEX IF NOT EXISTS idx_audit_events_target_id ON audit_events(target_id);',
  ];

  static const List<String> createAllStatements = <String>[
    ...createStatements,
    ...createIndexStatements,
  ];

  static const String _createAccountsTable = '''
CREATE TABLE IF NOT EXISTS accounts (
  account_id TEXT PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('asset', 'liability', 'income', 'expense', 'equity')),
  name TEXT NOT NULL,
  parent_account_id TEXT REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE SET NULL,
  is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''';

  static const String _createTransactionsTable = '''
CREATE TABLE IF NOT EXISTS transactions (
  transaction_id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment')),
  status TEXT NOT NULL CHECK (status IN ('posted', 'pending', 'void')),
  description TEXT,
  counterparty TEXT,
  external_ref TEXT,
  period_lock_state TEXT NOT NULL DEFAULT 'open',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''';

  static const String _createEntriesTable = '''
CREATE TABLE IF NOT EXISTS entries (
  entry_id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE CASCADE,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  direction TEXT NOT NULL CHECK (direction IN ('increase', 'decrease')),
  amount INTEGER NOT NULL CHECK (amount > 0),
  memo TEXT
);
''';

  static const String _createPeriodClosuresTable = '''
CREATE TABLE IF NOT EXISTS period_closures (
  closure_id TEXT PRIMARY KEY,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  closed_at TEXT NOT NULL,
  note TEXT,
  CHECK (start_date <= end_date)
);
''';

  static const String _createSettingsTable = '''
CREATE TABLE IF NOT EXISTS settings (
  setting_key TEXT PRIMARY KEY,
  setting_value TEXT NOT NULL
);
''';

  static const String _createAuditEventsTable = '''
CREATE TABLE IF NOT EXISTS audit_events (
  audit_event_id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''';
}
