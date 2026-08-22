import 'package:flutter/material.dart';

/// 主题调色板（Spec §2.1）：一套主题的全部颜色 Token。
/// 取值见设计文档 §3.1（五组：品牌与交互 / 表面层级 / 文字 / 线条 / 玻璃与环境光）。
///
/// 玻璃拟态重构（Glassmorphism v2）新增四组玻璃 Token：
/// - [ambient]：环境光渐变色（默认无背景图时的 Mesh 光斑，3 色）；
/// - [glassFill]：玻璃卡片通透填充（半透明，透出环境光）；
/// - [glassFillStrong]：弹层/导航等高密度表面的强填充（更不透明，保证可读）；
/// - [glassBorder]：玻璃高光描边（1px 发丝线）。
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
    this.ambient = const [],
    this.glassFill = const Color(0xA6FFFFFF),
    this.glassFillStrong = const Color(0xE5FFFFFF),
    this.glassBorder = const Color(0x99FFFFFF),
  });

  // 品牌与交互
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;

  // 表面层级（surface/surfaceVariant 保持不透明，作为兜底与 ColorScheme 槽位）
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

  // 玻璃与环境光（Glassmorphism v2）
  /// 环境光 Mesh 渐变色斑（默认背景层；3 色，随主题明暗成套设计）
  final List<Color> ambient;

  /// 玻璃卡片填充（半透明：浅色白 65% / 深色主题色调 72%）
  final Color glassFill;

  /// 玻璃强填充（底部弹层/对话框/导航栏：浅色白 90% / 深色 88%）
  final Color glassFillStrong;

  /// 玻璃高光发丝描边（浅色白 60% / 深色白 22%）
  final Color glassBorder;

  ThemePalette lerp(ThemePalette other, double t) {
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> cl(List<Color> a, List<Color> b) {
      final n = a.length > b.length ? a.length : b.length;
      return List.generate(n, (i) {
        if (i >= a.length) return b[i];
        if (i >= b.length) return a[i];
        return Color.lerp(a[i], b[i], t)!;
      });
    }

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
      ambient: cl(ambient, other.ambient),
      glassFill: c(glassFill, other.glassFill),
      glassFillStrong: c(glassFillStrong, other.glassFillStrong),
      glassBorder: c(glassBorder, other.glassBorder),
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

/// 8 套玻璃拟态预制主题（Glassmorphism v2，设计文档 §4 T1–T8 全量值）。
///
/// 设计语言对齐玻璃 UI 视觉稿：明亮/深邃的环境光渐变底 + 磨砂通透卡片 +
/// 高光发丝描边；文字与主色保持原校验值，对比度 ≥ WCAG AA（测试锁定）。
const kThemePresetsV2 = <AppThemePreset>[
  // T1 青碧·晨（浅色 · 品牌）晨雾薄荷玻璃
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
      background: Color(0xFFEDF6F3),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFE7F1EE),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF1A2B29),
      textSecondary: Color(0xFF5A6B69),
      textDisabled: Color(0xFF9DB0AD),
      border: Color(0xFFD6E4E1),
      divider: Color(0xFFE9F1EF),
      ambient: [Color(0xFF6FD0BE), Color(0xFF9BD8F2), Color(0xFFC9EBD6)],
      glassFill: Color(0xA6FFFFFF),
      glassFillStrong: Color(0xE5FFFFFF),
      glassBorder: Color(0x99FFFFFF),
    ),
  ),
  // T2 晴空·蓝（浅色 · 清爽）晴空蔚蓝玻璃
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
      background: Color(0xFFEDF4FB),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFE6EFF8),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF16222B),
      textSecondary: Color(0xFF54666F),
      textDisabled: Color(0xFF9AACB4),
      border: Color(0xFFD3E2EF),
      divider: Color(0xFFE7F0F7),
      ambient: [Color(0xFF7CC3F5), Color(0xFFA9D9FF), Color(0xFFD6E9FF)],
      glassFill: Color(0xA6FFFFFF),
      glassFillStrong: Color(0xE5FFFFFF),
      glassBorder: Color(0x99FFFFFF),
    ),
  ),
  // T3 紫藤·雅（浅色 · 优雅）暮紫藤萝玻璃
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
      background: Color(0xFFF7F2FB),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFF0E9F6),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF241A2B),
      textSecondary: Color(0xFF655A6E),
      textDisabled: Color(0xFFAB9FB3),
      border: Color(0xFFE1D7EA),
      divider: Color(0xFFEFE9F5),
      ambient: [Color(0xFFC9A8EC), Color(0xFFEFB8DE), Color(0xFFB9C6F2)],
      glassFill: Color(0xA6FFFFFF),
      glassFillStrong: Color(0xE5FFFFFF),
      glassBorder: Color(0x99FFFFFF),
    ),
  ),
  // T4 暖屿·橙（浅色 · 温暖）蜜桃暖阳玻璃
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
      background: Color(0xFFFBF3E9),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFF5ECE0),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFF2B2118),
      textSecondary: Color(0xFF6E5F52),
      textDisabled: Color(0xFFB3A496),
      border: Color(0xFFE9DCC9),
      divider: Color(0xFFF3EBDE),
      ambient: [Color(0xFFFFC49E), Color(0xFFFFB1A6), Color(0xFFFFDFAD)],
      glassFill: Color(0xA6FFFFFF),
      glassFillStrong: Color(0xE5FFFFFF),
      glassBorder: Color(0x99FFFFFF),
    ),
  ),
  // T5 石墨·夜（深色 · 中性）石墨冷光玻璃
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
      background: Color(0xFF0F1215),
      surface: Color(0xFF1A1E24),
      surfaceVariant: Color(0xFF252B33),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE5E8EC),
      textSecondary: Color(0xFF9AA3AD),
      textDisabled: Color(0xFF5E6670),
      border: Color(0xFF343B44),
      divider: Color(0xFF292F36),
      ambient: [Color(0xFF2E3A46), Color(0xFF39495A), Color(0xFF232B35)],
      glassFill: Color(0xB81A1E24),
      glassFillStrong: Color(0xE01A1E24),
      glassBorder: Color(0x38FFFFFF),
    ),
  ),
  // T6 深海·蓝（深色 · 科技）深海极光玻璃
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
      background: Color(0xFF0A111E),
      surface: Color(0xFF152238),
      surfaceVariant: Color(0xFF1D2E48),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE3ECF5),
      textSecondary: Color(0xFF93A6BB),
      textDisabled: Color(0xFF54687E),
      border: Color(0xFF2A3E5C),
      divider: Color(0xFF203350),
      ambient: [Color(0xFF16406E), Color(0xFF0E5A6E), Color(0xFF23306E)],
      glassFill: Color(0xB8152238),
      glassFillStrong: Color(0xE0152238),
      glassBorder: Color(0x38FFFFFF),
    ),
  ),
  // T7 墨竹·绿（深色 · 自然）竹林萤光玻璃
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
      background: Color(0xFF0C1210),
      surface: Color(0xFF182420),
      surfaceVariant: Color(0xFF21322C),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE2EFE4),
      textSecondary: Color(0xFF95AC98),
      textDisabled: Color(0xFF57695A),
      border: Color(0xFF2C4238),
      divider: Color(0xFF24382F),
      ambient: [Color(0xFF1C5540), Color(0xFF14524E), Color(0xFF2E5A22)],
      glassFill: Color(0xB8182420),
      glassFillStrong: Color(0xE0182420),
      glassBorder: Color(0x38FFFFFF),
    ),
  ),
  // T8 绛紫·夜（深色 · 个性）霓虹绛紫玻璃
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
      background: Color(0xFF110C1B),
      surface: Color(0xFF221A2E),
      surfaceVariant: Color(0xFF2E2340),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFEFE7F6),
      textSecondary: Color(0xFFAE9DBE),
      textDisabled: Color(0xFF6B5B7A),
      border: Color(0xFF3E3054),
      divider: Color(0xFF332846),
      ambient: [Color(0xFF4A2570), Color(0xFF5E2050), Color(0xFF2A2E78)],
      glassFill: Color(0xB8221A2E),
      glassFillStrong: Color(0xE0221A2E),
      glassBorder: Color(0x38FFFFFF),
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
