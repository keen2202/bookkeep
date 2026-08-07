import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/repository_exceptions.dart';
import '../../core/ledger_version.dart';
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
  ref.watch(ledgerVersionProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  final seed = await ref.watch(categorySeedProvider.future);
  await repo.installSeeds(seed);
  return repo.listCategories(includeDeleted: false);
});

/// 分类管理页（Spec §3.3 / BK-P0-003）；无内层 Scaffold/AppBar/FAB
/// （审查 U-1：单 AppBar 单 FAB 由主 shell 组装，动作经 [categoriesPageAction] 暴露）
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesViewModelProvider);
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    return categories.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (list) => _CategoryList(categories: list, viewer: viewer),
    );
  }
}

/// 主 shell AppBar 动作：新建分类（viewer 只读 → null，Spec §4.1 双重拒绝）
Widget? categoriesPageAction(BuildContext context, WidgetRef ref) {
  if (ref.watch(currentRoleProvider) == 'viewer') return null;
  return IconButton(
    tooltip: '新建分类',
    icon: const Icon(Icons.add),
    onPressed: () => CategoryEditSheet.show(context),
  );
}

class _CategoryList extends ConsumerStatefulWidget {
  const _CategoryList({required this.categories, required this.viewer});

  final List<Category> categories;

  /// viewer 只读：隐藏编辑/删除入口（Spec §4.1 权限矩阵）
  final bool viewer;

  @override
  ConsumerState<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends ConsumerState<_CategoryList> {
  /// 有子级父分类的折叠集（默认全部展开）
  final Set<int> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final parents = categories.where((c) => c.parentId == null).toList();
    // 审查 U-10：扁平化后经 ListView.builder 惰性构建（大分类数下 60fps）
    final tiles = <Widget>[
      for (final parent in parents) ...[
        _ParentHeader(
          parent: parent,
          hasChildren: categories.any((c) => c.parentId == parent.id),
          collapsed: _collapsed.contains(parent.id),
          onToggle: () => setState(() {
            if (!_collapsed.add(parent.id)) _collapsed.remove(parent.id);
          }),
          onMore: widget.viewer || parent.isSystem
              ? null
              : () => _showActions(context, ref, parent),
        ),
        if (!_collapsed.contains(parent.id))
          for (final child in categories.where((c) => c.parentId == parent.id))
            ListTile(
              leading: Icon(categoryIcon(child.icon), color: Color(child.color)),
              title: Text(child.name),
              trailing: child.isSystem || widget.viewer
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showActions(context, ref, child),
                    ),
            ),
      ],
    ];
    return ListView.builder(
      itemCount: tiles.length,
      itemBuilder: (context, i) => tiles[i],
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
  const _ParentHeader({
    required this.parent,
    required this.hasChildren,
    required this.collapsed,
    required this.onToggle,
    this.onMore,
  });

  final Category parent;
  final bool hasChildren;
  final bool collapsed;
  final VoidCallback onToggle;
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasChildren)
            Icon(collapsed ? Icons.expand_less : Icons.expand_more),
          if (onMore != null)
            IconButton(icon: const Icon(Icons.more_vert), onPressed: onMore),
        ],
      ),
      onTap: hasChildren ? onToggle : null,
    );
  }
}
