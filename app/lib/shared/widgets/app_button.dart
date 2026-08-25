import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';

/// 按钮变体（FGDS v1.0，Spec §4.4）：
/// - [AppButtonVariant.primary] 主操作：主题色着色玻璃（非实色，AC-07）；
/// - [AppButtonVariant.secondary] 次级：无色玻璃（G2 基材五态矩阵）；
/// - [AppButtonVariant.danger] 危险操作：danger 色着色玻璃；
/// - [AppButtonVariant.text] 文字按钮。
enum AppButtonVariant { primary, secondary, text, danger }

/// FG-BTN 统一按钮（Spec §4.4 状态参数矩阵；BK-FG-011）：
///
/// 次级玻璃按钮五态（浅色值；深色见 [GlassButtonTokens] 双值表）：
///
/// | 状态 | blur σ | fill α | 其他 |
/// |------|--------|--------|------|
/// | 默认 | 20 | 0.60(0.12) | G2 标准双层描边 |
/// | Hover | 24 | 0.68(0.16) | 内高光 +0.05，150ms |
/// | Pressed | 16 | 0.48(0.09) | scale 0.98 + 内阴影 |
/// | Focus | 20 | 0.60(0.12) | +2px 外环 primary α0.50 |
/// | 禁用 | 8 | 0.32(0.06) | 去高光、文字 disabled |
///
/// 主操作着色玻璃：blur σ20 不变；fill = primary α0.75(0.65)，文字 #FFFFFF
/// 实色；hover/pressed 仅变 fill α（+0.08 / −0.10）与 scale；禁用 fill α0.30、
/// 文字 α0.50。通用规格：高 44/32、圆角 12（胶囊可选）、水平 padding 20、
/// 文字 15/600。全部数值来自 [GlassButtonTokens]（AC-01 单源）。
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.block = false,
    this.compact = false,
    this.capsule = false,
  });

  /// 主操作按钮：主题色着色玻璃
  const AppButton.primary({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
    this.compact = false,
    this.capsule = false,
  }) : variant = AppButtonVariant.primary;

  /// 次级按钮：中性玻璃
  const AppButton.secondary({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
    this.compact = false,
    this.capsule = false,
  }) : variant = AppButtonVariant.secondary;

  /// 文字按钮
  const AppButton.text({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
    this.compact = false,
    this.capsule = false,
  }) : variant = AppButtonVariant.text;

  /// 危险操作按钮：danger 色着色玻璃
  const AppButton.danger({
    super.key,
    required this.child,
    this.onPressed,
    this.loading = false,
    this.block = false,
    this.compact = false,
    this.capsule = false,
  }) : variant = AppButtonVariant.danger;

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// 加载态：内置 spinner，禁止重复点击
  final bool loading;

  /// 是否撑满父宽
  final bool block;

  /// 紧凑档（高 32）
  final bool compact;

  /// 胶囊形态（全圆角）
  final bool capsule;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    if (widget.variant == AppButtonVariant.text) {
      return _buildTextButton(context);
    }
    return _buildGlassButton(context);
  }

  // -------------------------------------------------------------------------
  // 文字按钮
  // -------------------------------------------------------------------------
  Widget _buildTextButton(BuildContext context) {
    final palette = context.palette;
    final height = widget.compact
        ? GlassButtonTokens.heightCompact
        : GlassButtonTokens.heightStandard;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(64, height)),
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
            child:
                CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
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
  // 玻璃按钮：五态矩阵（Spec §4.4）
  // -------------------------------------------------------------------------
  Widget _buildGlassButton(BuildContext context) {
    final palette = context.palette;
    final dark = context.tokens.isDark;

    final isTinted = widget.variant != AppButtonVariant.secondary;
    final tint = widget.variant == AppButtonVariant.danger
        ? (dark ? GlassThemeColors.dangerDark : GlassThemeColors.dangerLight)
        : palette.primary;

    // ── 状态解析（次级按钮五态矩阵 / 着色玻璃恒 σ20 仅调 fill）──
    double sigma;
    double highlightAlpha;
    Color fill;

    if (!_enabled) {
      sigma = isTinted ? GlassButtonTokens.blurDefault : GlassButtonTokens.blurDisabled; // 禁用 σ8（主按钮恒 20）
      highlightAlpha = 0; // 禁用去内高光
      fill = isTinted
          ? tint.withValues(alpha: GlassButtonTokens.primaryDisabledFill)
          : Colors.white
              .withValues(alpha: dark ? GlassButtonTokens.fillDisabledDark : GlassButtonTokens.fillDisabledLight);
    } else if (isTinted) {
      // 主操作/危险着色玻璃：σ20 不变，fill 仅随 hover/pressed 微调
      var alpha = dark ? GlassButtonTokens.primaryFillDark : GlassButtonTokens.primaryFillLight;
      if (_pressed) {
        alpha = (alpha - GlassButtonTokens.primaryPressedDrop).clamp(0.0, 1.0);
      } else if (_hover) {
        alpha = (alpha + GlassButtonTokens.primaryHoverBoost).clamp(0.0, 1.0);
      }
      sigma = GlassButtonTokens.blurDefault;
      highlightAlpha =
          resolveGlassSpec(level: GlassLevel.g2, brightness: palette.brightness)
              .borderInnerHighlight
              .a;
      fill = tint.withValues(alpha: alpha);
    } else if (_pressed) {
      sigma = GlassButtonTokens.blurPressed;
      highlightAlpha =
          resolveGlassSpec(level: GlassLevel.g2, brightness: palette.brightness)
              .borderInnerHighlight
              .a;
      fill = Colors.white
          .withValues(alpha: dark ? GlassButtonTokens.fillPressedDark : GlassButtonTokens.fillPressedLight);
    } else if (_hover) {
      sigma = GlassButtonTokens.blurHover;
      highlightAlpha = resolveGlassSpec(
                  level: GlassLevel.g2, brightness: palette.brightness)
              .borderInnerHighlight
              .a +
          GlassButtonTokens.hoverHighlightBoost; // 内高光 α +0.05
      fill = Colors.white
          .withValues(alpha: dark ? GlassButtonTokens.fillHoverDark : GlassButtonTokens.fillHoverLight);
    } else {
      sigma = GlassButtonTokens.blurDefault;
      highlightAlpha =
          resolveGlassSpec(level: GlassLevel.g2, brightness: palette.brightness)
              .borderInnerHighlight
              .a;
      fill = Colors.white
          .withValues(alpha: dark ? GlassButtonTokens.fillDefaultDark : GlassButtonTokens.fillDefaultLight);
    }

    // 文字色：着色玻璃白字实色（禁用 α0.50）；次级 textPrimary / textDisabled
    final foreground = isTinted
        ? palette.onPrimary.withValues(
            alpha: !_enabled ? GlassButtonTokens.primaryDisabledTextAlpha : 1.0)
        : (_enabled ? palette.textPrimary : palette.textDisabled);

    final radius = BorderRadius.circular(
        widget.capsule ? AppRadius.pill : AppRadius.md);
    final height = widget.compact
        ? GlassButtonTokens.heightCompact
        : GlassButtonTokens.heightStandard;

    final surface = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: AnimatedContainer(
          duration: GlassMotion.micro,
          curve: GlassMotion.curve,
          height: height,
          padding: const EdgeInsets.symmetric(
              horizontal: GlassButtonTokens.horizontalPadding),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(
              color: resolveGlassSpec(
                      level: GlassLevel.g2, brightness: palette.brightness)
                  .borderOuter,
              width: 0.5,
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: highlightAlpha),
              width: 0.5,
            ),
            // Pressed 顶部内阴影近似（inset 0/1/3 #000 α0.08）
            gradient: _pressed
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, 0.10),
                    colors: [
                      Colors.black
                          .withValues(alpha: GlassButtonTokens.pressedInnerShadowAlpha),
                      Colors.transparent,
                    ],
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: GlassMotion.micro,
            style: (context.text.labelLarge ?? const TextStyle())
                .copyWith(color: foreground),
            child: widget.loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : IconTheme.merge(
                    data: IconThemeData(color: foreground, size: 18),
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );

    // Focus：2px 外环 primary α0.50（键盘导航可见；常驻 3px 余量防位移）
    Widget button = Padding(
      padding: const EdgeInsets.all(3),
      child: AnimatedContainer(
        duration: GlassMotion.state,
        curve: GlassMotion.curve,
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: _focused && _enabled
                ? palette.primary.withValues(alpha: GlassButtonTokens.focusRingAlpha)
                : Colors.transparent,
            width: GlassButtonTokens.focusRingWidth,
          ),
        ),
        child: surface,
      ),
    );

    button = Semantics(
      button: true,
      enabled: _enabled,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) {
          if (_enabled && !_hover) setState(() => _hover = true);
        },
        onExit: (_) {
          if (_hover) setState(() => _hover = false);
        },
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? widget.onPressed : null,
            onTapDown: (_) {
              if (_enabled) setState(() => _pressed = true);
            },
            onTapUp: (_) {
              if (_pressed) setState(() => _pressed = false);
            },
            onTapCancel: () {
              if (_pressed) setState(() => _pressed = false);
            },
            child: button,
          ),
        ),
      ),
    );

    // Pressed scale 0.98（150ms，Spec §6 微交互）
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: GlassMotion.micro,
      curve: GlassMotion.curve,
      child: SizedBox(
        width: widget.block ? double.infinity : null,
        child: button,
      ),
    );
  }
}
