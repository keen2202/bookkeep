import '../../data/local/tables/categories_table.dart';

/// 系统分类 seed 数据模型（Spec §3.3 / BK-P0-003，version 化便于升级迁移）
class CategorySeed {
  const CategorySeed({required this.version, required this.parents});

  final int version;
  final List<CategorySeedNode> parents;

  int get totalCount =>
      parents.fold(0, (sum, p) => sum + 1 + p.children.length);

  factory CategorySeed.fromJson(Map<String, dynamic> json) {
    return CategorySeed(
      version: json['version'] as int,
      parents: [
        for (final parent in json['categories'] as List)
          CategorySeedNode.fromJson(parent as Map<String, dynamic>),
      ],
    );
  }
}

class CategorySeedNode {
  const CategorySeedNode({
    required this.name,
    required this.icon,
    required this.color,
    required this.kind,
    this.children = const [],
  });

  final String name;
  final String icon;
  final int color;
  final CategoryKind kind;
  final List<CategorySeedNode> children;

  factory CategorySeedNode.fromJson(
    Map<String, dynamic> json, {
    CategoryKind? parentKind,
  }) {
    final kind = json['kind'] != null
        ? CategoryKind.values.byName(json['kind'] as String)
        : (parentKind ?? CategoryKind.expense);
    return CategorySeedNode(
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as int,
      kind: kind,
      children: [
        for (final child in (json['children'] as List?) ?? [])
          CategorySeedNode.fromJson(
            (child as Map<String, dynamic>).cast<String, dynamic>(),
            parentKind: kind,
          ),
      ],
    );
  }
}
