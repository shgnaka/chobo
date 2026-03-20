import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<void> setSetting(ChoboSettingRecord setting) async {
    await _db.customInsert(
      '''
      INSERT INTO settings (
        setting_key,
        setting_value
      ) VALUES (?, ?)
      ON CONFLICT(setting_key) DO UPDATE SET
        setting_value = excluded.setting_value
      ''',
      variables: <Variable>[
        Variable(setting.settingKey),
        Variable(setting.settingValue),
      ],
    );
  }

  Future<ChoboSettingRecord?> getSetting(String settingKey) async {
    final row = await _db.customSelect(
      '''
      SELECT setting_key, setting_value
      FROM settings
      WHERE setting_key = ?
      ''',
      variables: <Variable>[Variable(settingKey)],
    ).getSingleOrNull();
    return row == null ? null : ChoboSettingRecord.fromRow(row);
  }

  Future<List<ChoboSettingRecord>> listSettings() async {
    final rows = await _db.customSelect(
      '''
      SELECT setting_key, setting_value
      FROM settings
      ORDER BY setting_key
      ''',
    ).get();
    return rows.map(ChoboSettingRecord.fromRow).toList(growable: false);
  }
}
