import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass_tokens.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/category_picker.dart';

/// BK-DOC-31 需求3：记账页分类选择器的选中光晕收敛（blur 20 → 8）
void main() {
  Category category({
    required int id,
    int? parentId,
    required String name,
    required int color,
  }) =>
      Category(
        id: id,
        bookId: 'book-test',
        parentId: parentId,
        name: name,
        icon: 'restaurant',
        color: color,
        kind: CategoryKind.expense,
        isSystem: false,
        sortOrder: 0,
        updatedAt: DateTime.utc(2026, 8, 1),
      );

  final categories = [
    category(id: 1, name: '餐饮', color: 0xFFEF5350),
    category(id: 2, parentId: 1, name: '早餐', color: 0xFFEF5350),
    category(id: 3, parentId: 1, name: '午餐', color: 0xFFEF5350),
  ];

  /// 收集 GlassSelection 投射的光晕（BoxShadow）
  List<BoxShadow> glows(WidgetTester tester) {
    final result = <BoxShadow>[];
    for (final container in tester.widgetList<Container>(find.byType(Container))) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.boxShadow != null) {
        result.addAll(decoration.boxShadow!);
      }
    }
    return result;
  }

  Future<void> pump(WidgetTester tester, {int? selectedId}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(kThemePresetsV2.first),
      home: Scaffold(
        body: CategoryPicker(
          categories: categories,
          kind: CategoryKind.expense,
          initialCategoryId: selectedId,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('选中二级分类：光晕为 compact 值（blur 8 / primary α0.30）', (tester) async {
    await pump(tester, selectedId: 2);

    final shadows = glows(tester);
    expect(shadows, isNotEmpty);
    for (final shadow in shadows) {
      expect(shadow.blurRadius, GlassSelectionTokens.compactGlowBlur);
      expect(shadow.spreadRadius, 0);
      expect(
        shadow.color,
        tester
            .element(find.byType(CategoryPicker))
            .palette
            .primary
            .withValues(alpha: GlassSelectionTokens.compactGlowAlpha),
      );
    }
    // 收敛后的光晕远小于 FG-SEL 默认值（不再向外发散糊住相邻 chip）
    expect(
      GlassSelectionTokens.compactGlowBlur,
      lessThan(GlassSelectionTokens.glowBlur),
    );
  });

  testWidgets('未选中态不投射光晕', (tester) async {
    await pump(tester);

    expect(glows(tester), isEmpty);
  });

  testWidgets('点选二级分类回调 id（选中效果不改变交互语义）', (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(kThemePresetsV2.first),
      home: Scaffold(
        body: CategoryPicker(
          categories: categories,
          kind: CategoryKind.expense,
          onSelected: (id) => picked = id,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('午餐'));
    expect(picked, 3);
  });
}
