import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/constants.dart';
import '../sync/token_store.dart';
import 'books_api.dart';
import 'books_providers.dart';
import 'member_manager.dart';
import 'share_invite_sheet.dart';

const bookTemplateLabels = {
  'default': '默认',
  'life': '生活',
  'family': '家庭',
  'travel': '旅行',
  'business': '生意',
};

/// 账本管理页（Spec §4.1 / BK-T-010）：列表 / 新建 / 切换 / 邀请 / 成员
class BooksPage extends ConsumerWidget {
  const BooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksViewModelProvider);
    final currentId = ref.watch(currentBookIdProvider);
    final current = ref.watch(currentBookProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账本')),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(booksViewModelProvider),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('当前账本：${current.value?.name ?? '默认账本'}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final book in list)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(book.name),
                  subtitle: Text(
                    '${bookTemplateLabels[book.type] ?? book.type}'
                    '${book.id == currentId ? ' · 当前' : ''}',
                  ),
                  trailing: book.id == currentId
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : null,
                  onTap: book.id == currentId
                      ? null
                      : () async {
                          await ref.read(bookRepositoryProvider).switchBook(book.id);
                          ref.invalidate(booksViewModelProvider);
                          ref.invalidate(currentBookProvider);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已切换到「${book.name}」')),
                          );
                        },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建账本'),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var type = 'default';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建账本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '账本名称'),
                maxLength: 30,
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: [
                  for (final entry in bookTemplateLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => type = v ?? 'default'),
                decoration: const InputDecoration(labelText: '场景模板'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await ref.read(bookRepositoryProvider).createLocalBook(
                      id: const Uuid().v4(),
                      name: name,
                      type: type,
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                ref.invalidate(booksViewModelProvider);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账本级操作（邀请/成员）统一入口：账本页右上角
Future<void> showBookActions(BuildContext context, {required String bookId}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('邀请成员'),
              onTap: () {
                Navigator.pop(context);
                ShareInviteSheet.show(context, bookId: bookId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('成员管理'),
              onTap: () {
                Navigator.pop(context);
                MemberManagerSheet.show(context, bookId: bookId);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// 云端 API 与登录态（baseUrl 见 constants；token 来自安全存储）
BooksApi booksApi() => BooksApi(baseUrl: kServerBaseUrl);

Future<String?> accessToken() => SecureTokenStore().read().then((t) => t?.accessToken);
