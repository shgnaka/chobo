class ChoboSchema {
  ChoboSchema._();

  static const int schemaVersion = 10;

  static const String databaseFileName = 'chobo.sqlite';

  static const String accountsTable = 'accounts';
  static const String transactionsTable = 'transactions';
  static const String entriesTable = 'entries';
  static const String periodClosuresTable = 'period_closures';
  static const String settingsTable = 'settings';
  static const String auditEventsTable = 'audit_events';
  static const String pointsAccountsTable = 'points_accounts';
  static const String pointsTransactionsTable = 'points_transactions';
  static const String recurringTemplatesTable = 'recurring_templates';
  static const String tagsTable = 'tags';
  static const String transactionTagsTable = 'transaction_tags';
  static const String counterpartiesTable = 'counterparties';
  static const String budgetsTable = 'budgets';
  static const String budgetAlertsTable = 'budget_alerts';
  static const String transactionTemplatesTable = 'transaction_templates';
  static const String recentSelectionsTable = 'recent_selections';

  static const List<String> createStatements = <String>[
    _createAccountsTable,
    _createTransactionsTable,
    _createEntriesTable,
    _createPeriodClosuresTable,
    _createSettingsTable,
    _createAuditEventsTable,
    _createPointsAccountsTable,
    _createPointsTransactionsTable,
    _createRecurringTemplatesTable,
    _createTagsTable,
    _createTransactionTagsTable,
    _createCounterpartiesTable,
    _createBudgetsTable,
    _createBudgetAlertsTable,
    _createTransactionTemplatesTable,
    _createRecentSelectionsTable,
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
    'CREATE INDEX IF NOT EXISTS idx_points_accounts_name ON points_accounts(name);',
    'CREATE INDEX IF NOT EXISTS idx_points_transactions_points_account_id ON points_transactions(points_account_id);',
    'CREATE INDEX IF NOT EXISTS idx_points_transactions_transaction_id ON points_transactions(transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_points_transactions_created_at ON points_transactions(created_at);',
    'CREATE INDEX IF NOT EXISTS idx_recurring_templates_next_date ON recurring_templates(next_generation_date);',
    'CREATE INDEX IF NOT EXISTS idx_recurring_templates_is_active ON recurring_templates(is_active);',
    'CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);',
    'CREATE INDEX IF NOT EXISTS idx_transaction_tags_transaction_id ON transaction_tags(transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_transaction_tags_tag_id ON transaction_tags(tag_id);',
    'CREATE INDEX IF NOT EXISTS idx_counterparties_normalized_name ON counterparties(normalized_name);',
    'CREATE INDEX IF NOT EXISTS idx_budgets_account_id ON budgets(account_id);',
    'CREATE INDEX IF NOT EXISTS idx_budgets_month ON budgets(month);',
    'CREATE INDEX IF NOT EXISTS idx_budget_alerts_budget_id ON budget_alerts(budget_id);',
    'CREATE INDEX IF NOT EXISTS idx_budget_alerts_triggered_at ON budget_alerts(triggered_at);',
    'CREATE INDEX IF NOT EXISTS idx_transaction_templates_name ON transaction_templates(name);',
    'CREATE INDEX IF NOT EXISTS idx_transaction_templates_usage ON transaction_templates(usage_count DESC);',
    'CREATE INDEX IF NOT EXISTS idx_recent_selections_field_type ON recent_selections(field_type);',
    'CREATE INDEX IF NOT EXISTS idx_recent_selections_frequency ON recent_selections(frequency DESC);',
    'CREATE INDEX IF NOT EXISTS idx_recent_selections_last_selected ON recent_selections(last_selected_at DESC);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_description ON transactions(description);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_date_type_status ON transactions(date, type, status);',
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
  currency TEXT NOT NULL DEFAULT 'JPY',
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
  type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment', 'advance_payment', 'reimbursement')),
  status TEXT NOT NULL CHECK (status IN ('posted', 'pending', 'void')),
  description TEXT,
  counterparty TEXT,
  counterparty_id TEXT REFERENCES counterparties(counterparty_id) ON UPDATE CASCADE ON DELETE SET NULL,
  external_ref TEXT,
  original_transaction_id TEXT REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL,
  refund_type TEXT CHECK (refund_type IN ('full', 'partial') OR refund_type IS NULL),
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

  static const String _createPointsAccountsTable = '''
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
''';

  static const String _createPointsTransactionsTable = '''
CREATE TABLE IF NOT EXISTS points_transactions (
  points_transaction_id TEXT PRIMARY KEY,
  points_account_id TEXT NOT NULL REFERENCES points_accounts(points_account_id) ON UPDATE CASCADE ON DELETE CASCADE,
  transaction_id TEXT REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL,
  direction TEXT NOT NULL CHECK (direction IN ('earned', 'redeemed', 'expired', 'adjusted')),
  points_amount INTEGER NOT NULL,
  jpy_value INTEGER NOT NULL DEFAULT 0 CHECK (jpy_value >= 0),
  description TEXT,
  occurred_at TEXT NOT NULL,
  expiration_date TEXT,
  created_at TEXT NOT NULL
);
''';

  static const String _createRecurringTemplatesTable = '''
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
''';

  static const String _createTagsTable = '''
CREATE TABLE IF NOT EXISTS tags (
  tag_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(name)
);
''';

  static const String _createTransactionTagsTable = '''
CREATE TABLE IF NOT EXISTS transaction_tags (
  transaction_id TEXT NOT NULL REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags(tag_id) ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, tag_id)
);
''';

  static const String _createCounterpartiesTable = '''
CREATE TABLE IF NOT EXISTS counterparties (
  counterparty_id TEXT PRIMARY KEY,
  normalized_name TEXT NOT NULL,
  raw_name TEXT NOT NULL,
  metadata TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(normalized_name)
);
''';

  static const String _createBudgetsTable = '''
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
''';

  static const String _createBudgetAlertsTable = '''
CREATE TABLE IF NOT EXISTS budget_alerts (
  alert_id TEXT PRIMARY KEY,
  budget_id TEXT NOT NULL REFERENCES budgets(budget_id) ON UPDATE CASCADE ON DELETE CASCADE,
  triggered_at TEXT NOT NULL,
  actual_amount INTEGER NOT NULL,
  budget_amount INTEGER NOT NULL,
  threshold_percent INTEGER NOT NULL,
  notified INTEGER NOT NULL DEFAULT 0 CHECK (notified IN (0, 1))
);
''';

  static const String _createTransactionTemplatesTable = '''
CREATE TABLE IF NOT EXISTS transaction_templates (
  template_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment', 'advance_payment', 'reimbursement')),
  entries_template TEXT NOT NULL,
  default_description TEXT,
  usage_count INTEGER NOT NULL DEFAULT 0,
  last_used_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''';

  static const String _createRecentSelectionsTable = '''
CREATE TABLE IF NOT EXISTS recent_selections (
  selection_id TEXT PRIMARY KEY,
  field_type TEXT NOT NULL CHECK (field_type IN ('account', 'counterparty', 'description', 'tag')),
  field_value TEXT NOT NULL,
  transaction_type TEXT,
  frequency INTEGER NOT NULL DEFAULT 1,
  last_selected_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(field_type, field_value, transaction_type)
);
''';
}
