import 'package:flutter/material.dart';

import '../../domain/services/budget_progress_calculator.dart';

/// 预算进度条（Spec §3.4）：80% 预警 / 100% 超支
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final color = progress.exceeded
        ? Theme.of(context).colorScheme.error
        : progress.overThreshold
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (progress.percent / 100).clamp(0.0, 1.0),
        minHeight: 6,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }
}
