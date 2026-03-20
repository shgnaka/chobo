import 'dart:convert';

import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class AuditEventRepository {
  AuditEventRepository(this._db);

  final AppDatabase _db;

  Future<void> recordEvent(ChoboAuditEventRecord event) async {
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
      variables: <Variable>[
        Variable(event.auditEventId),
        Variable(event.eventType),
        Variable(event.targetId),
        Variable(event.payload),
        Variable(event.createdAt),
      ],
    );
  }

  Future<void> recordJsonEvent({
    required String auditEventId,
    required String eventType,
    required String targetId,
    required Map<String, Object?> payload,
    String? createdAt,
  }) async {
    await recordEvent(
      ChoboAuditEventRecord(
        auditEventId: auditEventId,
        eventType: eventType,
        targetId: targetId,
        payload: jsonEncode(payload),
        createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<List<ChoboAuditEventRecord>> listEvents({
    String? targetId,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT audit_event_id, event_type, target_id, payload, created_at
      FROM audit_events
      WHERE (? IS NULL OR target_id = ?)
      ORDER BY created_at DESC, audit_event_id DESC
      ''',
      variables: <Variable>[
        Variable(targetId),
        Variable(targetId),
      ],
    ).get();
    return rows.map(ChoboAuditEventRecord.fromRow).toList(growable: false);
  }
}
