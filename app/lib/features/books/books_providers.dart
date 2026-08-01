import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/repositories/transaction_repository.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ref.watch(databaseProvider));
});

/// 当前账本 id：main() 启动时以真实默认账本覆盖；仓库经此注入 book 上下文
/// （Spec §4.1：查询层强制 book 过滤，杜绝越权读取）
final currentBookIdProvider = StateProvider<String>((ref) => kDefaultBookId);

final booksViewModelProvider = FutureProvider<List<Book>>((ref) {
  return ref.watch(bookRepositoryProvider).listBooks();
});

final currentBookProvider = FutureProvider<Book?>((ref) {
  return ref.watch(bookRepositoryProvider).currentBook();
});

// —— 业务仓库按当前账本注入 book 上下文 ——

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(currentBookIdProvider),
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(currentBookIdProvider),
  );
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(currentBookIdProvider),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(currentBookIdProvider),
  );
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(currentBookIdProvider),
  );
});
