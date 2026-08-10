/// 遮罩模式（Spec §2.3）：auto 智能（按亮度自动映射）/ manual 手动（滑杆）
enum OverlayMode {
  auto('智能'),
  manual('手动');

  const OverlayMode(this.label);
  final String label;
}

/// 背景图设置（Spec §2.3，app_meta 持久化；main() 启动注入）
///
/// [imagePath]：应用文档目录内相对路径（`background/bg.png`）；
/// [manualAlpha]：手动模式遮罩透明度 0.0 ~ 0.92（Spec §5.3 上限）。
class BackgroundSettings {
  const BackgroundSettings({
    this.enabled = false,
    this.imagePath,
    this.overlayMode = OverlayMode.auto,
    this.manualAlpha = 0.70,
    this.blurEnabled = true,
  });

  final bool enabled;

  /// 应用文档目录内相对路径；null 表示未设置图片
  final String? imagePath;
  final OverlayMode overlayMode;
  final double manualAlpha;
  final bool blurEnabled;

  static const defaults = BackgroundSettings();

  BackgroundSettings copyWith({
    bool? enabled,
    String? imagePath,
    bool clearImage = false,
    OverlayMode? overlayMode,
    double? manualAlpha,
    bool? blurEnabled,
  }) =>
      BackgroundSettings(
        enabled: enabled ?? this.enabled,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        overlayMode: overlayMode ?? this.overlayMode,
        manualAlpha: manualAlpha ?? this.manualAlpha,
        blurEnabled: blurEnabled ?? this.blurEnabled,
      );
}
