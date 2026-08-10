import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/features/settings/appearance_page.dart';
import 'package:bookkeep_app/shared/theme/background/background_controller.dart';
import 'package:bookkeep_app/shared/theme/background/background_service.dart';
import 'package:bookkeep_app/shared/theme/background/background_settings.dart';
import 'package:bookkeep_app/shared/theme/theme_controller.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/theme/theme_settings.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// "外观"设置页（BK-UI-015）：8 套预制主题即时生效 + 图标风格 + 个性背景控制
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
    await tester.scrollUntilVisible(find.text('个性背景'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('个性背景'), findsOneWidget);
  });

  group('背景控制区（Spec §7）', () {
    /// 夹具文件用同步 API（FakeAsync 下异步文件 IO 永不完成，见挂起排查）
    Future<String> makeImageFile() async {
      final file = File('${tempDir.path}/sample.png');
      // 最小合法 PNG（1×1 白）
      file.writeAsBytesSync(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, //
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, //
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, //
        0x00, 0x00, 0x03, 0x00, 0x01, 0x82, 0x47, 0xF1, //
        0x7A, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
        0x44, 0xAE, 0x42, 0x60, 0x82, //
      ]);
      return file.path;
    }

    List<Override> backgroundOverrides(BackgroundSettings settings,
        {BackgroundService? service, double luminance = 0.5}) {
      return [
        backgroundControllerProvider.overrideWith(
            () => _FakeBackgroundController(settings)),
        if (service != null) backgroundServiceProvider.overrideWithValue(service),
        backgroundLuminanceProvider.overrideWith((ref) async => luminance),
      ];
    }

    testWidgets('select image → applied + persisted; restore default clears',
        (tester) async {
      final db = await harnessDb();
      final imagePath = await makeImageFile();
      final fakeService = _FakeService(File(imagePath), tempDir);
      await pumpPage(tester, pageHarness(db, extra: [
        backgroundServiceProvider.overrideWithValue(fakeService),
        backgroundLuminanceProvider.overrideWith((ref) async => 0.9),
      ]));

      // 背景区在懒加载 ListView 视口外，先滚动到可见
      await tester.scrollUntilVisible(find.text('使用背景图片'), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('使用背景图片'), findsOneWidget);
      // 未选图：开关禁用，提示选图
      final switchTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '使用背景图片'),
      );
      expect(switchTile.onChanged, isNull);
      expect(find.text('请先选择一张相册图片'), findsOneWidget);

      // 选图：fake zone 中 await 真实异步链（async 微任务/文件 IO）永不完成
      // （preset 等纯 drift 用例不挂，是因为 drift 走 isolate 消息；文件 IO
      // 走事件循环），故在 runAsync（真实 zone）内执行；夹具与 fake 服务的
      // 文件操作已同步化避免二次挂起
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(AppearancePage)),
      ).read(backgroundControllerProvider.notifier);
      final result = await tester.runAsync(controller.pickAndApply);
      expect(result!.isSuccess, isTrue);
      await tester.pump();

      // 应用成功：开关可用且开启，持久化落库
      final updated = await SettingsRepository(db).backgroundSettings();
      expect(updated.enabled, isTrue);
      expect(updated.imagePath, 'background/bg.png');
      expect(find.text('遮罩'), findsOneWidget);
      expect(find.text('背景模糊'), findsOneWidget);

      // 恢复默认：开关关闭、图片路径清除
      await tester.runAsync(controller.clear);
      await tester.pumpAndSettle();
      final cleared = await SettingsRepository(db).backgroundSettings();
      expect(cleared.enabled, isFalse);
      expect(cleared.imagePath, isNull);
    });

    testWidgets('manual alpha slider updates live and persists', (tester) async {
      final db = await harnessDb();
      await pumpPage(tester, pageHarness(db, extra: backgroundOverrides(
        const BackgroundSettings(
          enabled: true,
          imagePath: 'background/bg.png',
          overlayMode: OverlayMode.manual,
          manualAlpha: 0.5,
        ),
      )));

      await tapVisible(tester, find.text('手动'));
      await tester.pump();

      // 滑杆 + 评级存在；拖动滑杆到最右 → α 接近上限
      final slider = find.byType(Slider);
      await tapVisible(tester, slider);
      await tester.drag(slider, const Offset(400, 0));
      await tester.pump();
      final sliderWidget = tester.widget<Slider>(slider);
      expect(sliderWidget.value, greaterThan(0.8));

      final state = ProviderScope.containerOf(
        tester.element(find.byType(AppearancePage)),
      );
      expect(
        state.read(backgroundControllerProvider).valueOrNull!.manualAlpha,
        greaterThan(0.8),
      );
      final persisted = await SettingsRepository(db).backgroundSettings();
      expect(persisted.manualAlpha, greaterThan(0.8));
    });

    testWidgets('blur switch toggles and persists', (tester) async {
      final db = await harnessDb();
      await pumpPage(tester, pageHarness(db, extra: backgroundOverrides(
        const BackgroundSettings(
          enabled: true,
          imagePath: 'background/bg.png',
        ),
      )));

      final toggle = find.widgetWithText(SwitchListTile, '背景模糊');
      await tapVisible(tester, toggle);
      await tester.pump();

      final persisted = await SettingsRepository(db).backgroundSettings();
      expect(persisted.blurEnabled, isFalse);
    });
  });
}

/// 固定背景设置（不经 DB 读取；blur/滑杆持久化用例仍落真库验证）
class _FakeBackgroundController extends BackgroundController {
  _FakeBackgroundController(this.settings);

  final BackgroundSettings settings;

  @override
  Future<BackgroundSettings> build() async => settings;
}

/// fake 服务：跳过系统相册与 path_provider，全部落在临时目录
class _FakeService extends BackgroundService {
  _FakeService(this.pickedFile, this.tempDir);

  final File pickedFile;
  final Directory tempDir;

  @override
  Future<XFile?> pickImage() async => XFile(pickedFile.path);

  @override
  Future<File> importImage(XFile source) async {
    final target = File('${tempDir.path}/background/bg.png');
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(await source.readAsBytes());
    return target;
  }

  @override
  Future<void> deleteImage() async {
    final target = File('${tempDir.path}/background/bg.png');
    if (target.existsSync()) target.deleteSync();
  }
}
