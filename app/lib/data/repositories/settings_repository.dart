import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/background/background_settings.dart';
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

  // UI 重构（Spec §2.3/D5）：背景系统键（图片仅存本地，不同步不备份）
  static const _bgEnabledKey = 'bg_enabled';
  static const _bgImagePathKey = 'bg_image_path';
  static const _bgOverlayModeKey = 'bg_overlay_mode';
  static const _bgOverlayAlphaKey = 'bg_overlay_alpha';
  static const _bgBlurKey = 'bg_blur';

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

  /// 背景设置（Spec §2.3）：全键缺失回退默认（无背景图）
  Future<BackgroundSettings> backgroundSettings() async {
    final rows = await (db.select(db.appMeta)
          ..where((t) => t.key.isIn({
                _bgEnabledKey,
                _bgImagePathKey,
                _bgOverlayModeKey,
                _bgOverlayAlphaKey,
                _bgBlurKey,
              })))
        .get();
    final map = {for (final r in rows) r.key: r.value};
    final rawPath = map[_bgImagePathKey];
    return BackgroundSettings(
      enabled: map[_bgEnabledKey] == 'true',
      // 空串（clear 后写入的占位）与缺失键统一归一为 null
      imagePath: (rawPath == null || rawPath.isEmpty) ? null : rawPath,
      overlayMode: map[_bgOverlayModeKey] == 'manual'
          ? OverlayMode.manual
          : OverlayMode.auto,
      manualAlpha: double.tryParse(map[_bgOverlayAlphaKey] ?? '') ??
          BackgroundSettings.defaults.manualAlpha,
      blurEnabled: map[_bgBlurKey] != 'false',
    );
  }

  Future<void> setBackgroundSettings(BackgroundSettings settings) async {
    await db.batch((batch) {
      void put(String key, String value) {
        batch.insert(db.appMeta, AppMetaCompanion.insert(key: key, value: value),
            onConflict: DoUpdate((_) => AppMetaCompanion(value: Value(value))));
      }

      put(_bgEnabledKey, '${settings.enabled}');
      put(_bgImagePathKey, settings.imagePath ?? '');
      put(_bgOverlayModeKey, settings.overlayMode.name);
      put(_bgOverlayAlphaKey, '${settings.manualAlpha}');
      put(_bgBlurKey, '${settings.blurEnabled}');
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
