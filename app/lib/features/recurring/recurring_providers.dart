import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../books/books_providers.dart' show currentBookIdProvider;
import 'recurring_service.dart';

/// 周期补跑服务：注入携带 currentBookId 的实例（审查 B-3——
/// 直接 new RecurringService(db) 会把周期流水写入占位账本）
final recurringServiceProvider = Provider<RecurringService>((ref) {
  return RecurringService(
    ref.watch(databaseProvider),
    bookId: ref.watch(currentBookIdProvider),
  );
});

/// 当前账本的周期规则列表（watch currentBookId：切账本自动重建）
final recurringRulesProvider = FutureProvider<List<RecurringRule>>((ref) async {
  final db = ref.watch(databaseProvider);
  final bookId = ref.watch(currentBookIdProvider);
  return (db.select(db.recurringRules)
        ..where((t) => t.bookId.equals(bookId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();
});
