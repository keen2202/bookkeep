import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme_presets.dart';
import 'glass_quality.dart';

/// 玻璃层级体系（Glassmorphism v3，Spec §2）：
/// L0 环境层之上，玻璃表面按「离用户越近 → 越亮、越磨砂、描边越高光」
/// 分为四层（设计文档 §3.1 五层深度模型的 L1–L4）：
///
/// - [GlassTier.panel]    L1 内容面板层：卡片 / 图表容器 / 分组容器
/// - [GlassTier.dock]     L2 吸附层：底部导航栏 / 吸顶栏 / FAB 区
/// - [GlassTier.overlay]  L3 浮层：弹窗 / 底部弹层 / 下拉菜单
/// - [GlassTier.floating] L4 悬浮提示层：SnackBar / Toast / Tooltip
///
/// σ / 填充 α / 描边 α 三参数随层级严格单调递增（单元测试锁定，
/// 设计原则「深度可读」：任何层级差异必须同时体现在 ≥2 个维度）。
enum GlassTier { panel, dock, overlay, floating }

/// 顶部高光样式（Spec §3.2 色带防线）：
/// - [gradient]：ForegroundDecoration 顶部渐变高光（默认）；
/// - [solidLine]：1px 实线（α_top）+ 其下 1px 半强线——真机色带探针
///   走查可见台阶纹时的单点降级开关（BK-GLS-000 决议项）。
enum GlassHighlightStyle { gradient, solidLine }

/// 顶部高光全局样式（Spec §3.2 单点 feature flag）。
/// 默认渐变；Impeller 对渐变自带抖动 + 渐变 stop 间隔 ≥0.15 防线生效时
/// 无需降级。真机走查判定色带可见后改 [GlassHighlightStyle.solidLine]。
const GlassHighlightStyle kGlassHighlightStyle = GlassHighlightStyle.gradient;

/// 浅色主题描边增强备选参数（Spec §2.4）：浅色填充近白、白描边增量有限，
/// A/B 小样不过关时启用（L1 描边 α 0.20→0.32）。默认关闭。
const bool kGlassBorderBoost = false;

/// 层级参数总表（Spec §2.1 基础档 = high 画质；规范源 canonical）。
extension GlassTierX on GlassTier {
  /// 层级序号（L1..L4 → 0..3）
  int get index => switch (this) {
        GlassTier.panel => 0,
        GlassTier.dock => 1,
        GlassTier.overlay => 2,
        GlassTier.floating => 3,
      };

  /// 模糊 σ（ui.ImageFilter.blur 直取值；CSS blur(r) ≈ sigma r/2 仅作沟通换算）
  double get baseSigma => switch (this) {
        GlassTier.panel => 10,
        GlassTier.dock => 16,
        GlassTier.overlay => 28,
        GlassTier.floating => 36,
      };

  /// 填充 α（浅·白基，high 档）
  double get baseFillAlphaLight => switch (this) {
        GlassTier.panel => 0.55,
        GlassTier.dock => 0.65,
        GlassTier.overlay => 0.75,
        GlassTier.floating => 0.85,
      };

  /// 填充 α（深·surface 基，high 档；非纯黑，带主题色温）
  double get baseFillAlphaDark => switch (this) {
        GlassTier.panel => 0.66,
        GlassTier.dock => 0.72,
        GlassTier.overlay => 0.80,
        GlassTier.floating => 0.86,
      };

  /// 描边白 α（浅色；L1 = 0x33FFFFFF 即需求基准 rgba(255,255,255,0.2)）。
  /// [kGlassBorderBoost] 启用时 L1 上调至 0.32（Spec §2.4 备选参数）。
  double get baseBorderAlphaLight {
    final boost = kGlassBorderBoost && this == GlassTier.panel ? 0.12 : 0.0;
    return switch (this) {
          GlassTier.panel => 0.20,
          GlassTier.dock => 0.22,
          GlassTier.overlay => 0.25,
          GlassTier.floating => 0.30,
        } +
        boost;
  }

  /// 描边白 α（深色逐层实值 0.16/0.18/0.20/0.24，Spec §2.4 标定：
  /// ×0.6 方案 L1=0.12 合成对比度仅 1.44:1 < 1.5 下限被否决；
  /// 0.16 实测 1.64:1。更高层因填充更亮，同 α 对比度略降故阶梯上移）
  double get baseBorderAlphaDark => switch (this) {
        GlassTier.panel => 0.16,
        GlassTier.dock => 0.18,
        GlassTier.overlay => 0.20,
        GlassTier.floating => 0.24,
      };

  /// 顶部高光 α_top 基准（浅/深，设计文档 §5.2：浅 0.25 / 深 0.10，
  /// 按 L1 1.0 / L2 1.1 / L3 1.2 / L4 1.3 微调后的规范值）
  ({double light, double dark}) get baseHighlightAlpha => switch (this) {
        GlassTier.panel => (light: 0.25, dark: 0.10),
        GlassTier.dock => (light: 0.28, dark: 0.11),
        GlassTier.overlay => (light: 0.30, dark: 0.12),
        GlassTier.floating => (light: 0.33, dark: 0.13),
      };

  /// 阴影缩放系数（v2 双态阴影 y=4/blur=18 按 offset/blur 同比缩放）
  double get shadowScale => switch (this) {
        GlassTier.panel => 1.0,
        GlassTier.dock => 1.2,
        GlassTier.overlay => 1.5,
        GlassTier.floating => 1.8,
      };
}

/// 已解析的玻璃表面规格（Spec §2.2）：渲染所需全部视觉参数一次解析，
/// 组件层（GlassPanel/AppCard/GlassIcon/app_theme 组装器）只消费本对象。
class GlassSpec {
  const GlassSpec({
    required this.fill,
    required this.sigmaX,
    required this.sigmaY,
    required this.borderColor,
    required this.highlightAlphaTop,
    this.topHighlight,
    this.shadows = const [],
  });

  /// 已按 brightness/quality/imageMode 解析的填充色
  final Color fill;

  /// 高斯模糊 σ（quality 归零规则见 resolvedSigma；standard 档 L1/L2 为 0）
  final double sigmaX;
  final double sigmaY;

  /// 描边色：白 × 层 α × 明暗实值（深色用 §2.4 标定表），宽度恒 1 逻辑像素
  final Color borderColor;

  /// ForegroundDecoration 用顶部高光渐变；solidLine 模式为 null
  /// （改由 [highlightAlphaTop] 绘制双细线，GlassPanel 内分支渲染）
  final Gradient? topHighlight;

  /// 顶部高光 α_top（solidLine 模式的实线强度；单元测试断言用）
  final double highlightAlphaTop;

  /// 悬浮阴影（§2.1 缩放系数生成）
  final List<BoxShadow> shadows;

  /// σ 是否为零（fill-only 主路径，调用方可跳过 BackdropFilter 节点）
  bool get isFillOnly => sigmaX <= 0 && sigmaY <= 0;
}

/// 画质三档（Spec §2.3）填充补偿规则（叠加于 §2.1 基础值）：
///
/// | 档位 | 补偿 |
/// | high | 无 |
/// | standard | 浅 L1 +0.06 / L2 +0.03；深 L1 +0.04 / L2 +0.02 |
/// | saver | 浅/深均 +0.08/+0.06/+0.02/+0.02（L1→L4） |
double compensatedFillAlpha({
  required GlassTier tier,
  required bool dark,
  required GlassQuality quality,
}) {
  var alpha = dark ? tier.baseFillAlphaDark : tier.baseFillAlphaLight;
  switch (quality) {
    case GlassQuality.high:
      break;
    case GlassQuality.standard:
      alpha += switch (tier.index) {
        0 => dark ? 0.04 : 0.06,
        1 => dark ? 0.02 : 0.03,
        _ => 0.0,
      };
    case GlassQuality.saver:
      alpha += switch (tier.index) {
        0 => 0.08,
        1 => 0.06,
        _ => 0.02,
      };
  }
  return alpha.clamp(0.0, 1.0);
}

/// 画质三档的最终 σ（Spec §2.3）：
/// standard 档 L1/L2 归零（fill-only 主路径，零 saveLayer）；saver 档仅
/// L3/L4 保留且 σ×0.6；high 档全层级真实磨砂。
double resolvedSigma({
  required GlassTier tier,
  required GlassQuality quality,
}) {
  return switch (quality) {
    GlassQuality.high => tier.baseSigma,
    GlassQuality.standard => tier.index >= 2 ? tier.baseSigma : 0.0,
    GlassQuality.saver => tier.index >= 2 ? tier.baseSigma * 0.6 : 0.0,
  };
}

/// 玻璃表面唯一解析入口（D1/D5：新代码一律走本函数）。
///
/// - 浅色填充 = 白基 × 表内 α；深色填充 = `palette.surface` × 表内 α
///   （带主题色温，非纯黑，Spec §2.1 规则一）；
/// - 背景图模式 L1 加厚 +0.06（上限 0.80，Spec §4.6）；
/// - solidLine 分支在此单点收敛（Spec §3.2 色带防线）。
GlassSpec resolveGlassSpec({
  required GlassTier tier,
  required Brightness brightness,
  required ThemePalette palette,
  GlassQuality quality = GlassQuality.standard,
  bool imageBackgroundMode = false,
  @visibleForTesting GlassHighlightStyle? highlightStyleOverride,
}) {
  final dark = brightness == Brightness.dark;
  var fillAlpha = compensatedFillAlpha(
    tier: tier,
    dark: dark,
    quality: quality,
  );
  if (imageBackgroundMode && tier == GlassTier.panel) {
    // Spec §4.6：复杂纹理降低有效对比，主声部加厚兜底（上限 0.80）
    fillAlpha = (fillAlpha + 0.06).clamp(0.0, 0.80);
  }
  final fill = dark
      ? palette.surface.withValues(alpha: fillAlpha)
      : Colors.white.withValues(alpha: fillAlpha);
  final borderAlpha =
      dark ? tier.baseBorderAlphaDark : tier.baseBorderAlphaLight;
  final highlightAlpha = dark
      ? tier.baseHighlightAlpha.dark
      : tier.baseHighlightAlpha.light;
  final sigma = resolvedSigma(tier: tier, quality: quality);
  final borderColor = Colors.white.withValues(alpha: borderAlpha);

  // 悬浮阴影（设计文档 §5.3）：v2 双态阴影（浅 10% 黑 / 深 25% 黑）
  // y=4、blur=18，按层缩放 offset/blur 同比放大
  final s = tier.shadowScale;
  final shadows = [
    BoxShadow(
      offset: Offset(0, 4 * s),
      blurRadius: 18 * s,
      color: dark ? const Color(0x40000000) : const Color(0x1A000000),
    ),
  ];

  // 顶部高光（设计文档 §5.2）：ForegroundDecoration 顶部渐变，
  // 高光带高度固定为面板高度 45%（stop 区间充足，防色带）；
  // solidLine 模式置 null，由 GlassPanel 绘制双细线（单点分支收敛于此）。
  final style = highlightStyleOverride ?? kGlassHighlightStyle;
  Gradient? topHighlight;
  if (style == GlassHighlightStyle.gradient) {
    topHighlight = LinearGradient(
      begin: Alignment.topCenter,
      end: const Alignment(0, 0.45),
      colors: [
        Colors.white.withValues(alpha: highlightAlpha),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0.0, 1.0],
    );
  }

  return GlassSpec(
    fill: fill,
    sigmaX: sigma,
    sigmaY: sigma,
    borderColor: borderColor,
    topHighlight: topHighlight,
    highlightAlphaTop: highlightAlpha,
    shadows: shadows,
  );
}

/// WCAG 相对亮度（装饰性线条与文字对比度验算用，Spec §2.4）
double glassRelativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// 两色 WCAG 对比度（描边可见性下限 1.5:1 与 ContrastGuard 共用）
double glassContrastRatio(Color a, Color b) {
  final l1 = glassRelativeLuminance(a);
  final l2 = glassRelativeLuminance(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// 不透明底色上叠加半透明前景色（线性 RGB 合成，Spec §2.4 手工验算同式）
Color glassComposite(Color fg, Color bg) {
  final a = fg.a;
  return Color.fromARGB(
    255,
    ((fg.r * a + bg.r * (1 - a)) * 255).round(),
    ((fg.g * a + bg.g * (1 - a)) * 255).round(),
    ((fg.b * a + bg.b * (1 - a)) * 255).round(),
  );
}
