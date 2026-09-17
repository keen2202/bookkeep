import 'package:flutter/rendering.dart';

import 'bk_painter_base.dart';

/// `bk.act.entry` 正圆轮廓 + 中心等臂「+」（34 D3 / §7.1；AC-10）。
///
/// 禁止票据复合图形；容器若为 primary 实色玻璃，本体由调用方传 `onPrimary`。
class BkActEntryPainter extends BkPainterBase {
  BkActEntryPainter({
    required super.color,
    required super.selected,
    super.selectedT,
  });

  /// 圆心与半径（24 栅格）
  static const Offset center = Offset(12, 12);
  static const double radius = 9;

  /// 加号半臂长（总臂长 8/24 栅格，34 §7.1）
  static const double plusHalf = 4;

  static final Path circlePath = Path()
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  static final Path plusPath = Path()
    ..moveTo(center.dx - plusHalf, center.dy)
    ..lineTo(center.dx + plusHalf, center.dy)
    ..moveTo(center.dx, center.dy - plusHalf)
    ..lineTo(center.dx, center.dy + plusHalf);

  @override
  void paintOnGrid(Canvas canvas) {
    // entry 无 selected 双态；始终线性描边
    canvas.drawPath(circlePath, strokePaint());
    canvas.drawPath(plusPath, strokePaint());
  }
}
