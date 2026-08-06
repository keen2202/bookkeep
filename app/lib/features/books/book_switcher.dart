import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import 'books_page.dart';
import 'books_providers.dart';

/// 主界面 AppBar 账本切换器（Spec §4.1 / BK-T-010）
class BookSwitcher extends ConsumerWidget {
  const BookSwitcher({super.key});

  static const _manageValue = '__manage__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksViewModelProvider);
    final currentId = ref.watch(currentBookIdProvider);
    final current = ref.watch(currentBookProvider);
    final list = books.maybeWhen(data: (l) => l, orElse: () => <Book>[]);
    return PopupMenuButton<String>(
      tooltip: '切换账本',
      onSelected: (value) async {
        if (value == _manageValue) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BooksPage()));
          return;
        }
        if (value == currentId) return;
        await ref.read(bookRepositoryProvider).switchBook(value);
        // 同步当前账本 provider：驱动各仓库/视图模型按新账本重建
        ref.read(currentBookIdProvider.notifier).state = value;
        // 同步新账本角色到写拦截（离线用本地缓存）
        final role = await ref.read(bookRepositoryProvider).roleOf(value);
        ref.read(currentRoleProvider.notifier).state = role;
        ref.invalidate(booksViewModelProvider);
        ref.invalidate(currentBookProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已切换账本')),
          );
        }
      },
      itemBuilder: (context) => [
        if (list.isEmpty)
          const PopupMenuItem(enabled: false, child: Text('暂无账本'))
        else
          for (final book in list)
            PopupMenuItem(
              value: book.id,
              child: Row(
                children: [
                  Icon(
                    book.id == currentId ? Icons.check_circle : Icons.menu_book_outlined,
                    size: 18,
                    color: book.id == currentId ? Colors.teal : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(book.name)),
                ],
              ),
            ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _manageValue, child: Text('管理账本…')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined),
          const SizedBox(width: 4),
          Text(current.value?.name ?? '账本', style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
