import 'package:flutter/material.dart';

/// 主题调色板（Spec §2.1）：一套主题的全部颜色 Token。
/// 取值见设计文档 §3.1（五组：品牌与交互 / 表面层级 / 文字 / 线条 / 玻璃与环境光）。
///
/// 玻璃拟态 v3 重构（Glassmorphism v3，Spec §6）：
/// - [ambient] 环境光 Mesh 扩为 **4 元素**（锚点固定 左上/右中/左下/右上，
///   第 4 色为右上同族浅色，GLS-004 定值入 Checklist）；
/// - `glassFill/glassFillStrong/glassBorder` 三字段退役为**派生值**
///   （D5：映射 L1/L3 层级函数基准，兼容旧调用点零破坏；
///   新代码一律走 `resolveGlassSpec()`）。
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
    required this.textDisabled,
    required this.border,
    required this.divider,
    this.ambient = const [],
  });

  /// 主题明暗（v3 新增：glass 系派生字段按此分流取值）
  final Brightness brightness;

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

  // 环境光（Glassmorphism v3：4 元素成套，锚点 左上/右中/左下/右上）
  /// 环境光 Mesh 渐变色斑（默认背景层；随主题明暗成套设计）
  final List<Color> ambient;

  bool get isDark => brightness == Brightness.dark;

  /// 玻璃卡片填充（D5 派生值：L1 基准——浅色白基 α0.55 / 深色 surface 基
  /// α0.66；旧值 65%/72% 已收敛进层级表）
  Color get glassFill => isDark
      ? surface.withValues(alpha: 0.66)
      : surface.withValues(alpha: 0.55);

  /// 玻璃强填充（D5 派生值：L3 浮层基准——浅 α0.75 / 深 α0.80，
  /// 与 `resolveGlassSpec(tier: overlay)` 的 fill 同源）
  Color get glassFillStrong => isDark
      ? surface.withValues(alpha: 0.80)
      : surface.withValues(alpha: 0.75);

  /// 玻璃高光发丝描边（D5 派生值：L1 描边——浅白 α0.20 / 深 α0.16 实值，
  /// 旧漂移值 0x99FFFFFF/0x38FFFFFF 已收敛进 Spec §2.1 表）
  Color get glassBorder =>
      Colors.white.withValues(alpha: isDark ? 0.16 : 0.20);

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
      textDisabled: c(textDisabled, other.textDisabled),
      border: c(border, other.border),
      divider: c(divider, other.divider),
      ambient: cl(ambient, other.ambient),
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

/// 8 套玻璃拟态预制主题（Glassmorphism v3，设计文档 §6.2 取值变更表）：
///
/// v3 变更——①全部 ambient 补齐第 4 色（右上锚位同族色）；②T5/T7/T8
/// 背景 `background` 提亮 3–5 个明度档（§4.7 纯色禁令：深色玻璃要有可透之光）；
/// ③glass 系字段退役为派生值（不再显式携带）。文字与主色保持原校验值，
/// 对比度 ≥ WCAG AA（测试锁定）。
const kThemePresetsV2 = <AppThemePreset>[
  // T1 青碧·晨（浅色 · 品牌）晨雾薄荷玻璃
  AppThemePreset(
    id: 't1',
    name: '青碧·晨',
    brightness: Brightness.light,
    styleTag: '品牌',
    palette: ThemePalette(
      brightness: Brightness.light,
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
      // v3 第 4 色 #BFE8DC（右上锚位，GLS-004 checklist 定值）
      ambient: [
        Color(0xFF6FD0BE),
        Color(0xFF9BD8F2),
        Color(0xFFC9EBD6),
        Color(0xFFBFE8DC),
      ],
    ),
  ),
  // T2 晴空·蓝（浅色 · 清爽）晴空蔚蓝玻璃
  AppThemePreset(
    id: 't2',
    name: '晴空·蓝',
    brightness: Brightness.light,
    styleTag: '清爽',
    palette: ThemePalette(
      brightness: Brightness.light,
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
      // v3 第 4 色 #CCE4FA
      ambient: [
        Color(0xFF7CC3F5),
        Color(0xFFA9D9FF),
        Color(0xFFD6E9FF),
        Color(0xFFCCE4FA),
      ],
    ),
  ),
  // T3 紫藤·雅（浅色 · 优雅）暮紫藤萝玻璃
  AppThemePreset(
    id: 't3',
    name: '紫藤·雅',
    brightness: Brightness.light,
    styleTag: '优雅',
    palette: ThemePalette(
      brightness: Brightness.light,
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
      // v3 第 4 色 #D9CBF2
      ambient: [
        Color(0xFFC9A8EC),
        Color(0xFFEFB8DE),
        Color(0xFFB9C6F2),
        Color(0xFFD9CBF2),
      ],
    ),
  ),
  // T4 暖屿·橙（浅色 · 温暖）蜜桃暖阳玻璃
  AppThemePreset(
    id: 't4',
    name: '暖屿·橙',
    brightness: Brightness.light,
    styleTag: '温暖',
    palette: ThemePalette(
      brightness: Brightness.light,
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
      // v3 第 4 色 #FFE7BF
      ambient: [
        Color(0xFFFFC49E),
        Color(0xFFFFB1A6),
        Color(0xFFFFDFAD),
        Color(0xFFFFE7BF),
      ],
    ),
  ),
  // T5 石墨·夜（深色 · 中性）石墨冷光玻璃（v3：背景提亮 #0F1215 → #13171C）
  AppThemePreset(
    id: 't5',
    name: '石墨·夜',
    brightness: Brightness.dark,
    styleTag: '中性',
    palette: ThemePalette(
      brightness: Brightness.dark,
      primary: Color(0xFF90A4AE),
      onPrimary: Color(0xFF10151A),
      primaryContainer: Color(0xFF37474F),
      secondary: Color(0xFF78909C),
      background: Color(0xFF13171C),
      surface: Color(0xFF1A1E24),
      surfaceVariant: Color(0xFF252B33),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE5E8EC),
      textSecondary: Color(0xFF9AA3AD),
      textDisabled: Color(0xFF5E6670),
      border: Color(0xFF343B44),
      divider: Color(0xFF292F36),
      // v3 第 4 色 #3E4A57（青灰）
      ambient: [
        Color(0xFF2E3A46),
        Color(0xFF39495A),
        Color(0xFF232B35),
        Color(0xFF3E4A57),
      ],
    ),
  ),
  // T6 深海·蓝（深色 · 科技）深海极光玻璃
  AppThemePreset(
    id: 't6',
    name: '深海·蓝',
    brightness: Brightness.dark,
    styleTag: '科技',
    palette: ThemePalette(
      brightness: Brightness.dark,
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
      // v3 第 4 色 #1B6E8C
      ambient: [
        Color(0xFF16406E),
        Color(0xFF0E5A6E),
        Color(0xFF23306E),
        Color(0xFF1B6E8C),
      ],
    ),
  ),
  // T7 墨竹·绿（深色 · 自然）竹林萤光玻璃（v3：背景提亮 #0C1210 → #101713）
  AppThemePreset(
    id: 't7',
    name: '墨竹·绿',
    brightness: Brightness.dark,
    styleTag: '自然',
    palette: ThemePalette(
      brightness: Brightness.dark,
      primary: Color(0xFF66BB6A),
      onPrimary: Color(0xFF0C1F10),
      primaryContainer: Color(0xFF1E4620),
      secondary: Color(0xFF81C784),
      background: Color(0xFF101713),
      surface: Color(0xFF182420),
      surfaceVariant: Color(0xFF21322C),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFE2EFE4),
      textSecondary: Color(0xFF95AC98),
      textDisabled: Color(0xFF57695A),
      border: Color(0xFF2C4238),
      divider: Color(0xFF24382F),
      // v3 第 4 色 #2E6E34
      ambient: [
        Color(0xFF1C5540),
        Color(0xFF14524E),
        Color(0xFF2E5A22),
        Color(0xFF2E6E34),
      ],
    ),
  ),
  // T8 绛紫·夜（深色 · 个性）霓虹绛紫玻璃（v3：背景提亮 #110C1B → #171126）
  AppThemePreset(
    id: 't8',
    name: '绛紫·夜',
    brightness: Brightness.dark,
    styleTag: '个性',
    palette: ThemePalette(
      brightness: Brightness.dark,
      primary: Color(0xFFB388D8),
      onPrimary: Color(0xFF241033),
      primaryContainer: Color(0xFF4A2B66),
      secondary: Color(0xFFCE93D8),
      background: Color(0xFF171126),
      surface: Color(0xFF221A2E),
      surfaceVariant: Color(0xFF2E2340),
      scrim: Color(0xFF000000),
      textPrimary: Color(0xFFEFE7F6),
      textSecondary: Color(0xFFAE9DBE),
      textDisabled: Color(0xFF6B5B7A),
      border: Color(0xFF3E3054),
      divider: Color(0xFF332846),
      // v3 第 4 色 #6E2A8C
      ambient: [
        Color(0xFF4A2570),
        Color(0xFF5E2050),
        Color(0xFF2A2E78),
        Color(0xFF6E2A8C),
      ],
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
