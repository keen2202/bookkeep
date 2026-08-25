
import 'dart:io';

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
import 'package:bookkeep_app/features/settings/appearance_page.dart';
import 'package:bookkeep_app/shared/theme/glass_prefs.dart';
import 'package:bookkeep_app/shared/theme/theme_controller.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/theme/theme_settings.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// "外观"设置页（FGDS v1.0）：8 套预制主题即时生效 + 图标风格 + 玻璃磨砂降级开关。
/// 旧「个性背景 / 环境光」控制区已随纯净背景约束拆除（Spec §2.2，AC-02）。
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('appearance_test_');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<AppDatabase> harnessDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  /// 手机尺寸表面（390×844 逻辑），并 pump 页面
  Future<void> pumpPage(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  Widget pageHarness(AppDatabase db, {List<Override> extra = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...extra,
      ],
      child: const MaterialApp(home: AppearancePage()),
    );
  }

  /// 滚到目标可见后点击
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('preset theme switch applies immediately and persists', (tester) async {
    final db = await harnessDb();
    await pumpPage(tester, pageHarness(db));

    // 8 套预制 + 自定义格
    expect(find.byType(AppearancePage), findsOneWidget);
    for (final preset in kThemePresetsV2) {
      expect(find.text(preset.name), findsOneWidget);
    }

    await tapVisible(tester, find.text('晴空·蓝'));
    await tester.pump();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(AppearancePage)));
    expect(container.read(themeControllerProvider).presetId, 't2');

    final persisted = await SettingsRepository(db).themeSettings();
    expect(persisted.presetId, 't2');
  });

  testWidgets('custom cell opens the custom theme sheet and applies seed + mode',
      (tester) async {
    final db = await harnessDb();
    await pumpPage(tester, pageHarness(db));

    await tapVisible(tester, find.text('自定义'));
    await tester.pumpAndSettle();
    expect(find.text('自定义主题'), findsOneWidget);
    expect(find.text('外观模式'), findsOneWidget);

    // 选天蓝种子色 + 深色模式（40×40 种子圆点；主题卡预览里同色 6×6 圆点需排除）
    final target = kThemePresets[1];
    await tester.tap(find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == 40 &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == target,
    ));
    await tester.tap(find.text('深色'));
    await tester.pump();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(AppearancePage)));
    expect(container.read(themeControllerProvider).isCustom, isTrue);
    expect(container.read(themeControllerProvider).seedColor, target);
    expect(container.read(themeControllerProvider).mode, ThemeMode.dark);

    final persisted = await SettingsRepository(db).themeSettings();
    expect(persisted.seedColor, target);
    expect(persisted.mode, ThemeMode.dark);
  });

  testWidgets('icon pack switch applies immediately and persists', (tester) async {
    final db = await harnessDb();
    await pumpPage(tester, pageHarness(db));

    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);

    await tapVisible(tester, find.text('圆角'));
    await tester.pump();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(AppearancePage)));
    expect(container.read(themeControllerProvider).iconPack, IconPack.rounded);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

    final persisted = await SettingsRepository(db).themeSettings();
    expect(persisted.iconPack, IconPack.rounded);
  });

  // ── FGDS：玻璃质感唯一可调项——磨砂降级开关（BK-FG-003）──

  testWidgets('玻璃降级开关：即时生效并持久化', (tester) async {
    final db = await harnessDb();
    await pumpPage(tester, pageHarness(db));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearancePage)),
    );
    expect(container.read(glassPrefsProvider).blurEnabled, isTrue);

    await tester.scrollUntilVisible(find.text('真实磨砂'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('真实磨砂'));
    await tester.pumpAndSettle();
    expect(container.read(glassPrefsProvider).blurEnabled, isFalse);
    final stored = await SettingsRepository(db).glassPrefs();
    expect(stored.blurEnabled, isFalse);
  });

  testWidgets('settings sheet entry opens the appearance page', (tester) async {
    final db = await harnessDb();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(find.text('主题方案'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('图标风格'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('图标风格'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('玻璃质感'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('玻璃质感'), findsOneWidget);
  });
}
