import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import 'glass_icon.dart';
import 'glass_panel.dart';
import 'glass_selection.dart';

/// AppBar 动作按钮：28 档 [GlassIcon] 容器 + tooltip（旧 GlassIconButton
/// 的 FG-ICON 收敛出口）
class GlassAppBarAction extends StatelessWidget {
  const GlassAppBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.tint = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool tint;

  @override
  Widget build(BuildContext context) {
    Widget action = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: GlassIcon(icon: icon, size: GlassIconSize.s28, tint: tint),
    );
    if (tooltip != null) {
      action = Tooltip(message: tooltip!, child: action);
    }
    return action;
  }
}

/// FG-NAV 吸顶 AppBar（Spec §4.6；BK-FG-021）：G3 吸附层（σ28、fill
/// 0.72/0.18），通栏圆角 0；底部分隔线 0.5px——静止于顶部时隐藏，
/// 滚动后渐显（浅色 #000 α0.08 / 深色 #FFF α0.10，iOS 惯例）。
///
/// [elevation]（滚动距离比例）驱动分隔线透明度；真实磨砂由内建
/// BackdropFilter 承载，滚动内容从其下方穿过时被实时柔化。
class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions = const [],
    this.leading,
    this.showDivider = false,
  });

  final Widget? title;
  final List<Widget> actions;
  final Widget? leading;

  /// 分隔线渐显开关（滚动 >0 时为 true）
  final bool showDivider;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends State<GlassAppBar> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = context.tokens.isDark;
    return GlassPanel(
      level: GlassLevel.g3,
      borderRadius: BorderRadius.zero,
      shadows: false,
      padding: EdgeInsets.zero,
      // edge-to-edge（main.dart：透明状态栏；Android 15+/16 强制全屏绘制）：
      // 玻璃层通铺到状态栏下方保持磨砂观感，工具栏行经 [SafeArea] 下移系统
      // 状态栏高度——对齐内建 AppBar 的 primary 行为，修复标题/动作按钮与
      // 手机状态栏重合。preferredSize 保持 kToolbarHeight：Scaffold 会把
      // 状态栏高度追加进 appBar 槽位可用高度，此处自然高度恰好填满。
      child: SafeArea(
        bottom: false,
        // Stack 固定总高 = kToolbarHeight：工具栏行占满，分隔线以
        // Positioned 叠加于底缘——亚像素舍入不产生 RenderFlex 溢出
        child: SizedBox(
          height: kToolbarHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NavigationToolbar(
                leading: widget.leading,
                middle: DefaultTextStyle.merge(
                  style: context.text.titleLarge,
                  child: widget.title ?? const SizedBox.shrink(),
                ),
                trailing:
                    Row(mainAxisSize: MainAxisSize.min, children: widget.actions),
                centerMiddle: false,
                middleSpacing: AppSpacing.sm,
              ),
              // 滚动联动分隔线：静止隐藏 → 滚动渐显（200ms）
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: GlassMotion.state,
                  curve: GlassMotion.curve,
                  height: 0.5,
                  color: palette.divider.withValues(
                    alpha: widget.showDivider
                        ? (dark
                            ? GlassTableTokens.headerDividerAlphaDark
                            : GlassTableTokens.headerDividerAlphaLight)
                        : 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// FG-NAV 玻璃页面脚手架：Scaffold + G3 吸顶 [GlassAppBar] 的组合出口，
/// 内建「滚动后分隔线渐显」联动（body 内任意可滚动组件的
/// UserScrollNotification 均可驱动）。
class GlassScaffold extends StatefulWidget {
  const GlassScaffold({
    super.key,
    this.title,
    this.actions = const [],
    this.leading,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final Widget? title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget body;

  /// 悬浮按钮（如账户页「新建账户」FAB）
  final Widget? floatingActionButton;

  /// 覆盖 Scaffold 底色（默认主题白名单底色）
  final Color? backgroundColor;

  @override
  State<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<GlassScaffold> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: GlassAppBar(
          title: widget.title,
          actions: widget.actions,
          // 对齐原 AppBar 行为：可返回路由自动提供返回键
          leading: widget.leading ??
              ((ModalRoute.of(context)?.canPop ?? false)
                  ? const BackButton()
                  : null),
          showDivider: _scrolled,
        ),
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          final scrolled = n.metrics.pixels > 0;
          if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
          return false;
        },
        child: widget.body,
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

/// FG-NAV 底部导航项（Spec §4.6：图标项用 28 档 G1 容器，选中项套 FG-SEL）
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.label,
    this.tintIcon,
  });

  final IconData icon;
  final String label;

  /// 选中时替换的 tint 图标（可选）
  final IconData? tintIcon;
}

/// 底栏中央动作（BK-DOC-28 需求6）：夹在两个 Tab 之间的主操作按钮。
/// 非 Tab 项——不参与 [GlassBottomBar.selectedIndex] 选中态，点按不切换页面。
typedef GlassCenterAction = ({
  IconData icon,
  String semanticLabel,
  VoidCallback onTap,
});

/// 中央动作按钮直径（底栏内收敛尺寸；[GlassFab] 的 56 用于内容区悬浮）
const double _centerActionSize = 48;

/// FG-NAV 底部导航栏（Spec §4.6；BK-FG-021）：G3 通栏玻璃 + 顶部
/// 0.5px 分隔线（滚动联动语义同 AppBar）；图标项 28 档 [GlassIcon]，
/// 选中项以 [GlassSelection] 呈现 FG-SEL 四层。
///
/// [centerAction] 非空时在 items 中点插入固定 [_centerActionSize] 圆形主操作
/// 按钮（BK-DOC-28 需求6：记账入口下沉底栏中央、不可拖拽），两侧 Tab 经
/// [Expanded] 均分剩余宽度；为 null 时与纯 items 均分布局完全一致。
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.showDivider = false,
    this.centerAction,
  });

  final List<GlassNavItem> items;

  final int selectedIndex;
  final ValueChanged<int> onTap;

  final bool showDivider;

  /// 中央主操作按钮（可选；null = 纯 items 均分布局）
  final GlassCenterAction? centerAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = context.tokens.isDark;
    return GlassPanel(
      level: GlassLevel.g3,
      borderRadius: BorderRadius.zero,
      shadows: false,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部分隔线（滚动后渐显，iOS 惯例）
          AnimatedContainer(
            duration: GlassMotion.state,
            curve: GlassMotion.curve,
            height: 0.5,
            color: palette.divider.withValues(
              alpha: showDivider
                  ? (dark
                      ? GlassTableTokens.headerDividerAlphaDark
                      : GlassTableTokens.headerDividerAlphaLight)
                  : 0,
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  // 中央动作槽插在 items 中点（2 Tab → [Tab0][＋][Tab1]）
                  if (centerAction != null && i == items.length ~/ 2)
                    _centerButton(context, centerAction!),
                  Expanded(child: _item(context, i)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, int i) {
    final item = items[i];
    final selected = i == selectedIndex;
    final palette = context.palette;
    return InkWell(
      onTap: () => onTap(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标项：28 档 G1 容器；选中项套 FG-SEL 四层（宿主 fill 为 G1 α）
            GlassSelection(
              selected: selected,
              hostFillAlpha: context.tokens.isDark
                  ? GlassLevel.g1.fillAlphaDark
                  : GlassLevel.g1.fillAlphaLight,
              borderRadius: BorderRadius.circular(
                  GlassIconTokens.size28 * GlassIconTokens.radiusFactor),
              child: GlassIcon(
                icon: selected && item.tintIcon != null
                    ? item.tintIcon!
                    : item.icon,
                size: GlassIconSize.s28,
                tint: selected,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.label,
              style: context.text.labelSmall?.copyWith(
                color: selected ? palette.primary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 中央主操作按钮：与 [GlassFab] 同一主操作着色玻璃配方（G5 + primary
  /// fill α 走 [GlassButtonTokens]），尺寸收敛为 [_centerActionSize] 圆形以
  /// 适配底栏高度；不参与 Tab 选中态（BK-DOC-28 需求6）。
  Widget _centerButton(BuildContext context, GlassCenterAction action) {
    final palette = context.palette;
    final dark = context.tokens.isDark;
    final fill = palette.primary.withValues(
      alpha: dark
          ? GlassButtonTokens.primaryFillDark
          : GlassButtonTokens.primaryFillLight,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: action.semanticLabel,
        child: GlassPanel(
          level: GlassLevel.g5,
          borderRadius: AppRadius.pillAll,
          fillOverride: fill,
          onTap: action.onTap,
          child: SizedBox.square(
            dimension: _centerActionSize,
            child: Center(
              child: Icon(action.icon, size: 24, color: palette.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// FG-OVL FAB（Spec §4.7；BK-FG-022）：G5 着色玻璃 56×56、圆角 16，
/// 主操作着色同 FG-BTN 主按钮（primary α0.75/0.65），白色实色图标。
class GlassFab extends StatelessWidget {
  const GlassFab({super.key, required this.icon, this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = context.tokens.isDark;
    final fill = palette.primary.withValues(
      alpha: dark
          ? GlassButtonTokens.primaryFillDark
          : GlassButtonTokens.primaryFillLight,
    );
    Widget fab = GlassPanel(
      level: GlassLevel.g5,
      borderRadius: AppRadius.cardAll,
      fillOverride: fill,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 56,
        child: Center(
          child: Icon(icon, size: 24, color: palette.onPrimary),
        ),
      ),
    );
    if (tooltip != null) {
      fab = Tooltip(message: tooltip!, child: fab);
    }
    return fab;
  }
}
