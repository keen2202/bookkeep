import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// 按钮变体（设计文档 §3.4）
enum AppButtonVariant { primary, secondary, text, danger }

/// 统一按钮（Spec §6）：高 48、圆角 md、按压 96% 缩放 + 12% 加深遮罩（150ms）、
/// loading 内置 spinner 防重入。全项目 ElevatedButton/TextButton/OutlinedButton
/// 的收敛出口。
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.block = false,
  });

  /// 主按钮（primary + onPrimary）
  const AppButton.primary({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
  }) : variant = AppButtonVariant.primary;

  /// 次按钮（primaryContainer 浅底）
  const AppButton.secondary({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
  }) : variant = AppButtonVariant.secondary;

  /// 文字按钮
  const AppButton.text({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
  }) : variant = AppButtonVariant.text;

  /// 危险操作（expense 语义色）
  const AppButton.danger({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
  }) : variant = AppButtonVariant.danger;

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// 加载态：内置 spinner，禁止重复点击
  final bool loading;

  /// 是否撑满父宽
  final bool block;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.variant == AppButtonVariant.text) return;
    if (v == _pressed) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final appColors = context.appColors;
    final enabled = widget.onPressed != null && !widget.loading;

    final (Color? bg, Color fg) = switch (widget.variant) {
      AppButtonVariant.primary => (palette.primary, palette.onPrimary),
      AppButtonVariant.secondary => (palette.primaryContainer, palette.textPrimary),
      AppButtonVariant.danger => (
          appColors.expense,
          ThemeData.estimateBrightnessForColor(appColors.expense) == Brightness.dark
              ? Colors.white
              : palette.textPrimary,
        ),
      AppButtonVariant.text => (null, palette.primary),
    };

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      // 禁用态：主/危险按钮淡化底，前景统一 textDisabled（Flutter 3.44 移除
      // disabledBackgroundColor/disabledForegroundColor，改由 WidgetState 解析）
      backgroundColor: bg == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? palette.textDisabled.withValues(alpha: 0.24)
                  : bg,
            ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? palette.textDisabled
            : fg,
      ),
      // 按压 12% 加深遮罩
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? palette.scrim.withValues(alpha: 0.12)
            : null,
      ),
      textStyle: WidgetStatePropertyAll(context.text.labelLarge),
    );

    final label = widget.loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.variant == AppButtonVariant.text ? palette.primary : fg,
            ),
          )
        : widget.child;

    final Widget button = switch (widget.variant) {
      AppButtonVariant.text => TextButton(
          onPressed: enabled ? widget.onPressed : null,
          style: style,
          child: label,
        ),
      _ => ElevatedButton(
          onPressed: enabled ? widget.onPressed : null,
          style: style.copyWith(
            elevation: const WidgetStatePropertyAll(0),
          ),
          child: label,
        ),
    };

    // 按压 96% 缩放（150ms，easeOutCubic，设计文档 §3.4 动效）
    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: widget.block ? double.infinity : null,
          child: button,
        ),
      ),
    );
  }
}
