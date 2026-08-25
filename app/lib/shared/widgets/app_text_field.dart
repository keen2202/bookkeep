import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';

/// FG-INP 统一输入框（Spec §4.8；BK-FG-023）：
/// - 材质：G2 基材、fill 降至 α0.45（浅）/0.10（深），与卡片区分
///   （主题 inputDecorationTheme 单源提供）；
/// - 圆角 12 / 高度 44；
/// - 聚焦：内高光 α +0.05（顶部渐变近似）+ 2px 外环 primary α0.50；
/// - 错误：外环 danger α0.60，下方错误文字 danger 色；
/// - 禁用：fill α0.24/0.05、文字 text.disabled。
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

  /// 禁用态（false 时按 §4.8 禁用参数渲染且不可交互）
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _internalFocus;

  FocusNode get _effectiveFocus =>
      widget.focusNode ?? (_internalFocus ??= FocusNode());

  @override
  void dispose() {
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _effectiveFocus,
      builder: (context, _) {
        final focused = _effectiveFocus.hasFocus && widget.enabled;
        // 聚焦内高光增强：顶部白色渐变（基准 +0.05，Spec §4.8 聚焦行）
        final highlightAlpha = focused
            ? resolveGlassSpec(
                    level: GlassLevel.g2, brightness: context.tokens.brightness)
                .topHighlightAlpha +
                GlassInputTokens.focusHighlightBoost
            : null;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            gradient: focused
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, GlassInputTokens.focusHighlightBoost * 4),
                    colors: [
                      Colors.white.withValues(alpha: highlightAlpha!),
                      Colors.transparent,
                    ],
                  )
                : null,
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
              // 禁用态降档填充（Spec §4.8：fill α 0.24 浅 / 0.05 深）
              fillColor: !widget.enabled
                  ? Colors.white.withValues(
                      alpha: context.tokens.isDark
                          ? GlassInputTokens.disabledFillDark
                          : GlassInputTokens.disabledFillLight)
                  : null,
            ),
          ),
        );
      },
    );
  }
}
