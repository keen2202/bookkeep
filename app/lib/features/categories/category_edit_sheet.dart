import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/category_icon.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_sheet.dart';
import '../books/books_providers.dart' show categoryRepositoryProvider;
import 'categories_page.dart' show categoriesViewModelProvider;

/// 分类层级（BK-DOC-26 需求7）：直接创建一级分类，或归属到既有
/// 一级分类下作为二级分类
enum CategoryLevel { top, sub }

/// 新建/编辑分类（Spec §3.3 / BK-P0-003；BK-DOC-26 需求7：
/// 层级选择 + 自定义图标）
class CategoryEditSheet extends ConsumerStatefulWidget {
  const CategoryEditSheet({super.key, this.category, this.initialKind});

  final Category? category;

  /// 新建时的收支类型预填（BK-DOC-28 需求5 AC5-3：来自分类页当前 tab）；
  /// 编辑态忽略——既有分类的 kind 不可改
  final CategoryKind? initialKind;

  static Future<void> show(
    BuildContext context, {
    Category? category,
    CategoryKind? initialKind,
  }) {
    // AppSheet 统一底部弹层（拖拽柄 / 圆角 lg / scrim 54%）
    return showAppSheet<void>(
      context,
      title: category == null ? '新建分类' : '编辑分类',
      child: CategoryEditSheet(
        category: category,
        initialKind: category == null ? initialKind : null,
      ),
    );
  }

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryKind _kind;
  late int _colorIndex;
  late String _iconName;
  CategoryLevel _level = CategoryLevel.top;
  int? _parentId;
  bool _saving = false;

  static const _palette = [
    0xFFFF7043, 0xFFFFB300, 0xFF66BB6A, 0xFF26C6DA, //
    0xFF42A5F5, 0xFF7E57C2, 0xFFEC407A, 0xFF8D6E63,
  ];

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    // 编辑态用既有 kind；新建态预填来源 tab（需求5 AC5-3），无则默认支出
    _kind = category?.kind ?? widget.initialKind ?? CategoryKind.expense;
    // 图标预填：编辑态沿用既有图标；新建默认通用标签
    _iconName = category?.icon ?? 'tag';
    _colorIndex = _palette.indexWhere((c) => c == category?.color);
    if (_colorIndex < 0) _colorIndex = 0;
    if (category != null && category.parentId != null) {
      _level = CategoryLevel.sub;
      _parentId = category.parentId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 父级候选：与当前收支类型一致的既有一级分类（二级分类须与父级同类型）
  List<Category> _parentCandidates(List<Category> all) =>
      all.where((c) => c.parentId == null && c.kind == _kind).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isCreate = widget.category == null;
    if (isCreate && _level == CategoryLevel.sub && _parentId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(categoryRepositoryProvider);
    try {
      if (isCreate) {
        await repo.createCategory(
          name: _nameController.text.trim(),
          icon: _iconName,
          color: _palette[_colorIndex],
          kind: _kind,
          // 层级（BK-DOC-26 需求7）：一级为 null；二级归属所选父级
          parentId: _level == CategoryLevel.sub ? _parentId : null,
        );
      } else {
        await repo.updateCategory(widget.category!.id,
            name: _nameController.text.trim(),
            color: _palette[_colorIndex],
            icon: _iconName);
      }
      ref.invalidate(categoriesViewModelProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.category == null;
    // 分类树（父级候选来源）：加载中不影响名称/图标/颜色填写
    final categories = ref.watch(categoriesViewModelProvider).valueOrNull ?? const [];
    final parents = _parentCandidates(categories);
    // 外层间距由 AppSheet.sheetPadding 提供
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '分类名称'),
            validator: (v) {
              final name = v?.trim() ?? '';
              if (name.isEmpty) return '请输入分类名称';
              if (name.length > 20) return '名称不能超过 20 字';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          if (isCreate) ...[
            SegmentedButton<CategoryKind>(
              segments: const [
                ButtonSegment(value: CategoryKind.expense, label: Text('支出')),
                ButtonSegment(value: CategoryKind.income, label: Text('收入')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                // 父级候选随收支类型变化：清空重选，避免跨类型归属
                _parentId = null;
              }),
            ),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            // 层级选择（BK-DOC-26 需求7）：一级 / 二级（归属一级分类）
            SegmentedButton<CategoryLevel>(
              segments: const [
                ButtonSegment(value: CategoryLevel.top, label: Text('一级分类')),
                ButtonSegment(value: CategoryLevel.sub, label: Text('二级分类')),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            if (_level == CategoryLevel.sub) ...[
              const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
              if (parents.isEmpty)
                Text(
                  '暂无同类型一级分类，请先创建一级分类',
                  style: TextStyle(color: context.appColors.warning),
                )
              else
                DropdownButtonFormField<int>(
                  // 类型切换/异步回填后换 key 重建 State 才能正确回显
                  key: ValueKey('parent-$_kind-$_parentId'),
                  initialValue: _parentId,
                  decoration: const InputDecoration(labelText: '归属一级分类'),
                  validator: (v) => v == null ? '请选择归属的一级分类' : null,
                  items: [
                    for (final p in parents)
                      DropdownMenuItem(
                        value: p.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(categoryIcon(p.icon),
                                size: 18, color: Color(p.color)),
                            const SizedBox(width: AppSpacing.xs),
                            Text(p.name),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _parentId = v),
                ),
            ],
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          ],
          // 图标选择（BK-DOC-26 需求7）：语义分组内置图标库
          Row(
            children: [
              Text('图标', style: context.text.titleSmall),
              const SizedBox(width: AppSpacing.sm),
              Icon(categoryIcon(_iconName),
                  size: 20, color: Color(_palette[_colorIndex])),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _IconPicker(
            selected: _iconName,
            onSelected: (name) => setState(() => _iconName = name),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text('颜色', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          // 审查 U-7：颜色选择触控目标 ≥48dp；小屏溢出改 Wrap 自动换行
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < _palette.length; i++)
                Semantics(
                  button: true,
                  label: '颜色 ${i + 1}',
                  selected: _colorIndex == i,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.lg),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _colorIndex = i);
                    },
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(_palette[i]),
                          child: _colorIndex == i
                              // 勾选色随底色动态取对比色（UI 重构 Spec §6 收敛）
                              ? Icon(Icons.check,
                                  size: 18,
                                  color: onColorFor(Color(_palette[i])))
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          AppButton.primary(
            onPressed: _save,
            loading: _saving,
            block: true,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// 图标选择器（BK-DOC-26 需求7）：按语义分组渲染内置图标库；
/// 触控目标 48dp（审查 U-7 同颜色选择器）
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (group, names) in categoryIconGroups) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
            child: Text(group, style: context.text.bodySmall),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final name in names)
                Semantics(
                  button: true,
                  label: name,
                  selected: selected == name,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelected(name);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selected == name
                            ? palette.primary.withValues(alpha: 0.15)
                            : null,
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        border: selected == name
                            ? Border.all(color: palette.primary, width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        categoryIcon(name),
                        size: 22,
                        color: selected == name
                            ? palette.primary
                            : palette.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
