import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.bill.empty` 空态主形：仅票据线性轮廓（34 D4 / §7.2）。
///
/// 禁止星标、漂浮票据、小柱等二层装饰。
class BkBillEmptyPainter extends BkPainterBase {
  BkBillEmptyPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  static final Path outline = Path()
    ..moveTo(6, 3)
    ..lineTo(18, 3)
    ..lineTo(18, 21)
    ..lineTo(6, 21)
    ..close();

  @override
  void paintOnGrid(Canvas canvas) {
    canvas.drawPath(outline, strokePaint());
  }
}
