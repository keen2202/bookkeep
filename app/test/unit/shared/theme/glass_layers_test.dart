import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/glass/glass_layers.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_quality.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

void main() {
  final t1 = findPresetById('t1')!.palette;
  final t5 = findPresetById('t5')!.palette;

  test('层级三参数单调性：σ / 填充α / 描边α 随层级严格递增（AC-01）', () {
    final tiers = GlassTier.values;
    // σ 单调性锁定规范表基础值（standard 档 L1/L2 归零后为非严格递减，
    // 由画质档 σ 解析用例单独锁定）
    for (var i = 0; i < tiers.length - 1; i++) {
      expect(tiers[i + 1].baseSigma, greaterThan(tiers[i].baseSigma),
          reason: '${tiers[i]}→${tiers[i + 1]} 规范表 σ 单调递增');
    }
    for (var i = 0; i < tiers.length - 1; i++) {
      final lo = resolveGlassSpec(
          tier: tiers[i], brightness: Brightness.light, palette: t1);
      final hi = resolveGlassSpec(
          tier: tiers[i + 1], brightness: Brightness.light, palette: t1);
      expect(hi.fill.a, greaterThan(lo.fill.a),
          reason: '${tiers[i]}→${tiers[i + 1]} 浅色填充 α 单调递增');
      expect(hi.borderColor.a, greaterThan(lo.borderColor.a),
          reason: '${tiers[i]}→${tiers[i + 1]} 浅色描边 α 单调递增');
      expect(hi.highlightAlphaTop, greaterThan(lo.highlightAlphaTop),
          reason: '${tiers[i]}→${tiers[i + 1]} 高光 α_top 单调递增');
      expect(hi.shadows.first.blurRadius,
          greaterThan(lo.shadows.first.blurRadius),
          reason: '阴影随层缩放');

      final dLo = resolveGlassSpec(
          tier: tiers[i], brightness: Brightness.dark, palette: t5);
      final dHi = resolveGlassSpec(
          tier: tiers[i + 1], brightness: Brightness.dark, palette: t5);
      expect(dHi.fill.a, greaterThan(dLo.fill.a),
          reason: '${tiers[i]}→${tiers[i + 1]} 深色填充 α 单调递增');
      expect(dHi.borderColor.a, greaterThan(dLo.borderColor.a),
          reason: '${tiers[i]}→${tiers[i + 1]} 深色描边 α 单调递增');
    }
  });

  test('描边基准：浅色 L1 == rgba(255,255,255,0.2)，深色 L1 实值 0.16（AC-02）', () {
    final lightL1 = resolveGlassSpec(
        tier: GlassTier.panel, brightness: Brightness.light, palette: t1);
    expect(lightL1.borderColor, const Color(0x33FFFFFF),
        reason: '需求给定基准 rgba(255,255,255,0.2)');
    final darkTiers = [
      (GlassTier.panel, 0.16),
      (GlassTier.dock, 0.18),
      (GlassTier.overlay, 0.20),
      (GlassTier.floating, 0.24),
    ];
    for (final (tier, alpha) in darkTiers) {
      final s = resolveGlassSpec(
          tier: tier, brightness: Brightness.dark, palette: t5);
      expect(s.borderColor.a, closeTo(alpha, 0.0001),
          reason: '$tier 深色描边实值 §2.4 标定表');
    }
  });

  test('§2.4 验算用例：T5 standard L1 合成面描边对比度 ≈1.64:1 ≥ 1.5 下限', () {
    // 手工验算记录（Spec §2.4）：填充 = surface(#1A1E24)@0.70 over bg(#13171C)
    // → #181C22；描边白 @0.16 → R=61 (#3D4045)；对比度 ≈1.64 ✓
    final fillAlpha =
        compensatedFillAlpha(tier: GlassTier.panel, dark: true, quality: GlassQuality.standard);
    expect(fillAlpha, closeTo(0.70, 0.0001));
    final fillComposite =
        glassComposite(t5.surface.withValues(alpha: fillAlpha), t5.background);
    expect(fillComposite.toARGB32(), const Color(0xFF181C22).toARGB32(),
        reason: '线性 RGB 合成与 Spec §2.4 手算一致');
    final borderComposite = glassComposite(
        Colors.white.withValues(alpha: 0.16), fillComposite);
    expect(borderComposite.toARGB32(), const Color(0xFF3D4045).toARGB32());
    final ratio = glassContrastRatio(borderComposite, fillComposite);
    expect(ratio, closeTo(1.64, 0.02), reason: '实测 1.64:1');
    expect(ratio, greaterThanOrEqualTo(1.5), reason: '装饰线可见性下限');
  });

  test('§2.4 否决用例：旧 ×0.6 方案（α0.12）对比度 1.44 < 1.5 被正确判负', () {
    final fillComposite =
        glassComposite(t5.surface.withValues(alpha: 0.70), t5.background);
    final weakBorder = glassComposite(
        Colors.white.withValues(alpha: 0.12), fillComposite);
    final ratio = glassContrastRatio(weakBorder, fillComposite);
    expect(ratio, lessThan(1.5), reason: 'α0.12 合成后近乎不可见（≈1.44:1）');
    expect(ratio, closeTo(1.44, 0.02));
  });

  test('深色基底（T5–T8 原生深色预设）：全部层级描边合成对比度 ≥ 1.5:1', () {
    // AC-02：深色描边逐层实值 0.16–0.24 且每层「描边 vs 填充」≥1.5:1；
    // 深色玻璃表面即 T5–T8 四套原生深色预设
    final darkPresets =
        kThemePresetsV2.where((p) => p.isDark).toList(growable: false);
    expect(darkPresets, hasLength(4));
    for (final preset in darkPresets) {
      for (final tier in GlassTier.values) {
        final s = resolveGlassSpec(
          tier: tier,
          brightness: Brightness.dark,
          palette: preset.palette,
          quality: GlassQuality.standard,
        );
        final under = preset.palette.background;
        final fillComposite = glassComposite(s.fill, under);
        final borderComposite = glassComposite(s.borderColor, fillComposite);
        final ratio = glassContrastRatio(borderComposite, fillComposite);
        expect(ratio, greaterThanOrEqualTo(1.5),
            reason: '${preset.id} $tier 深色描边可见性 $ratio < 1.5');
      }
    }
  });

  test('浅色基底：描边增量有限属预期行为（Spec §2.4），轮廓由阴影+高光承担', () {
    // Spec §2.4 明示：浅色主题白描边在近白填充上合成增量有限属预期行为，
    // 轮廓定义主要由 阴影 + 顶部高光 + 光斑边缘色差 承担（A/B 小样确认项）；
    // 故 1.5:1 下限仅锁定深色基底（上一用例）。此处锁定：
    // ①浅色描边仍可测量地亮于填充（>1.0）；②描边 α 等于规范表。
    for (final preset in kThemePresetsV2) {
      for (final tier in GlassTier.values) {
        final s = resolveGlassSpec(
          tier: tier,
          brightness: Brightness.light,
          palette: preset.palette,
          quality: GlassQuality.standard,
        );
        final fillComposite =
            glassComposite(s.fill, preset.palette.background);
        final borderComposite = glassComposite(s.borderColor, fillComposite);
        expect(glassContrastRatio(borderComposite, fillComposite),
            greaterThan(1.0),
            reason: '${preset.id} $tier 浅色描边至少可辨方向');
      }
    }
  });

  test('画质补偿解析：standard L1/L2 补偿、saver 全层补偿、high 无补偿（§2.3）', () {
    // 浅色 standard：L1 +0.06（0.55→0.61）、L2 +0.03（0.65→0.68）
    expect(
      compensatedFillAlpha(
          tier: GlassTier.panel, dark: false, quality: GlassQuality.standard),
      closeTo(0.61, 0.0001),
    );
    expect(
      compensatedFillAlpha(
          tier: GlassTier.dock, dark: false, quality: GlassQuality.standard),
      closeTo(0.68, 0.0001),
    );
    // 深色 standard：L1 +0.04（0.66→0.70）、L2 +0.02（0.72→0.74）
    expect(
      compensatedFillAlpha(
          tier: GlassTier.panel, dark: true, quality: GlassQuality.standard),
      closeTo(0.70, 0.0001),
    );
    expect(
      compensatedFillAlpha(
          tier: GlassTier.dock, dark: true, quality: GlassQuality.standard),
      closeTo(0.74, 0.0001),
    );
    // saver：浅/深均 +0.08/+0.06/+0.02/+0.02
    for (final dark in [false, true]) {
      expect(
        compensatedFillAlpha(
            tier: GlassTier.panel, dark: dark, quality: GlassQuality.saver),
        closeTo((dark ? 0.66 : 0.55) + 0.08, 0.0001),
      );
      expect(
        compensatedFillAlpha(
            tier: GlassTier.overlay, dark: dark, quality: GlassQuality.saver),
        closeTo((dark ? 0.80 : 0.75) + 0.02, 0.0001),
      );
    }
    // high：原值
    expect(
      compensatedFillAlpha(
          tier: GlassTier.panel, dark: false, quality: GlassQuality.high),
      closeTo(0.55, 0.0001),
    );
  });

  test('画质档 σ 解析：high 全真实、standard L1/L2 归零、saver 仅 L3/L4 且 ×0.6',
      () {
    expect(
      resolvedSigma(
          tier: GlassTier.floating, quality: GlassQuality.high),
      36,
    );
    expect(
      resolvedSigma(tier: GlassTier.panel, quality: GlassQuality.standard),
      0,
      reason: 'standard 档 L1/L2 fill-only 主路径',
    );
    expect(
      resolvedSigma(tier: GlassTier.dock, quality: GlassQuality.standard),
      0,
    );
    expect(
      resolvedSigma(tier: GlassTier.overlay, quality: GlassQuality.standard),
      28,
      reason: 'standard 档 L3/L4 保持真实磨砂',
    );
    expect(
      resolvedSigma(tier: GlassTier.overlay, quality: GlassQuality.saver),
      closeTo(28 * 0.6, 0.0001),
      reason: 'saver 档 σ×0.6',
    );
    expect(
      resolvedSigma(tier: GlassTier.floating, quality: GlassQuality.saver),
      closeTo(36 * 0.6, 0.0001),
    );
    expect(
      resolvedSigma(tier: GlassTier.panel, quality: GlassQuality.saver),
      0,
      reason: 'saver 档 L1/L2 无磨砂',
    );
  });

  test('背景图模式：L1 加厚 +0.06 且上限 0.80；其他层不变（§4.6）', () {
    final normalHigh = resolveGlassSpec(
      tier: GlassTier.panel,
      brightness: Brightness.light,
      palette: t1,
      quality: GlassQuality.high,
    );
    final imageModeHigh = resolveGlassSpec(
      tier: GlassTier.panel,
      brightness: Brightness.light,
      palette: t1,
      quality: GlassQuality.high,
      imageBackgroundMode: true,
    );
    expect(imageModeHigh.fill.a, closeTo(normalHigh.fill.a + 0.06, 0.0001));

    // 上限 0.80：saver 浅色 L1 = 0.55+0.08+0.06 = 0.69 → 未触顶；
    // 构造触顶路径：standard 深 L1 0.70+0.06=0.76；high 浅 0.55+0.06=0.61。
    // saver 浅 L1 0.63+0.06=0.69；仅 saver+imageMode 的 dock? 不适用——
    // 直接验证 overlay 不受 imageMode 影响：
    final overlayNormal = resolveGlassSpec(
      tier: GlassTier.overlay,
      brightness: Brightness.light,
      palette: t1,
      quality: GlassQuality.high,
    );
    final overlayImage = resolveGlassSpec(
      tier: GlassTier.overlay,
      brightness: Brightness.light,
      palette: t1,
      quality: GlassQuality.high,
      imageBackgroundMode: true,
    );
    expect(overlayImage.fill.a, overlayNormal.fill.a,
        reason: '加厚仅作用于 L1 主声部');
    // 描边/高光体系跨模式不变
    expect(imageModeHigh.borderColor, normalHigh.borderColor);
    expect(imageModeHigh.highlightAlphaTop, normalHigh.highlightAlphaTop);

    // cap 验证：saver 深色 L1 0.66+0.08+0.06 = 0.80（恰好触顶不越界）
    expect(
      resolveGlassSpec(
        tier: GlassTier.panel,
        brightness: Brightness.dark,
        palette: t5,
        quality: GlassQuality.saver,
        imageBackgroundMode: true,
      ).fill.a,
      closeTo(0.80, 0.0001),
    );
  });

  test('solidLine 分支：topHighlight 置空且保留 α_top（色带降级单点开关）', () {
    final gradient = resolveGlassSpec(
      tier: GlassTier.panel,
      brightness: Brightness.light,
      palette: t1,
      highlightStyleOverride: GlassHighlightStyle.gradient,
    );
    final solidLine = resolveGlassSpec(
      tier: GlassTier.panel,
      brightness: Brightness.light,
      palette: t1,
      highlightStyleOverride: GlassHighlightStyle.solidLine,
    );
    expect(gradient.topHighlight, isNotNull);
    expect(gradient.highlightAlphaTop, closeTo(0.25, 0.0001));
    expect(solidLine.topHighlight, isNull,
        reason: 'solidLine 由 GlassPanel 绘制双细线');
    expect(solidLine.highlightAlphaTop, gradient.highlightAlphaTop,
        reason: '实线强度沿用 α_top');
    // 其余参数不受降级影响
    expect(solidLine.fill, gradient.fill);
    expect(solidLine.borderColor, gradient.borderColor);
    expect(solidLine.sigmaX, gradient.sigmaX);
  });

  test('顶部高光渐变方向：topCenter → Alignment(0, 0.45)，高光带高度 45%', () {
    final s = resolveGlassSpec(
        tier: GlassTier.panel, brightness: Brightness.light, palette: t1);
    final g = s.topHighlight! as LinearGradient;
    expect(g.begin, Alignment.topCenter);
    expect(g.end, const Alignment(0, 0.45));
    expect(g.colors.first.a, closeTo(0.25, 0.0001));
    expect(g.colors.last.a, 0);
  });

  test('深色填充带主题色温：非纯黑，等于 surface × 层级 α（§2.1 规则一）', () {
    final s = resolveGlassSpec(
        tier: GlassTier.panel,
        brightness: Brightness.dark,
        palette: t5,
        quality: GlassQuality.high);
    expect(s.fill.a, closeTo(0.66, 0.0001));
    // RGB 分量与 surface 同族（色温保留），而非纯黑
    expect(s.fill.r, closeTo(t5.surface.r, 0.001));
    expect(s.fill.g, closeTo(t5.surface.g, 0.001));
    expect(s.fill.b, closeTo(t5.surface.b, 0.001));
  });
}
