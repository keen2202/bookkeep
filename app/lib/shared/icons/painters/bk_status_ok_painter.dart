import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.status.ok` 完成：圆 + 对勾（34 §7.4）。
class BkStatusOkPainter extends BkPainterBase {
  BkStatusOkPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static final Path circle = Path()
    ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9));

  static final Path check = Path()
    ..moveTo(7.5, 12.2)
    ..lineTo(10.7, 15.3)
    ..lineTo(16.8, 8.8);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(circle, p);
    canvas.drawPath(check, p);
  }
}
