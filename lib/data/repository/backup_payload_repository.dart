import 'package:drift/drift.dart';

import '../../backup/backup_payload_envelope.dart';
import '../local_db/app_database.dart';

class BackupPayloadRepository {
  BackupPayloadRepository(this._db);

  final AppDatabase _db;

  Future<BackupPayloadEnvelope> exportPayload() async {
    return BackupPayloadEnvelope(
      accounts: await _exportRows(
        '''
        SELECT account_id, kind, name, parent_account_id, is_default,
               is_archived, created_at, updated_at
        FROM accounts
        ORDER BY account_id
        ''',
        <String>[
          'account_id',
          'kind',
          'name',
          'parent_account_id',
          'is_default',
          'is_archived',
          'created_at',
          'updated_at',
        ],
        boolColumns: <String>{
          'is_default',
          'is_archived',
        },
      ),
      transactions: await _exportRows(
        '''
        SELECT transaction_id, date, type, status, description, counterparty,
               external_ref, period_lock_state, created_at, updated_at
        FROM transactions
        ORDER BY date, created_at, transaction_id
        ''',
        <String>[
          'transaction_id',
          'date',
          'type',
          'status',
          'description',
          'counterparty',
          'external_ref',
          'period_lock_state',
          'created_at',
          'updated_at',
        ],
      ),
      entries: await _exportRows(
        '''
        SELECT entry_id, transaction_id, account_id, direction, amount, memo
        FROM entries
        ORDER BY transaction_id, entry_id
        ''',
        <String>[
          'entry_id',
          'transaction_id',
          'account_id',
          'direction',
          'amount',
          'memo',
        ],
      ),
      periodClosures: await _exportRows(
        '''
        SELECT closure_id, start_date, end_date, closed_at, note
        FROM period_closures
        ORDER BY start_date, end_date, closure_id
        ''',
        <String>[
          'closure_id',
          'start_date',
          'end_date',
          'closed_at',
          'note',
        ],
      ),
      settings: await _exportRows(
        '''
        SELECT setting_key, setting_value
        FROM settings
        ORDER BY setting_key
        ''',
        <String>[
          'setting_key',
          'setting_value',
        ],
      ),
      auditEvents: await _exportRows(
        '''
        SELECT audit_event_id, event_type, target_id, payload, created_at
        FROM audit_events
        ORDER BY created_at, audit_event_id
        ''',
        <String>[
          'audit_event_id',
          'event_type',
          'target_id',
          'payload',
          'created_at',
        ],
      ),
    );
  }

  Future<void> importPayload(BackupPayloadEnvelope payload) async {
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM entries');
      await _db.customStatement('DELETE FROM transactions');
      await _db.customStatement('DELETE FROM period_closures');
      await _db.customStatement('DELETE FROM settings');
      await _db.customStatement('DELETE FROM audit_events');
      await _db.customStatement('DELETE FROM accounts');

      for (final account in payload.accounts) {
        await _db.customInsert(
          '''
          INSERT INTO accounts (
            account_id,
            kind,
            name,
            parent_account_id,
            is_default,
            is_archived,
            created_at,
            updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: _accountVariables(account),
        );
      }

      for (final transaction in payload.transactions) {
        await _db.customInsert(
          '''
          INSERT INTO transactions (
            transaction_id,
            date,
            type,
            status,
            description,
            counterparty,
            external_ref,
            period_lock_state,
            created_at,
            updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: _transactionVariables(transaction),
        );
      }

      for (final entry in payload.entries) {
        await _db.customInsert(
          '''
          INSERT INTO entries (
            entry_id,
            transaction_id,
            account_id,
            direction,
            amount,
            memo
          ) VALUES (?, ?, ?, ?, ?, ?)
          ''',
          variables: _entryVariables(entry),
        );
      }

      for (final closure in payload.periodClosures) {
        await _db.customInsert(
          '''
          INSERT INTO period_closures (
            closure_id,
            start_date,
            end_date,
            closed_at,
            note
          ) VALUES (?, ?, ?, ?, ?)
          ''',
          variables: _closureVariables(closure),
        );
      }

      for (final setting in payload.settings) {
        await _db.customInsert(
          '''
          INSERT INTO settings (
            setting_key,
            setting_value
          ) VALUES (?, ?)
          ''',
          variables: _settingVariables(setting),
        );
      }

      for (final auditEvent in payload.auditEvents) {
        await _db.customInsert(
          '''
          INSERT INTO audit_events (
            audit_event_id,
            event_type,
            target_id,
            payload,
            created_at
          ) VALUES (?, ?, ?, ?, ?)
          ''',
          variables: _auditEventVariables(auditEvent),
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> _exportRows(
    String sql,
    List<String> columns, {
    Set<String> boolColumns = const <String>{},
  }) async {
    final rows = await _db.customSelect(sql).get();
    return rows
        .map((row) => _rowToMap(row, columns, boolColumns))
        .toList(growable: false);
  }

  Map<String, Object?> _rowToMap(
    QueryRow row,
    List<String> columns,
    Set<String> boolColumns,
  ) {
    return <String, Object?>{
      for (final column in columns)
        column: boolColumns.contains(column)
            ? row.read<int>(column) == 1
            : row.read<Object?>(column),
    };
  }

  List<Variable> _accountVariables(Map<String, Object?> account) {
    return <Variable>[
      Variable(account['account_id']),
      Variable(account['kind']),
      Variable(account['name']),
      Variable(account['parent_account_id']),
      Variable(account['is_default']),
      Variable(account['is_archived']),
      Variable(account['created_at'] ?? _now()),
      Variable(account['updated_at'] ?? _now()),
    ];
  }

  List<Variable> _transactionVariables(Map<String, Object?> transaction) {
    return <Variable>[
      Variable(transaction['transaction_id']),
      Variable(transaction['date']),
      Variable(transaction['type']),
      Variable(transaction['status']),
      Variable(transaction['description']),
      Variable(transaction['counterparty']),
      Variable(transaction['external_ref']),
      Variable(transaction['period_lock_state'] ?? 'open'),
      Variable(transaction['created_at'] ?? _now()),
      Variable(transaction['updated_at'] ?? _now()),
    ];
  }

  List<Variable> _entryVariables(Map<String, Object?> entry) {
    return <Variable>[
      Variable(entry['entry_id']),
      Variable(entry['transaction_id']),
      Variable(entry['account_id']),
      Variable(entry['direction']),
      Variable(entry['amount']),
      Variable(entry['memo']),
    ];
  }

  List<Variable> _closureVariables(Map<String, Object?> closure) {
    return <Variable>[
      Variable(closure['closure_id']),
      Variable(closure['start_date']),
      Variable(closure['end_date']),
      Variable(closure['closed_at']),
      Variable(closure['note']),
    ];
  }

  List<Variable> _settingVariables(Map<String, Object?> setting) {
    return <Variable>[
      Variable(setting['setting_key']),
      Variable(setting['setting_value']),
    ];
  }

  List<Variable> _auditEventVariables(Map<String, Object?> auditEvent) {
    return <Variable>[
      Variable(auditEvent['audit_event_id']),
      Variable(auditEvent['event_type']),
      Variable(auditEvent['target_id']),
      Variable(auditEvent['payload']),
      Variable(auditEvent['created_at']),
    ];
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
