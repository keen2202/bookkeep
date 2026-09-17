import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import 'bk_icon_registry.dart';
import 'bk_icon_tokens.dart';
import 'bk_icons.dart';

/// BK-ICON 统一出口 Widget（BK-DOC-34 §6.2 / §8；BK-IC-002）。
///
/// - 默认色 `palette.textPrimary`；nav 族 + selected → `palette.primary`；
/// - 非 nav 忽略 selected（35 §4.5）；
/// - 绘制坐标系固定 24，由 [size] 缩放；
/// - 选中过渡 200ms（减弱动态 100ms），仅色/态过渡、无路径 morph（AC-06）；
/// - 未注册 ID：debug assert，release 回退 Material `Icons.category`（A3）。
class BkIcon extends StatefulWidget {
  const BkIcon(
    this.name, {
    super.key,
    this.size,
    this.selected = false,
    this.color,
  });

  /// 设计 ID（见 [BkIcons]）
  final String name;

  /// 绘制边长；null 时默认 24
  final double? size;

  /// Tab 选中态（仅 nav 族生效）
  final bool selected;

  /// 覆盖颜色；null → palette.textPrimary（selected nav → primary）
  final Color? color;

  @override
  State<BkIcon> createState() => _BkIconState();
}

class _BkIconState extends State<BkIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _curved;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _animatesColor =>
      BkIcons.isNav(widget.name) && widget.color == null;

  @override
  void initState() {
    super.initState();
    BkIconRegistry.ensureInitialized();
    _controller = AnimationController(
      vsync: this,
      duration: BkIconTokens.selectedDuration,
      value: widget.selected ? 1 : 0,
    );
    _curved = CurvedAnimation(parent: _controller, curve: GlassMotion.curve);
  }

  @override
  void didUpdateWidget(covariant BkIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _controller.duration = _reduceMotion
          ? BkIconTokens.selectedReducedDuration
          : BkIconTokens.selectedDuration;
      if (widget.selected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _resolveTargetColor(BuildContext context) {
    if (widget.color != null) return widget.color!;
    final palette = context.palette;
    if (widget.selected && BkIcons.isNav(widget.name)) {
      return palette.primary;
    }
    return palette.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? BkIconTokens.canvas;
    final palette = context.palette;
    final target = _resolveTargetColor(context);

    // nav 选中：textPrimary ↔ primary 颜色插值；其余直接用解析色
    final Color paintColor;
    if (_animatesColor) {
      paintColor =
          Color.lerp(palette.textPrimary, target, _curved.value)!;
    } else {
      paintColor = target;
    }

    final selectedT = BkIcons.isNav(widget.name) ? _controller.value : null;

    final painter = BkIconRegistry.resolve(
      widget.name,
      color: paintColor,
      selected: widget.selected,
      selectedT: selectedT,
    );

    if (painter == null) {
      // debug 已在 BkIconRegistry.resolve 内 assert；release 按 35 §2.1/A3
      // 先查过渡 fallback，再回退 category，并输出可检索日志。
      final fallback = BkIconRegistry.materialFallback(widget.name);
      final fallbackIcon = fallback ?? Icons.category;
      debugPrint('BkIcon 未注册: ${widget.name}；release fallback: $fallbackIcon');
      return Icon(fallbackIcon, size: size, color: paintColor);
    }

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: painter),
      ),
    );
  }
}
