import 'package:flutter/material.dart';

import 'glass/glass_layers.dart'
    show GlassTier, glassComposite, glassContrastRatio, compensatedFillAlpha;
import 'glass/glass_quality.dart';
import 'theme_presets.dart';

/// ContrastGuard 对比度联动（Glassmorphism v3，Spec §4.5 / 设计文档 §4.5，
/// 评审意见 #4 回应）：环境光强度三档会改变光斑 alpha，进而影响玻璃卡片上
/// 文字的有效对比度。本机制在「用户强度请求」与「WCAG AA 下限」冲突时
/// 自动钳制——**个性化让位于可读性时自动降档并向用户说明**（外观页徽标）。
///
/// 最坏情况建模：
/// ```
/// blobUnderCard = composite(background, brightestBlob × (0.95 × I × 0.85))
/// cardWorst     = composite(blobUnderCard, glassFill)      // standard 档 L1
/// 判定：contrast(textPrimary, cardWorst) ≥ 4.5（正文）
///       contrast(displayAmount 同底) ≥ 3.0（大金额 w700）
/// ```
///
/// - 0.85 为「光斑中心透过玻璃的残余可见度」经验系数
///   （BK-GLS-000 实测校准后冻结，见 docs/report/gls-v3/spike.md）；
/// - 自动钳制顺序：浓郁 → 标准 → 含蓄 逐级回退；仍不满足则运行时对该场景
///   玻璃填充 +0.05（[extraFillAlpha]，运行时生效、不写盘、不改用户设置）；
/// - 锁定态金额脱敏优先级最高，不受本机制影响；
/// - 测试锁定：8 预设 × {soft, standard, rich} × 浅深两态共 48 组合达标；
///   新增预设/强度档必须先过此门。
abstract final class ContrastGuard {
  /// 光斑中心透过玻璃的残余可见度系数（BK-GLS-000 校准冻结值）
  static const double blobResidualFactor = 0.85;

  /// 光斑渐变中心的绘制 alpha 上限（衰减曲线首 stop 0.95I）
  static const double blobPeakAlpha = 0.95;

  /// 正文对比度下限（WCAG AA）
  static const double bodyThreshold = 4.5;

  /// 大金额数字下限（displayAmount 34sp w700 场景）
  static const double displayThreshold = 3.0;

  /// 钳制后兜底的填充增量（运行时叠加，不写盘）
  static const double extraFill = 0.05;

  /// 钳制到 soft 后仍不满足时的兜底增量；满足则 0。
  /// 运行时叠加于当前场景玻璃填充 alpha（不写盘、不改用户设置）。
  /// 返回钳制后的有效强度：从 [requested] 起按 浓郁→标准→含蓄 逐级回退，
  /// 取首个满足正文 + 大金额双下限的档位；全不满足返回 soft
  /// （由调用方叠加 [extraFillAlpha] 兜底）。
  ///
  /// [brightness] 覆盖明暗上下文（默认取 palette.brightness）——
  /// 单元测试用同一调色板在浅/深两种玻璃填充基底下验证（48 组合矩阵）。
  static AmbientIntensity effectiveIntensity({
    required ThemePalette palette,
    required AmbientIntensity requested,
    GlassQuality quality = GlassQuality.standard,
    Brightness? brightness,
  }) {
    final bright = brightness ?? palette.brightness;
    for (final candidate in clampOrder(requested)) {
      if (_passes(palette, candidate.factor, quality, bright)) return candidate;
    }
    return AmbientIntensity.soft;
  }

  static double extraFillAlpha({
    required ThemePalette palette,
    required AmbientIntensity effective,
    GlassQuality quality = GlassQuality.standard,
    Brightness? brightness,
  }) {
    return _passes(
      palette,
      effective.factor,
      quality,
      brightness ?? palette.brightness,
    )
        ? 0.0
        : extraFill;
  }

  /// 钳制顺序：自 requested 向含蓄方向逐级回退
  /// （浓郁→标准→含蓄；测试锁定顺序语义）
  static List<AmbientIntensity> clampOrder(AmbientIntensity requested) {
    return switch (requested) {
      AmbientIntensity.rich => [
          AmbientIntensity.rich,
          AmbientIntensity.standard,
          AmbientIntensity.soft,
        ],
      AmbientIntensity.standard => [
          AmbientIntensity.standard,
          AmbientIntensity.soft,
        ],
      AmbientIntensity.soft => const [AmbientIntensity.soft],
    };
  }

  /// 最坏情况卡片合成面是否同时满足正文与大金额双阈值
  static bool _passes(
    ThemePalette palette,
    double intensityFactor,
    GlassQuality quality,
    Brightness brightness,
  ) {
    final worst = worstCaseCardSurface(palette, intensityFactor, quality,
        brightness: brightness);
    final body = glassContrastRatio(palette.textPrimary, worst);
    if (body < bodyThreshold) return false;
    // displayAmount 与正文同色（textPrimary），几何上 body 达标则 display 必达标；
    // 保留独立判定以锁定未来「大金额专用色」扩展的门槛语义
    final display = glassContrastRatio(palette.textPrimary, worst);
    return display >= displayThreshold;
  }

  /// 最坏情况卡片底色合成值（测试与徽标展示共用）：
  /// 最亮光斑（ambient 中相对亮度最高者）中心压在 background 上，
  /// 再叠 standard 档 L1 玻璃填充（浅白基/深 surface 基 + 画质补偿）。
  static Color worstCaseCardSurface(
    ThemePalette palette,
    double intensityFactor,
    GlassQuality quality, {
    Brightness? brightness,
  }) {
    final dark = (brightness ?? palette.brightness) == Brightness.dark;
    final blobs = palette.ambient.isEmpty
        ? [palette.primaryContainer]
        : palette.ambient;
    var brightest = blobs.first;
    for (final b in blobs) {
      if (glassContrastRatio(b, palette.background) >
          glassContrastRatio(brightest, palette.background)) {
        brightest = b;
      }
    }
    // 光斑中心有效 alpha = 峰值 0.95 × 强度 I × 透过玻璃残余 0.85
    final peakAlpha =
        (blobPeakAlpha * intensityFactor * blobResidualFactor).clamp(0.0, 1.0);
    final blobOnBg = glassComposite(
      brightest.withValues(alpha: peakAlpha),
      palette.background,
    );
    final fillAlpha = compensatedFillAlpha(
      tier: GlassTier.panel,
      dark: dark,
      quality: quality,
    );
    final fill = dark
        ? palette.surface.withValues(alpha: fillAlpha)
        : const Color(0xFFFFFFFF).withValues(alpha: fillAlpha);
    return glassComposite(fill, blobOnBg);
  }
}
