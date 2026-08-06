import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';

void main() {
  test('currentBookIdProvider updates rebuild book-scoped repository providers', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // 模拟 main() 启动时 overrideWith 冻结当前账本
        currentBookIdProvider.overrideWith((ref) => 'book-A'),
      ],
    );
    addTearDown(container.dispose);

    final repoA = container.read(categoryRepositoryProvider);
    expect(repoA.bookId, 'book-A');

    // 模拟 BookSwitcher/BooksPage 切换账本后的状态同步
    container.read(currentBookIdProvider.notifier).state = 'book-B';

    final repoB = container.read(categoryRepositoryProvider);
    expect(repoB.bookId, 'book-B');
    expect(identical(repoA, repoB), isFalse);
  });
}
