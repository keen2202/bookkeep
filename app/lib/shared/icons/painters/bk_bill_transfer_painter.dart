import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.bill.transfer` 水平双向箭头（34 §7.2；不染红绿）。
class BkBillTransferPainter extends BkPainterBase {
  BkBillTransferPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static final Path shaft = Path()
    ..moveTo(5, 12)
    ..lineTo(19, 12);

  static final Path leftHead = Path()
    ..moveTo(9, 8)
    ..lineTo(5, 12)
    ..lineTo(9, 16);

  static final Path rightHead = Path()
    ..moveTo(15, 8)
    ..lineTo(19, 12)
    ..lineTo(15, 16);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(shaft, p);
    canvas.drawPath(leftHead, p);
    canvas.drawPath(rightHead, p);
  }
}
