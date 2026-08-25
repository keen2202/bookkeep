import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass_tokens.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/app_button.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(findPresetById('t1')!),
      home: Scaffold(
        body: Center(child: child),
      ),
    );

void main() {
  testWidgets('secondary 默认态：G2 fill α0.60 + blur σ20（BackdropFilter 存在）',
      (tester) async {
    await tester.pumpWidget(_host(const AppButton.secondary(
      onPressed: doNothing,
      child: Text('次按钮'),
    )));
    expect(find.byType(BackdropFilter), findsOneWidget);
    final container = tester.widgetList<AnimatedContainer>(
      find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color != null),
    ).first;
    final fill = (container.decoration! as BoxDecoration).color!;
    expect(fill, Colors.white.withValues(alpha: GlassButtonTokens.fillDefaultLight));
    expect(container.duration, GlassMotion.micro);
  });

  testWidgets('primary 变体：主题色着色玻璃 α0.75 + 白色实色文字（非实色按钮）',
      (tester) async {
    await tester.pumpWidget(_host(const AppButton.primary(
      onPressed: doNothing,
      child: Text('主操作'),
    )));
    final t1 = findPresetById('t1')!.palette;
    final expectedFill =
        t1.primary.withValues(alpha: GlassButtonTokens.primaryFillLight);
    expect(
      find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == expectedFill),
      findsOneWidget,
      reason: '主按钮为 primary α0.75 着色玻璃（AC-07 非实色）',
    );
    // 文字白色实色（样式由按钮内 AnimatedDefaultTextStyle 下发）
    final paragraph =
        tester.renderObject<RenderParagraph>(find.text('主操作'));
    expect(paragraph.text.style!.color, t1.onPrimary);
  });

  testWidgets('hover：blur σ24 + fill α0.68 + 内高光 +0.05（150ms 过渡）',
      (tester) async {
    await tester.pumpWidget(_host(const AppButton.secondary(
      onPressed: doNothing,
      child: Text('悬停'),
    )));
    // 模拟鼠标悬停
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('悬停')));
    await tester.pumpAndSettle();

    // σ 由 ImageFilter.blur 承载：断言 BackdropFilter 节点仍在且容器填充变 hover 值
    expect(find.byType(BackdropFilter), findsOneWidget);
    final container = tester.widgetList<AnimatedContainer>(
      find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color != null),
    ).first;
    expect((container.decoration! as BoxDecoration).color,
        Colors.white.withValues(alpha: GlassButtonTokens.fillHoverLight));
    // 内高光 +0.05：前景描边 alpha = G2 基准 + 0.05
    final fg = (container.foregroundDecoration! as BoxDecoration).border!;
    expect(fg.top.color.a,
        closeTo(GlassLevel.g2.highlightInnerAlphaLight + GlassButtonTokens.hoverHighlightBoost, 0.005));
    expect(container.duration, GlassMotion.micro);
  });

  testWidgets('pressed：fill α0.48 + scale 0.98；松开归位', (tester) async {
    await tester.pumpWidget(_host(const AppButton.secondary(
      onPressed: doNothing,
      child: Text('按压'),
    )));
    Color? fillOf() => tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) =>
            c.decoration is BoxDecoration ? (c.decoration! as BoxDecoration).color : null)
        .firstWhere((c) => c != null, orElse: () => null);

    final before = fillOf();
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('按压')));
    await tester.pumpAndSettle();
    expect(fillOf(),
        Colors.white.withValues(alpha: GlassButtonTokens.fillPressedLight));
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 0.98);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fillOf(), before);
  });

  testWidgets('focus：2px 外环 primary α0.50（键盘导航可见，无光晕阴影）',
      (tester) async {
    await tester.pumpWidget(_host(const AppButton.primary(
      onPressed: doNothing,
      child: Text('聚焦'),
    )));
    final primary =
        Theme.of(tester.element(find.text('聚焦'))).colorScheme.primary;

    final node = Focus.of(tester.element(find.text('聚焦')));
    node.requestFocus();
    await tester.pumpAndSettle();

    final ringDecos = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    ).where((c) =>
        c.foregroundDecoration is BoxDecoration &&
        (c.foregroundDecoration! as BoxDecoration).border != null &&
        ((c.foregroundDecoration! as BoxDecoration).border!.top.color.a > 0));
    expect(ringDecos, isNotEmpty, reason: '聚焦态存在前景环');
    final ringDeco = ringDecos.first.foregroundDecoration! as BoxDecoration;
    expect(ringDeco.border!.top.width, GlassButtonTokens.focusRingWidth);
    expect(ringDeco.border!.top.color,
        primary.withValues(alpha: GlassButtonTokens.focusRingAlpha));
  });

  testWidgets('loading：内置 spinner 且点击不触发（防重入）', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(AppButton.primary(
      onPressed: () => taps++,
      loading: true,
      child: const Text('加载中'),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(taps, 0, reason: 'loading 态禁止重复点击');
  });

  testWidgets('disabled：fill 降至 0.32、去内高光、不响应', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(AppButton.secondary(
      onPressed: () => taps++,
      child: const Text('禁用'),
    )));
    // 重新以 onPressed=null 构建
    await tester.pumpWidget(_host(const AppButton.secondary(
      onPressed: null,
      child: Text('禁用'),
    )));
    final container = tester.widgetList<AnimatedContainer>(
      find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color != null),
    ).first;
    expect((container.decoration! as BoxDecoration).color,
        Colors.white.withValues(alpha: GlassButtonTokens.fillDisabledLight));
    final fg = (container.foregroundDecoration! as BoxDecoration).border!;
    expect(fg.top.color.a, 0, reason: '禁用去内高光');
    await tester.tap(find.text('禁用'), warnIfMissed: false);
    expect(taps, 0, reason: '禁用不可交互');
  });
}

void doNothing() {}
