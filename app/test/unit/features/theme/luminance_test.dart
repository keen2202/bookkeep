import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/background/luminance.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

/// 亮度采样 / α 映射 / 对比度闭环（Spec §5 与 §9 单元层：40 用例）
void main() {
  group('亮度采样（Spec §5.1）', () {
    test('纯白图 → L ≈ 1.0', () {
      final rgba = Uint8List(32 * 32 * 4);
      for (var i = 0; i < 32 * 32; i++) {
        rgba[i * 4] = 255;
        rgba[i * 4 + 1] = 255;
        rgba[i * 4 + 2] = 255;
        rgba[i * 4 + 3] = 255;
      }
      expect(luminanceFromRgbaPixels(rgba), closeTo(1.0, 0.001));
    });

    test('纯黑图 → L ≈ 0.0', () {
      final rgba = Uint8List(32 * 32 * 4); // 全 0
      expect(luminanceFromRgbaPixels(rgba), closeTo(0.0, 0.001));
    });

    test('纯红图 → L = 0.2126（Rec.709 加权）', () {
      final rgba = Uint8List(32 * 32 * 4);
      for (var i = 0; i < 32 * 32; i++) {
        rgba[i * 4] = 255;
        rgba[i * 4 + 3] = 255;
      }
      expect(luminanceFromRgbaPixels(rgba), closeTo(0.2126, 0.001));
    });

    test('黑白渐变图 → L 介于 0~1 且高于 gamma 域中灰线性值', () {
      final rgba = Uint8List(32 * 32 * 4);
      for (var y = 0; y < 32; y++) {
        final v = (y * 255 ~/ 31);
        for (var x = 0; x < 32; x++) {
          final o = (y * 32 + x) * 4;
          rgba[o] = v;
          rgba[o + 1] = v;
          rgba[o + 2] = v;
          rgba[o + 3] = 255;
        }
      }
      final L = luminanceFromRgbaPixels(rgba);
      expect(L, greaterThan(0));
      expect(L, lessThan(1));
      // 逐像素线性化后取平均（凸函数）：mean(linear(v)) > linear(mean(v))，
      // 32 档离散采样 ≈ 0.314（线性化在平均之前，Spec §5.1）
      expect(L, closeTo(0.314, 0.02));
      expect(L, greaterThan(relativeLuminance(const Color(0xFF7F7F7F))));
    });

    test('中灰 50% → 线性域亮度约 0.214（非 0.5，验证线性化生效）', () {
      final rgba = Uint8List(4)..setAll(0, [128, 128, 128, 255]);
      final L = luminanceFromRgbaPixels(rgba);
      expect(L, lessThan(0.25));
      expect(L, greaterThan(0.15));
    });

    test('decodeLuminance：PNG 解码 32×32 采样与像素直算一致', () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 64, 64),
        ui.Paint()..color = const ui.Color(0xFF9E9E9E),
      );
      final image = await recorder.endRecording().toImage(64, 64);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final L = await decodeLuminance(png.buffer.asUint8List());
      expect(L, closeTo(relativeLuminance(const Color(0xFF9E9E9E)), 0.01));
    });

    test('decodeLuminance：损坏字节抛 FormatException', () async {
      await expectLater(
        decodeLuminance(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('α 映射（Spec §5.2 分段插值）', () {
    test('锚点取值与文档一致', () {
      expect(overlayAlphaFor(0.00, dark: false), 0.50);
      expect(overlayAlphaFor(0.15, dark: false), 0.55);
      expect(overlayAlphaFor(0.35, dark: false), 0.60);
      expect(overlayAlphaFor(0.55, dark: false), 0.72);
      expect(overlayAlphaFor(0.75, dark: false), 0.82);
      expect(overlayAlphaFor(1.00, dark: false), 0.86);
      expect(overlayAlphaFor(0.00, dark: true), 0.48);
      expect(overlayAlphaFor(0.15, dark: true), 0.52);
      expect(overlayAlphaFor(0.35, dark: true), 0.58);
      expect(overlayAlphaFor(0.55, dark: true), 0.68);
      expect(overlayAlphaFor(0.75, dark: true), 0.78);
      expect(overlayAlphaFor(1.00, dark: true), 0.82);
    });

    test('锚点间线性插值且单调递增', () {
      var prev = 0.0;
      for (var i = 0; i <= 200; i++) {
        final L = i / 200;
        final a = overlayAlphaFor(L, dark: false);
        expect(a, greaterThanOrEqualTo(prev - 1e-9),
            reason: 'L=$L 处 α 非单调');
        prev = a;
      }
    });

    test('插值连续：临界点两侧无跳变', () {
      expect(overlayAlphaFor(0.1499, dark: false),
          closeTo(overlayAlphaFor(0.1501, dark: false), 0.005));
      expect(overlayAlphaFor(0.5499, dark: false),
          closeTo(overlayAlphaFor(0.5501, dark: false), 0.005));
      expect(overlayAlphaFor(0.3499, dark: true),
          closeTo(overlayAlphaFor(0.3501, dark: true), 0.005));
    });

    test('深色主题 α 全区间低于浅色主题（同亮度对比）', () {
      for (var i = 0; i <= 100; i++) {
        final L = i / 100;
        expect(overlayAlphaFor(L, dark: true),
            lessThan(overlayAlphaFor(L, dark: false)));
      }
    });

    test('越界输入按端点收敛', () {
      expect(overlayAlphaFor(-0.5, dark: false), overlayAlphaFor(0, dark: false));
      expect(overlayAlphaFor(1.5, dark: false), overlayAlphaFor(1, dark: false));
    });
  });

  group('对比度校验闭环（Spec §5.3）', () {
    test('contrast 公式：黑白对比 21:1，白对 Material grey 约 2.85:1', () {
      expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
      // Colors.grey = #9E9E9E，线性亮度 0.342 → (1.05)/(0.342+0.05)
      expect(contrastRatio(Colors.white, Colors.grey), closeTo(2.68, 0.05));
    });

    test('有效亮度公式', () {
      final eff = effectiveLuminance(imageL: 0.8, alpha: 0.6, backgroundL: 0.9);
      expect(eff, closeTo(0.8 * 0.4 + 0.9 * 0.6, 1e-9));
    });

    test('状态栏图标明暗：effLum > 0.5 → 深色图标', () {
      expect(useDarkStatusIcons(effLum: 0.51), isTrue);
      expect(useDarkStatusIcons(effLum: 0.5), isFalse);
      expect(useDarkStatusIcons(effLum: 0.1), isFalse);
    });

    // Spec §9：8 主题 × 5 档亮度 = 40 用例，全部收敛至 ≥ 4.5:1
    const levels = <(String, double)>[
      ('极亮', 0.95),
      ('亮', 0.65),
      ('中调', 0.45),
      ('暗', 0.25),
      ('极暗', 0.05),
    ];

    test('40 用例：8 主题 × 5 档亮度全部收敛至 ≥ 4.5:1', () {
      for (final preset in kThemePresetsV2) {
        for (final (label, L) in levels) {
          final alpha = resolveOverlayAlpha(
            imageL: L,
            background: preset.palette.background,
            textPrimary: preset.palette.textPrimary,
            dark: preset.isDark,
          );
          final bgL = relativeLuminance(preset.palette.background);
          final textL = relativeLuminance(preset.palette.textPrimary);
          final eff = effectiveLuminance(imageL: L, alpha: alpha, backgroundL: bgL);
          final ratio = contrastRatioFromLuminance(textL, eff);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '${preset.id}(${preset.name}) $label 图 L=$L 收敛 α=$alpha 后对比度 $ratio < 4.5');
          expect(alpha, lessThanOrEqualTo(kOverlayAlphaCap));
          // 闭环单调：α 只会从锚点映射值上浮
          expect(alpha, greaterThanOrEqualTo(overlayAlphaFor(L, dark: preset.isDark)));
        }
      }
    });

    test('闭环上浮仅在不足时发生：暗图 + 深色主题无需上浮', () {
      final preset = findPresetById('t5')!; // 石墨·夜
      final alpha = resolveOverlayAlpha(
        imageL: 0.05,
        background: preset.palette.background,
        textPrimary: preset.palette.textPrimary,
        dark: true,
      );
      expect(alpha, overlayAlphaFor(0.05, dark: true));
    });

    test('极亮图 + 浅色主题：α 上浮至达标且不超过上限', () {
      final preset = findPresetById('t1')!;
      final alpha = resolveOverlayAlpha(
        imageL: 1.0,
        background: preset.palette.background,
        textPrimary: preset.palette.textPrimary,
        dark: false,
      );
      expect(alpha, greaterThanOrEqualTo(0.86));
      expect(alpha, lessThanOrEqualTo(kOverlayAlphaCap));
    });

    test('textSecondary 对不透明卡片 surface 达标（数据区绝对可读，设计 §5.4.1）', () {
      // 次级文案实际落在不透明白卡片（surface）上，不直接压在遮罩底色上；
      // 8 主题 × 中调图：卡片内次级文案对比度 ≥ 4.5（调色板出厂校验值）
      for (final preset in kThemePresetsV2) {
        final sec = contrastRatio(
            preset.palette.textSecondary, preset.palette.surface);
        expect(sec, greaterThanOrEqualTo(4.5),
            reason: '${preset.id} 卡片内次级文案对比度 $sec < 4.5:1');
      }
    });
  });
}
