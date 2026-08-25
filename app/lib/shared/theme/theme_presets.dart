import 'package:flutter/material.dart';

import 'glass_tokens.dart';

/// 主题调色板（FGDS v1.0，Spec §2）：一套主题的全部颜色 Token。
///
/// iOS 毛玻璃重构（BK-FG-001/002/032）：
/// - 玻璃参数（blur/fill/描边/高光/投影/圆角）全部移入 [GlassLevel]
///   （`glass_tokens.dart` 唯一参数源），本类不再携带任何玻璃数值；
/// - 旧 `ambient` 环境光 Mesh 四色与 `glassFill/glassFillStrong/glassBorder`
///   派生字段一次性拆除（Spec §8 清除清单，AC-02/AC-08）；
/// - 背景收敛为白名单唯二底色 `#F2F2F7` / `#000000`（Spec §2.2 硬约束）；
/// - 文字四档对齐 Spec §5；预设间差异仅剩「主题色 + 背景明暗」（BK-FG-032，
///   任一预设下玻璃参数一致）。
class ThemePalette {
  const ThemePalette({
    required this.brightness,
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
    required this.textTertiary,
    required this.textDisabled,
    required this.border,
    required this.divider,
  });

  /// 主题明暗（玻璃双值分流唯一依据，Spec §7.2）
  final Brightness brightness;

  // 品牌与交互（Spec §2.1：主色仅出现在 主操作按钮/选中态/图标 tint 三处）
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;

  // 表面层级（ColorScheme 槽位与图表兜底，非玻璃参数）
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color scrim;

  // 文字四档（Spec §5）
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // 发丝线条（设计文档 §7：一律 0.5px 半透明细线的颜色槽位）
  final Color border;
  final Color divider;

  bool get isDark => brightness == Brightness.dark;

  ThemePalette lerp(ThemePalette other, double t) {
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ThemePalette(
      brightness: t < 0.5 ? brightness : other.brightness,
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
      textTertiary: c(textTertiary, other.textTertiary),
      textDisabled: c(textDisabled, other.textDisabled),
      border: c(border, other.border),
      divider: c(divider, other.divider),
    );
  }
}

/// 预制主题（不可变数据类）
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

  /// 自定义种子色模式（第 9 种"主题"，保留旧 fromSeed 能力）
  static const customId = 'custom';
}

// ---------------------------------------------------------------------------
// 收敛后的中性槽位（BK-FG-032：全预设统一，取值来自 Spec §2.2/§5 唯一真源）
// ---------------------------------------------------------------------------

/// 浅色中性组：背景 systemGray6、表面纯白、文字/线条对齐 Spec §5 与发丝线语言
ThemePalette _lightNeutral({required Color primary, required Color container, required Color secondary}) {
  return ThemePalette(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: GlassThemeColors.onPrimary,
    primaryContainer: container,
    secondary: secondary,
    background: GlassBackground.baseLight,
    surface: const Color(0xFFFFFFFF),
    surfaceVariant: const Color(0xFFE5E5EA),
    scrim: const Color(0xFF000000),
    textPrimary: GlassTextColors.primary(Brightness.light),
    textSecondary: GlassTextColors.secondary(Brightness.light),
    textTertiary: GlassTextColors.tertiary(Brightness.light),
    textDisabled: GlassTextColors.disabled(Brightness.light),
    border: const Color(0xFF000000).withValues(alpha: 0.12),
    divider: const Color(0xFF000000).withValues(alpha: 0.06),
  );
}

/// 深色中性组：背景纯黑、表面 #1C1C1E、文字反白四档
ThemePalette _darkNeutral({required Color primary, required Color container, required Color secondary}) {
  return ThemePalette(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: GlassThemeColors.onPrimary,
    primaryContainer: container,
    secondary: secondary,
    background: GlassBackground.baseDark,
    surface: const Color(0xFF1C1C1E),
    surfaceVariant: const Color(0xFF2C2C2E),
    scrim: const Color(0xFF000000),
    textPrimary: GlassTextColors.primary(Brightness.dark),
    textSecondary: GlassTextColors.secondary(Brightness.dark),
    textTertiary: GlassTextColors.tertiary(Brightness.dark),
    textDisabled: GlassTextColors.disabled(Brightness.dark),
    border: const Color(0xFFFFFFFF).withValues(alpha: 0.16),
    divider: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
  );
}

/// 8 套预制主题（BK-FG-032 收敛版）：差异仅剩「主题色 + 背景明暗」，
/// 玻璃参数由 [GlassLevel] 全局统一，不再各持一套。
final kThemePresetsV2 = <AppThemePreset>[
  // T1 青碧·晨（浅色 · 品牌）
  AppThemePreset(
    id: 't1',
    name: '青碧·晨',
    brightness: Brightness.light,
    styleTag: '品牌',
    palette: _lightNeutral(
      primary: Color(0xFF00897B),
      container: Color(0xFFB2DFDB),
      secondary: Color(0xFF26A69A),
    ),
  ),
  // T2 晴空·蓝（浅色 · 清爽）
  AppThemePreset(
    id: 't2',
    name: '晴空·蓝',
    brightness: Brightness.light,
    styleTag: '清爽',
    palette: _lightNeutral(
      primary: Color(0xFF0A84FF),
      container: Color(0xFFB3E5FC),
      secondary: Color(0xFF4FC3F7),
    ),
  ),
  // T3 紫藤·雅（浅色 · 优雅）
  AppThemePreset(
    id: 't3',
    name: '紫藤·雅',
    brightness: Brightness.light,
    styleTag: '优雅',
    palette: _lightNeutral(
      primary: Color(0xFF8E24AA),
      container: Color(0xFFE1BEE7),
      secondary: Color(0xFFBA68C8),
    ),
  ),
  // T4 暖屿·橙（浅色 · 温暖）
  AppThemePreset(
    id: 't4',
    name: '暖屿·橙',
    brightness: Brightness.light,
    styleTag: '温暖',
    palette: _lightNeutral(
      primary: Color(0xFFEF6C00),
      container: Color(0xFFFFE0B2),
      secondary: Color(0xFFFFA726),
    ),
  ),
  // T5 石墨·夜（深色 · 中性）：主色提亮保证纯黑背景上光晕/聚焦环可见（§9）
  AppThemePreset(
    id: 't5',
    name: '石墨·夜',
    brightness: Brightness.dark,
    styleTag: '中性',
    palette: _darkNeutral(
      primary: Color(0xFFA7B4BE),
      container: Color(0xFF37474F),
      secondary: Color(0xFF90A4AE),
    ),
  ),
  // T6 深海·蓝（深色 · 科技）
  AppThemePreset(
    id: 't6',
    name: '深海·蓝',
    brightness: Brightness.dark,
    styleTag: '科技',
    palette: _darkNeutral(
      primary: Color(0xFF64B5F6),
      container: Color(0xFF1E3A56),
      secondary: Color(0xFF81C7E8),
    ),
  ),
  // T7 墨竹·绿（深色 · 自然）
  AppThemePreset(
    id: 't7',
    name: '墨竹·绿',
    brightness: Brightness.dark,
    styleTag: '自然',
    palette: _darkNeutral(
      primary: Color(0xFF81C784),
      container: Color(0xFF1E4620),
      secondary: Color(0xFF9CCC9F),
    ),
  ),
  // T8 绛紫·夜（深色 · 个性）
  AppThemePreset(
    id: 't8',
    name: '绛紫·夜',
    brightness: Brightness.dark,
    styleTag: '个性',
    palette: _darkNeutral(
      primary: Color(0xFFCE93D8),
      container: Color(0xFF4A2B66),
      secondary: Color(0xFFDA9FE6),
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
