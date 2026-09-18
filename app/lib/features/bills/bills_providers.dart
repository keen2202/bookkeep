import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';
import '../books/books_providers.dart' show transactionRepositoryProvider;
import 'bills_grouping.dart';

/// 账单首屏窗口大小（Spec R-20）；超出后经「加载更早」递增
const kBillsPageSize = 200;

/// 已请求的窗口上限（含已加载部分）
final billsPageSizeProvider = StateProvider<int>((ref) => kBillsPageSize);

/// 账单筛选条件（BK-IC-023）。
///
/// 只作用于当前窗口内已加载流水：`type` 与 `categoryId` 可单独/组合使用；
/// 分类只支持精确 ID（分类库 P2 迁移后保持与 `categoryIcon` 的 `bk.cat.*` 契约一致）。
class BillFilter {
  const BillFilter({this.type, this.categoryId});

  final TransactionType? type;
  final int? categoryId;

  bool get isActive => type != null || categoryId != null;

  BillFilter withType(TransactionType? next) =>
      BillFilter(type: next, categoryId: categoryId);

  BillFilter withCategory(int? next) =>
      BillFilter(type: type, categoryId: next);

  BillFilter clear() => const BillFilter();

  bool matches(Transaction transaction) {
    if (type != null && transaction.type != type) return false;
    if (categoryId != null && transaction.categoryId != categoryId) {
      return false;
    }
    return true;
  }
}

/// 当前账单筛选条件；UI 通过 `_BillFilterBar` / `showBillFilterSheet` 修改。
final billFilterProvider = StateProvider<BillFilter>((ref) => const BillFilter());

class BillsViewModel {
  const BillsViewModel({required this.days, required this.hasMore});

  final List<BillDay> days;
  final bool hasMore;
}

/// 账单视图模型：窗口加载 + 筛选 + 按天分组
/// （写操作后经刷新总线自动重建，审查 F-1 / Spec R-20）
final billsViewModelProvider = FutureProvider<BillsViewModel>((ref) async {
  ref.watch(ledgerVersionProvider);
  final limit = ref.watch(billsPageSizeProvider);
  final filter = ref.watch(billFilterProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final page = await repo.listTransactions(limit: limit + 1);
  final hasMore = page.length > limit;
  final visible = page.take(limit).where(filter.matches).toList();
  return BillsViewModel(
    days: groupBillsByDay(visible),
    hasMore: hasMore,
  );
});
