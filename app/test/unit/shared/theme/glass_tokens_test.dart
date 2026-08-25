import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/glass_tokens.dart';

void main() {
  // ── Spec §3 层级参数表逐项锁定（BK-FG-001 唯一参数源）──

  test('blur 表：σ ∈ {12,20,28,36,44} 且沿 G1→G5 严格递增（AC-01）', () {
    final blurs = GlassLevel.values.map((l) => l.blur).toList();
    expect(blurs, [12, 20, 28, 36, 44]);
    for (var i = 0; i < blurs.length - 1; i++) {
      expect(blurs[i + 1], greaterThan(blurs[i]), reason: 'σ 单调递增');
    }
  });

  test('fill α 表：浅色 {0.55,0.60,0.72,0.80,0.85} / 深色 {0.10,0.12,0.18,0.24,0.30}', () {
    expect(GlassLevel.values.map((l) => l.fillAlphaLight).toList(),
        [0.55, 0.60, 0.72, 0.80, 0.85]);
    expect(GlassLevel.values.map((l) => l.fillAlphaDark).toList(),
        [0.10, 0.12, 0.18, 0.24, 0.30]);
    for (var i = 0; i < 4; i++) {
      expect(GlassLevel.values[i + 1].fillAlphaLight,
          greaterThan(GlassLevel.values[i].fillAlphaLight));
      expect(GlassLevel.values[i + 1].fillAlphaDark,
          greaterThan(GlassLevel.values[i].fillAlphaDark));
    }
  });

  test('双层描边表：外深内高光 α 与层级表一致', () {
    final outerL = GlassLevel.values.map((l) => l.borderOuterAlphaLight).toList();
    final outerD = GlassLevel.values.map((l) => l.borderOuterAlphaDark).toList();
    expect(outerL, [0.06, 0.06, 0.08, 0.10, 0.10]);
    expect(outerD, [0.30, 0.30, 0.35, 0.40, 0.40]);

    final innerL = GlassLevel.values.map((l) => l.highlightInnerAlphaLight).toList();
    final innerD = GlassLevel.values.map((l) => l.highlightInnerAlphaDark).toList();
    expect(innerL, [0.35, 0.35, 0.40, 0.45, 0.50]);
    expect(innerD, [0.12, 0.12, 0.14, 0.16, 0.18]);
  });

  test('环境投影表：x/y/blur/alpha 逐层对齐，spread 恒 0', () {
    BoxShadow spec(GlassLevel level) =>
        level.shadowFor(const Color(0xFF000000));
    expect(spec(GlassLevel.g1).offset, const Offset(0, 2));
    expect(spec(GlassLevel.g1).blurRadius, 8);
    expect(spec(GlassLevel.g1).color.a, closeTo(0.04, 0.0001));

    expect(spec(GlassLevel.g2).offset, const Offset(0, 4));
    expect(spec(GlassLevel.g2).blurRadius, 16);
    expect(spec(GlassLevel.g2).color.a, closeTo(0.06, 0.0001));

    expect(spec(GlassLevel.g3).offset, const Offset(0, 6));
    expect(spec(GlassLevel.g3).blurRadius, 20);
    expect(spec(GlassLevel.g3).color.a, closeTo(0.08, 0.0001));

    expect(spec(GlassLevel.g4).offset, const Offset(0, 12));
    expect(spec(GlassLevel.g4).blurRadius, 32);
    expect(spec(GlassLevel.g4).color.a, closeTo(0.12, 0.0001));

    expect(spec(GlassLevel.g5).offset, const Offset(0, 8));
    expect(spec(GlassLevel.g5).blurRadius, 24);
    expect(spec(GlassLevel.g5).color.a, closeTo(0.10, 0.0001));
  });

  test('resolveGlassSpec：填充白基、描边黑/白基色与模式分流正确', () {
    for (final level in GlassLevel.values) {
      final light = resolveGlassSpec(level: level, brightness: Brightness.light);
      final dark = resolveGlassSpec(level: level, brightness: Brightness.dark);
      // 填充 = #FFFFFF × 层 α
      expect(light.fill, Colors.white.withValues(alpha: level.fillAlphaLight));
      expect(dark.fill, Colors.white.withValues(alpha: level.fillAlphaDark));
      // 外侧勾边 #000 / 内侧高光 #FFF
      expect(
          light.borderOuter, Colors.black.withValues(alpha: level.borderOuterAlphaLight));
      expect(dark.borderInnerHighlight,
          Colors.white.withValues(alpha: level.highlightInnerAlphaDark));
      // 顶部内高光：浅 0.20→0 / 深 0.08→0；覆盖高度 40%
      expect(light.topHighlightAlpha, 0.20);
      expect(dark.topHighlightAlpha, 0.08);
      expect(light.topHighlightCoverage, 0.40);
      // blurEnabled=false：跳过模糊 + fill +0.10 补偿
      final degraded =
          resolveGlassSpec(level: level, brightness: Brightness.light, blurEnabled: false);
      expect(degraded.fill.a,
          closeTo((level.fillAlphaLight + kBlurDegradeFillCompensation).clamp(0.0, 1.0), 0.0001));
    }
  });

  test('嵌套升档规则：G2 宿主的内层取 G3 填充值且强制零模糊', () {
    expect(nestedFillLevel(GlassLevel.g2), GlassLevel.g3);
    final host = resolveGlassSpec(level: GlassLevel.g2, brightness: Brightness.light);
    // 结构性 fill-only（嵌套层）：不加降级补偿，严格取层级表填充值
    final inner = resolveGlassSpec(
        level: nestedFillLevel(GlassLevel.g2),
        brightness: Brightness.light,
        blurEnabled: false,
        degradeCompensation: false);
    expect(inner.blurEnabled, isFalse, reason: '内层不新增 BackdropFilter');
    expect(inner.fill.a, closeTo(GlassLevel.g3.fillAlphaLight, 0.0001),
        reason: '内层用下一档填充值');
    expect(inner.fill.a, greaterThan(host.fill.a));
    // 对照：用户降级路径才叠加 +0.10 补偿
    final degraded =
        resolveGlassSpec(level: GlassLevel.g2, brightness: Brightness.light, blurEnabled: false);
    expect(degraded.fill.a,
        closeTo(GlassLevel.g2.fillAlphaLight + kBlurDegradeFillCompensation, 0.0001));
  });

  test('背景/遮罩/主题色 Token：§2.1–§2.3 定值', () {
    expect(GlassBackground.baseLight, const Color(0xFFF2F2F7));
    expect(GlassBackground.baseDark, const Color(0xFF000000));
    // 遮罩 #000 α0.32
    expect(GlassBackground.scrimOf(Colors.black).a, closeTo(0.32, 0.0001));
    expect(GlassBackground.scrimOf(Colors.black),
        Colors.black.withValues(alpha: 0.32));
    // 主色浅 #0A84FF / 深 #409CFF；onPrimary 白
    expect(GlassThemeColors.primaryLight, const Color(0xFF0A84FF));
    expect(GlassThemeColors.primaryDark, const Color(0xFF409CFF));
    expect(GlassThemeColors.onPrimary, const Color(0xFFFFFFFF));
    // danger/success 双值
    expect(GlassThemeColors.dangerLight, const Color(0xFFFF3B30));
    expect(GlassThemeColors.dangerDark, const Color(0xFFFF453A));
    expect(GlassThemeColors.successLight, const Color(0xFF34C759));
    expect(GlassThemeColors.successDark, const Color(0xFF30D158));
  });

  test('文字四档：§5 取值与 alpha 分流', () {
    expect(GlassTextColors.primary(Brightness.light), const Color(0xFF1C1C1E));
    expect(GlassTextColors.primary(Brightness.dark), Colors.white);
    expect(GlassTextColors.secondary(Brightness.light).a, closeTo(0.60, 0.0001));
    expect(GlassTextColors.tertiary(Brightness.dark).a, closeTo(0.36, 0.0001));
    expect(GlassTextColors.disabled(Brightness.light).a, closeTo(0.24, 0.0001));
  });

  test('FG-BTN 状态矩阵：blur σ 与 fill α 定值（Spec §4.4）', () {
    expect(GlassButtonTokens.blurDefault, 20);
    expect(GlassButtonTokens.blurHover, 24);
    expect(GlassButtonTokens.blurPressed, 16);
    expect(GlassButtonTokens.blurDisabled, 8);
    expect(GlassButtonTokens.fillHoverLight, 0.68);
    expect(GlassButtonTokens.fillPressedLight, 0.48);
    expect(GlassButtonTokens.fillDisabledLight, 0.32);
    expect(GlassButtonTokens.primaryFillLight, 0.75);
    expect(GlassButtonTokens.primaryFillDark, 0.65);
    expect(GlassButtonTokens.heightStandard, 44);
    expect(GlassButtonTokens.heightCompact, 32);
  });

  test('FG-SEL 四层定值（Spec §4.2）', () {
    expect(GlassSelectionTokens.brightenFillLight, 0.72);
    expect(GlassSelectionTokens.brightenFillDark, 0.18);
    expect(GlassSelectionTokens.glowAlpha, 0.25);
    expect(GlassSelectionTokens.glowBlur, 20);
    expect(GlassSelectionTokens.overlayTopLight, 0.12);
    expect(GlassSelectionTokens.overlayBottomLight, 0.06);
    expect(GlassSelectionTokens.overlayTopDark, 0.10);
    expect(GlassSelectionTokens.overlayBottomDark, 0.05);
    expect(GlassSelectionTokens.outerEdgeAlphaLight, 0.30);
    expect(GlassSelectionTokens.outerEdgeAlphaDark, 0.35);
  });

  test('FG-TBL 斑马纹与分隔线定值（Spec §4.3）：奇偶差固定 0.15/0.04', () {
    expect(GlassTableTokens.zebraOddFillLight - GlassTableTokens.zebraEvenFillLight,
        closeTo(0.15, 0.0001));
    expect(GlassTableTokens.zebraOddFillDark - GlassTableTokens.zebraEvenFillDark,
        closeTo(0.04, 0.0001));
    expect(GlassTableTokens.hoverDeltaLight, 0.10);
    expect(GlassTableTokens.hoverDeltaDark, 0.04);
    expect(GlassTableTokens.rowDividerAlphaLight, 0.05);
    expect(GlassTableTokens.rowDividerAlphaDark, 0.06);
    expect(GlassTableTokens.headerDividerAlphaLight, 0.06);
    expect(GlassTableTokens.headerDividerAlphaDark, 0.08);
  });

  test('WCAG 合成公式：与 Spec §7.1 合成底色一致', () {
    // 浅色 G2：white@0.60 over #F2F2F7 ≈ #FAFAFC
    final panel = glassComposite(
      Colors.white.withValues(alpha: GlassLevel.g2.fillAlphaLight),
      const Color(0xFFF2F2F7),
    );
    expect(panel.toARGB32(), const Color(0xFFFAFAFC).toARGB32());
    // 深色 G5：white@0.30 over black = #4D4D4D
    final darkPanel = glassComposite(
      Colors.white.withValues(alpha: GlassLevel.g5.fillAlphaDark),
      const Color(0xFF000000),
    );
    expect(darkPanel.toARGB32(), const Color(0xFF4D4D4D).toARGB32());
    // 主文字对比度 > 4.5（AC-03 主判定）
    expect(
        glassContrastRatio(
            const Color(0xFF1C1C1E), const Color(0xFFFAFAFC)),
        greaterThanOrEqualTo(4.5));
  });
}
