import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.rpt.pie` 圆 + 半径分隔（可缺口）（34 §7.3）。
class BkRptPiePainter extends BkPainterBase {
  BkRptPiePainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static const Offset center = Offset(12, 12);
  static const double radius = 9;

  static final Path circlePath = Path()
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  /// 从圆心到右上的半径分隔（约 45°）
  static final Path radiusSep = (() {
    const rad = math.pi / 4;
    final end = Offset(
      center.dx + radius * math.cos(rad),
      center.dy - radius * math.sin(rad),
    );
    return Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(end.dx, end.dy);
  })();

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(circlePath, p);
    canvas.drawPath(radiusSep, p);
  }
}
