import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import '../../data/repositories/settings_repository.dart';
import 'app_theme.dart';
import 'theme_presets.dart';
import 'theme_settings.dart';

/// 主题切换接口（Spec §3.1）：立即全树热重建并持久化到 app_meta。
///
/// 独立文件（而非并入 theme_settings.dart）是为了保持 shared/theme → data
/// 单向依赖（settings_repository.dart 依赖 theme_settings.dart 的模型）。
///
/// 启动注入：main() 读出持久化值后经
/// `themeControllerProvider.overrideWith(() => ThemeController(initial: s))`
/// 覆盖，行为与原 themeSettingsProvider 注入一致。
class ThemeController extends Notifier<ThemeSettings> {
  ThemeController({this._initial});

  final ThemeSettings? _initial;

  @override
  ThemeSettings build() => _initial ?? ThemeSettings.defaults;

  Future<void> _apply(ThemeSettings next) async {
    state = next;
    final repo = SettingsRepository(ref.read(databaseProvider));
    await repo.setThemeSettings(next);
  }

  /// 切换到预制主题（'t1'..'t8'）
  Future<void> applyPreset(String presetId) =>
      _apply(state.copyWith(presetId: presetId));

  /// 切换到自定义种子色模式（保留旧能力，Spec D3）
  Future<void> applyCustomSeed(Color seed, ThemeMode mode) => _apply(
        state.copyWith(
          presetId: AppThemePreset.customId,
          seedColor: seed,
          mode: mode,
        ),
      );

  /// 切换图标包
  Future<void> setIconPack(IconPack pack) =>
      _apply(state.copyWith(iconPack: pack));
}

/// 当前主题设置（默认值在 main() 启动时被持久化值覆盖）
final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

/// 由 ThemeSettings 解析 MaterialApp 主题三要素（app.dart / main.dart 秒开分支共用）：
/// - 预制主题：theme/darkTheme 同取该主题直出，mode 锁定为预设明暗（完整观感不随系统漂移）；
/// - 自定义模式：浅/深双槽位 fromSeed，mode 沿用用户设置（跟随系统生效）。
({ThemeData theme, ThemeData darkTheme, ThemeMode mode}) materialThemesFor(ThemeSettings s) {
  final preset = s.preset;
  if (preset != null) {
    final t = buildTheme(preset);
    return (
      theme: t,
      darkTheme: t,
      mode: preset.isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }
  return (
    theme: buildTheme(null, customSeed: s.seedColor, customMode: ThemeMode.light),
    darkTheme: buildTheme(null, customSeed: s.seedColor, customMode: ThemeMode.dark),
    mode: s.mode,
  );
}
