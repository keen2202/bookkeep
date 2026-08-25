import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import 'glass_panel.dart';

/// FG-OVL 统一底部弹层（Spec §4.7；BK-FG-022）：G4 玻璃面板（σ36、fill
/// 0.80/0.24）、顶部圆角 20、底部贴边、背板遮罩 α0.32；入场位移沿用
/// showModalBottomSheet 默认 250ms 动画（Spec §6 浮层进出）。
/// showModalBottomSheet 的全项目收敛出口。
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.title,
    this.padding = AppSpacing.sheetPadding,
  });

  final Widget child;

  /// 可选标题（title 字阶，居中）
  final String? title;

  /// 内容区内边距（默认 sheetPadding：左右 16 / 上 8 / 下 16）
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassPanel(
      level: GlassLevel.g4,
      borderRadius: AppRadius.sheetTop,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Padding(
          // 键盘弹起时整体上移
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽柄 32×4
              Padding(
                padding: const EdgeInsets.only(
                    top: AppSpacing.sm, bottom: AppSpacing.xs),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textTertiary,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(title!, style: context.text.titleLarge),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: padding,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹出统一底部弹层（isScrollControlled，内容自适应高度）；
/// 遮罩为 Spec §2.3 glass.scrim α0.32。
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required Widget child,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: GlassBackground.scrimOf(Colors.black),
    builder: (_) => AppSheet(title: title, child: child),
  );
}
