import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../utils/category_icon.dart';

/// 两级分类选择器（Spec §3.3 / BK-P0-003）
class CategoryPicker extends StatefulWidget {
  const CategoryPicker({
    super.key,
    required this.categories,
    required this.kind,
    this.initialCategoryId,
    this.onSelected,
  });

  final List<Category> categories;
  final CategoryKind kind;
  final int? initialCategoryId;
  final ValueChanged<int>? onSelected;

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  late int? _selectedId;
  /// 有子级父分类的折叠集（默认全部展开）
  final Set<int> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialCategoryId;
  }

  List<Category> get _parents =>
      widget.categories.where((c) => c.parentId == null && c.kind == widget.kind).toList();

  List<Category> _childrenOf(int parentId) => widget.categories
      .where((c) => c.parentId == parentId && c.kind == widget.kind)
      .toList();

  bool _hasChildren(int parentId) => _childrenOf(parentId).isNotEmpty;

  void _toggle(int parentId) => setState(() {
        if (!_collapsed.add(parentId)) _collapsed.remove(parentId);
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final parent in _parents) ...[
          // 有子级：点击折叠/展开；无子级（自建顶层分类）：点击直接选中
          _ParentTile(
            parent: parent,
            hasChildren: _hasChildren(parent.id),
            expanded: !_collapsed.contains(parent.id),
            onTap: () => _hasChildren(parent.id)
                ? _toggle(parent.id)
                : widget.onSelected?.call(parent.id),
          ),
          if (_hasChildren(parent.id) && !_collapsed.contains(parent.id))
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final child in _childrenOf(parent.id))
                    _CategoryChip(
                      category: child,
                      selected: _selectedId == child.id,
                      onTap: () => widget.onSelected?.call(child.id),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ParentTile extends StatelessWidget {
  const _ParentTile({
    required this.parent,
    required this.hasChildren,
    required this.expanded,
    required this.onTap,
  });

  final Category parent;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(categoryIcon(parent.icon), color: Color(parent.color)),
      title: Text(parent.name),
      trailing: hasChildren
          ? Icon(expanded ? Icons.expand_more : Icons.expand_less, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return FilterChip(
      label: Text(category.name),
      avatar: Icon(categoryIcon(category.icon), size: 18, color: color),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(color: selected ? color : null),
    );
  }
}
