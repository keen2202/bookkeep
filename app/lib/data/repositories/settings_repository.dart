import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/glass_prefs.dart';
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
  // UI 重构（Spec §2.2/D5）：预制主题键；旧用户无此键时按旧 seed_color 落 'custom'
  static const _themePresetIdKey = 'theme_preset_id';

  // 旧背景图系统五键（bg_*）随纯净背景约束一并废弃（Spec §2.2，AC-02）：
  // 历史键读取时忽略、不再写入。

  // FGDS v1.0（BK-FG-003）：玻璃降级开关键；旧 v3 的 glass_quality /
  // ambient_* 四键已废弃——读取时忽略、不再写入（Spec §8 清除清单，AC-08）
  static const _glassBlurEnabledKey = 'glass_blur_enabled';

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

  /// 主题设置（兼容规则 Spec §2.2：无 theme_preset_id 键时，
  /// 旧用户存在 theme_seed → presetId='custom'（观感与旧版一致）；
  /// 全新安装 → 默认 't1' 青碧·晨）
  Future<ThemeSettings> themeSettings() async {
    final rows = await (db.select(db.appMeta)
          ..where((t) => t.key.isIn({
                _themeSeedKey,
                _themeModeKey,
                _themeIconPackKey,
                _themePresetIdKey,
              })))
        .get();
    final map = {for (final r in rows) r.key: r.value};
    final seed = _parseHexColor(map[_themeSeedKey]);
    final mode = switch (map[_themeModeKey]) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final iconPack = IconPack.values.asNameMap()[map[_themeIconPackKey]];
    final presetId = map[_themePresetIdKey] ??
        (map.containsKey(_themeSeedKey) ? 'custom' : ThemeSettings.defaults.presetId);
    return ThemeSettings(
      presetId: presetId,
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
      batch.insert(db.appMeta,
          AppMetaCompanion.insert(key: _themePresetIdKey, value: settings.presetId),
          onConflict: DoUpdate(
              (_) => AppMetaCompanion(value: Value(settings.presetId))));
    });
  }

  /// 玻璃偏好（FGDS v1.0）：键缺失回退默认（启用磨砂）
  Future<GlassPrefs> glassPrefs() async {
    final rows = await (db.select(db.appMeta)
          ..where((t) => t.key.equals(_glassBlurEnabledKey)))
        .get();
    final map = {for (final r in rows) r.key: r.value};
    return GlassPrefs(blurEnabled: map[_glassBlurEnabledKey] != 'false');
  }

  Future<void> setGlassPrefs(GlassPrefs prefs) async {
    await db.batch((batch) {
      batch.insert(
        db.appMeta,
        AppMetaCompanion.insert(
            key: _glassBlurEnabledKey, value: '${prefs.blurEnabled}'),
        onConflict: DoUpdate((_) =>
            AppMetaCompanion(value: Value('${prefs.blurEnabled}'))),
      );
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
