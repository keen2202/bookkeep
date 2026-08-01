import 'package:drift/drift.dart';

import '../local/database.dart';

/// 应用设置（app_meta 持久化，Spec §3.1 秒开模式）
class SettingsRepository {
  SettingsRepository(this.db);
  final AppDatabase db;

  static const _secondsOpenKey = 'seconds_open_mode';

  Future<bool> secondsOpenMode() async {
    final rows =
        await (db.select(db.appMeta)..where((t) => t.key.equals(_secondsOpenKey))).get();
    if (rows.isEmpty) return false;
    return rows.single.value == 'true';
  }

  Future<void> setSecondsOpenMode(bool enabled) async {
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: _secondsOpenKey, value: '$enabled'),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('$enabled'))),
        );
  }
}
