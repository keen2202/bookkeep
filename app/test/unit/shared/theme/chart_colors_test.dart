import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/chart_colors.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

void main() {
  test('FGDS 锁定测试：分类色序列由「主色系 + 语义色」派生（8 色）', () {
    for (final preset in kThemePresetsV2) {
      final theme = buildTheme(preset);
      final palette = preset.palette;
      final semantic = theme.extension<AppColors>()!;
      final expected = chartSeriesColorsFromPalette(palette, semantic);
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
    }
  });

  test('派生插值位：容器色/次色向语义色收敛（替代旧 ambient 光斑源）', () {
    final t1 = findPresetById('t1')!.palette;
    final s = AppColors.light;
    final colors = chartSeriesColorsFromPalette(t1, s);
    expect(colors[5].toARGB32(),
        Color.lerp(t1.primaryContainer, t1.primary, 0.45)!.toARGB32());
    expect(colors[6].toARGB32(),
        Color.lerp(t1.secondary, t1.primary, 0.40)!.toARGB32());
    expect(colors[7].toARGB32(),
        Color.lerp(t1.primaryContainer, s.warning, 0.50)!.toARGB32());
    // 主色变化应传导到派生序列（同源语义）
    final shiftedPalette = ThemePalette(
      brightness: Brightness.light,
      primary: const Color(0xFF8E24AA),
      onPrimary: t1.onPrimary,
      primaryContainer: t1.primaryContainer,
      secondary: t1.secondary,
      background: t1.background,
      surface: t1.surface,
      surfaceVariant: t1.surfaceVariant,
      scrim: t1.scrim,
      textPrimary: t1.textPrimary,
      textSecondary: t1.textSecondary,
      textTertiary: t1.textTertiary,
      textDisabled: t1.textDisabled,
      border: t1.border,
      divider: t1.divider,
    );
    final shifted =
        chartSeriesColorsFromPalette(shiftedPalette, AppColors.light);
    expect(shifted[0].toARGB32(), isNot(colors[0].toARGB32()),
        reason: '主题色变化应传导到派生序列');
  });
}
