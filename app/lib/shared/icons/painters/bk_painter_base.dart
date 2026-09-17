import 'package:flutter/rendering.dart';

import '../bk_icon_tokens.dart';

/// BK-ICON Painter 基类（BK-DOC-34 §8.3 / BK-DOC-35 §2.4；BK-IC-005）。
///
/// 约定：
/// - 子类只在 [BkIconTokens.canvas]（24）栅格内绘制，基类负责缩放到实际 Size；
/// - [shouldRepaint] 仅当 [color] / [selected] / [selectedT] 变化时为 true；
/// - **禁止**每帧 `Path()` 堆分配——路径应为编译期常量或惰性 final；
/// - 选中态用 [t]（0→1）驱动 fill 透明度与颜色插值，不做路径 morph。
abstract class BkPainterBase extends CustomPainter {
  BkPainterBase({
    required this.color,
    required this.selected,
    this.selectedT,
  });

  /// 当前绘制色（来自 ThemePalette 槽位，禁止缓存主题色）
  final Color color;

  /// 逻辑选中态（nav 族语义；非 nav 忽略）
  final bool selected;

  /// 选中过渡进度 [0,1]；null 时跟随 [selected]（true→1 / false→0）
  final double? selectedT;

  /// 实际过渡进度（clamp 到 [0,1]）
  double get t {
    final raw = selectedT ?? (selected ? 1.0 : 0.0);
    if (raw <= 0) return 0;
    if (raw >= 1) return 1;
    return raw;
  }

  /// 在 24×24 栅格坐标系内绘制
  void paintOnGrid(Canvas canvas);

  /// 标准描边画笔
  Paint strokePaint({double? width}) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width ?? BkIconTokens.strokeWidth
    ..strokeCap = BkIconTokens.strokeCap
    ..strokeJoin = BkIconTokens.strokeJoin;

  /// 填充画笔；[opacity] 额外透明度（选中 fill 过渡）
  Paint fillPaint({double opacity = 1}) => Paint()
    ..color = opacity >= 1 ? color : color.withValues(alpha: color.a * opacity)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final scale = side / BkIconTokens.canvas;
    canvas
      ..save()
      ..scale(scale);
    paintOnGrid(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BkPainterBase oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.selected != selected ||
      oldDelegate.selectedT != selectedT;
}
