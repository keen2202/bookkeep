import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.status.lock` 盾 + 锁孔（34 §7.4）。
class BkStatusLockPainter extends BkPainterBase {
  BkStatusLockPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  /// 盾形（上宽下尖）
  static final Path shield = Path()
    ..moveTo(12, 3)
    ..lineTo(20, 6)
    ..lineTo(20, 12)
    ..cubicTo(20, 17, 16, 20, 12, 21)
    ..cubicTo(8, 20, 4, 17, 4, 12)
    ..lineTo(4, 6)
    ..close();

  /// 锁孔：圆 + 短杆
  static final Path keyhole = Path()
    ..addOval(Rect.fromCircle(center: const Offset(12, 11), radius: 2))
    ..moveTo(12, 13)
    ..lineTo(12, 16);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(shield, p);
    canvas.drawPath(keyhole, p);
  }
}
