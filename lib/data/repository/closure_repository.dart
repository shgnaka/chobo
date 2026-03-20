import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class ClosureRepository {
  ClosureRepository(this._db);

  final AppDatabase _db;

  Future<void> createClosure(ChoboClosureRecord closure) async {
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
      variables: <Variable>[
        Variable(closure.closureId),
        Variable(closure.startDate),
        Variable(closure.endDate),
        Variable(closure.closedAt),
        Variable(closure.note),
      ],
    );
  }

  Future<List<ChoboClosureRecord>> listClosures() async {
    final rows = await _db.customSelect(
      '''
      SELECT closure_id, start_date, end_date, closed_at, note
      FROM period_closures
      ORDER BY start_date DESC, end_date DESC, closure_id DESC
      ''',
    ).get();
    return rows.map(ChoboClosureRecord.fromRow).toList(growable: false);
  }

  Future<ChoboClosureRecord?> getClosureForDate(String date) async {
    final row = await _db.customSelect(
      '''
      SELECT closure_id, start_date, end_date, closed_at, note
      FROM period_closures
      WHERE ? BETWEEN start_date AND end_date
      ORDER BY start_date DESC, end_date DESC, closure_id DESC
      LIMIT 1
      ''',
      variables: <Variable>[Variable(date)],
    ).getSingleOrNull();
    return row == null ? null : ChoboClosureRecord.fromRow(row);
  }

  Future<bool> isDateClosed(String date) async {
    return await getClosureForDate(date) != null;
  }
}
