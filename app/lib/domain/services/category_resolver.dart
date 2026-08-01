import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';

/// 分类解析（id → 名称/图标/颜色/父级名）。软删除分类保留行，
/// 因此历史流水仍可解析出原分类名（Spec §3.3 快照语义）。
class CategoryResolver {
  CategoryResolver(List<Category> categories)
      : _byId = {for (final c in categories) c.id: c};

  final Map<int, Category> _byId;

  CategoryInfo? resolve(int? id) {
    if (id == null) return null;
    final category = _byId[id];
    if (category == null) return null;
    return CategoryInfo(
      name: category.name,
      icon: category.icon,
      color: category.color,
      kind: category.kind,
      parentName: category.parentId != null ? _byId[category.parentId]?.name : null,
    );
  }
}

class CategoryInfo {
  const CategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.kind,
    this.parentName,
  });

  final String name;
  final String icon;
  final int color;
  final CategoryKind kind;
  final String? parentName;
}
