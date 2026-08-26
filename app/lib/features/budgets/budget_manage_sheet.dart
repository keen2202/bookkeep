import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../shared/theme/app_theme.dart';
import '../auth_lock/lock_controller.dart';
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'budget_edit_sheet.dart';
import 'budget_progress_bar.dart';
import 'budget_providers.dart';

/// 预算管理弹层（预算 tab 移除后的管理入口）：预算卡片列表 + 新建，
/// 卡片点按进入编辑（复用 BudgetEditSheet）
class BudgetManageSheet extends ConsumerWidget {
  const BudgetManageSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 需求：主题默认的 G4 玻璃填充过透（记账页数字键盘会从下方透出），
      // 预算管理弹层改用不透明 surface 底色，完整覆盖下层内容
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const BudgetManageSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsViewModelProvider);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text('预算管理', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: '新建预算',
                    icon: const Icon(Icons.add),
                    onPressed: () => BudgetEditSheet.show(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: budgets.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败：$e')),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('还没有预算，点击 + 新建'));
                  }
                  final categoriesAsync = ref.watch(categoriesViewModelProvider);
                  final categories = categoriesAsync.maybeWhen(
                    data: (c) => {for (final cat in c) cat.id: cat},
                    orElse: () => const <int, Category>{},
                  );
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _BudgetCard(
                        item: item,
                        categoryName: item.budget.categoryId == null
                            ? '总预算'
                            : categories[item.budget.categoryId]?.name ?? '分类',
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.item, required this.categoryName});

  final BudgetWithProgress item;
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = item.progress;
    final theme = Theme.of(context);
    final masked = ref.watch(amountMaskProvider);
    final money = masked ? maskedMoney() : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => BudgetEditSheet.show(context, budget: item.budget),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(categoryName, style: theme.textTheme.titleMedium),
                  Text(
                    '${money ?? formatMoney(progress.spentMinor)} / ${money ?? formatMoney(item.budget.amountMinor)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BudgetProgressBar(progress: progress),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('剩余 ${money ?? formatMoney(progress.remainingMinor)}',
                      style: theme.textTheme.bodySmall),
                  Text('日均 ${money ?? formatMoney(progress.dailyBudgetMinor)}',
                      style: theme.textTheme.bodySmall),
                  if (progress.exceeded)
                    Text('已超支', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))
                  else if (progress.overThreshold)
                    Text('接近上限',
                        style: theme.textTheme.bodySmall?.copyWith(color: context.appColors.warning)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
