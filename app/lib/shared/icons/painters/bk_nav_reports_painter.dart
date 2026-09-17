import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.nav.reports` 三根高度差柱 + 底部基线（34 §7.1）。
///
/// 未选中：线性柱框；选中：柱体 fill `primary`。
class BkNavReportsPainter extends BkPainterBase {
  BkNavReportsPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static const double baselineY = 19;
  static const double barWidth = 3.2;

  static const List<(double cx, double height)> bars = [
    (7.5, 8),
    (12, 13),
    (16.5, 6),
  ];

  static Path barPath(double cx, double height) {
    final left = cx - barWidth / 2;
    return Path()
      ..moveTo(left, baselineY)
      ..lineTo(left, baselineY - height)
      ..lineTo(left + barWidth, baselineY - height)
      ..lineTo(left + barWidth, baselineY)
      ..close();
  }

  static final Path bar0 = barPath(7.5, 8);
  static final Path bar1 = barPath(12, 13);
  static final Path bar2 = barPath(16.5, 6);
  static final List<Path> barPaths = [bar0, bar1, bar2];

  static final Path baseline = Path()
    ..moveTo(4, baselineY)
    ..lineTo(20, baselineY);

  @override
  void paintOnGrid(Canvas canvas) {
    final fillT = t;

    if (fillT > 0) {
      for (final path in barPaths) {
        canvas.drawPath(path, fillPaint(opacity: fillT));
      }
    }
    if (fillT < 1) {
      final p = strokePaint();
      if (fillT > 0) {
        p.color = color.withValues(alpha: color.a * (1 - fillT));
      }
      for (final path in barPaths) {
        canvas.drawPath(path, p);
      }
    }
    // 基线始终线性（不参与 fill）
    canvas.drawPath(baseline, strokePaint());
  }
}
