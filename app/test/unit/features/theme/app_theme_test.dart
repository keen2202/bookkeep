import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/theme/theme_settings.dart';
import 'package:bookkeep_app/shared/theme/tokens.dart';

void main() {
  // 自定义种子色模式（旧 fromSeed 路径，Spec D3）：浅/深双槽位
  ThemeData buildCustom(Brightness brightness, [Color? seed]) => buildTheme(
        null,
        customSeed: seed ?? kDefaultSeedColor,
        customMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
      );

  test('审查 U-2：深浅主题同源构建且携带语义色扩展', () {
    final light = buildCustom(Brightness.light);
    final dark = buildCustom(Brightness.dark);

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    // 红绿语义色保持静态，accent 跟随种子色（M3 tonal 主色）
    final lightExt = light.extension<AppColors>()!;
    final darkExt = dark.extension<AppColors>()!;
    expect(lightExt.income, AppColors.light.income);
    expect(lightExt.expense, AppColors.light.expense);
    expect(lightExt.warning, AppColors.light.warning);
    expect(lightExt.accent, light.colorScheme.primary);
    expect(darkExt.income, AppColors.dark.income);
    expect(darkExt.expense, AppColors.dark.expense);
    expect(darkExt.warning, AppColors.dark.warning);
    expect(darkExt.accent, dark.colorScheme.primary);
  });

  test('个性化主题：种子色改变主色与 accent，红绿语义不变', () {
    final teal = buildCustom(Brightness.light);
    final violet =
        buildCustom(Brightness.light, const Color(0xFF8E24AA));

    expect(violet.colorScheme.primary, isNot(teal.colorScheme.primary));
    expect(violet.extension<AppColors>()!.accent, violet.colorScheme.primary);
    expect(violet.extension<AppColors>()!.income, teal.extension<AppColors>()!.income);
    expect(violet.extension<AppColors>()!.expense, teal.extension<AppColors>()!.expense);
  });

  test('审查 U-8：语义色深浅两套对比度达 WCAG 4.5:1（正文场景）', () {
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
    final lightSurface = Colors.white;
    final darkSurface = const Color(0xFF121212);

    for (final color in [light.income, light.expense, light.warning, light.accent]) {
      expect(contrast(color, lightSurface), greaterThanOrEqualTo(4.5),
          reason: '浅色态 $color 对白底对比度不足');
    }
    for (final color in [dark.income, dark.expense, dark.warning, dark.accent]) {
      expect(contrast(color, darkSurface), greaterThanOrEqualTo(4.5),
          reason: '深色态 $color 对深底对比度不足');
    }
  });

  test('个性化主题：动态 accent（M3 主色）对界面底色对比度达标', () {
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

    for (final seed in kThemePresets) {
      final light = buildCustom(Brightness.light, seed);
      final dark = buildCustom(Brightness.dark, seed);
      expect(contrast(light.colorScheme.primary, Colors.white), greaterThanOrEqualTo(4.5),
          reason: '浅色态种子 $seed 主色对白底对比度不足');
      expect(
          contrast(dark.colorScheme.primary, const Color(0xFF121212)),
          greaterThanOrEqualTo(4.5),
          reason: '深色态种子 $seed 主色对深底对比度不足');
    }
  });

  test('系统栏样式随亮度联动', () {
    final light = buildCustom(Brightness.light);
    final dark = buildCustom(Brightness.dark);
    // BK-UI-014：静态 systemOverlayStyle 已从 AppBarTheme 移除，
    // 状态栏图标明暗改由 AppBackground 按主题明暗/遮罩有效亮度动态计算
    expect(light.appBarTheme.systemOverlayStyle, isNull);
    expect(dark.appBarTheme.systemOverlayStyle, isNull);
  });

  // ── UI 重构（BK-UI-002）：预制主题直出 ──

  test('预制主题：8 套直出且调色板全量落地 ColorScheme', () {
    expect(kThemePresetsV2, hasLength(8));
    expect(findPresetById('t1'), isNotNull);
    expect(findPresetById('t9'), isNull);

    for (final preset in kThemePresetsV2) {
      final theme = buildTheme(preset);
      expect(theme.brightness, preset.brightness, reason: '${preset.id} 明暗');
      // ColorScheme 显式构造（Spec §4.1，不再 fromSeed 派生）
      expect(theme.colorScheme.primary, preset.palette.primary);
      expect(theme.colorScheme.onPrimary, preset.palette.onPrimary);
      expect(theme.colorScheme.surface, preset.palette.surface);
      expect(theme.colorScheme.onSurface, preset.palette.textPrimary);
      expect(theme.colorScheme.outline, preset.palette.border);
      // 语义色扩展锁定
      final semantic = theme.extension<AppColors>()!;
      expect(semantic.income,
          preset.isDark ? AppColors.dark.income : AppColors.light.income);
      // Token 扩展携带调色板与字阶
      final tokens = theme.extension<AppTokens>()!;
      expect(tokens.palette.primary, preset.palette.primary);
      expect(tokens.palette.textPrimary, preset.palette.textPrimary);
      expect(tokens.palette.surface, preset.palette.surface);
      expect(tokens.amountStyle.fontFeatures, isNotEmpty);
    }
  });

  test('预制主题：浅色卡片阴影 / 深色卡片描边（设计文档 §3.3）', () {
    final light = buildTheme(findPresetById('t1')!);
    final dark = buildTheme(findPresetById('t5')!);
    expect(light.cardTheme.elevation, 2);
    expect(dark.cardTheme.elevation, 0);
    expect((dark.cardTheme.shape! as RoundedRectangleBorder).side,
        isNot(BorderSide.none));
  });

  // ── 玻璃拟态主题重构（Glassmorphism v2）──

  test('玻璃 Token：8 套主题全量携带环境光与通透填充，强填充更实', () {
    for (final preset in kThemePresetsV2) {
      final p = preset.palette;
      expect(p.ambient.length, 3, reason: '${preset.id} 环境光色斑应为 3 色');
      expect(p.glassFill.a, lessThan(1.0), reason: '${preset.id} 卡片填充须半透明');
      expect(p.glassFillStrong.a, greaterThan(p.glassFill.a),
          reason: '${preset.id} 弹层强填充应比卡片更不透明');
      expect(p.glassBorder.a, greaterThan(0), reason: '${preset.id} 高光描边可见');
    }
  });

  test('玻璃对比度守卫：正文压在任意光斑上的磨砂混合面 ≥ WCAG AA', () {
    double lum(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    }

    double contrast(Color a, Color b) {
      final l1 = lum(a), l2 = lum(b);
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    /// 玻璃填充与底层色的 alpha 混合（最差情况 = 光斑原色透出）
    Color frostOver(Color fill, Color under) => Color.fromARGB(
          255,
          ((fill.r * fill.a + under.r * (1 - fill.a)) * 255).round(),
          ((fill.g * fill.a + under.g * (1 - fill.a)) * 255).round(),
          ((fill.b * fill.a + under.b * (1 - fill.a)) * 255).round(),
        );

    for (final preset in kThemePresetsV2) {
      final p = preset.palette;
      for (final (i, blob) in p.ambient.indexed) {
        final blended = frostOver(p.glassFill, blob);
        final primary = contrast(p.textPrimary, blended);
        expect(primary, greaterThanOrEqualTo(4.5),
            reason: '${preset.id} 光斑#$i 上主文案对比度 $primary < 4.5');
        final secondary = contrast(p.textSecondary, blended);
        expect(secondary, greaterThanOrEqualTo(3.0),
            reason: '${preset.id} 光斑#$i 上次级文案对比度 $secondary < 3.0');
      }
    }
  });

  test('玻璃卡片装饰：磨砂填充 + 高光发丝描边，浅深主题同构', () {
    for (final preset in kThemePresetsV2) {
      final theme = buildTheme(preset);
      expect(theme.cardTheme.color, preset.palette.glassFill,
          reason: '${preset.id} Card 底色应为玻璃填充');
      final side =
          (theme.cardTheme.shape! as RoundedRectangleBorder).side;
      expect(side.color, preset.palette.glassBorder,
          reason: '${preset.id} Card 描边应为高光发丝线');
      final decoration = theme.extension<AppTokens>()!.cardDecoration;
      expect(decoration.color, preset.palette.glassFill);
      expect(decoration.boxShadow, isNotNull, reason: '${preset.id} 保留悬浮阴影');
    }
  });

  test('玻璃拟态：Scaffold 透明化让位背景层；弹层/导航用强填充', () {
    for (final id in ['t1', 't5']) {
      final theme = buildTheme(findPresetById(id)!);
      expect(theme.scaffoldBackgroundColor, Colors.transparent,
          reason: '$id 页面底色让位给环境光/背景图');
      expect(theme.bottomSheetTheme.backgroundColor,
          findPresetById(id)!.palette.glassFillStrong);
      expect(theme.navigationBarTheme.backgroundColor,
          findPresetById(id)!.palette.glassFillStrong);
    }
  });

  test('调色板 lerp：环境光与玻璃字段随主题过渡插值', () {
    final a = findPresetById('t1')!.palette;
    final b = findPresetById('t6')!.palette;
    final mid = a.lerp(b, 0.5);
    expect(mid.ambient.length, 3);
    expect(mid.glassFill.a, closeTo((a.glassFill.a + b.glassFill.a) / 2, 0.01));
    expect(mid.primary, Color.lerp(a.primary, b.primary, 0.5)!);
  });
}
