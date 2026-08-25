import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import 'glass_panel.dart';

/// FG-CARD 统一卡片（Spec §4.5 / 设计文档 §5.5；BK-FG-012）：
/// [GlassPanel] G2 薄封装——半透明填充 + 双层发丝描边 + 顶部内高光渐变 +
/// 环境投影 0/4/16/α0.06，σ20 真实磨砂（降级开关生效时 fill +0.10 补偿）。
///
/// - 内边距 16（紧凑 12）；卡片间距由调用方按同组 12 / 跨组 20 排布；
/// - 嵌套最多一层：内层分组容器请用 [GlassPanel.nested]（下一档填充值、
///   不新增 BackdropFilter、圆角 12）；
/// - 整卡可点时按压反馈走 FG-BTN pressed 规则（fill 0.48/0.09 + scale 0.98，
///   由 [GlassPanel] 内建）。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padded = true,
    this.margin,
    this.compactPadding = false,
  });

  final Widget child;

  /// 传入即可点（FG-CARD 点击反馈）
  final VoidCallback? onTap;

  /// 内边距开关（false 时零填充，由 child 自管）
  final bool padded;

  /// 紧凑内边距 12（Spec §4.5）
  final bool compactPadding;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: GlassPanel(
        level: GlassLevel.g2,
        borderRadius: AppRadius.cardAll,
        onTap: onTap,
        padding: padded
            ? (compactPadding ? AppSpacing.cardPaddingCompact : AppSpacing.cardPadding)
            : null,
        child: child,
      ),
    );
  }
}
