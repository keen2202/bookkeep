import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../glass/glass_panel.dart';
import '../glass/glass_quality.dart';
import '../theme_presets.dart';
import 'ambient_gradient.dart';
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

/// 全局应用背景部件（BK-UI-014，设计文档 §5.1）：
/// - 无背景图：主题环境光渐变（[AmbientGradient]，玻璃拟态默认光环境）；
/// - 有背景图：背景图 → 智能遮罩（主题 background 色 × α）→ 8px 高斯模糊
///   → 内容层。
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
    // 审核 F2：渲染侧消费 backgroundImageFileProvider（绝对路径解析），
    // null（未启用/未选图/文件缺失）走"无背景图"分支
    final imageFile = ref.watch(backgroundImageFileProvider).valueOrNull;
    // v3（GLS-014 渲染桥）：把持久化玻璃偏好投影为 InheritedWidget 作用域，
    // 背景/玻璃渲染层零 Provider 依赖；锁定态经真实锁控制器注入
    final prefs = ref.watch(glassPrefsProvider);
    // 锁定态作用域由壳层（app.dart builder）在更外层注入，此处只投影玻璃偏好
    Widget scope({required Widget child}) => GlassPrefsScope(
      motionEnabled: prefs.motionEnabled,
      intensity: prefs.intensity,
      child: child,
    );
    if (imageFile == null) {
      // 无背景图：渲染主题环境光渐变（v3 动态环境光，设计文档 §4）；
      // 状态栏图标按主题明暗
      final dark = context.tokens.isDark;
      return _statusBarRegion(
        dark: dark ? Brightness.light : Brightness.dark,
        child: scope(
          child: GlassImageModeScope(
            enabled: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // RepaintBoundary 隔离渐变层：内容滚动不连带背景重绘；
                // v3 动效仅重绘本边界内的画布（D4 成本锁死在背景层）
                RepaintBoundary(child: AmbientGradient()),
                Positioned.fill(child: child),
              ],
            ),
          ),
        ),
      );
    }

    final settings = ref.watch(
      backgroundControllerProvider.select((s) => s.valueOrNull),
    );
    final imageL = ref.watch(backgroundLuminanceProvider).valueOrNull;
    final visuals = backgroundVisuals(
      settings: settings ?? BackgroundSettings.defaults,
      imageL: imageL,
      palette: context.palette,
      dark: context.tokens.isDark,
    );

    final imageRevision = ref.watch(backgroundRevisionProvider);
    final decodeWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();

    return _statusBarRegion(
      dark: visuals.darkStatusIcons ? Brightness.dark : Brightness.light,
      child: scope(
        child: GlassImageModeScope(
          // v3 §4.6：背景图模式下 L1 玻璃填充加厚 +0.06（上限 0.80）
          enabled: true,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景层整体包在 IgnorePointer 中：图/遮罩/模糊只做视觉，
                // 不参与命中测试，确保 TabBar、FAB、按钮等交互元素不被遮挡。
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ① 背景图（绝对路径；cacheWidth 限解码尺寸，Spec §5.4.5 / §10 内存）。
                        // Key 绑定热重载版本号，确保同一路径覆盖选图后立即重新解码。
                        Image(
                          image: ResizeImage(
                            RevisionFileImage(
                              imageFile,
                              revision: imageRevision,
                            ),
                            width: decodeWidth,
                          ),
                          key: ValueKey('bg-image-$imageRevision'),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                        // ② 智能遮罩（主题 background 色，保证卡片层级不被冲淡）
                        ColoredBox(
                          color: context.palette.background.withValues(
                            alpha: visuals.alpha,
                          ),
                        ),
                        // ③ 8px 高斯模糊（可关闭，Spec §5.2 / §10 性能）
                        if (settings?.blurEnabled ?? false)
                          BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: blurSigma,
                              sigmaY: blurSigma,
                            ),
                            child: const SizedBox.expand(),
                          ),
                      ],
                    ),
                  ),
                ),
                // ④ 内容层始终位于最上层且可命中。
                Positioned.fill(child: child),
              ],
            ),
          ),
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
