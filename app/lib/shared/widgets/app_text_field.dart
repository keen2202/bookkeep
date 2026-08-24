import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// 统一输入框（设计文档 §3.4 / Spec §6 + Glassmorphism v3 §5.1，GLS-006）：
/// 填充改玻璃（浅色白 α0.12 / 深色白 α0.06，由主题 inputDecorationTheme
/// 提供 0x1FFFFFFF / 0x0FFFFFFF）、圆角 sm、聚焦描边 primary 2px、错误态
/// expense 描边 + 12sp 错误文案。
///
/// v3 focus 光晕：外层 AnimatedContainer 提供 primary α0.18 blur12 光晕 +
/// primary 2px 描边（180ms easeOut）；hover 描边白 0.35（120ms）；error 光晕
/// 随 expense 色。视觉规格来自主题 InputDecorationTheme，本组件做光晕包装
/// 与参数收敛。
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.error,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.onChanged,
    this.onTap,
    this.focusNode,
  });

  final TextEditingController? controller;

  /// 浮动标签
  final String? label;

  final String? hint;

  /// 错误文案（非空即错误态）
  final String? error;

  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool autofocus;
  final bool readOnly;

  /// 禁用态（false 时降低不透明度且不可交互）
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _internalFocus;
  bool _hover = false;

  FocusNode get _effectiveFocus =>
      widget.focusNode ?? (_internalFocus ??= FocusNode());

  @override
  void dispose() {
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final appColors = context.appColors;
    return ListenableBuilder(
      listenable: _effectiveFocus,
      builder: (context, _) {
        final focused = _effectiveFocus.hasFocus;
        final hasError = widget.error != null && widget.error!.isNotEmpty;
        // focus 光晕：primary α0.18 blur12（180ms）；error 态随 expense 色
        final glowColor = hasError ? appColors.expense : palette.primary;
        return MouseRegion(
          cursor: WidgetStateMouseCursor.clickable.resolve({}),
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: Duration(milliseconds: focused || hasError ? 180 : 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: AppRadius.smAll,
              border: Border.all(
                color: _hover && !focused && !hasError
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: focused || hasError
                  ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _effectiveFocus,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              maxLength: widget.maxLength,
              maxLines: widget.maxLines,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              onChanged: widget.onChanged,
              onTap: widget.onTap,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                errorText: widget.error,
                prefixIcon: widget.prefix,
                suffixIcon: widget.suffix,
                counterText: widget.maxLength == null ? null : '',
                // hover 描边白 0.35（120ms，v3 §5.2 输入框行）
                enabledBorder: _hover
                    ? OutlineInputBorder(
                        borderRadius: AppRadius.smAll,
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
