import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import 'glass_nav.dart';

/// FAB 尺寸与边距（与 [GlassFab] 的 56×56 规格一致）
const _fabSize = 56.0;
const _fabMargin = AppSpacing.md;

/// 长按拖拽 FAB（BK-DOC-26 需求4）：
/// - 默认位置 = 内容区底部水平居中（「屏幕底部正中间」，位于底部导航上方）；
/// - 长按进入拖拽：触觉反馈 + 按钮放大 + 主色光晕，明确「可移动」；
/// - 拖拽中按钮实时跟随并被钳制在内容区内（不出屏）；
/// - 松手后经 [onPlacementChanged] 回传归一化锚点（持久化由调用方完成）；
/// - 普通点按仍触发 [onTap]（记一笔）。
///
/// 以 [Positioned.fill] 覆盖在内容区之上；按钮之外区域不拦截手势。
class DraggableGlassFab extends StatefulWidget {
  const DraggableGlassFab({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.anchor,
    required this.onPlacementChanged,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// 无障碍标签（替代 Tooltip，避免与长按拖拽手势竞争）
  final String? semanticLabel;

  /// 归一化锚点；null = 默认底部正中
  final ({double ax, double ay})? anchor;

  /// 拖拽松手回调：回传新的归一化锚点
  final ValueChanged<({double ax, double ay})> onPlacementChanged;

  @override
  State<DraggableGlassFab> createState() => _DraggableGlassFabState();
}

class _DraggableGlassFabState extends State<DraggableGlassFab> {
  final GlobalKey _areaKey = GlobalKey();

  bool _dragging = false;

  /// 拖拽中的像素中心（内容区坐标）；非拖拽态为 null
  Offset? _dragCenter;

  /// 由归一化锚点解析像素中心；越界值钳制回内容区
  Offset _resolveCenter(Size box) {
    final anchor = widget.anchor;
    if (anchor == null) {
      // 默认：底部水平居中（贴底部导航上缘，留一个边距）
      return Offset(box.width / 2, box.height - _fabSize / 2 - _fabMargin);
    }
    return _clampCenter(Offset(anchor.ax * box.width, anchor.ay * box.height), box);
  }

  Offset _clampCenter(Offset c, Size box) {
    final half = _fabSize / 2;
    final minX = half + _fabMargin;
    final maxX = box.width - half - _fabMargin;
    final minY = half + _fabMargin;
    final maxY = box.height - half - _fabMargin;
    // 极端窄小布局兜底（正常内容区恒大于按钮 + 双边距）
    if (maxX < minX || maxY < minY) return box.center(Offset.zero);
    return Offset(c.dx.clamp(minX, maxX), c.dy.clamp(minY, maxY));
  }

  void _onLongPressStart() {
    HapticFeedback.mediumImpact();
    setState(() => _dragging = true);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final render = _areaKey.currentContext?.findRenderObject();
    if (render is! RenderBox) return;
    final local = render.globalToLocal(details.globalPosition);
    final box = render.size;
    setState(() => _dragCenter = _clampCenter(local, box));
  }

  void _onLongPressEnd(Offset fallbackCenter, Size box) {
    final center = _dragCenter ?? fallbackCenter;
    HapticFeedback.selectionClick();
    setState(() {
      _dragging = false;
      _dragCenter = null;
    });
    widget.onPlacementChanged((
      ax: center.dx / box.width,
      ay: center.dy / box.height,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final center = _dragCenter ?? _resolveCenter(box);
        // 光晕框 = 按钮四周各扩 8，拖拽态渐显
        const haloPad = AppSpacing.sm;
        return Stack(
          key: _areaKey,
          fit: StackFit.expand,
          children: [
            Positioned(
              left: center.dx - _fabSize / 2 - haloPad,
              top: center.dy - _fabSize / 2 - haloPad,
              width: _fabSize + haloPad * 2,
              height: _fabSize + haloPad * 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onLongPressStart: (_) => _onLongPressStart(),
                onLongPressMoveUpdate: _onLongPressMoveUpdate,
                onLongPressEnd: (_) => _onLongPressEnd(center, box),
                child: Semantics(
                  button: true,
                  label: widget.semanticLabel,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 拖拽光晕：主色低透明度圆角框，明确「可移动」反馈
                      AnimatedOpacity(
                        opacity: _dragging ? 1 : 0,
                        duration: GlassMotion.state,
                        curve: GlassMotion.curve,
                        child: Container(
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.18),
                            borderRadius: AppRadius.cardAll,
                          ),
                        ),
                      ),
                      // 拖拽放大 1.12×（状态动效档位）
                      AnimatedScale(
                        scale: _dragging ? 1.12 : 1.0,
                        duration: GlassMotion.state,
                        curve: GlassMotion.curve,
                        child: GlassFab(icon: widget.icon, onTap: null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
