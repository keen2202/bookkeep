import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import '../utils/category_icon.dart';
import 'glass_selection.dart';

/// 两级分类选择器（Spec §3.3 / BK-P0-003；FGDS v1.0 BK-FG-022）：
/// 选中态由实色 FilterChip 改为 FG-SEL 四层叠加（GlassSelection），
/// 未选中为 G4 降档玻璃填充——禁止实色填充选中态（AC-07）。
/// BK-DOC-31 需求3：分类控件尺寸小、间距密，选中光晕收敛为
/// [GlassSelectionTokens.compactGlowAlpha] / [compactGlowBlur]，
/// 不再向相邻分类发散（其余四层与默认语义不变）。
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
            selected: _selectedId == parent.id && !_hasChildren(parent.id),
            onTap: () => _hasChildren(parent.id)
                ? _toggle(parent.id)
                : widget.onSelected?.call(parent.id),
          ),
          if (_hasChildren(parent.id) && !_collapsed.contains(parent.id))
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
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
    required this.selected,
    required this.onTap,
  });

  final Category parent;
  final bool hasChildren;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final iconColor = selected ? palette.primary : Color(parent.color);
    return GlassSelection(
      selected: selected,
      borderRadius: AppRadius.smAll,
      // UI-05：分类弹窗选中态增强外缘，与 FG-SEL 四层叠加共存；默认行为不变。
      edgeWidth: 1,
      edgeAlphaLight: 0.6,
      edgeAlphaDark: 0.6,
      // BK-DOC-31 需求3：光晕收敛（blur 20 → 8），不再糊住相邻分类行
      glowAlpha: GlassSelectionTokens.compactGlowAlpha,
      glowBlur: GlassSelectionTokens.compactGlowBlur,
      // ListTile 背景与水波纹画在最近 Material 祖先上：透明 Material 隔离
      // GlassSelection 的着色 DecoratedBox，避免「背景不可见」断言
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        leading: Icon(categoryIcon(parent.icon), color: iconColor),
        // 一级分类加粗主文字色，与下方缩进的二级 chip 形成层级对比
        title: Text(
          parent.name,
          style: context.text.titleSmall
              ?.copyWith(color: selected ? palette.primary : palette.textPrimary),
        ),
        trailing: hasChildren
            ? Icon(expanded ? Icons.expand_more : Icons.expand_less, size: 18)
            : null,
        onTap: onTap,
      ),
      ),
    );
  }
}

/// 分类 chip：G4 降档玻璃填充 + 发丝描边；选中套 FG-SEL 四层叠加
/// （宿主 fill 为 G4 档，层①增量按 G4 基准计算）
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
    final dark = context.tokens.isDark;
    final palette = context.palette;
    final g4 = resolveGlassSpec(level: GlassLevel.g4, brightness: context.tokens.brightness);
    final iconColor = selected ? palette.primary : Color(category.color);
    return GlassSelection(
      selected: selected,
      hostFillAlpha: dark ? GlassLevel.g4.fillAlphaDark : GlassLevel.g4.fillAlphaLight,
      borderRadius: AppRadius.pillAll,
      // UI-05：选中态外缘增强为 1px primary α0.6，兼顾浅/深主题辨识度。
      edgeWidth: 1,
      edgeAlphaLight: 0.6,
      edgeAlphaDark: 0.6,
      // BK-DOC-31 需求3：chip 尺寸小、Wrap 间距仅 8，光晕同样收敛
      glowAlpha: GlassSelectionTokens.compactGlowAlpha,
      glowBlur: GlassSelectionTokens.compactGlowBlur,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: g4.fill,
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: g4.borderOuter, width: 0.5),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: g4.borderInnerHighlight, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(categoryIcon(category.icon), size: 16, color: iconColor),
              const SizedBox(width: AppSpacing.xs + 2),
              DefaultTextStyle.merge(
                style: context.text.bodyMedium
                    ?.copyWith(color: selected ? palette.primary : palette.textPrimary),
                child: Text(category.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
