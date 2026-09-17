import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.bill.filter` 漏斗（34 §7.2）。
class BkBillFilterPainter extends BkPainterBase {
  BkBillFilterPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static final Path funnel = Path()
    ..moveTo(4, 5)
    ..lineTo(20, 5)
    ..lineTo(14, 12)
    ..lineTo(14, 19)
    ..lineTo(10, 21)
    ..lineTo(10, 12)
    ..close();

  @override
  void paintOnGrid(Canvas canvas) {
    canvas.drawPath(funnel, strokePaint());
  }
}
