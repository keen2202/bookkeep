import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/repository_exceptions.dart';
import '../../data/local/database.dart';
import '../../domain/models/category_seed.dart';
import '../../shared/utils/category_icon.dart';
import '../books/books_providers.dart'
    show categoryRepositoryProvider, currentRoleProvider;
import 'category_edit_sheet.dart';

/// 系统分类 seed（从 assets 加载；测试可 override）
final categorySeedProvider = FutureProvider<CategorySeed>((ref) async {
  final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
  return CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

/// 分类视图模型：先确保 seed 已安装（首次安装完整），再返回两级分类树
final categoriesViewModelProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  final seed = await ref.watch(categorySeedProvider.future);
  await repo.installSeeds(seed);
  return repo.listCategories(includeDeleted: false);
});

/// 分类管理页（Spec §3.3 / BK-P0-003）
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesViewModelProvider);
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    return Scaffold(
      appBar: AppBar(title: const Text('分类')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) => _CategoryList(categories: list, viewer: viewer),
      ),
      // viewer 只读（Spec §4.1 权限矩阵：UI 与服务端双重拒绝）
      floatingActionButton: viewer
          ? null
          : FloatingActionButton(
              onPressed: () => CategoryEditSheet.show(context),
              tooltip: '新建分类',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories, required this.viewer});

  final List<Category> categories;

  /// viewer 只读：隐藏编辑/删除入口（Spec §4.1 权限矩阵）
  final bool viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parents = categories.where((c) => c.parentId == null).toList();
    return ListView(
      children: [
        for (final parent in parents) ...[
          _ParentHeader(
            parent: parent,
            onMore: !viewer && !parent.isSystem
                ? () => _showActions(context, ref, parent)
                : null,
          ),
          for (final child in categories.where((c) => c.parentId == parent.id))
            ListTile(
              leading: Icon(categoryIcon(child.icon), color: Color(child.color)),
              title: Text(child.name),
              trailing: child.isSystem || viewer
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showActions(context, ref, child),
                    ),
            ),
        ],
      ],
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref, Category category) async {
    final repo = ref.read(categoryRepositoryProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await CategoryEditSheet.show(context, category: category);
      case 'delete':
        try {
          await repo.deleteCategory(category.id);
        } on CategoryInUseException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
    }
    ref.invalidate(categoriesViewModelProvider);
  }
}

class _ParentHeader extends StatelessWidget {
  const _ParentHeader({required this.parent, this.onMore});

  final Category parent;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(categoryIcon(parent.icon), color: Color(parent.color)),
      title: Text(
        parent.name,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Color(parent.color), fontWeight: FontWeight.bold),
      ),
      trailing: onMore == null
          ? null
          : IconButton(icon: const Icon(Icons.more_vert), onPressed: onMore),
    );
  }
}
