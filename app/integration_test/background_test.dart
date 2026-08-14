import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/shared/theme/background/background_settings.dart';

/// 背景系统集成测试（BK-UI-017，Spec §9 集成层）：
/// 选图→应用→杀进程重启→背景与遮罩恢复；手动/智能模式互切；主题切换回归。
///
/// 真机运行（需真实相册与文件系统）：
///   flutter test integration_test/background_test.dart -d device
/// Android 13+ 走 PhotoPicker；iOS 首次弹相册权限。
/// 未接入 CI 自动跑（文档 §11 风险缓冲：真机各 1 轮）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 干净状态启动（清空背景设置与图片文件）
  Future<void> resetState() async {
    final docs = await getApplicationDocumentsDirectory();
    final bg = File('${docs.path}/background/bg.png');
    if (bg.existsSync()) bg.deleteSync();
  }

  testWidgets('选图→应用→重启恢复→模式互切', (tester) async {
    await resetState();

    // 启动应用（真实数据库 + 全部真实 provider）；
    // 集成测试用独立未加密库，避免污染真实数据与 SQLCipher 迁移链
    final dbFile = await integrationDbFile();
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const BookkeepApp(),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // ① 外观页：未选图状态（审核 F1：首次选图主按钮存在）
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('使用背景图片'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('请先选择一张相册图片'), findsOneWidget);
    expect(find.text('选择背景图片'), findsOneWidget);

    // ② 首次选图：未选图态主按钮 → 系统相册（真机弹 PhotoPicker/相册，人工选图）
    await tester.tap(find.text('选择背景图片'));
    // 等待系统相册返回（人工选择后自动继续）
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));

    // 应用成功：开关开启、遮罩/模糊控制出现、设置持久化
    expect(find.text('遮罩'), findsOneWidget);
    expect(find.text('背景模糊'), findsOneWidget);
    final settings = await SettingsRepository(db).backgroundSettings();
    expect(settings.enabled, isTrue);
    expect(settings.imagePath, 'background/bg.png');

    // ③ 模拟杀进程重启：重建 app 树（真实场景是重启 App；集成测试内以
    // 重建 ProviderScope 等价验证持久化恢复）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const BookkeepApp(),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 重启后背景仍生效：AppBackground 已挂载（背景图文件存在）
    final restored = await SettingsRepository(db).backgroundSettings();
    expect(restored.enabled, isTrue);
    expect(restored.imagePath, 'background/bg.png');
    final bgFile = File('${(await getApplicationDocumentsDirectory()).path}/'
        '${restored.imagePath}');
    expect(bgFile.existsSync(), isTrue);

    // ④ 遮罩模式互切：智能 → 手动（滑杆出现）→ 智能
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('遮罩'), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('手动'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('文字对比度：'), findsOneWidget);

    await tester.tap(find.text('智能'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);

    final mode = await SettingsRepository(db).backgroundSettings();
    expect(mode.overlayMode, OverlayMode.auto);

    // ⑤ 主题切换回归：切第 2 套预制主题仍正常（背景不阻塞全树热重建）
    await tester.scrollUntilVisible(find.text('晴空·蓝'), -120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('晴空·蓝'));
    await tester.pumpAndSettle();
    final theme = await SettingsRepository(db).themeSettings();
    expect(theme.presetId, 't2');

    // ⑥ 清理：恢复默认（删除本地图片）
    await tester.scrollUntilVisible(find.text('恢复默认'), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    final cleared = await SettingsRepository(db).backgroundSettings();
    expect(cleared.enabled, isFalse);
    expect(cleared.imagePath, isNull);
    expect(bgFile.existsSync(), isFalse);
  });
}

/// 集成测试独立库文件（与生产库分开，避免污染真实数据）
Future<File> integrationDbFile() async {
  final docs = await getApplicationDocumentsDirectory();
  final f = File('${docs.path}/bookkeep_integration_test.sqlite');
  if (f.existsSync()) f.deleteSync();
  return f;
}
