import 'dart:math' as math show pow;

import 'package:flutter/material.dart';

/// iOS 毛玻璃 Token 唯一参数源（FGDS v1.0，Spec 23 文档 §1–§6）。
///
/// 命名规则（Spec §1）：`glass.<类别>.<层级或语义>[.<模式>]`；
/// 组件代码只允许引用 [GlassLevel]（如 `GlassLevel.g2`）与本文档的
/// 静态取值方法，禁止在组件内书写模糊半径 / 透明度 / 描边 / 阴影字面量
/// （AC-01 静态扫描门禁）。
///
/// - 层级：G1 图标容器 → G5 轻提示，blur 与 fill α 沿 G1→G5 严格递增；
/// - 模式缺省时提供 light/dark 双值，由 `Brightness` 单点分流
///   （Spec §7.2：禁止组件内 `isDark ? a : b` 散写）。

// ---------------------------------------------------------------------------
// 层级体系（Spec §3 层级参数表）
// ---------------------------------------------------------------------------

/// 玻璃层级（设计文档 §4 五层深度模型 G1–G5；G0 背景层非玻璃）
enum GlassLevel { g1, g2, g3, g4, g5 }

/// 层级参数总表（Spec §3 核心规范，唯一真源）
extension GlassLevelX on GlassLevel {
  /// 层级序号（G1..G5 → 0..4）
  int get index => switch (this) {
        GlassLevel.g1 => 0,
        GlassLevel.g2 => 1,
        GlassLevel.g3 => 2,
        GlassLevel.g4 => 3,
        GlassLevel.g5 => 4,
      };

  /// 模糊 σ（px）。全系统仅允许 {12, 20, 28, 36, 44}（AC-01）
  double get blur => switch (this) {
        GlassLevel.g1 => 12,
        GlassLevel.g2 => 20,
        GlassLevel.g3 => 28,
        GlassLevel.g4 => 36,
        GlassLevel.g5 => 44,
      };

  /// 填充基色统一 #FFFFFF，通过 alpha 区分层级与模式（Spec §3）
  double get fillAlphaLight => switch (this) {
        GlassLevel.g1 => 0.55,
        GlassLevel.g2 => 0.60,
        GlassLevel.g3 => 0.72,
        GlassLevel.g4 => 0.80,
        GlassLevel.g5 => 0.85,
      };

  double get fillAlphaDark => switch (this) {
        GlassLevel.g1 => 0.10,
        GlassLevel.g2 => 0.12,
        GlassLevel.g3 => 0.18,
        GlassLevel.g4 => 0.24,
        GlassLevel.g5 => 0.30,
      };

  /// 外侧描边（0.5px #000000 α）：勾勒轮廓
  double get borderOuterAlphaLight => switch (this) {
        GlassLevel.g1 || GlassLevel.g2 => 0.06,
        GlassLevel.g3 => 0.08,
        GlassLevel.g4 || GlassLevel.g5 => 0.10,
      };

  double get borderOuterAlphaDark => switch (this) {
        GlassLevel.g1 || GlassLevel.g2 => 0.30,
        GlassLevel.g3 => 0.35,
        GlassLevel.g4 || GlassLevel.g5 => 0.40,
      };

  /// 内侧高光（0.5px #FFFFFF α）：模拟玻璃边缘折射
  double get highlightInnerAlphaLight => switch (this) {
        GlassLevel.g1 || GlassLevel.g2 => 0.35,
        GlassLevel.g3 => 0.40,
        GlassLevel.g4 => 0.45,
        GlassLevel.g5 => 0.50,
      };

  double get highlightInnerAlphaDark => switch (this) {
        GlassLevel.g1 || GlassLevel.g2 => 0.12,
        GlassLevel.g3 => 0.14,
        GlassLevel.g4 => 0.16,
        GlassLevel.g5 => 0.18,
      };

  /// 环境投影（x/y/blur/alpha，spread 恒为 0；深色模式投影 alpha 与浅色相同，
  /// 纯黑背景上投影天然弱化——设计文档 §9 / Spec §3 注）
  BoxShadow shadowFor(Color base) => switch (this) {
        GlassLevel.g1 => BoxShadow(
            offset: const Offset(0, 2), blurRadius: 8, color: base.withValues(alpha: 0.04)),
        GlassLevel.g2 => BoxShadow(
            offset: const Offset(0, 4), blurRadius: 16, color: base.withValues(alpha: 0.06)),
        GlassLevel.g3 => BoxShadow(
            offset: const Offset(0, 6), blurRadius: 20, color: base.withValues(alpha: 0.08)),
        GlassLevel.g4 => BoxShadow(
            offset: const Offset(0, 12), blurRadius: 32, color: base.withValues(alpha: 0.12)),
        GlassLevel.g5 => BoxShadow(
            offset: const Offset(0, 8), blurRadius: 24, color: base.withValues(alpha: 0.10)),
      };
}

// ---------------------------------------------------------------------------
// 派生规则（Spec §3）
// ---------------------------------------------------------------------------

/// 卡片嵌套升档（最多一层）：G2 卡片内的分组容器用下一档（G3）填充值、
/// 不新增 BackdropFilter（blur 保持宿主档位）、圆角 12。
GlassLevel nestedFillLevel(GlassLevel host) =>
    GlassLevel.values[(host.index + 1).clamp(0, GlassLevel.values.length - 1)];

/// 低性能降级补偿（BK-FG-003 / 任务分解风险对策）：禁用模糊时
/// fill α +0.10 补偿可读性。
const double kBlurDegradeFillCompensation = 0.10;

// ---------------------------------------------------------------------------
// 主题色（Spec §2.1）
// ---------------------------------------------------------------------------

abstract final class GlassThemeColors {
  /// 默认主色（iOS systemBlue / 提亮版）；预制主题以各自品牌主色覆盖此槽位
  static const primaryLight = Color(0xFF0A84FF);
  static const primaryDark = Color(0xFF409CFF);

  /// 着色玻璃上的文字
  static const onPrimary = Color(0xFFFFFFFF);

  /// 危险操作
  static const dangerLight = Color(0xFFFF3B30);
  static const dangerDark = Color(0xFFFF453A);

  /// 收入 / 正向状态
  static const successLight = Color(0xFF34C759);
  static const successDark = Color(0xFF30D158);
}

// ---------------------------------------------------------------------------
// 背景与遮罩（Spec §2.2/§2.3 硬约束）
// ---------------------------------------------------------------------------

abstract final class GlassBackground {
  /// 背景白名单唯二底色：浅色 systemGray6 / 深色纯黑（设计文档 §3.1）
  static const baseLight = Color(0xFFF2F2F7);
  static const baseDark = Color(0xFF000000);

  /// 允许的唯一变化：同色系垂直单色微渐变（明度差 ≤3%，同 H 同 S）。
  /// 返回 [顶色, 底色]；当前默认路径为纯色（§2.2「只渲染 base 或
  /// base + 微渐变」取前者，本 API 供走查/开启微渐变时使用）。
  static List<Color>? microGradient(Brightness brightness) {
    final base = brightness == Brightness.dark ? baseDark : baseLight;
    // 顶部向白/黑方向偏移 ≤3% 明度，底部回到 base：同 H 同 S 单色渐变
    final top = Color.lerp(
        base, brightness == Brightness.dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        brightness == Brightness.dark ? 0.03 : 0.015)!;
    return [top, base];
  }

  /// G4 模态浮层背后的全屏遮罩：#000000 α 0.32
  static Color scrimOf(Color base) => base.withValues(alpha: 0.32);
}

// ---------------------------------------------------------------------------
// 文字四档（Spec §5；实色渲染于玻璃之上，不参与半透明）
// ---------------------------------------------------------------------------

abstract final class GlassTextColors {
  static const primaryLight = Color(0xFF1C1C1E);
  static const secondaryBaseLight = Color(0xFF3C3C43);

  static Color primary(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFFFFFFF) : primaryLight;

  static Color secondary(Brightness b) => (b == Brightness.dark
          ? const Color(0xFFFFFFFF)
          : secondaryBaseLight)
      .withValues(alpha: 0.60);

  static Color tertiary(Brightness b) => (b == Brightness.dark
          ? const Color(0xFFFFFFFF)
          : secondaryBaseLight)
      .withValues(alpha: 0.36);

  static Color disabled(Brightness b) => (b == Brightness.dark
          ? const Color(0xFFFFFFFF)
          : secondaryBaseLight)
      .withValues(alpha: 0.24);
}

// ---------------------------------------------------------------------------
// 动效常量（Spec §6；曲线统一 cubic-bezier(0.4, 0.0, 0.2, 1)）
// ---------------------------------------------------------------------------

abstract final class GlassMotion {
  /// 统一状态曲线
  static const Curve curve = Cubic(0.4, 0.0, 0.2, 1.0);

  /// 微交互（hover/pressed）
  static const Duration micro = Duration(milliseconds: 150);

  /// 状态切换（选中/聚焦/主题切换）
  static const Duration state = Duration(milliseconds: 200);

  /// 浮层进出
  static const Duration overlay = Duration(milliseconds: 250);

  /// 「减弱动态效果」降级：100ms 纯透明度
  static const Duration reduced = Duration(milliseconds: 100);
}

// ---------------------------------------------------------------------------
// 语义 Token：FG-TBL 表格 / FG-SEL 选中态 / FG-BTN 按钮（Spec §4.2–§4.4）
// ---------------------------------------------------------------------------

/// FG-SEL 选中态（Spec §4.2 四层叠加）
abstract final class GlassSelectionTokens {
  /// 层① 玻璃增亮目标 fill α（G3 档）：宿主填充提升至此值
  static const double brightenFillLight = 0.72;
  static const double brightenFillDark = 0.18;

  /// 层② 柔和光晕：primary α0.25，blur 20，spread 0，offset 0/0
  static const double glowAlpha = 0.25;
  static const double glowBlur = 20;

  /// 层③ 透明叠加层：primary 垂直渐变（顶→底）
  static const double overlayTopLight = 0.12;
  static const double overlayBottomLight = 0.06;
  static const double overlayTopDark = 0.10;
  static const double overlayBottomDark = 0.05;

  /// 层④ 描边：内侧高光 0.5px #FFFFFF + 外缘 0.5px primary
  static const double innerHighlightLight = 0.50;
  static const double innerHighlightDark = 0.20;
  static const double outerEdgeAlphaLight = 0.30;
  static const double outerEdgeAlphaDark = 0.35;
}

/// FG-TBL 表格语义（Spec §4.3）
abstract final class GlassTableTokens {
  /// 斑马纹（纯透明度区分；行级禁 BackdropFilter）
  static const double zebraOddFillLight = 0.45;
  static const double zebraOddFillDark = 0.10;
  static const double zebraEvenFillLight = 0.30;
  static const double zebraEvenFillDark = 0.06;

  /// 行 hover：该行 fill α +0.10（浅）/ +0.04（深），150ms 过渡
  static const double hoverDeltaLight = 0.10;
  static const double hoverDeltaDark = 0.04;

  /// 表头底部分隔线：浅 #000 α0.06 / 深 #FFF α0.08
  static const double headerDividerAlphaLight = 0.06;
  static const double headerDividerAlphaDark = 0.08;

  /// 行分隔线：浅 #000 α0.05 / 深 #FFF α0.06，左右内缩 16px
  static const double rowDividerAlphaLight = 0.05;
  static const double rowDividerAlphaDark = 0.06;
}

/// FG-BTN 按钮状态参数矩阵（Spec §4.4；次级玻璃按钮 G2 基材）
abstract final class GlassButtonTokens {
  /// 状态 blur σ 矩阵（默认 20 = G2；§4.4 规定值，与层级表同源收录）
  static const double blurDefault = 20;
  static const double blurHover = 24;
  static const double blurPressed = 16;
  static const double blurDisabled = 8;

  /// 次级按钮各态 fill α（浅色表；深色见括号内 §4.4 双值）
  static const double fillDefaultLight = 0.60;
  static const double fillDefaultDark = 0.12;
  static const double fillHoverLight = 0.68;
  static const double fillHoverDark = 0.16;
  static const double fillPressedLight = 0.48;
  static const double fillPressedDark = 0.09;
  static const double fillDisabledLight = 0.32;
  static const double fillDisabledDark = 0.06;

  /// Hover 内高光 α +0.05
  static const double hoverHighlightBoost = 0.05;

  /// Pressed 内阴影 inset 0/1/3 #000 α0.08（顶部内阴影近似绘制）
  static const double pressedInnerShadowAlpha = 0.08;

  /// Focus 外环：2px primary α0.50
  static const double focusRingAlpha = 0.50;
  static const double focusRingWidth = 2;

  /// 主操作着色玻璃（blur σ20 不变）：fill = primary α
  static const double primaryFillLight = 0.75;
  static const double primaryFillDark = 0.65;
  static const double primaryHoverBoost = 0.08;
  static const double primaryPressedDrop = 0.10;
  static const double primaryDisabledFill = 0.30;
  static const double primaryDisabledTextAlpha = 0.50;

  /// 通用规格：高度 44（标准）/ 32（紧凑）；水平 padding 20
  static const double heightStandard = 44;
  static const double heightCompact = 32;
  static const double horizontalPadding = 20;
}

/// FG-INP 输入框语义（Spec §4.8）
abstract final class GlassInputTokens {
  /// G2 降档填充
  static const double fillLight = 0.45;
  static const double fillDark = 0.10;

  /// 聚焦：内高光 α +0.05 + 2px 外环 primary α0.50
  static const double focusHighlightBoost = 0.05;

  /// 错误外环 danger α0.60
  static const double errorRingAlpha = 0.60;

  /// 禁用 fill α
  static const double disabledFillLight = 0.24;
  static const double disabledFillDark = 0.05;

  /// 高度 44 / 圆角 12
  static const double height = 44;
}

/// FG-ICON 图标容器（Spec §4.1）
abstract final class GlassIconTokens {
  /// 尺寸档位（正方形）
  static const double size28 = 28;
  static const double size36 = 36;
  static const double size44 = 44;

  /// 连续圆角近似：尺寸 × 0.28（7.84 / 10.08 / 12.32）
  static const double radiusFactor = 0.28;

  /// 图标本体尺寸 = 容器 × 0.55
  static const double iconScale = 0.55;

  /// tint 变体：容器 fill 混入主题色 α（浅 0.10 / 深 0.08 叠加）
  static const double tintOverlayLight = 0.10;
  static const double tintOverlayDark = 0.08;
}

// ---------------------------------------------------------------------------
// 已解析玻璃规格（组件层唯一消费形态）
// ---------------------------------------------------------------------------

/// 一次解析、组件只消费（Spec §1：组件禁止持值）。
class GlassSpec {
  const GlassSpec({
    required this.level,
    required this.blur,
    required this.fill,
    required this.borderOuter,
    required this.borderInnerHighlight,
    required this.topHighlightAlpha,
    required this.topHighlightCoverage,
    required this.shadows,
    required this.radius,
    required this.blurEnabled,
  });

  final GlassLevel level;

  /// 高斯模糊 σ；[blurEnabled] 为 false 时本值不产生 BackdropFilter 节点
  final double blur;

  /// 半透明填充（#FFFFFF × 层级 α，含降级补偿后的最终值）
  final Color fill;

  /// 外侧 0.5px 深色勾边
  final Color borderOuter;

  /// 内侧 0.5px 白色高光描边
  final Color borderInnerHighlight;

  /// 顶部内高光渐变强度（#FFFFFF α，浅 0.20→0 / 深 0.08→0）
  final double topHighlightAlpha;

  /// 顶部内高光覆盖高度比例（组件高度的 40%，自上而下线性和到 0）
  final double topHighlightCoverage;

  /// 环境投影（单光源单层，禁彩色/堆叠）
  final List<BoxShadow> shadows;

  /// 层级默认圆角
  final double radius;

  /// 是否允许真实磨砂（false 时调用方跳过 BackdropFilter）
  final bool blurEnabled;
}

/// 玻璃表面唯一解析入口：层级 × 明暗（+ 可选降级）→ 全部渲染参数。
GlassSpec resolveGlassSpec({
  required GlassLevel level,
  required Brightness brightness,
  bool blurEnabled = true,

  /// 禁用模糊时是否叠加 fill α+0.10 补偿：用户降级开；嵌套等结构性
  /// fill-only 关（内层严格取下一档填充值，Spec §3 派生规则）。
  bool degradeCompensation = true,
  double? radius,
}) {
  final dark = brightness == Brightness.dark;
  var fillAlpha = dark ? level.fillAlphaDark : level.fillAlphaLight;
  if (!blurEnabled && degradeCompensation) {
    fillAlpha =
        (fillAlpha + kBlurDegradeFillCompensation).clamp(0.0, 1.0);
  }
  return GlassSpec(
    level: level,
    blur: level.blur,
    fill: const Color(0xFFFFFFFF).withValues(alpha: fillAlpha),
    borderOuter: const Color(0xFF000000)
        .withValues(alpha: dark ? level.borderOuterAlphaDark : level.borderOuterAlphaLight),
    borderInnerHighlight: const Color(0xFFFFFFFF)
        .withValues(
            alpha: dark ? level.highlightInnerAlphaDark : level.highlightInnerAlphaLight),
    topHighlightAlpha: dark ? 0.08 : 0.20,
    topHighlightCoverage: 0.40,
    shadows: [level.shadowFor(const Color(0xFF000000))],
    radius: radius ?? defaultRadius(level),
    blurEnabled: blurEnabled,
  );
}

/// 层级默认圆角（Spec §3 圆角行 / 设计文档 §7 四档语言）：
/// G1 由尺寸 ×0.28 动态计算不入表；G2 卡片 16；G3 通栏 0（浮条 16 由
/// 调用方传参）；G4 浮层 20；G5 Toast 14（胶囊全圆角由调用方传 pill）。
double defaultRadius(GlassLevel level) => switch (level) {
      GlassLevel.g1 => 12,
      GlassLevel.g2 => 16,
      GlassLevel.g3 => 0,
      GlassLevel.g4 => 20,
      GlassLevel.g5 => 14,
    };

// ---------------------------------------------------------------------------
// WCAG 验算工具（Spec §7.1 合成公式；对比度脚本与运行时共用同式）
// ---------------------------------------------------------------------------

/// sRGB 相对亮度
double glassRelativeLuminance(Color c) {
  double channel(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// 两色 WCAG 对比度
double glassContrastRatio(Color a, Color b) {
  final l1 = glassRelativeLuminance(a);
  final l2 = glassRelativeLuminance(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// 不透明底色上叠加半透明前景色（线性 RGB 合成，Spec §7.1 同式）
Color glassComposite(Color fg, Color bg) {
  final a = fg.a;
  return Color.fromARGB(
    255,
    ((fg.r * a + bg.r * (1 - a)) * 255).round(),
    ((fg.g * a + bg.g * (1 - a)) * 255).round(),
    ((fg.b * a + bg.b * (1 - a)) * 255).round(),
  );
}
