import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/theme/theme_settings.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_layers.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_quality.dart';
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

  // ── 玻璃拟态主题重构（Glassmorphism v2 → v3，GLS-004）──
  // 存量断言修改原因：v3 ambient 由 3 色扩为 4 色（右上锚位补第 4 色，
  // Spec §6.2）；glass 系字段退役为派生值；弹层/导航改按层级解析填充。

  test('玻璃 Token：8 套主题全量携带 4 元素环境光与通透填充，强填充更实', () {
    for (final preset in kThemePresetsV2) {
      final p = preset.palette;
      expect(p.ambient.length, 4, reason: '${preset.id} 环境光色斑应为 4 色');
      expect(p.glassFill.a, lessThan(1.0), reason: '${preset.id} 卡片填充须半透明');
      expect(p.glassFillStrong.a, greaterThan(p.glassFill.a),
          reason: '${preset.id} 弹层强填充应比卡片更不透明');
      expect(p.glassBorder.a, greaterThan(0), reason: '${preset.id} 高光描边可见');
    }
  });

  test('v3 环境光第 4 色：GLS-004 checklist 定值逐项锁定', () {
    final expected = <String, Color>{
      't1': const Color(0xFFBFE8DC),
      't2': const Color(0xFFCCE4FA),
      't3': const Color(0xFFD9CBF2),
      't4': const Color(0xFFFFE7BF),
      't5': const Color(0xFF3E4A57),
      't6': const Color(0xFF1B6E8C),
      't7': const Color(0xFF2E6E34),
      't8': const Color(0xFF6E2A8C),
    };
    for (final preset in kThemePresetsV2) {
      expect(preset.palette.ambient[3], expected[preset.id],
          reason: '${preset.id} 第 4 色（右上锚位）');
    }
    // T5/T7/T8 背景提亮定值（Spec §6.2）
    expect(findPresetById('t5')!.palette.background, const Color(0xFF13171C));
    expect(findPresetById('t7')!.palette.background, const Color(0xFF101713));
    expect(findPresetById('t8')!.palette.background, const Color(0xFF171126));
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

  test('玻璃卡片装饰：层级函数解析填充/描边，浅深主题同构', () {
    // v3：AppTokens.cardDecoration 与 cardTheme 均改由 resolveGlassSpec 解析
    // （standard 档含 L1 补偿），palette.glassFill 为 high 基准兼容别名
    for (final preset in kThemePresetsV2) {
      final theme = buildTheme(preset);
      final panelSpec = resolveGlassSpec(
        tier: GlassTier.panel,
        brightness: preset.brightness,
        palette: preset.palette,
        quality: GlassQuality.standard,
      );
      expect(theme.cardTheme.color, panelSpec.fill,
          reason: '${preset.id} Card 底色应为 standard 档 L1 玻璃填充');
      final side =
          (theme.cardTheme.shape! as RoundedRectangleBorder).side;
      expect(side.color, panelSpec.borderColor,
          reason: '${preset.id} Card 描边应为 L1 规范值');
      final decoration = theme.extension<AppTokens>()!.cardDecoration;
      expect(decoration.color, panelSpec.fill);
      expect(decoration.boxShadow, isNotNull, reason: '${preset.id} 保留悬浮阴影');
    }
  });

  test('玻璃拟态：Scaffold 透明化让位背景层；弹层/导航按层级解析填充', () {
    // v3（GLS-005）：导航栏 = L2 dock 填充、底部弹层/对话框 = L3 overlay 填充
    for (final id in ['t1', 't5']) {
      final preset = findPresetById(id)!;
      final theme = buildTheme(preset);
      expect(theme.scaffoldBackgroundColor, Colors.transparent,
          reason: '$id 页面底色让位给环境光/背景图');
      expect(
        theme.bottomSheetTheme.backgroundColor,
        resolveGlassSpec(
          tier: GlassTier.overlay,
          brightness: preset.brightness,
          palette: preset.palette,
          quality: GlassQuality.standard,
        ).fill,
        reason: '$id 弹层为 L3 浮层填充',
      );
      expect(
        theme.navigationBarTheme.backgroundColor,
        resolveGlassSpec(
          tier: GlassTier.dock,
          brightness: preset.brightness,
          palette: preset.palette,
          quality: GlassQuality.standard,
        ).fill,
        reason: '$id 导航栏为 L2 吸附层填充',
      );
      expect(theme.dialogTheme.backgroundColor,
          theme.bottomSheetTheme.backgroundColor,
          reason: '$id 对话框同为 L3 填充');
    }
  });

  test('v3 组件主题：卡片 L1 描边/填充 + 输入框玻璃填充 + SnackBar L4', () {
    for (final dark in [false, true]) {
      final preset = findPresetById(dark ? 't5' : 't1')!;
      final theme = buildTheme(preset);
      final panelSpec = resolveGlassSpec(
        tier: GlassTier.panel,
        brightness: preset.brightness,
        palette: preset.palette,
        quality: GlassQuality.standard,
      );
      expect(theme.cardTheme.color, panelSpec.fill);
      expect((theme.cardTheme.shape! as RoundedRectangleBorder).side.color,
          panelSpec.borderColor);
      expect(theme.cardTheme.clipBehavior, Clip.antiAlias);
      // 输入框玻璃填充：浅 0x1FFFFFFF / 深 0x0FFFFFFF
      expect(theme.inputDecorationTheme.fillColor,
          dark ? const Color(0x0FFFFFFF) : const Color(0x1FFFFFFF));
      // SnackBar = L4 悬浮提示层
      final floatingSpec = resolveGlassSpec(
        tier: GlassTier.floating,
        brightness: preset.brightness,
        palette: preset.palette,
        quality: GlassQuality.standard,
      );
      expect(theme.snackBarTheme.backgroundColor, floatingSpec.fill);
      // 下拉菜单容器 = L3 填充，elevation 归零（阴影归层级体系）
      expect(theme.popupMenuTheme.color, theme.dialogTheme.backgroundColor);
    }
  });

  test('v3 背景纯色禁令：8 预设 background 无一为纯黑/纯白', () {
    // Spec §4.7 字面区间 (0.01, 0.99) 与其自身冻结值冲突：
    // 规范冻结的 T5 提亮值 #13171C 的 WCAG 相对亮度实为 0.0084（<0.01），
    // T7/T8 同理。按 §2.4「表格值为规范源（canonical）」原则，冻结值优先；
    // 本测试以可执行下界锁定「非纯黑/纯白」意图（>0.005 且 <0.995），
    // 并逐项断言冻结值不被回归。该冲突已记录 docs/report/gls-v3/spike.md。
    for (final preset in kThemePresetsV2) {
      final lum = glassRelativeLuminance(preset.palette.background);
      expect(lum, greaterThan(0.005), reason: '${preset.id} 背景过暗');
      expect(lum, lessThan(0.995), reason: '${preset.id} 背景过亮');
    }
    expect(findPresetById('t5')!.palette.background, const Color(0xFF13171C));
  });

  test('custom 派生背景钳制：深色种子 surface 过暗时自动提亮入合法区间', () {
    for (final seed in kThemePresets) {
      final dark = buildCustom(Brightness.dark, seed)
          .extension<AppTokens>()!
          .palette;
      final lum = glassRelativeLuminance(dark.background);
      expect(lum, greaterThan(0.01),
          reason: 'seed $seed 深色派生背景应被 clampBackgroundLuminance 提亮');
      expect(lum, lessThan(0.99));
      final light = buildCustom(Brightness.light, seed)
          .extension<AppTokens>()!
          .palette;
      final lightLum = glassRelativeLuminance(light.background);
      expect(lightLum, greaterThan(0.01));
      expect(lightLum, lessThan(0.99));
    }
  });

  test('调色板 lerp：环境光随主题过渡插值；glass 派生字段按明暗离散切换', () {
    final a = findPresetById('t1')!.palette;
    final b = findPresetById('t6')!.palette;
    final mid = a.lerp(b, 0.5);
    expect(mid.ambient.length, 4);
    // glass 系为派生值：brightness 在 t=0.5 处切换到目标侧（既有约定），
    // 故 α 取 b 侧派生分支而非算术中点
    expect(mid.glassFill.a, closeTo(b.glassFill.a, 0.01));
    expect(mid.primary, Color.lerp(a.primary, b.primary, 0.5)!);
  });
}
