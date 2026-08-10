import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 统一输入框（设计文档 §3.4 / Spec §6）：填充 surfaceVariant、圆角 sm、
/// 聚焦描边 primary 2px、错误态 expense 描边 + 12sp 错误文案。
/// 视觉规格全部来自主题 InputDecorationTheme（app_theme.dart 组装），
/// 本组件只做参数收敛与语义化封装。
class AppTextField extends StatelessWidget {
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
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      autofocus: autofocus,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        prefixIcon: prefix,
        suffixIcon: suffix,
        counterText: maxLength == null ? null : '',
      ),
    );
  }
}
