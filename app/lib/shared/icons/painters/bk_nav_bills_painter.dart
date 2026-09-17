import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.nav.bills` 长票据 + 底部直边 + 2 条流水线（34 §7.1）。
///
/// 未选中：线性轮廓；选中：票据体 fill `primary`，流水线 destination-out 挖空。
class BkNavBillsPainter extends BkPainterBase {
  BkNavBillsPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  /// 票据外轮廓（底部简化为直边，保证 16px 清晰）
  static final Path outline = Path()
    ..moveTo(5, 3)
    ..lineTo(19, 3)
    ..lineTo(19, 21)
    ..lineTo(5, 21)
    ..close();

  static final Path lineTop = Path()
    ..moveTo(8, 9)
    ..lineTo(16, 9);

  static final Path lineBottom = Path()
    ..moveTo(8, 13)
    ..lineTo(16, 13);

  @override
  void paintOnGrid(Canvas canvas) {
    final fillT = t;
    if (fillT > 0) {
      canvas.saveLayer(Offset.zero & const Size.square(24), Paint());
      canvas.drawPath(outline, fillPaint(opacity: fillT));
      if (fillT > 0.5) {
        final cut = Paint()
          ..blendMode = BlendMode.dstOut
          ..strokeWidth = 1.75
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(lineTop, cut);
        canvas.drawPath(lineBottom, cut);
      }
      canvas.restore();
    }
    if (fillT < 1) {
      final p = strokePaint();
      if (fillT > 0) {
        p.color = color.withValues(alpha: color.a * (1 - fillT));
      }
      canvas.drawPath(outline, p);
      canvas.drawPath(lineTop, p);
      canvas.drawPath(lineBottom, p);
    }
  }
}
