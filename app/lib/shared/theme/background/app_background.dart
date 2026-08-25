import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../glass_tokens.dart';
import '../glass_prefs.dart';
import '../../widgets/glass_panel.dart';

/// 全局应用背景部件（FGDS v1.0，Spec §2.2 背景硬约束；BK-FG-002）：
///
/// - 只渲染白名单底色 `#F2F2F7`（浅）/ `#000000`（深），或同色系垂直
///   单色微渐变（明度差 ≤3%）——默认取纯色路径；
/// - 旧 `ambient` Mesh 渐变、光斑绘制、漂移动画与背景图模式已全部拆除
///   （设计文档 §3 禁止清单，AC-02 扫描零残留）；
/// - 接入位置：MaterialApp.builder（Navigator 之上），二级页与弹层共享
///   同一背景；同时注入 [GlassPrefsScope]（玻璃降级偏好作用域）。
class AppBackground extends ConsumerWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = context.tokens.brightness;
    final dark = brightness == Brightness.dark;
    final blurEnabled =
        ref.watch(glassPrefsProvider.select((p) => p.blurEnabled));
    return _statusBarRegion(
      dark: dark,
      child: GlassPrefsScope(
        blurEnabled: blurEnabled,
        child: ColoredBox(
          // Spec §2.2：背景白名单唯二底色（纯色路径）
          color: dark ? GlassBackground.baseDark : GlassBackground.baseLight,
          child: child,
        ),
      ),
    );
  }

  /// 状态栏/导航栏图标明暗（AnnotatedRegion 置于 Navigator 之上全局生效）
  Widget _statusBarRegion({required bool dark, required Widget child}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
