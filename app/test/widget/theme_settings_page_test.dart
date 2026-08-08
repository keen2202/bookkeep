import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/features/settings/theme_settings_page.dart';
import 'package:bookkeep_app/shared/theme/theme_settings.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// 个性化主题设置页：预设色/外观模式即时生效 + 持久化 + 设置面板入口
void main() {
  testWidgets('preset theme switch applies immediately and persists', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: ThemeSettingsPage()),
    ));
    await tester.pump();

    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);

    // 点按第二个预设色（天蓝）
    final target = kThemePresets[1];
    await tester.tap(find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == target,
    ));
    await tester.pump();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(ThemeSettingsPage)));
    expect(container.read(themeSettingsProvider).seedColor, target);

    final persisted = await SettingsRepository(db).themeSettings();
    expect(persisted.seedColor, target);
    expect(persisted.mode, ThemeMode.system);
  });

  testWidgets('appearance mode switch persists', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: ThemeSettingsPage()),
    ));
    await tester.pump();

    await tester.tap(find.text('深色'));
    await tester.pump();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(ThemeSettingsPage)));
    expect(container.read(themeSettingsProvider).mode, ThemeMode.dark);

    final persisted = await SettingsRepository(db).themeSettings();
    expect(persisted.mode, ThemeMode.dark);
  });

  testWidgets('icon pack switch applies immediately and persists', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: ThemeSettingsPage()),
    ));
    await tester.pump();

    // 默认线性图标
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);

    await tester.tap(find.text('圆角'));
    await tester.pump();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(ThemeSettingsPage)));
    expect(container.read(themeSettingsProvider).iconPack, IconPack.rounded);
    // 模块图标预览与种子色/外观模式同步切换
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);

    final persisted = await SettingsRepository(db).themeSettings();
    expect(persisted.iconPack, IconPack.rounded);
    // 其余字段不受图标切换影响
    expect(persisted.mode, ThemeMode.system);
  });

  testWidgets('nav bar icons follow the selected icon pack', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const BookkeepApp(),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byIcon(Icons.calendar_month_outlined), findsWidgets);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('个性化主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('圆角'));
    await tester.pump();

    // 返回后底部导航图标随图标风格替换（zh 本地化下返回键 tooltip 非 'Back'，按类型查找）
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.calendar_month_rounded), findsWidgets);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
  });

  testWidgets('settings sheet entry opens the theme page', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const BookkeepApp(),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('个性化主题'));
    await tester.pumpAndSettle();

    expect(find.text('主题颜色'), findsOneWidget);
    expect(find.text('外观模式'), findsOneWidget);
  });
}
