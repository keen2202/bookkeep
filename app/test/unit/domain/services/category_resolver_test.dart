import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/domain/services/category_resolver.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('CategoryResolver', () {
    test('resolves a leaf category with its parent name', () {
      final resolver = CategoryResolver([
        category(id: 1, name: '餐饮', icon: 'restaurant', color: 0xFF111111, isSystem: true),
        category(id: 2, name: '早餐', icon: 'free_breakfast', color: 0xFF222222, isSystem: true, parentId: 1),
      ]);

      final info = resolver.resolve(2);

      expect(info?.name, '早餐');
      expect(info?.parentName, '餐饮');
      expect(info?.icon, 'free_breakfast');
      expect(info?.color, 0xFF222222);
    });

    test('still resolves a soft-deleted category (history snapshot semantics)', () {
      final resolver = CategoryResolver([
        category(id: 1, name: '临时', icon: 'tag', color: 0xFF333333, isSystem: false, deletedAt: DateTime.utc(2026, 8, 2)),
      ]);

      expect(resolver.resolve(1)?.name, '临时');
    });

    test('returns null for unknown ids', () {
      final resolver = CategoryResolver([]);
      expect(resolver.resolve(999), isNull);
    });
  });
}
