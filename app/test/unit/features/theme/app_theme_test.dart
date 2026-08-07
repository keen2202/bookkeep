import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';

void main() {
  test('审查 U-2：深浅主题同源构建且携带语义色扩展', () {
    final light = buildTheme(Brightness.light);
    final dark = buildTheme(Brightness.dark);

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<AppColors>(), AppColors.light);
    expect(dark.extension<AppColors>(), AppColors.dark);
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

  test('审查 U-2：系统栏样式随亮度联动', () {
    final light = buildTheme(Brightness.light);
    final dark = buildTheme(Brightness.dark);
    expect(light.appBarTheme.systemOverlayStyle!.statusBarIconBrightness,
        Brightness.dark);
    expect(dark.appBarTheme.systemOverlayStyle!.statusBarIconBrightness,
        Brightness.light);
  });
}
