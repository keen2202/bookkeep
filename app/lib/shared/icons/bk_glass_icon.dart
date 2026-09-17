import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';
import '../widgets/glass_icon.dart';
import 'bk_icon.dart';

/// GlassIcon（G1 容器）× BkIcon（CustomPaint 本体）组合组件
/// （BK-DOC-35 假设 A1；BK-IC-003 / BK-IC-011）。
///
/// - 容器材质仍为 G1（BK-DOC-23 §4.1），不改 blur/fill/描边/高光/投影；
/// - 本体尺寸 = 容器 × 0.55；
/// - [selected] 为 true 时默认容器 tint（与 Tab 选中 fill 兼容）；
/// - 可用 [tint] 覆盖默认 tint 策略。
class BkGlassIcon extends StatelessWidget {
  const BkGlassIcon({
    super.key,
    required this.name,
    this.size = GlassIconSize.s36,
    this.selected = false,
    this.tint,
    this.color,
  });

  /// BK-ICON 设计 ID（见 `BkIcons`）
  final String name;

  /// 容器尺寸档位
  final GlassIconSize size;

  /// Tab 选中态（nav 族 fill 双态 + 容器 tint）
  final bool selected;

  /// 覆盖容器 tint；null 时等于 [selected]
  final bool? tint;

  /// 覆盖本体颜色
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bodySize = size.side * GlassIconTokens.iconScale;
    final useTint = tint ?? selected;
    return GlassIcon(
      size: size,
      tint: useTint,
      custom: BkIcon(
        name,
        size: bodySize,
        selected: selected,
        color: color,
      ),
    );
  }
}
