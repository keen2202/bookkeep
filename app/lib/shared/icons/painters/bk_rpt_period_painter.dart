import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.rpt.period` 环形箭头 + 短柱（34 §7.3；避免纯时钟）。
class BkRptPeriodPainter extends BkPainterBase {
  BkRptPeriodPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static const Offset center = Offset(12, 12);
  static const double radius = 8;

  /// 缺口环（约 300°，右上开口）
  static final Path arcPath = (() {
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 3;
    const sweep = math.pi * 5 / 3;
    return Path()..addArc(rect, start, sweep);
  })();

  /// 箭头尖（开口末端）
  static final Path arrowHead = (() {
    const endAngle = -math.pi / 3 + math.pi * 5 / 3;
    final tip = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 2.5, tip.dy - 1)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + 1, tip.dy - 2.5);
  })();

  /// 中心短柱（周期对比语义）
  static final Path shortBar = Path()
    ..moveTo(12, 15)
    ..lineTo(12, 9)
    ..moveTo(12, 9)
    ..lineTo(10, 11)
    ..moveTo(12, 9)
    ..lineTo(14, 11);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(arcPath, p);
    canvas.drawPath(arrowHead, p);
    canvas.drawPath(shortBar, strokePaint(width: 1.5));
  }
}
