import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../books/books_providers.dart' show transactionRepositoryProvider;
import 'bills_grouping.dart';

/// 账单首屏窗口大小（Spec R-20）；超出后经「加载更早」递增
const kBillsPageSize = 200;

/// 已请求的窗口上限（含已加载部分）
final billsPageSizeProvider = StateProvider<int>((ref) => kBillsPageSize);

class BillsViewModel {
  const BillsViewModel({required this.days, required this.hasMore});

  final List<BillDay> days;
  final bool hasMore;
}

/// 账单视图模型：窗口加载 + 按天分组（写操作后经刷新总线自动重建，审查 F-1 / Spec R-20）
final billsViewModelProvider = FutureProvider<BillsViewModel>((ref) async {
  ref.watch(ledgerVersionProvider);
  final limit = ref.watch(billsPageSizeProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final page = await repo.listTransactions(limit: limit + 1);
  final hasMore = page.length > limit;
  return BillsViewModel(
    days: groupBillsByDay(page.take(limit).toList()),
    hasMore: hasMore,
  );
});
