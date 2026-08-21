import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/background/app_background.dart';
import 'package:bookkeep_app/shared/theme/background/background_controller.dart';
import 'package:bookkeep_app/shared/theme/background/background_service.dart';
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

  Widget harness(
    BackgroundSettings settings, {
    double? luminance,
    bool realFileProvider = false,
    List<Override> extra = const [],
    Widget? home,
  }) {
    return ProviderScope(
      overrides: [
        backgroundControllerProvider
            .overrideWith(() => _FakeController(settings)),
        if (luminance != null)
          backgroundLuminanceProvider.overrideWith((ref) async => luminance),
        // 默认夹具：settings.imagePath 已是绝对路径，直接作为解析结果注入；
        // realFileProvider: true 时走真实 backgroundImageFileProvider（解析用例）
        if (!realFileProvider)
          backgroundImageFileProvider.overrideWith((ref) {
            final s = ref
                .watch(backgroundControllerProvider.select((v) => v.valueOrNull));
            final p = s?.imagePath;
            if (s == null || !s.enabled || p == null) return null;
            return File(p);
          }),
        ...extra,
      ],
      child: MaterialApp(
        theme: buildTheme(findPresetById('t1')!),
        builder: (context, child) => AppBackground(child: child!),
        home: home ?? const Scaffold(body: Center(child: Text('内容'))),
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester, Widget widget) async {
    // 图片解码/文件解析为真实异步 IO，在 runAsync（真实 zone）内完成避免挂起；
    // 轮询背景图文件与亮度两个 provider 直至结算（确定性等待，替代固定 sleep，
    // 覆盖真实 provider 的"controller 加载 → 重解析文件"异步链）
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      for (var i = 0; i < 200; i++) {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AppBackground)),
        );
        final fileState = container.read(backgroundImageFileProvider);
        final lumState = container.read(backgroundLuminanceProvider);
        if (!fileState.isLoading && !lumState.isLoading) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
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

  testWidgets('背景 revision 变化后 Image Key 与 Provider 同步刷新', (tester) async {
    await pumpApp(tester, harness(
      BackgroundSettings(enabled: true, imagePath: imagePath),
      luminance: 0.5,
    ));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppBackground)),
    );
    final before = tester.widget<Image>(find.byType(Image));
    expect(before.key, const ValueKey('bg-image-0'));

    container.read(backgroundRevisionProvider.notifier).state = 1;
    await tester.pump();

    final after = tester.widget<Image>(find.byType(Image));
    expect(after.key, const ValueKey('bg-image-1'));
    var provider = after.image;
    if (provider is ResizeImage) provider = provider.imageProvider;
    expect((provider as RevisionFileImage).revision, 1);
  });

  testWidgets('背景启用时不拦截内容点击', (tester) async {
    var tapped = false;
    await pumpApp(tester, harness(
      BackgroundSettings(enabled: true, imagePath: imagePath),
      luminance: 0.5,
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => tapped = true,
            child: const Text('点我'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('点我'));
    await tester.pump();
    expect(tapped, isTrue);
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
    final stackFinder = find.ancestor(
      of: find.byType(Image),
      matching: find.byType(Stack),
    ).first;
    final mask = tester
        .widgetList<ColoredBox>(
          find.descendant(of: stackFinder, matching: find.byType(ColoredBox)),
        )
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

    final stackFinder = find.ancestor(
      of: find.byType(Image),
      matching: find.byType(Stack),
    ).first;
    final mask = tester
        .widgetList<ColoredBox>(
          find.descendant(of: stackFinder, matching: find.byType(ColoredBox)),
        )
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

  testWidgets('相对路径键值经 backgroundImageFileProvider 解析为绝对路径且文件存在',
      (tester) async {
    // 在 tempDir 下建立与持久化键值一致的相对路径文件（background/bg.png）
    final dir = Directory('${tempDir.path}/background')..createSync(recursive: true);
    File(imagePath).copySync('${dir.path}/bg.png');
    final settings =
        BackgroundSettings(enabled: true, imagePath: 'background/bg.png');

    // 真实 provider 链路：settings 键值（相对路径）→ resolveImageFile → 绝对路径
    await pumpApp(tester, harness(
      settings,
      luminance: 0.5,
      realFileProvider: true,
      extra: [
        backgroundServiceProvider.overrideWithValue(_FakeResolveService(tempDir)),
      ],
    ));

    expect(find.text('内容'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    // cacheWidth 会让 Image 将 RevisionFileImage 包进 ResizeImage，先解包再断言
    var provider = image.image;
    if (provider is ResizeImage) provider = provider.imageProvider;
    final resolved = (provider as FileImage).file.path;
    expect(resolved, '${tempDir.path}/background/bg.png');
  });
}

/// fake 服务：resolveImageFile 映射到临时目录（与真实实现映射文档目录一致）
class _FakeResolveService extends BackgroundService {
  _FakeResolveService(this.tempDir);

  final Directory tempDir;

  @override
  Future<File?> resolveImageFile(String relativePath) async {
    final target = File('${tempDir.path}/$relativePath');
    return await target.exists() ? target : null;
  }
}
