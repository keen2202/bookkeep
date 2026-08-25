import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';

/// FG-SEL 选中态（毛玻璃高亮，四层叠加；Spec §4.2 / 设计文档 §5.2，
/// BK-FG-013）：覆盖于宿主组件之上，宿主原 blur 不变。
///
/// 四层（未选中态四层全部不存在——整组移除，非 α0 常驻）：
/// ① 玻璃增亮——fill α 提升至 G3 档（浅 0.72 / 深 0.18），以「目标值 −
///    宿主填充」的增量层绘制（[hostFillAlpha] 缺省按 G2 面板取值）；
/// ② 柔和光晕——primary α0.25、blur 20、spread 0、offset 0/0；
/// ③ 透明叠加层——primary 垂直渐变 α 0.12→0.06（深色 0.10→0.05）；
/// ④ 描边——内侧高光 0.5px #FFFFFF α0.50（深 0.20）+ 外缘 0.5px
///    primary α0.30（深 0.35）。
///
/// 过渡：200ms cubic-bezier(0.4,0,0.2,1)，四层作为一个整体同步淡入淡出；
/// 禁止实色填充/左侧色条/仅文字变色作为唯一选中信号（AC-07）。
class GlassSelection extends StatelessWidget {
  const GlassSelection({
    super.key,
    required this.child,
    required this.selected,
    this.borderRadius,
    this.hostFillAlpha,
  });

  final Widget child;

  /// 选中态开关
  final bool selected;

  /// 覆盖层圆角（需与宿主容器一致以保证四层贴合）
  final BorderRadius? borderRadius;

  /// 宿主当前 fill α（用于计算层①增量；缺省按 G2 面板 0.60/0.12 处理，
  /// 表格行请传斑马纹实际值）
  final double? hostFillAlpha;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // 四层组合的同步过渡：出现/消失均为 200ms 整体渐变，
        // 未选中终态为空（层完全不存在，Spec §4.2 过渡行）
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: GlassMotion.state,
              switchInCurve: GlassMotion.curve,
              switchOutCurve: GlassMotion.curve,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              child: selected
                  ? _SelectionLayers(
                      key: const ValueKey('fg-sel-layers'),
                      borderRadius: borderRadius ?? BorderRadius.zero,
                      hostFillAlpha: hostFillAlpha,
                    )
                  : const SizedBox.shrink(key: ValueKey('fg-sel-none')),
            ),
          ),
        ),
      ],
    );
  }
}

/// 四层覆盖（单 Widget 保证四层同步过渡）
class _SelectionLayers extends StatelessWidget {
  const _SelectionLayers({
    super.key,
    required this.borderRadius,
    this.hostFillAlpha,
  });

  final BorderRadius borderRadius;
  final double? hostFillAlpha;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = context.tokens.isDark;

    // 层① 玻璃增亮增量 = 目标（G3 档）− 宿主当前值
    final target = dark ? GlassSelectionTokens.brightenFillDark : GlassSelectionTokens.brightenFillLight;
    final host = hostFillAlpha ?? (dark ? 0.12 : 0.60);
    final brightenDelta = (target - host).clamp(0.0, 1.0);

    return Container(
      // 层② 柔和光晕随外缘形状投射（primary α0.25、blur 20、spread 0、offset 0/0）
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: GlassSelectionTokens.glowAlpha),
            blurRadius: GlassSelectionTokens.glowBlur,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          // 层④ 外缘 primary 细线
          color: palette.primary.withValues(
              alpha:
                  dark ? GlassSelectionTokens.outerEdgeAlphaDark : GlassSelectionTokens.outerEdgeAlphaLight),
          width: 0.5,
        ),
        // 层① 玻璃增亮（白基增量层）
        color: Colors.white.withValues(alpha: brightenDelta),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          // 层④ 内侧白色高光细线
          color: Colors.white
              .withValues(alpha: dark ? GlassSelectionTokens.innerHighlightDark : GlassSelectionTokens.innerHighlightLight),
          width: 0.5,
        ),
        // 层③ primary 垂直渐变透明叠加层（顶→底）
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.primary.withValues(
                alpha: dark ? GlassSelectionTokens.overlayTopDark : GlassSelectionTokens.overlayTopLight),
            palette.primary.withValues(
                alpha:
                    dark ? GlassSelectionTokens.overlayBottomDark : GlassSelectionTokens.overlayBottomLight),
          ],
        ),
      ),
    );
  }
}
