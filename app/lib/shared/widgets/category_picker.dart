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

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialCategoryId;
  }

  List<Category> get _parents =>
      widget.categories.where((c) => c.parentId == null && c.kind == widget.kind).toList();

  List<Category> _childrenOf(int parentId) =>
      widget.categories.where((c) => c.parentId == parentId).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final parent in _parents) ...[
          _ParentTile(parent: parent, expanded: _childrenOf(parent.id).isNotEmpty),
          if (_childrenOf(parent.id).isNotEmpty)
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
                      onTap: () => setState(() => _selectedId = child.id),
                    ),
                ],
              ),
            ),
        ],
        if (_selectedId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => widget.onSelected?.call(_selectedId!),
                child: const Text('确定'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ParentTile extends StatelessWidget {
  const _ParentTile({required this.parent, required this.expanded});

  final Category parent;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(categoryIcon(parent.icon), color: Color(parent.color)),
      title: Text(parent.name),
      trailing: expanded ? const Icon(Icons.expand_more, size: 18) : null,
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
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(color: selected ? color : null),
    );
  }
}
