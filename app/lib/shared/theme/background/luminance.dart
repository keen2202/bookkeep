import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 背景图亮度 / 智能遮罩算法（BK-UI-012，Spec §5）：
/// sRGB 线性化 → Rec.709 加权亮度 → α 分段插值 → WCAG 对比度校验闭环。
/// 纯 Dart 实现（dart:ui 解码仅 [decodeLuminance] 一处），全部计算可单测。

/// WCAG 对比度底线（正文 ≥ 4.5:1，设计原则 3）
const double kMinContrast = 4.5;

/// 遮罩透明度上限（Spec §5.3 闭环步进上限）
const double kOverlayAlphaCap = 0.92;

/// sRGB 通道值 → 线性光（Spec §5.1：c'<=0.03928 分段）
double linearizeChannel(double v) => v <= 0.03928
    ? v / 12.92
    : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

/// Rec.709 相对亮度 L ∈ [0,1]（Spec §5.1）
double relativeLuminance(Color c) {
  final r = linearizeChannel(c.r);
  final g = linearizeChannel(c.g);
  final b = linearizeChannel(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// 由 rgba8888 像素缓冲（32×32 采样结果）计算平均亮度（Spec §5.1：
/// 先线性化再加权，避免在 gamma 域直接平均）
double luminanceFromRgbaPixels(Uint8List rgba8888) {
  if (rgba8888.isEmpty) return 0;
  final count = rgba8888.length ~/ 4;
  var sum = 0.0;
  for (var i = 0; i < count; i++) {
    final o = i * 4;
    final r = linearizeChannel(rgba8888[o] / 255);
    final g = linearizeChannel(rgba8888[o + 1] / 255);
    final b = linearizeChannel(rgba8888[o + 2] / 255);
    sum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
  return sum / count;
}

/// 解码图片字节流 → 32×32 采样 → 平均亮度（Spec §5.4.3：32×32 解码 < 16ms）。
/// 解码失败（非图片/损坏）抛 [FormatException]。
Future<double> decodeLuminance(Uint8List bytes, {int size = 32}) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: size, targetHeight: size);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (data == null) throw const FormatException('背景图解码失败');
    return luminanceFromRgbaPixels(data.buffer.asUint8List());
  } on FormatException {
    rethrow;
  } catch (_) {
    // instantiateImageCodec 对损坏字节抛 Exception('Invalid image data')
    throw const FormatException('背景图解码失败');
  }
}

/// 遮罩透明度分段锚点（Spec §5.2：α 随 L 线性插值，避免临界跳变）
const kOverlayAnchors = <(double l, double light, double dark)>[
  (0.00, 0.50, 0.48),
  (0.15, 0.55, 0.52),
  (0.35, 0.60, 0.58),
  (0.55, 0.72, 0.68),
  (0.75, 0.82, 0.78),
  (1.00, 0.86, 0.82),
];

/// 智能遮罩 α 映射：按主题明暗取锚点列，锚点间线性插值（Spec §5.2）
double overlayAlphaFor(double luminance, {required bool dark}) {
  final clamped = luminance.clamp(0.0, 1.0);
  for (var i = 0; i < kOverlayAnchors.length - 1; i++) {
    final (l0, a0l, a0d) = kOverlayAnchors[i];
    final (l1, a1l, a1d) = kOverlayAnchors[i + 1];
    if (clamped < l1) {
      final t = (clamped - l0) / (l1 - l0);
      final a0 = dark ? a0d : a0l;
      final a1 = dark ? a1d : a1l;
      return a0 + (a1 - a0) * t;
    }
  }
  final (_, lastL, lastD) = kOverlayAnchors.last;
  return dark ? lastD : lastL;
}

/// 遮罩后有效亮度（Spec §5.3 近似：图·(1-α) + background·α）
double effectiveLuminance({
  required double imageL,
  required double alpha,
  required double backgroundL,
}) =>
    imageL * (1 - alpha) + backgroundL * alpha;

/// WCAG 2.x 对比度（Spec §5.3；入参为相对亮度）
double contrastRatioFromLuminance(double l1, double l2) {
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG 2.x 对比度（颜色入参）
double contrastRatio(Color a, Color b) =>
    contrastRatioFromLuminance(relativeLuminance(a), relativeLuminance(b));

/// 对比度校验闭环（Spec §5.3）：从映射 α 起，步进 0.05 上浮至
/// [kOverlayAlphaCap]，直至 textPrimary 对遮罩后底色对比度 ≥ 4.5。
/// 返回校验后的最终 α（恒 ≥ 锚点映射值）。
double resolveOverlayAlpha({
  required double imageL,
  required Color background,
  required Color textPrimary,
  required bool dark,
}) {
  final bgL = relativeLuminance(background);
  final textL = relativeLuminance(textPrimary);
  var alpha = overlayAlphaFor(imageL, dark: dark);
  while (alpha < kOverlayAlphaCap) {
    final eff = effectiveLuminance(imageL: imageL, alpha: alpha, backgroundL: bgL);
    if (contrastRatioFromLuminance(textL, eff) >= kMinContrast) break;
    alpha = math.min(alpha + 0.05, kOverlayAlphaCap);
  }
  return alpha;
}

/// 状态栏图标明暗（Spec §5.3：遮罩后有效亮度 > 0.5 → 深色图标）
bool useDarkStatusIcons({required double effLum}) => effLum > 0.5;
