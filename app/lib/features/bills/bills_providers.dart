import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../books/books_providers.dart' show transactionRepositoryProvider;
import 'bills_grouping.dart';

/// 账单视图模型：按天分组流水（写操作后经刷新总线自动重建，审查 F-1）
final billsViewModelProvider = FutureProvider<List<BillDay>>((ref) async {
  ref.watch(ledgerVersionProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  return groupBillsByDay(await repo.listTransactions());
});
