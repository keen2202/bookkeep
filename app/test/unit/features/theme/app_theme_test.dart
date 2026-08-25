import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass_tokens.dart';
import 'package:bookkeep_app/shared/theme/tokens.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

void main() {
  // 自定义种子色模式：浅/深双槽位
  ThemeData buildCustom(Brightness brightness, [Color? seed]) => buildTheme(
        null,
        customSeed: seed ?? kDefaultSeedColor,
        customMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
      );

  test('深浅主题同源构建且携带语义色扩展', () {
    final light = buildCustom(Brightness.light);
    final dark = buildCustom(Brightness.dark);

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    final lightExt = light.extension<AppColors>()!;
    final darkExt = dark.extension<AppColors>()!;
    expect(lightExt.income, AppColors.light.income);
    expect(lightExt.expense, AppColors.light.expense);
    expect(darkExt.income, AppColors.dark.income);
    expect(darkExt.accent, dark.colorScheme.primary);
  });

  test('个性化主题：种子色改变主色与 accent，语义色不变', () {
    final teal = buildCustom(Brightness.light);
    final violet =
        buildCustom(Brightness.light, const Color(0xFF8E24AA));

    expect(violet.colorScheme.primary, isNot(teal.colorScheme.primary));
    expect(violet.extension<AppColors>()!.accent, violet.colorScheme.primary);
    expect(violet.extension<AppColors>()!.income, teal.extension<AppColors>()!.income);
    expect(violet.extension<AppColors>()!.expense, teal.extension<AppColors>()!.expense);
  });

  test('审查 U-8 延续：语义色对界面底色对比度达 WCAG AA', () {
    double contrast(Color a, Color b) {
      double luminance(Color c) {
        double channel(double v) => v <= 0.03928
            ? v / 12.92
            : pow((v + 0.055) / 1.055, 2.4).toDouble();
        final r = channel(c.r), g = channel(c.g), b = channel(c.b);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }

      final l1 = luminance(a), l2 = luminance(b);
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    final light = AppColors.light;
    final dark = AppColors.dark;
    for (final color in [light.income, light.expense, light.warning]) {
      expect(contrast(color, Colors.white), greaterThanOrEqualTo(4.5),
          reason: '浅色态 $color 对白底对比度不足');
    }
    for (final color in [dark.income, dark.expense, dark.warning]) {
      expect(contrast(color, const Color(0xFF000000)), greaterThanOrEqualTo(4.5),
          reason: '深色态 $color 对纯黑底对比度不足');
    }
  });

  // ── 预制主题直出（BK-FG-032 收敛版）──

  test('预制主题：8 套直出且调色板全量落地 ColorScheme', () {
    expect(kThemePresetsV2, hasLength(8));
    expect(findPresetById('t1'), isNotNull);
    expect(findPresetById('t9'), isNull);

    for (final preset in kThemePresetsV2) {
      final theme = buildTheme(preset);
      expect(theme.brightness, preset.brightness, reason: '${preset.id} 明暗');
      expect(theme.colorScheme.primary, preset.palette.primary);
      expect(theme.colorScheme.onPrimary, preset.palette.onPrimary);
      expect(theme.colorScheme.surface, preset.palette.surface);
      expect(theme.colorScheme.onSurface, preset.palette.textPrimary);
      final semantic = theme.extension<AppColors>()!;
      expect(semantic.income,
          preset.isDark ? AppColors.dark.income : AppColors.light.income);
      final tokens = theme.extension<AppTokens>()!;
      expect(tokens.palette.primary, preset.palette.primary);
      expect(tokens.amountStyle.fontFeatures, isNotEmpty);
    }
  });

  test('BK-FG-002：全部预设背景收敛为 §2.2 白名单唯二底色', () {
    for (final preset in kThemePresetsV2) {
      expect(preset.palette.background,
          preset.isDark ? GlassBackground.baseDark : GlassBackground.baseLight,
          reason: '${preset.id} 背景必须为白名单底色');
      // 文字四档同样全预设统一（§5）
      expect(preset.palette.textPrimary,
          GlassTextColors.primary(preset.brightness),
          reason: '${preset.id} 主文字取自 §5');
      expect(preset.palette.textSecondary,
          GlassTextColors.secondary(preset.brightness),
          reason: '${preset.id} 次级文字取自 §5');
    }
  });

  test('BK-FG-032：预设差异仅剩「主题色 + 背景明暗」——玻璃参数全预设一致', () {
    final lights = kThemePresetsV2.where((p) => !p.isDark).toList();
    final darks = kThemePresetsV2.where((p) => p.isDark).toList();
    for (final group in [lights, darks]) {
      final head = group.first.palette;
      for (final p in group.map((e) => e.palette)) {
        expect(p.background, head.background, reason: '背景统一');
        expect(p.surface, head.surface, reason: '表面统一');
        expect(p.textPrimary, head.textPrimary, reason: '主文字统一');
        expect(p.textSecondary, head.textSecondary, reason: '次级文字统一');
        expect(p.textTertiary, head.textTertiary, reason: '三级文字统一');
        expect(p.textDisabled, head.textDisabled, reason: '禁用文字统一');
        expect(p.border, head.border, reason: '发丝线统一');
        expect(p.divider, head.divider, reason: '分隔线统一');
      }
    }
    // 同组内主题色两两互异（保留品牌识别）
    for (final group in [lights, darks]) {
      final primaries =
          group.map((p) => p.palette.primary.toARGB32()).toSet();
      expect(primaries.length, group.length,
          reason: '同明暗组内主题色应互异');
    }
  });

  test('FGDS 组件主题：Scaffold 底色=白名单底色；弹层/菜单=G4 填充', () {
    for (final id in ['t1', 't5']) {
      final preset = findPresetById(id)!;
      final theme = buildTheme(preset);
      expect(theme.scaffoldBackgroundColor,
          preset.isDark ? GlassBackground.baseDark : GlassBackground.baseLight,
          reason: '$id 页面底色为纯净底色');
      final g4Fill =
          resolveGlassSpec(level: GlassLevel.g4, brightness: preset.brightness).fill;
      expect(theme.bottomSheetTheme.backgroundColor, g4Fill,
          reason: '$id 弹层为 G4 填充');
      expect(theme.dialogTheme.backgroundColor, g4Fill, reason: '$id 对话框 G4');
      expect(theme.popupMenuTheme.color, g4Fill, reason: '$id 下拉菜单 G4');
      expect(theme.bottomSheetTheme.modalBarrierColor,
          GlassBackground.scrimOf(Colors.black),
          reason: '$id 遮罩 α0.32（Spec §2.3）');
    }
  });

  test('FGDS 组件主题：输入框 G2 降档填充 + 卡片 R16 + SnackBar 胶囊', () {
    for (final dark in [false, true]) {
      final preset = findPresetById(dark ? 't5' : 't1')!;
      final theme = buildTheme(preset);
      // 输入框降档填充（Spec §4.8）
      expect(theme.inputDecorationTheme.fillColor,
          Colors.white.withValues(alpha: dark ? 0.10 : 0.45));
      // 卡片 R16（G2 圆角，Spec §3）
      expect(
          (theme.cardTheme.shape! as RoundedRectangleBorder)
              .borderRadius
              .resolve(null),
          BorderRadius.circular(AppRadius.card));
      expect(theme.cardTheme.clipBehavior, Clip.antiAlias);
      // SnackBar 胶囊形态（G5，Spec §4.7）
      expect(
          (theme.snackBarTheme.shape! as RoundedRectangleBorder)
              .borderRadius
              .resolve(null),
          BorderRadius.circular(AppRadius.pill));
    }
  });

  test('FGDS 组件主题：聚焦/错误环参数来自 §4.8 Token', () {
    final theme = buildTheme(findPresetById('t1')!);
    final input = theme.inputDecorationTheme;
    expect(input.focusedBorder!.borderSide.width, GlassButtonTokens.focusRingWidth);
    expect(
        input.focusedBorder!.borderSide.color,
        findPresetById('t1')!.palette.primary
            .withValues(alpha: GlassButtonTokens.focusRingAlpha));
  });

  test('调色板 lerp：颜色随主题过渡插值，无玻璃字段残留', () {
    final a = findPresetById('t1')!.palette;
    final b = findPresetById('t6')!.palette;
    final mid = a.lerp(b, 0.5);
    expect(mid.primary, Color.lerp(a.primary, b.primary, 0.5)!);
    expect(mid.textPrimary, isNotNull);
  });
}
