import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/utils/category_icon.dart';

/// 分类图标库（BK-DOC-26 需求7）：分组完整性 + 映射有效性 + 内容丰富度
void main() {
  test('icon groups cover core spending scenarios', () {
    final groups = categoryIconGroups.map((g) => g.$1).toSet();
    for (final required in ['餐饮', '交通', '购物', '居家', '娱乐', '医疗', '教育', '金融']) {
      expect(groups, contains(required));
    }
  });

  test('every grouped icon name resolves to a real mapping', () {
    for (final (group, names) in categoryIconGroups) {
      expect(names, isNotEmpty, reason: '$group 组为空');
      for (final name in names) {
        final icon = categoryIcon(name);
        // categoryIcon 对缺失名回退 Icons.category；'category' 本身是合法名
        expect(icon == Icons.category && name != 'category', isFalse,
            reason: '$group 组图标 $name 无映射');
      }
    }
  });

  test('unknown icon name falls back to a generic icon', () {
    expect(categoryIcon('definitely_not_an_icon'), Icons.category);
  });

  test('library is content-rich (>= 80 icons across >= 8 groups)', () {
    final total =
        categoryIconGroups.fold<int>(0, (sum, g) => sum + g.$2.length);
    expect(total, greaterThanOrEqualTo(80));
    expect(categoryIconGroups.length, greaterThanOrEqualTo(8));
  });
}
