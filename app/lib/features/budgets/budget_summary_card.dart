import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../shared/icons/bk_icon.dart';
import '../../shared/icons/bk_icons.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/glass_tokens.dart';
import '../../shared/widgets/glass_panel.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show currentRoleProvider;
import 'budget_manage_sheet.dart';
import 'budget_progress_bar.dart';
import 'budget_providers.dart';

/// 记账页顶部「本月预算」进度卡（预算整合进记账页）：
/// 点按进入预算管理弹层；viewer 只读（无任何写入口）
class BudgetSummaryCard extends ConsumerWidget {
  const BudgetSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    final summaryAsync = ref.watch(monthBudgetSummaryProvider);
    return summaryAsync.when(
      // 预算数据异步就绪前不占位（不阻塞快速记账）
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        if (summary == null) {
          if (viewer) return const SizedBox.shrink();
          return _card(
            context,
            onTap: () => BudgetManageSheet.show(context),
            child: Text('还没有本月预算，点击设置',
                style: Theme.of(context).textTheme.bodyMedium),
          );
        }
        final progress = summary.progress;
        final masked = ref.watch(amountMaskProvider);
        String money(int minor) => masked ? maskedMoney() : formatMoney(minor);
        final theme = Theme.of(context);
        final String? warningLabel;
        final Color? warningColor;
        if (progress.exceeded) {
          warningLabel = '已超支';
          warningColor = theme.colorScheme.error;
        } else if (progress.overThreshold) {
          warningLabel = '接近上限';
          warningColor = context.appColors.warning;
        } else {
          warningLabel = null;
          warningColor = null;
        }
        final badge = warningLabel == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BkIcon(
                    BkIcons.statusWarn,
                    size: 16,
                    color: warningColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    warningLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: warningColor),
                  ),
                ],
              );
        return _card(
          context,
          onTap: viewer ? null : () => BudgetManageSheet.show(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('本月预算', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  ?badge,
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              BudgetProgressBar(progress: progress),
              const SizedBox(height: 8),
              Text('已花 ${money(progress.spentMinor)} / 总额 ${money(summary.budget.amountMinor)}',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text('剩余 ${money(progress.remainingMinor)}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context,
      {required VoidCallback? onTap, required Widget child}) {
    // Glassmorphism v3（GLS-010 散点收敛）：Card → GlassPanel，
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GlassPanel(
        level: GlassLevel.g2,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
