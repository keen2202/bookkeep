import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.rpt.hide-amount` 眼睛 + 斜杠（34 §7.3）。
class BkRptHideAmountPainter extends BkPainterBase {
  BkRptHideAmountPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  /// 眼睛外轮廓（扁椭圆）
  static final Path eye = Path()
    ..moveTo(3, 12)
    ..cubicTo(6.5, 7, 17.5, 7, 21, 12)
    ..cubicTo(17.5, 17, 6.5, 17, 3, 12)
    ..close();

  static final Path pupil = Path()
    ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2.5));

  static final Path slash = Path()
    ..moveTo(4, 20)
    ..lineTo(20, 4);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(eye, p);
    canvas.drawPath(pupil, p);
    canvas.drawPath(slash, strokePaint(width: 1.75));
  }
}
