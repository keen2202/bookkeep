import 'package:flutter/material.dart';

import '../../domain/services/budget_progress_calculator.dart';
import '../../shared/theme/app_theme.dart';

/// 预算进度条（Spec §3.4）：80% 预警 / 100% 超支
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final color = progress.exceeded
        ? Theme.of(context).colorScheme.error
        : progress.overThreshold
            ? context.appColors.warning
            : Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (progress.percent / 100).clamp(0.0, 1.0),
        minHeight: 6,
        color: color,
        // v3（GLS-007）：轨道线 divider α0.5，与图表网格同源
        backgroundColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
