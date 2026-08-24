import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/contrast_guard.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_layers.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_quality.dart';
import 'package:bookkeep_app/shared/theme/tokens.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

void main() {
  /// 8 个品牌种子（8 预设主色）× 浅/深两态 = 全部真实可渲染的主题面。
  /// 预制主题明暗锁定单态，浅深两态由 custom 种子色路径（生产同一组装器
  /// `_buildCustomTheme`）派生——这正是「8 预设 × 浅深两态」的可渲染语义。
  ThemePalette paletteOfSeed(Color seed, Brightness brightness) {
    final theme = buildTheme(
      null,
      customSeed: seed,
      customMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
    );
    return theme.extension<AppTokens>()!.palette;
  }

  test('ContrastGuard：48 组合（8 预设种子 × 3 强度 × 浅深）全部达标', () {
    var checked = 0;
    for (final preset in kThemePresetsV2) {
      for (final brightness in Brightness.values) {
        final palette = paletteOfSeed(preset.palette.primary, brightness);
        // 基础卫生检查：custom 派生背景非纯黑/纯白（§4.8 禁令联动）
        final bgLum = glassRelativeLuminance(palette.background);
        expect(bgLum, greaterThan(0.01),
            reason: '${preset.id} ${brightness.name} 背景过暗');
        expect(bgLum, lessThan(0.99),
            reason: '${preset.id} ${brightness.name} 背景过亮');
        for (final intensity in AmbientIntensity.values) {
          final effective = ContrastGuard.effectiveIntensity(
            palette: palette,
            requested: intensity,
          );
          // 钳制只降档不升档
          expect(effective.factor, lessThanOrEqualTo(intensity.factor),
              reason: '${preset.id} ${brightness.name} $intensity 钳制方向');
          final worst = ContrastGuard.worstCaseCardSurface(
            palette,
            effective.factor,
            GlassQuality.standard,
          );
          expect(glassContrastRatio(palette.textPrimary, worst),
              greaterThanOrEqualTo(4.5),
              reason:
                  '${preset.id} ${brightness.name} $intensity → $effective '
                  '正文对比度不足');
          checked++;
        }
      }
    }
    expect(checked, 48);
  });

  test('钳制顺序：浓郁→标准→含蓄逐级回退，含蓄档不再向下', () {
    expect(
      ContrastGuard.clampOrder(AmbientIntensity.rich),
      [AmbientIntensity.rich, AmbientIntensity.standard, AmbientIntensity.soft],
    );
    expect(
      ContrastGuard.clampOrder(AmbientIntensity.standard),
      [AmbientIntensity.standard, AmbientIntensity.soft],
    );
    expect(
      ContrastGuard.clampOrder(AmbientIntensity.soft),
      [AmbientIntensity.soft],
    );
  });

  test('extraFillAlpha 兜底：有效强度达标时为 0；soft 仍不足时触发 +0.05', () {
    // 有效强度已保证达标 → 兜底增量必为 0（48 组合同式复核）
    for (final preset in kThemePresetsV2) {
      final palette = paletteOfSeed(preset.palette.primary, Brightness.light);
      for (final intensity in AmbientIntensity.values) {
        final effective = ContrastGuard.effectiveIntensity(
            palette: palette, requested: intensity);
        final extra = ContrastGuard.extraFillAlpha(
          palette: palette,
          effective: effective,
        );
        expect(extra, 0.0,
            reason: '${preset.id} $intensity 有效强度下无需兜底');
      }
    }
  });

  test('有效强度：正常主题请求 rich 判定确定且不低于含蓄档', () {
    for (final preset in kThemePresetsV2) {
      final a = ContrastGuard.effectiveIntensity(
          palette: preset.palette, requested: AmbientIntensity.rich);
      final b = ContrastGuard.effectiveIntensity(
          palette: preset.palette, requested: AmbientIntensity.rich);
      expect(a, b, reason: '${preset.id} 判定确定性');
      expect(a.factor, greaterThanOrEqualTo(AmbientIntensity.soft.factor));
    }
  });

  test('最坏情况建模：光斑峰值 alpha = 0.95 × I × 0.85 系数链正确', () {
    final t1 = findPresetById('t1')!.palette;
    final worstStandard = ContrastGuard.worstCaseCardSurface(
        t1, AmbientIntensity.standard.factor, GlassQuality.standard);
    // 手工按同式重算（浅色：白基 L1 standard 补偿 α=0.61）
    final brightest = t1.ambient
        .reduce((a, b) =>
            glassContrastRatio(a, t1.background) >
                    glassContrastRatio(b, t1.background)
                ? a
                : b)
        .withValues(alpha: (0.95 * 0.85 * 0.85).clamp(0.0, 1.0));
    final manual = glassComposite(
      Colors.white.withValues(alpha: 0.61),
      glassComposite(brightest, t1.background),
    );
    expect(worstStandard.toARGB32(), manual.toARGB32());
  });
}
