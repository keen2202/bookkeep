import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/repository_exceptions.dart';
import '../../core/ledger_version.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../../domain/models/category_seed.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/category_icon.dart';
import '../../shared/widgets/app_segmented_button.dart';
import '../../shared/widgets/glass_nav.dart' show GlassScaffold;
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

/// 分类页当前收支 tab（BK-DOC-28 需求5 / Spec §2.5）：列表过滤与 AppBar
/// 「新建分类」预填同源（AC5-3），故状态放在页面之外而非列表 State 内。
///
/// autoDispose：退出路由后无监听者即销毁，重进恢复默认「支出」——与需求4
/// 「重进恢复全折叠、不持久化」的心智一致。
final categoryKindTabProvider =
    StateProvider.autoDispose<CategoryKind>((ref) => CategoryKind.expense);

/// 分类管理页（BK-DOC-28 需求6）：分类入口自底部 Tab 下沉设置弹层后的
/// 独立路由页（同「周期记账」下沉先例）——`GlassScaffold`
/// 提供 G3 吸顶玻璃栏与返回键，AppBar 动作复用 [categoriesPageAction]。
///
/// 路由化后不再驻留主 shell 的 `IndexedStack`：每次进入重新加载，
/// 滚动位置、展开状态与收支 tab 均不保留（需求4「进入默认折叠」、
/// 需求5「默认支出」语义）。
class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold(
      title: const Text('分类'),
      actions: [ ?categoriesPageAction(context, ref) ],
      body: const CategoriesPage(),
    );
  }
}

/// 分类列表内容（Spec §3.3 / BK-P0-003；BK-DOC-28 需求5 顶部收支 tab）；
/// 无内层 Scaffold/AppBar/FAB（审查 U-1：单 AppBar 单 FAB 由宿主
/// [CategoryManagementPage] 组装，动作经 [categoriesPageAction] 暴露）
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesViewModelProvider);
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    final kind = ref.watch(categoryKindTabProvider);
    return Column(
      children: [
        // 需求5：AppBar 之下、列表之上的「支出 / 收入」两栏 tab（默认支出）；
        // 选中态样式沿用需求7 的共享分段控件（无 ✔、颜色突显）
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: AppSegmentedButton<CategoryKind>(
            segments: const [
              ButtonSegment(value: CategoryKind.expense, label: Text('支出')),
              ButtonSegment(value: CategoryKind.income, label: Text('收入')),
            ],
            selected: {kind},
            // 切换 tab → 列表重置全折叠由 _CategoryList.didUpdateWidget 承担
            onSelectionChanged: (s) =>
                ref.read(categoryKindTabProvider.notifier).state = s.first,
          ),
        ),
        Expanded(
          child: categories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (list) =>
                _CategoryList(categories: list, viewer: viewer, kind: kind),
          ),
        ),
      ],
    );
  }
}

/// 主 shell AppBar 动作：新建分类（viewer 只读 → null，Spec §4.1 双重拒绝）
Widget? categoriesPageAction(BuildContext context, WidgetRef ref) {
  if (ref.watch(currentRoleProvider) == 'viewer') return null;
  return IconButton(
    tooltip: '新建分类',
    icon: const Icon(Icons.add),
    // 需求5 AC5-3：预填当前 tab 的收支类型（弹层内仍可手动改）；
    // 点击时再读，避免 tab 切换连带重建 AppBar
    onPressed: () => CategoryEditSheet.show(
      context,
      initialKind: ref.read(categoryKindTabProvider),
    ),
  );
}

class _CategoryList extends ConsumerStatefulWidget {
  const _CategoryList({
    required this.categories,
    required this.viewer,
    required this.kind,
  });

  final List<Category> categories;

  /// viewer 只读：隐藏编辑/删除入口（Spec §4.1 权限矩阵）
  final bool viewer;

  /// 当前收支 tab（BK-DOC-28 需求5）：仅展示该类型的一级分类及其子级
  final CategoryKind kind;

  @override
  ConsumerState<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends ConsumerState<_CategoryList> {
  /// 已展开的父分类集（BK-DOC-28 需求4：默认空 = 全部折叠，不持久化）
  final Set<int> _expanded = {};

  @override
  void didUpdateWidget(covariant _CategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // AC4-3 / AC5-2：切换收支 tab 重置为全折叠；增删改引发的数据刷新
    // 走同一 State（kind 未变），展开态按 Spec §2.4 边界保持不动
    if (oldWidget.kind != widget.kind) _expanded.clear();
  }

  @override
  Widget build(BuildContext context) {
    // 需求5：按 tab 过滤一级分类（二级须与父级同类型，随父级一并展示）
    final categories = widget.categories;
    final parents = categories
        .where((c) => c.parentId == null && c.kind == widget.kind)
        .toList();
    if (parents.isEmpty) {
      final label = widget.kind == CategoryKind.expense ? '支出' : '收入';
      return Center(
        // viewer 无新建入口（Spec §4.1），文案不引导点击不存在的按钮
        child: Text(
            widget.viewer ? '暂无$label分类' : '暂无$label分类，点击右上角新建'),
      );
    }
    // 审查 U-10：扁平化后经 ListView.builder 惰性构建（大分类数下 60fps）
    final tiles = <Widget>[
      for (final parent in parents) ...[
        _ParentHeader(
          parent: parent,
          hasChildren: categories.any((c) => c.parentId == parent.id),
          expanded: _expanded.contains(parent.id),
          onToggle: () => setState(() {
            if (!_expanded.add(parent.id)) _expanded.remove(parent.id);
          }),
          onMore: widget.viewer ? null : () => _showActions(context, ref, parent),
        ),
        if (_expanded.contains(parent.id))
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
/// 分类自身色调淡底 + 圆角通栏条，标题加粗着色，右侧折叠/操作入口。
/// 箭头语义（BK-DOC-28 需求4 / Spec §2.4）：默认收起 → `expand_more`
/// （可展开），展开后 → `expand_less`（可收起）；无子级则不渲染箭头。
class _ParentHeader extends StatelessWidget {
  const _ParentHeader({
    required this.parent,
    required this.hasChildren,
    required this.expanded,
    required this.onToggle,
    this.onMore,
  });

  final Category parent;
  final bool hasChildren;
  final bool expanded;
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
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
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
