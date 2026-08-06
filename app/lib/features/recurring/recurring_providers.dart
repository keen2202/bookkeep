import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../books/books_providers.dart' show currentBookIdProvider;

/// 当前账本的周期规则列表（watch currentBookId：切账本自动重建）
final recurringRulesProvider = FutureProvider<List<RecurringRule>>((ref) async {
  final db = ref.watch(databaseProvider);
  final bookId = ref.watch(currentBookIdProvider);
  return (db.select(db.recurringRules)
        ..where((t) => t.bookId.equals(bookId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();
});
