import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass/glass_layers.dart';
import '../theme/glass/glass_panel.dart';
import '../theme/tokens.dart';

/// 按钮变体（设计文档 §3.4；v3 新增 glass 玻璃变体）
enum AppButtonVariant { primary, secondary, text, danger, glass }

/// 统一按钮（Spec §6 + Glassmorphism v3 §5.2）：高 48、圆角 md、
/// 按压 96% 缩放 + 填充加深（150ms）、loading 内置 spinner 防重入。
///
/// v3 玻璃化升级（GLS-006）：
/// - primary →「品牌色玻璃」（primary α0.90 叠白高光）；
/// - secondary/glass → 中性玻璃（L2 吸附层填充）；
/// - danger → expense α0.90 玻璃；
/// - text 不变；
/// - hover：描边 α+0.08 / 高光 +0.05（120ms）；focus：primary 2px 外环 +
///   primary α0.18 blur8 外晕（150ms）；press：scale 0.96 + scrim +0.08。
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.block = false,
  });

  /// 主按钮：品牌色玻璃（primary α0.90 + 白高光）
  const AppButton.primary({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
  }) : variant = AppButtonVariant.primary;

  /// 次按钮：中性玻璃（L2 填充）
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

  /// 危险操作：expense α0.90 玻璃
  const AppButton.danger({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
  }) : variant = AppButtonVariant.danger;

  /// 玻璃变体（v3 §5.2）：中性玻璃 + 真实磨砂（high 档 BackdropFilter σ16）
  const AppButton.glass({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
  }) : variant = AppButtonVariant.glass;

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
  bool _focused = false;

  void _setPressed(bool v) {
    if (widget.variant == AppButtonVariant.text) return;
    if (v == _pressed) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == AppButtonVariant.text) {
      return _buildTextButton(context);
    }
    return _buildGlassButton(context);
  }

  // -------------------------------------------------------------------------
  // 文字按钮（保持 v2 行为，不参与玻璃语言）
  // -------------------------------------------------------------------------
  Widget _buildTextButton(BuildContext context) {
    final palette = context.palette;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? palette.textDisabled
            : palette.primary,
      ),
      textStyle: WidgetStatePropertyAll(context.text.labelLarge),
    );
    final label = widget.loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
          )
        : widget.child;
    return SizedBox(
      width: widget.block ? double.infinity : null,
      child: TextButton(
        onPressed:
            widget.onPressed != null && !widget.loading ? widget.onPressed : null,
        style: style,
        child: label,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 玻璃按钮（primary/secondary/danger/glass 四变体共用管线）
  // -------------------------------------------------------------------------
  Widget _buildGlassButton(BuildContext context) {
    final palette = context.palette;
    final appColors = context.appColors;
    final enabled = widget.onPressed != null && !widget.loading;

    // L2 吸附层规格（§5.2：玻璃按钮取 dock 层填充与描边）；
    // 渲染复用 GlassPanel（D1 单一玻璃出口，BackdropFilter 不在按钮内自建）
    final dockSpec = resolveGlassSpec(
      tier: GlassTier.dock,
      brightness: context.tokens.brightness,
      palette: palette,
      quality: context.tokens.glassQuality,
    );

    final (Color baseFill, Color fg) = switch (widget.variant) {
      // 中性玻璃基（L2 填充）；primary/danger 在其上做品牌/语义着色
      AppButtonVariant.primary ||
      AppButtonVariant.glass ||
      AppButtonVariant.secondary =>
        (dockSpec.fill, palette.textPrimary),
      AppButtonVariant.danger => (dockSpec.fill, appColors.expense),
      _ => (dockSpec.fill, palette.textPrimary),
    };
    // primary 变体的品牌着色：主操作以 primary α0.90 叠加于中性玻璃之上，
    // 前景 onPrimary（§5.2 主操作着色）
    var fill = widget.variant == AppButtonVariant.primary
        ? Color.alphaBlend(palette.primary.withValues(alpha: 0.90), dockSpec.fill)
        : baseFill;
    if (widget.variant == AppButtonVariant.danger) {
      fill =
          Color.alphaBlend(appColors.expense.withValues(alpha: 0.90), dockSpec.fill);
    }
    final foregroundColor = switch (widget.variant) {
      AppButtonVariant.primary => palette.onPrimary,
      AppButtonVariant.danger =>
        ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
            ? Colors.white
            : palette.textPrimary,
      _ => fg,
    };

    final radius = BorderRadius.circular(AppRadius.md);

    final surface = GlassPanel(
      tier: GlassTier.dock,
      borderRadius: radius,
      onTap: enabled ? widget.onPressed : null,
      colorOverride: fill,
      child: SizedBox(
        height: 48,
        child: Center(
          child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 120),
          style: (context.text.labelLarge ?? const TextStyle())
              .copyWith(color: foregroundColor),
          child: widget.loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                )
              : IconTheme.merge(
                  data: IconThemeData(color: foregroundColor, size: 18),
                  child: widget.child,
                ),
          ),
        ),
      ),
    );

    // focus 外环 + 光晕（primary 2px + primary α0.18 blur8，150ms；
    // 常驻 2px 内边距保证聚焦态零布局位移）
    Widget button = Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: _focused ? palette.primary : Colors.transparent,
            width: 2,
          ),
        ),
        foregroundDecoration: BoxDecoration(borderRadius: radius),
        child: surface,
      ),
    );
    if (_focused) {
      button = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.18),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: button,
      );
    }

    button = Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: button,
          ),
        ),
      ),
    );

    // 按压 96% 缩放（150ms easeOutCubic，沿用 v2 Listener 手势管线）
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
