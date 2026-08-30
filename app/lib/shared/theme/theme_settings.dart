import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'theme_presets.dart';

/// 个性化主题设置（Spec §2.2，设备级偏好，app_meta 持久化；main() 启动时注入）
///
/// [presetId]：'t1'..'t8' 预制主题；'custom' 表示自定义种子色模式
/// （此时 [seedColor]/[mode] 生效，行为与旧版一致）。
///
/// 图标风格选择已随外观简化移除（Spec §2.3 / BK-DOC-26）：`IconPack`
/// 配置面整体收敛，模块图标固定 outlined 变体。
class ThemeSettings {
  const ThemeSettings({
    this.presetId = 't1',
    required this.seedColor,
    required this.mode,
  });

  final String presetId;
  final Color seedColor;
  final ThemeMode mode;

  ThemeSettings copyWith({
    String? presetId,
    Color? seedColor,
    ThemeMode? mode,
  }) =>
      ThemeSettings(
        presetId: presetId ?? this.presetId,
        seedColor: seedColor ?? this.seedColor,
        mode: mode ?? this.mode,
      );

  /// 当前生效的预制主题；null 表示自定义种子色模式
  AppThemePreset? get preset =>
      presetId == AppThemePreset.customId ? null : findPresetById(presetId);

  /// 是否自定义种子色模式（presetId 非法时按 custom 兜底，防脏数据）
  bool get isCustom => preset == null;

  static const defaults = ThemeSettings(
    presetId: 't1',
    seedColor: kDefaultSeedColor,
    mode: ThemeMode.system,
  );
}

/// 预设主题种子色（旧版自定义模式的快捷色板，避开纯红/纯绿，
/// 避免与收支语义色混淆；外观页"自定义"流程沿用）
const kThemePresets = <Color>[
  Color(0xFF00897B), // 青碧（默认品牌色）
  Color(0xFF0288D1), // 天蓝
  Color(0xFF3F51B5), // 靛蓝
  Color(0xFF8E24AA), // 紫罗兰
  Color(0xFFD81B60), // 玫红
  Color(0xFFEF6C00), // 暖橙
  Color(0xFF43A047), // 松绿
  Color(0xFF546E7A), // 石墨
];
