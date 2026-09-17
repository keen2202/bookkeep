import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.rpt.bars` 周期对比柱（与 nav.reports 同构，略简）（34 §7.3）。
class BkRptBarsPainter extends BkPainterBase {
  BkRptBarsPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static const double baselineY = 19;
  static const double barWidth = 3.0;

  static Path _bar(double cx, double height) {
    final left = cx - barWidth / 2;
    return Path()
      ..moveTo(left, baselineY)
      ..lineTo(left, baselineY - height)
      ..lineTo(left + barWidth, baselineY - height)
      ..lineTo(left + barWidth, baselineY)
      ..close();
  }

  static final List<Path> barPaths = [
    _bar(8, 9),
    _bar(12, 14),
    _bar(16, 7),
  ];

  static final Path baseline = Path()
    ..moveTo(5, baselineY)
    ..lineTo(19, baselineY);

  @override
  void paintOnGrid(Canvas canvas) {
    final p = strokePaint();
    for (final path in barPaths) {
      canvas.drawPath(path, p);
    }
    canvas.drawPath(baseline, strokePaint(width: 1.5));
  }
}
