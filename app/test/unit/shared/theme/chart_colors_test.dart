import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/chart_colors.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

void main() {
  test('GLS-007 锁定测试：分类色序列由 palette.ambient + semantic 派生（8 色）',
      () {
    for (final preset in kThemePresetsV2) {
      final theme = buildTheme(preset);
      final palette = preset.palette;
      final semantic = theme.extension<AppColors>()!;
      final expected =
          chartSeriesColorsFromPalette(palette, semantic);
      // 派生确定性：同输入同输出（防裸 hex 漂移）
      expect(chartSeriesColorsFromPalette(palette, semantic), expected,
          reason: '${preset.id} 派生确定性');
      expect(expected, hasLength(8), reason: '${preset.id} 序列长度');
      // 语义锚定位不随主题漂移
      expect(expected[0], palette.primary, reason: '${preset.id} 主色锚定');
      expect(expected[1], palette.secondary);
      expect(expected[2], semantic.income);
      expect(expected[3], semantic.warning);
      expect(expected[4], semantic.expense);
      // 序列可辨性：至少 7 色互异。已知遗留锚点：深色主题 secondary 与
      // AppColors.dark.income 同值（如 T7 #81C784），属 v2 锁定语义色的
      // 历史碰撞，不在 v3 范围内改动预设
      final distinct = expected.map((c) => c.toARGB32()).toSet();
      expect(distinct.length, greaterThanOrEqualTo(7),
          reason: '${preset.id} 分类色可辨性');
    }
  });

  test('GLS-007：环境光第 4 色参与派生（右上光斑 → 预警过渡）', () {
    final t1 = findPresetById('t1')!.palette;
    final s = AppColors.light;
    final colors = chartSeriesColorsFromPalette(t1, s);
    final manual = Color.lerp(t1.ambient[3], s.warning, 0.50)!;
    expect(colors[7].toARGB32(), manual.toARGB32());
    // ambient 变化应影响派生序列（光环境同源语义）
    final shifted = ThemePalette(
      brightness: Brightness.light,
      primary: t1.primary,
      onPrimary: t1.onPrimary,
      primaryContainer: t1.primaryContainer,
      secondary: t1.secondary,
      background: t1.background,
      surface: t1.surface,
      surfaceVariant: t1.surfaceVariant,
      scrim: t1.scrim,
      textPrimary: t1.textPrimary,
      textSecondary: t1.textSecondary,
      textDisabled: t1.textDisabled,
      border: t1.border,
      divider: t1.divider,
      ambient: [t1.ambient[2], t1.ambient[1], t1.ambient[0], t1.ambient[3]],
    );
    final shiftedColors = chartSeriesColorsFromPalette(shifted, s);
    expect(shiftedColors[5].toARGB32(), isNot(colors[5].toARGB32()),
        reason: '光斑顺序变化应传导到派生序列');
  });
}
