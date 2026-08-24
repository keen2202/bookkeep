import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/background/ambient_gradient.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

/// 背景图探针 fixture 生成器（Glassmorphism v3，Spec 附录 A / BK-GLS-017）。
///
/// `test/fixtures/bg_probe.png` 为入库的**多色渐变探针图**（T1 全套环境光
/// 渲染样张），供「样板间 × 自定义背景图」golden 用例作为背景图源。
///
/// 重新生成（一次性提交，勿随手刷新）：
/// ```
/// flutter test --update-goldens test/golden/generate_bg_fixture_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    goldenFileComparator = LocalFileComparator(
      Uri.parse(
        'file://${Directory.current.path}/test/golden/generate_bg_fixture_test.dart',
      ),
    );
  });

  testWidgets('生成 bg_probe.png（多色渐变探针）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        // 隔离真实数据库（drift_flutter 会触发 path_provider 插件）
        overrides: [
          databaseProvider.overrideWithValue(
            AppDatabase(NativeDatabase.memory()),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(findPresetById('t1')!),
          home: AmbientGradient(
            child: Container(
              alignment: Alignment.center,
              color: Colors.black26,
              child: const Text('BG PROBE'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../fixtures/bg_probe.png'),
    );
  });
}
