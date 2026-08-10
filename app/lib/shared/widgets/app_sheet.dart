import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// 统一底部弹层（设计文档 §3.4）：顶部圆角 lg、拖拽柄 32×4、背板 scrim 54%
/// （背板色由 BottomSheetThemeData.modalBarrierColor 提供），下滑关闭。
/// showModalBottomSheet 的全项目收敛出口（Spec §6）。
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
    return SafeArea(
      top: false,
      child: Padding(
        // 键盘弹起时整体上移
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                  color: palette.textDisabled,
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
    );
  }
}

/// 弹出统一底部弹层（isScrollControlled，内容自适应高度）
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
    builder: (_) => AppSheet(title: title, child: child),
  );
}
