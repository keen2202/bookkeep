import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.status.warn` 三角 + 感叹号（34 §7.4）。
class BkStatusWarnPainter extends BkPainterBase {
  BkStatusWarnPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static final Path triangle = Path()
    ..moveTo(12, 4)
    ..lineTo(21, 20)
    ..lineTo(3, 20)
    ..close();

  static final Path bang = Path()
    ..moveTo(12, 10)
    ..lineTo(12, 15)
    ..moveTo(12, 17.5)
    ..lineTo(12, 17.6);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(triangle, p);
    // 感叹号用更粗笔触保证 16px 可辨
    canvas.drawPath(bang, strokePaint(width: 1.75));
    canvas.drawCircle(const Offset(12, 17.5), 0.9, fillPaint());
  }
}
