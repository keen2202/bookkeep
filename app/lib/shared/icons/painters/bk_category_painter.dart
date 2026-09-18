import 'package:flutter/rendering.dart';

import '../bk_category_paths.dart';
import 'bk_painter_base.dart';

/// 分类库通用 Painter（BK-IC-050 / BK-DOC-35 Step 5）。
///
/// 所有 `bk.cat.*` 共用本 Painter：传入 seed `iconName`，
/// 由 [BkCategoryPaths] 在 24 栅格中给出线性 Path；不引入 SVG/图片资源。
class BkCategoryPainter extends BkPainterBase {
  BkCategoryPainter({
    required this.iconName,
    required super.color,
    required super.selected,
    super.selectedT,
  });

  /// seed `iconName`（非 `bk.cat.` 设计 ID）；别名由 BkCategoryPaths 解析。
  final String iconName;

  @override
  void paintOnGrid(Canvas canvas) {
    canvas.drawPath(BkCategoryPaths.resolve(iconName), strokePaint());
  }

  @override
  bool shouldRepaint(covariant BkCategoryPainter oldDelegate) =>
      super.shouldRepaint(oldDelegate) || oldDelegate.iconName != iconName;
}
