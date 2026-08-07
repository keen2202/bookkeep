import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// （Spec §4.1：查询层强制 book 过滤，杜绝越权读取）。默认 '' 表意"未初始化"，
/// 任何读取前必须经 main() override 注入（R-004：不再有固定占位 id）
final currentBookIdProvider = StateProvider<String>((ref) => '');

/// 当前用户在当前账本的角色（Spec §4.1 权限矩阵）。未知时默认 owner——
/// 拦截只做收紧（viewer 禁写），服务端始终为权威校验；值来自
/// serverBooksProvider（登录拉取）与本地缓存（离线）。
final currentRoleProvider = StateProvider<String>((ref) => 'owner');

final booksViewModelProvider = FutureProvider<List<Book>>((ref) {
  return ref.watch(bookRepositoryProvider).listBooks();
});

/// 各账本角色（共享/本地区分与写拦截驱动；服务端为权威，本地为缓存）
final bookRolesProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  final books = await repo.listBooks();
  final roles = <String, String>{};
  for (final book in books) {
    roles[book.id] = await repo.roleOf(book.id);
  }
  return roles;
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
