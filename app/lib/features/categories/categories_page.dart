import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/repository_exceptions.dart';
import '../../core/ledger_version.dart';import '../../data/local/database.dart';
import '../../domain/models/category_seed.dart';
import '../../shared/theme/tokens.dart';
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
          onMore: widget.viewer ? null : () => _showActions(context, ref, parent),
        ),
        if (!_collapsed.contains(parent.id))
          for (final child in categories.where((c) => c.parentId == parent.id))
            _ChildTile(
              child: child,
              viewer: widget.viewer,
              onActions: () => _showActions(context, ref, child),
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
    if (!context.mounted || action == null) return;
    var changed = false;
    switch (action) {
      case 'edit':
        await CategoryEditSheet.show(context, category: category);
        changed = true;
      case 'delete':
        // 删除需二次确认（Spec §3.3：删除被引用分类有提示且历史可见）
        final confirmed = await _confirmDelete(context, category);
        if (!confirmed) return;
        try {
          await repo.deleteCategory(category.id);
          changed = true;
        } on RepositoryException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
    }
    if (changed) ref.invalidate(categoriesViewModelProvider);
  }

  Future<bool> _confirmDelete(BuildContext context, Category category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('删除「${category.name}」后该分类不再可选；'
            '已有流水不受影响，保留原分类显示。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// 一级分类组头（需求：与二级分类直观区分）：
/// 分类自身色调淡底 + 圆角通栏条，标题加粗着色，右侧折叠/操作入口
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Container(
        // 一级分类淡色底条：以分类主色的低透明度铺底，与白底的二级行分层
        decoration: BoxDecoration(
          color: Color(parent.color).withValues(alpha: 0.12),
          borderRadius: AppRadius.smAll,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
            leading: Icon(categoryIcon(parent.icon), color: Color(parent.color)),
            title: Text(
              parent.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Color(parent.color), fontWeight: FontWeight.bold),
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
          ),
        ),
      ),
    );
  }
}

/// 二级分类行：相对一级组头整体右移缩进 + 常规字重，层级从属一目了然
class _ChildTile extends StatelessWidget {
  const _ChildTile({
    required this.child,
    required this.viewer,
    required this.onActions,
  });

  final Category child;
  final bool viewer;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // 缩进量 = 组头外边距(md) + 组头内边距(sm) + 一级缩进(lg)，
      // 使子项图标明显退入父级之下
      contentPadding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md + AppSpacing.sm + AppSpacing.lg,
        end: AppSpacing.md,
      ),
      leading: Icon(categoryIcon(child.icon), color: Color(child.color)),
      title: Text(child.name),
      // 编辑/删除入口（含系统分类，软删除保留历史流水分类名快照）：
      // 点击整行或右侧菜单均可打开操作弹层；viewer 只读隐藏
      onTap: viewer ? null : onActions,
      trailing: viewer
          ? null
          : IconButton(icon: const Icon(Icons.more_vert), onPressed: onActions),
    );
  }
}
