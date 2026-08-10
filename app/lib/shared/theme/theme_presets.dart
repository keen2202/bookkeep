import 'package:flutter/material.dart';

/// 主题调色板（Spec §2.1）：一套主题的全部颜色 Token。
/// 取值见设计文档 §3.1（四组：品牌与交互 / 表面层级 / 文字 / 线条）。
class ThemePalette {
  const ThemePalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.scrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.divider,
  });

  // 品牌与交互
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;

  // 表面层级
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color scrim;

  // 文字
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // 线条
  final Color border;
  final Color divider;

  ThemePalette lerp(ThemePalette other, double t) {
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ThemePalette(
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      secondary: c(secondary, other.secondary),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceVariant: c(surfaceVariant, other.surfaceVariant),
      scrim: c(scrim, other.scrim),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      border: c(border, other.border),
      divider: c(divider, other.divider),
    );
  }
}

/// 预制主题（Spec §2.1，不可变数据类）
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.name,
    required this.brightness,
    required this.styleTag,
    required this.palette,
  });

  /// 't1'..'t8'；自定义种子色模式使用 [customId]
  final String id;

  /// '青碧·晨' 等
  final String name;
  final Brightness brightness;

  /// 品牌/清爽/优雅/温暖/中性/科技/自然/个性
  final String styleTag;
  final ThemePalette palette;

  bool get isDark => brightness == Brightness.dark;

  /// 自定义种子色模式（第 9 种"主题"，保留旧 fromSeed 能力，Spec D3）
  static const customId = 'custom';
}

/// 8 套预制主题（设计文档 §4，T1–T8 全量值，对比度 ≥ WCAG AA 校验值）
const kThemePresetsV2 = <AppThemePreset>[
  // T1 青碧·晨（浅色 · 品牌默认）
  AppThemePreset(
    id: 't1',
    name: '青碧·晨',
    brightness: Brightness.light,
    styleTag: '品牌',
    palette: ThemePalette(
      primary: Color(0xFF00897B),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFB2DFDB),
      secondary: Color(0xFF26A69A),
      background: Color(0xFFF6F8F8),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFEDF3F2),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF1A2B29),
      textSecondary: Color(0xFF5A6B69),
      textDisabled: Color(0xFF9DB0AD),
      border: Color(0xFFD8E2E0),
      divider: Color(0xFFEAF0EF),
    ),
  ),
  // T2 晴空·蓝（浅色 · 清爽）
  AppThemePreset(
    id: 't2',
    name: '晴空·蓝',
    brightness: Brightness.light,
    styleTag: '清爽',
    palette: ThemePalette(
      primary: Color(0xFF0288D1),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFB3E5FC),
      secondary: Color(0xFF4FC3F7),
      background: Color(0xFFF5F9FC),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFEAF2F8),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF16222B),
      textSecondary: Color(0xFF54666F),
      textDisabled: Color(0xFF9AACB4),
      border: Color(0xFFD5E3EC),
      divider: Color(0xFFE8F0F6),
    ),
  ),
  // T3 紫藤·雅（浅色 · 优雅）
  AppThemePreset(
    id: 't3',
    name: '紫藤·雅',
    brightness: Brightness.light,
    styleTag: '优雅',
    palette: ThemePalette(
      primary: Color(0xFF8E24AA),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE1BEE7),
      secondary: Color(0xFFBA68C8),
      background: Color(0xFFFAF7FC),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFF2ECF6),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF241A2B),
      textSecondary: Color(0xFF655A6E),
      textDisabled: Color(0xFFAB9FB3),
      border: Color(0xFFE2D8E9),
      divider: Color(0xFFEFE9F4),
    ),
  ),
  // T4 暖屿·橙（浅色 · 温暖）
  AppThemePreset(
    id: 't4',
    name: '暖屿·橙',
    brightness: Brightness.light,
    styleTag: '温暖',
    palette: ThemePalette(
      primary: Color(0xFFEF6C00),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFE0B2),
      secondary: Color(0xFFFFA726),
      background: Color(0xFFFBF6F0),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFF5EDE4),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF2B2118),
      textSecondary: Color(0xFF6E5F52),
      textDisabled: Color(0xFFB3A496),
      border: Color(0xFFE8DCCB),
      divider: Color(0xFFF2E9DD),
    ),
  ),
  // T5 石墨·夜（深色 · 中性）
  AppThemePreset(
    id: 't5',
    name: '石墨·夜',
    brightness: Brightness.dark,
    styleTag: '中性',
    palette: ThemePalette(
      primary: Color(0xFF90A4AE),
      onPrimary: Color(0xFF10151A),
      primaryContainer: Color(0xFF37474F),
      secondary: Color(0xFF78909C),
      background: Color(0xFF121417),
      surface: Color(0xFF1C1F24),
      surfaceVariant: Color(0xFF262A31),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE4E6E9),
      textSecondary: Color(0xFF9AA0A6),
      textDisabled: Color(0xFF5F666D),
      border: Color(0xFF33383F),
      divider: Color(0xFF282C33),
    ),
  ),
  // T6 深海·蓝（深色 · 科技）
  AppThemePreset(
    id: 't6',
    name: '深海·蓝',
    brightness: Brightness.dark,
    styleTag: '科技',
    palette: ThemePalette(
      primary: Color(0xFF4FA3E3),
      onPrimary: Color(0xFF0B1B2A),
      primaryContainer: Color(0xFF1E3A56),
      secondary: Color(0xFF6EC1E4),
      background: Color(0xFF0D1621),
      surface: Color(0xFF152238),
      surfaceVariant: Color(0xFF1D2E48),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE3ECF5),
      textSecondary: Color(0xFF93A6BB),
      textDisabled: Color(0xFF54687E),
      border: Color(0xFF2A3E5C),
      divider: Color(0xFF203350),
    ),
  ),
  // T7 墨竹·绿（深色 · 自然）
  AppThemePreset(
    id: 't7',
    name: '墨竹·绿',
    brightness: Brightness.dark,
    styleTag: '自然',
    palette: ThemePalette(
      primary: Color(0xFF66BB6A),
      onPrimary: Color(0xFF0C1F10),
      primaryContainer: Color(0xFF1E4620),
      secondary: Color(0xFF81C784),
      background: Color(0xFF101614),
      surface: Color(0xFF182420),
      surfaceVariant: Color(0xFF21322C),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE2EFE4),
      textSecondary: Color(0xFF95AC98),
      textDisabled: Color(0xFF57695A),
      border: Color(0xFF2C4238),
      divider: Color(0xFF24382F),
    ),
  ),
  // T8 绛紫·夜（深色 · 个性）
  AppThemePreset(
    id: 't8',
    name: '绛紫·夜',
    brightness: Brightness.dark,
    styleTag: '个性',
    palette: ThemePalette(
      primary: Color(0xFFB388D8),
      onPrimary: Color(0xFF241033),
      primaryContainer: Color(0xFF4A2B66),
      secondary: Color(0xFFCE93D8),
      background: Color(0xFF17121E),
      surface: Color(0xFF221A2E),
      surfaceVariant: Color(0xFF2E2340),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFEFE7F6),
      textSecondary: Color(0xFFAE9DBE),
      textDisabled: Color(0xFF6B5B7A),
      border: Color(0xFF3E3054),
      divider: Color(0xFF332846),
    ),
  ),
];

/// 按 id 查找预制主题；'custom'/未知 id 返回 null（走自定义种子色路径）
AppThemePreset? findPresetById(String id) {
  for (final p in kThemePresetsV2) {
    if (p.id == id) return p;
  }
  return null;
}
