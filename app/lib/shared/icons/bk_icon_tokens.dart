import 'package:flutter/material.dart';

/// BK-ICON 栅格与描边 Token（BK-DOC-34 §4.1 / BK-DOC-35 Step 0）。
///
/// 与 [GlassIconTokens] 并列：本类只描述图标**本体**绘制参数，
/// 不复制 G1–G5 blur/fill 玻璃数值（仍以 BK-DOC-23 / `glass_tokens.dart` 为准）。
abstract final class BkIconTokens {
  /// 设计坐标系边长；全部 Path 在 24×24 栅格内定义，由 Painter 统一缩放
  static const double canvas = 24;

  /// 四周安全区（活动区 20×20）
  static const double safe = 2;

  /// 活动区边长
  static const double active = canvas - safe * 2;

  /// 默认描边宽度（16px 显示时可升至 [strokeCompact]，见 34 §4.3）
  static const double strokeWidth = 1.75;

  /// 紧凑尺寸描边（可选优化，A5：非 AC 硬性）
  static const double strokeCompact = 2.0;

  /// 线端 / 转角
  static const StrokeCap strokeCap = StrokeCap.round;
  static const StrokeJoin strokeJoin = StrokeJoin.round;

  /// 图标本体默认着色槽位由 `ThemePalette` 解析，此处不持有颜色。

  /// Tab 选中态过渡（34 §8.2 / BK-IC-013）
  static const Duration selectedDuration = Duration(milliseconds: 200);

  /// 减弱动态效果时的过渡时长
  static const Duration selectedReducedDuration = Duration(milliseconds: 100);
}
