import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.rpt.calendar` 周历框 + 顶栏挂环 + 网格点（34 §7.3）。
class BkRptCalendarPainter extends BkPainterBase {
  BkRptCalendarPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  /// 外框
  static final Path frame = Path()
    ..moveTo(4, 6)
    ..lineTo(20, 6)
    ..lineTo(20, 20)
    ..lineTo(4, 20)
    ..close();

  /// 顶栏横线
  static final Path header = Path()
    ..moveTo(4, 10)
    ..lineTo(20, 10);

  /// 挂环
  static final Path rings = Path()
    ..moveTo(8, 4)
    ..lineTo(8, 7)
    ..moveTo(16, 4)
    ..lineTo(16, 7);

  /// 网格点（2×2）
  static const List<Offset> dots = [
    Offset(8, 14),
    Offset(12, 14),
    Offset(16, 14),
    Offset(8, 17.5),
    Offset(12, 17.5),
  ];

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    canvas.drawPath(frame, p);
    canvas.drawPath(header, p);
    canvas.drawPath(rings, p);
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final d in dots) {
      canvas.drawCircle(d, 1.1, dotPaint);
    }
  }
}
