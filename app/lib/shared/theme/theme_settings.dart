import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

/// 个性化主题设置（设备级偏好，app_meta 持久化；main() 启动时注入）
class ThemeSettings {
  const ThemeSettings({required this.seedColor, required this.mode});

  final Color seedColor;
  final ThemeMode mode;

  static const defaults = ThemeSettings(
    seedColor: kDefaultSeedColor,
    mode: ThemeMode.system,
  );
}

/// 预设主题种子色（避开纯红/纯绿，避免与收支语义色混淆）
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

/// 当前主题设置（默认值在 main() 启动时被持久化值覆盖）
final themeSettingsProvider = StateProvider<ThemeSettings>((ref) => ThemeSettings.defaults);
