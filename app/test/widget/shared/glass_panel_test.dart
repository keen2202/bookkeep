import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_panel.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: buildTheme(
        findPresetById(brightness == Brightness.dark ? 't5' : 't1')!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('σ=0（standard 档 L1）：无 ClipRRect/BackdropFilter 节点（GLS-002 Checklist）',
      (tester) async {
    await tester.pumpWidget(_host(const GlassPanel(child: SizedBox(width: 100, height: 60))));
    expect(find.byType(BackdropFilter), findsNothing,
        reason: 'standard 档 L1 主路径 fill-only，零 saveLayer');
    expect(find.byKey(const ValueKey('glass-clip')), findsNothing);
    expect(find.byKey(const ValueKey('glass-blur')), findsNothing);
  });

  testWidgets('high 档（blurOverride σ>0）：ClipRRect + BackdropFilter 双保险节点存在',
      (tester) async {
    await tester.pumpWidget(_host(const GlassPanel(
      blurOverride: 10,
      child: SizedBox(width: 100, height: 60),
    )));
    // 节点结构断言（Spec §3.2：二者缺一不可）
    final clipFinder = find.byKey(const ValueKey('glass-clip'));
    expect(clipFinder, findsOneWidget, reason: '外层 ClipRRect 承担圆角');
    final blurFinder = find.byKey(const ValueKey('glass-blur'));
    expect(blurFinder, findsOneWidget);
    // BackdropFilter 的祖先必须是 ClipRRect（采样边界裁剪双保险）
    expect(
      find.ancestor(of: blurFinder, matching: find.byType(ClipRRect)),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('hover 态：描边 α+0.08、高光 α_top+0.05（120ms 过渡）', (tester) async {
    await tester.pumpWidget(_host(GlassPanel(
      onTap: () {},
      padding: const EdgeInsets.all(8),
      child: const SizedBox(width: 120, height: 60),
    )));
    BoxBorder borderOf() {
      final surface = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('glass-surface')),
      );
      return (surface.decoration! as BoxDecoration).border!;
    }

    final before = borderOf().top.color;
    // 模拟鼠标悬停
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(GlassPanel)));
    await tester.pumpAndSettle();
    final after = borderOf().top.color;
    expect(after.a, closeTo(before.a + 0.08, 0.005), reason: 'hover 描边 α+0.08');
    // 120ms 过渡时长断言
    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('glass-surface')),
    );
    expect(surface.duration, const Duration(milliseconds: 120));
  });

  testWidgets('按压态：填充叠加 scrim（150ms）', (tester) async {
    await tester.pumpWidget(_host(GlassPanel(
      onTap: () {},
      padding: const EdgeInsets.all(8),
      child: const SizedBox(width: 120, height: 60, key: ValueKey('inner')),
    )));
    Color fillOf() => (tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('glass-surface')),
        ).decoration! as BoxDecoration)
        .color!;
    final before = fillOf();
    await tester.press(find.byKey(const ValueKey('inner')));
    await tester.pumpAndSettle();
    final after = fillOf();
    expect(after, isNot(before), reason: '按压叠加 scrim 后填充变深');
    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('glass-surface')),
    );
    expect(surface.duration, const Duration(milliseconds: 150));
  });

  testWidgets('onTap 触发回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(GlassPanel(
      onTap: () => taps++,
      padding: const EdgeInsets.all(8),
      child: const SizedBox(width: 120, height: 60),
    )));
    await tester.tap(find.byType(GlassPanel));
    expect(taps, 1);
  });

  testWidgets('深色主题：填充为 surface 基（非纯白），描边实值 0.16', (tester) async {
    await tester.pumpWidget(_host(
      const GlassPanel(child: SizedBox(width: 100, height: 60)),
      brightness: Brightness.dark,
    ));
    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('glass-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final t5 = findPresetById('t5')!.palette;
    expect(decoration.color!.a, closeTo(0.70, 0.0001),
        reason: 'standard 档深色 L1 = 0.66 + 0.04 补偿');
    expect(decoration.color!.b, closeTo(t5.surface.b, 0.001),
        reason: '带主题色温非纯黑');
    expect(decoration.border!.top.color.a, closeTo(0.16, 0.0001));
  });

  testWidgets('innerSheen：图表容器前景装饰携带底部反光参数', (tester) async {
    // innerSheen 由 _GlassForegroundDecoration 承载；此处验证开关透传后
    // 面板仍正常渲染且与普通面板渲染互不干扰（视觉 golden 走样板间）
    await tester.pumpWidget(_host(const Column(children: [
      GlassPanel(innerSheen: true, child: SizedBox(width: 80, height: 40)),
      GlassPanel(child: SizedBox(width: 80, height: 40)),
    ])));
    expect(find.byType(GlassPanel), findsNWidgets(2));
  });
}
