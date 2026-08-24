import 'package:flutter/material.dart';

import '../theme/glass/glass_layers.dart';
import '../theme/glass/glass_panel.dart';
import '../theme/tokens.dart';

/// 统一卡片（设计文档 §3.4 / Spec §6；Glassmorphism v3 GLS-002）：
/// [GlassPanel]（L1 panel 层）薄封装，签名与 v2 完全兼容——存量调用点
/// 零改动。视觉规格由层级函数解析：半透明磨砂填充 + 1px 高光发丝描边 +
/// 顶部高光渐变 + 悬浮阴影；σ 按画质档解析（standard/saver 档 fill-only，
/// 零 saveLayer）。可点卡片 hover/press 三态过渡 + 水波纹。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padded = true,
    this.margin,
    this.color,
  });

  final Widget child;

  /// 传入即可点（水波纹 + 按压背景 4% 变化）
  final VoidCallback? onTap;

  /// 内边距（默认 md=16；false 时零填充，由 child 自管）
  final bool padded;

  final EdgeInsetsGeometry? margin;

  /// 覆盖底色（默认 L1 层级解析玻璃填充；传不透明色可关闭通透感）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: GlassPanel(
        tier: GlassTier.panel,
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        colorOverride: color,
        padding: padded ? AppSpacing.cardPadding : null,
        child: child,
      ),
    );
  }
}
