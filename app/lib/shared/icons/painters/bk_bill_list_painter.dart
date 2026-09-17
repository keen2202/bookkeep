import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.bill.list` 票据 + 3 条流水线（34 §7.2；比 nav.bills 更密）。
class BkBillListPainter extends BkPainterBase {
  BkBillListPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static final Path outline = Path()
    ..moveTo(5, 3)
    ..lineTo(19, 3)
    ..lineTo(19, 21)
    ..lineTo(5, 21)
    ..close();

  static final Path l1 = Path()
    ..moveTo(8, 8)
    ..lineTo(16, 8);

  static final Path l2 = Path()
    ..moveTo(8, 12)
    ..lineTo(16, 12);

  static final Path l3 = Path()
    ..moveTo(8, 16)
    ..lineTo(13, 16);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(outline, p);
    canvas.drawPath(l1, p);
    canvas.drawPath(l2, p);
    canvas.drawPath(l3, p);
  }
}
