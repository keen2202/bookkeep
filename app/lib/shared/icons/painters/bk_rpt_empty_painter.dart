import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.rpt.empty` 空态主形：等高基线上的三根矮柱（34 D4 / §7.3）。
///
/// 单层主形，无星标/装饰层。
class BkRptEmptyPainter extends BkPainterBase {
  BkRptEmptyPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static const double baselineY = 19;
  static const double barWidth = 3.2;

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
    _bar(7.5, 6),
    _bar(12, 9),
    _bar(16.5, 5),
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
    canvas.drawPath(baseline, strokePaint());
  }
}
