import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/icons/bk_category_icons.dart';
import 'package:bookkeep_app/shared/icons/bk_icon_registry.dart';
import 'package:bookkeep_app/shared/icons/bk_icons.dart';
import 'package:bookkeep_app/shared/utils/category_icon.dart';

/// 分类图标库（BK-DOC-26 需求7 / BK-DOC-34 P2）：
/// 分组完整性 + seed iconName 契约 + BK Painter 注册有效性 + 内容丰富度。
void main() {
  setUpAll(BkIconRegistry.ensureInitialized);

  test('icon groups cover core spending scenarios', () {
    final groups = categoryIconGroups.map((g) => g.$1).toSet();
    for (final required in ['餐饮', '交通', '购物', '居家', '娱乐', '医疗', '教育', '金融']) {
      expect(groups, contains(required));
    }
  });

  test('every grouped icon name resolves to a registered BK icon', () {
    for (final (group, names) in categoryIconGroups) {
      expect(names, isNotEmpty, reason: '$group 组为空');
      for (final name in names) {
        final id = categoryIcon(name);
        expect(BkCategoryCatalog.contains(name), isTrue,
            reason: '$group 组图标 $name 未进入 BkCategoryCatalog 目录');
        expect(id, '${BkIcons.catPrefix}$name');
        expect(BkIconRegistry.isRegistered(id), isTrue,
            reason: '$group 组图标 $name → $id 未注册 Painter');
      }
    }
  });

  test('directory covers categoryIconGroups and legacy names', () {
    final grouped = <String>{
      for (final (_, names) in categoryIconGroups) ...names,
    };
    final directory = BkCategoryCatalog.names.toSet();
    // 支持目录可大于分组目录：历史 iconName（如 'donate'）继续保留映射，
    // 避免老数据/既有自定义分类在 P2 迁移后失去图形。
    expect(grouped.difference(directory), isEmpty);
    expect(directory, containsAll(grouped));
  });

  test('unknown icon name falls back to generic bk.cat.category', () {
    expect(categoryIcon('definitely_not_an_icon'), BkIcons.catFallback);
    expect(BkIconRegistry.isRegistered(BkIcons.catFallback), isTrue);
  });

  test('seed iconName contract is preserved (no Material mapping)', () {
    // BK-IC-052：分类库正式路径不再暴露 IconData / Material 图标映射，
    // 契约仍是原始 iconName 字符串，由 BkCategoryCatalog 转为 bk.cat.*。
    for (final name in [
      'restaurant',
      'free_breakfast',
      'local_cafe',
      'directions_subway',
      'shopping_cart',
      'medical_services',
      'school',
      'favorite',
      'phone_iphone',
      'account_balance',
    ]) {
      expect(categoryIcon(name), '${BkIcons.catPrefix}$name');
    }
  });

  test('library is content-rich (>= 80 icons across >= 8 groups)', () {
    final total =
        categoryIconGroups.fold<int>(0, (sum, g) => sum + g.$2.length);
    expect(total, greaterThanOrEqualTo(80));
    expect(categoryIconGroups.length, greaterThanOrEqualTo(8));
    expect(BkCategoryCatalog.names.length, greaterThanOrEqualTo(80));
  });
}
