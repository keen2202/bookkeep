import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.status.sync` 双循环箭头（34 §7.4）。
class BkStatusSyncPainter extends BkPainterBase {
  BkStatusSyncPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static const Offset center = Offset(12, 12);
  static const double radius = 8;

  static final Path topArc = Path()
    ..addArc(Rect.fromCircle(center: center, radius: radius), math.pi * 1.1, math.pi * 1.1);

  static final Path topArrow = (() {
    const endAngle = math.pi * 1.1 + math.pi * 1.1;
    final tip = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 2.2, tip.dy - 1.8)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + 2.2, tip.dy - 0.2);
  })();

  static final Path bottomArc = Path()
    ..addArc(Rect.fromCircle(center: center, radius: radius), -math.pi * 0.1, math.pi * 1.1);

  static final Path bottomArrow = (() {
    const endAngle = -math.pi * 0.1 + math.pi * 1.1;
    final tip = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + 2.2, tip.dy + 1.8)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 2.2, tip.dy + 0.2);
  })();

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(topArc, p);
    canvas.drawPath(topArrow, p);
    canvas.drawPath(bottomArc, p);
    canvas.drawPath(bottomArrow, p);
  }
}
