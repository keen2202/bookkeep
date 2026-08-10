import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../theme_presets.dart';
import 'background_controller.dart';
import 'background_settings.dart';
import 'luminance.dart';

/// 背景视觉参数（AppBackground 与外观页实时预览共用同一套计算）
class BackgroundVisuals {
  const BackgroundVisuals({
    required this.alpha,
    required this.effLum,
    required this.darkStatusIcons,
  });

  /// 遮罩透明度（智能模式经对比度闭环，手动模式取滑杆值）
  final double alpha;

  /// 遮罩后有效亮度
  final double effLum;

  /// 状态栏图标是否深色（Spec §5.3：effLum > 0.5 → 深色图标）
  final bool darkStatusIcons;
}

/// 由背景设置 + 图片亮度 + 主题调色板计算遮罩参数（Spec §5.2/§5.3）
BackgroundVisuals backgroundVisuals({
  required BackgroundSettings settings,
  required double? imageL,
  required ThemePalette palette,
  required bool dark,
}) {
  final l = imageL ?? 0.5; // 亮度未就绪（首次采样前）按中调处理
  final alpha = settings.overlayMode == OverlayMode.manual
      ? settings.manualAlpha.clamp(0.0, kOverlayAlphaCap)
      : resolveOverlayAlpha(
          imageL: l,
          background: palette.background,
          textPrimary: palette.textPrimary,
          dark: dark,
        );
  final effLum = effectiveLuminance(
    imageL: l,
    alpha: alpha,
    backgroundL: relativeLuminance(palette.background),
  );
  return BackgroundVisuals(
    alpha: alpha,
    effLum: effLum,
    darkStatusIcons: useDarkStatusIcons(effLum: effLum),
  );
}

/// 全局应用背景三层部件（BK-UI-014，设计文档 §5.1）：
/// 背景图 → 智能遮罩（主题 background 色 × α）→ 8px 高斯模糊 → 内容层。
///
/// 接入位置：MaterialApp.builder（Navigator 之上），二级页与弹层共享同一
/// 背景（跨页视觉连续，Spec §3.3）；[RepaintBoundary] 隔离背景层避免
/// 内容重绘连带背景重绘（Spec §10 低端机滚动掉帧缓解）。
class AppBackground extends ConsumerWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  /// 遮罩之上叠加的高斯模糊半径（设计文档 §5.2：8px，可关闭）
  static const double blurSigma = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(backgroundControllerProvider.select((s) => s.valueOrNull));
    final imagePath = settings?.imagePath;
    final enabled = settings?.enabled ?? false;
    if (settings == null || !enabled || imagePath == null) {
      // 无背景图：状态栏图标按主题明暗（原 AppBarTheme 静态取值迁移至此）
      final dark = context.tokens.isDark;
      return _statusBarRegion(
        dark: dark ? Brightness.light : Brightness.dark,
        child: child,
      );
    }

    final imageL = ref.watch(backgroundLuminanceProvider).valueOrNull;
    final visuals = backgroundVisuals(
      settings: settings,
      imageL: imageL,
      palette: context.palette,
      dark: context.tokens.isDark,
    );

    final decodeWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round();

    return _statusBarRegion(
      dark: visuals.darkStatusIcons ? Brightness.dark : Brightness.light,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ① 背景图（cacheWidth 限解码尺寸，Spec §5.4.5 / §10 内存）
            Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              cacheWidth: decodeWidth,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            // ② 智能遮罩（主题 background 色，保证卡片层级不被冲淡）
            ColoredBox(color: context.palette.background.withValues(alpha: visuals.alpha)),
            // ③ 8px 高斯模糊（可关闭，Spec §5.2 / §10 性能）
            if (settings.blurEnabled)
              BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: const SizedBox.expand(),
              ),
            child,
          ],
        ),
      ),
    );
  }

  /// 状态栏/导航栏图标明暗（AnnotatedRegion 置于 Navigator 之上全局生效；
  /// AppBar 不再自带 systemOverlayStyle，避免静态值覆盖动态计算）
  Widget _statusBarRegion({required Brightness dark, required Widget child}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark,
      ),
      child: child,
    );
  }
}
