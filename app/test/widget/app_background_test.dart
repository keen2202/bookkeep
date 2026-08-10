import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/background/app_background.dart';
import 'package:bookkeep_app/shared/theme/background/background_controller.dart';
import 'package:bookkeep_app/shared/theme/background/background_settings.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

/// AppBackground 三层结构（Spec §9 widget 层）：图/遮罩/模糊 + 状态栏联动
class _FakeController extends BackgroundController {
  _FakeController(this.settings);

  final BackgroundSettings settings;

  @override
  Future<BackgroundSettings> build() async => settings;
}

void main() {
  late Directory tempDir;
  late String imagePath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('bg_test_');
    // 生成一张 64×64 灰图 PNG 作为背景文件
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 64, 64),
      ui.Paint()..color = const ui.Color(0xFF9E9E9E),
    );
    final image = await recorder.endRecording().toImage(64, 64);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('${tempDir.path}/bg.png');
    await file.writeAsBytes(png.buffer.asUint8List());
    imagePath = file.path;
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Widget harness(BackgroundSettings settings, {double? luminance}) {
    return ProviderScope(
      overrides: [
        backgroundControllerProvider
            .overrideWith(() => _FakeController(settings)),
        if (luminance != null)
          backgroundLuminanceProvider.overrideWith((ref) async => luminance),
      ],
      child: MaterialApp(
        theme: buildTheme(findPresetById('t1')!),
        builder: (context, child) => AppBackground(child: child!),
        home: const Scaffold(body: Center(child: Text('内容'))),
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester, Widget widget) async {
    // 图片解码为真实异步 IO，在 runAsync 内完成避免挂起
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    // provider 完成通知在假异步区刷出（见 bg_debug_test 验证）
    await tester.pump();
  }

  testWidgets('未启用背景：无图/遮罩/模糊层，直接渲染内容', (tester) async {
    await pumpApp(tester, harness(const BackgroundSettings()));

    expect(find.text('内容'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(AnnotatedRegion<SystemUiOverlayStyle>), findsOneWidget);
  });

  testWidgets('启用 + 智能遮罩：图/遮罩/模糊三层结构存在', (tester) async {
    await pumpApp(tester, harness(
      BackgroundSettings(enabled: true, imagePath: imagePath),
      luminance: 0.9, // 极亮图
    ));

    expect(find.text('内容'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);

    // 遮罩色 = 主题 background × α（极亮图浅色主题 α≈0.82+）
    final stack = tester.widget<Stack>(
      find.ancestor(of: find.byType(Image), matching: find.byType(Stack)).first,
    );
    final mask = stack.children
        .whereType<ColoredBox>()
        .firstWhere((c) => c.color.a > 0 && c.color.a < 1);
    expect(mask.color.a, greaterThanOrEqualTo(0.82));
  });

  testWidgets('手动模式：α 取滑杆值，不随亮度映射', (tester) async {
    await pumpApp(tester, harness(
      BackgroundSettings(
        enabled: true,
        imagePath: imagePath,
        overlayMode: OverlayMode.manual,
        manualAlpha: 0.35,
      ),
      luminance: 0.9, // 智能映射会给出 0.82+，手动必须忽略
    ));

    final stack = tester.widget<Stack>(
      find.ancestor(of: find.byType(Image), matching: find.byType(Stack)).first,
    );
    final mask = stack.children
        .whereType<ColoredBox>()
        .firstWhere((c) => c.color.a > 0 && c.color.a < 1);
    expect(mask.color.a, closeTo(0.35, 0.001));
  });

  testWidgets('关闭模糊：无 BackdropFilter 层', (tester) async {
    await pumpApp(tester, harness(
      BackgroundSettings(enabled: true, imagePath: imagePath, blurEnabled: false),
      luminance: 0.5,
    ));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('图片文件缺失：errorBuilder 兜底，内容仍可渲染', (tester) async {
    await pumpApp(tester, harness(
      BackgroundSettings(enabled: true, imagePath: '/nonexistent/bg.png'),
      luminance: 0.5,
    ));

    expect(find.text('内容'), findsOneWidget);
  });
}
