import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/theme_settings.dart';
import '../local/database.dart';

/// 应用设置（app_meta 持久化，Spec §3.1 秒开模式 / 个性化主题）
class SettingsRepository {
  SettingsRepository(this.db);
  final AppDatabase db;

  static const _secondsOpenKey = 'seconds_open_mode';
  static const _themeSeedKey = 'theme_seed';
  static const _themeModeKey = 'theme_mode';
  static const _themeIconPackKey = 'theme_icon_pack';

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

  /// 主题设置（未配置回退默认：青碧 + 跟随系统 + 线性图标）
  Future<ThemeSettings> themeSettings() async {
    final rows = await (db.select(db.appMeta)
          ..where((t) => t.key.isIn({_themeSeedKey, _themeModeKey, _themeIconPackKey})))
        .get();
    final map = {for (final r in rows) r.key: r.value};
    final seed = _parseHexColor(map[_themeSeedKey]);
    final mode = switch (map[_themeModeKey]) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final iconPack = IconPack.values.asNameMap()[map[_themeIconPackKey]];
    return ThemeSettings(
      seedColor: seed ?? ThemeSettings.defaults.seedColor,
      mode: mode,
      iconPack: iconPack ?? ThemeSettings.defaults.iconPack,
    );
  }

  Future<void> setThemeSettings(ThemeSettings settings) async {
    final seedHex = '#${(settings.seedColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    await db.batch((batch) {
      batch.insert(db.appMeta, AppMetaCompanion.insert(key: _themeSeedKey, value: seedHex),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value(seedHex))));
      batch.insert(db.appMeta,
          AppMetaCompanion.insert(key: _themeModeKey, value: settings.mode.name),
          onConflict: DoUpdate(
              (_) => AppMetaCompanion(value: Value(settings.mode.name))));
      batch.insert(db.appMeta,
          AppMetaCompanion.insert(key: _themeIconPackKey, value: settings.iconPack.name),
          onConflict: DoUpdate(
              (_) => AppMetaCompanion(value: Value(settings.iconPack.name))));
    });
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
