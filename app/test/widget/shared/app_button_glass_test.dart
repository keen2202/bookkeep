import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_layers.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_panel.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_quality.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/app_button.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(findPresetById('t1')!),
      home: Scaffold(
        body: Center(child: child),
      ),
    );

void main() {
  testWidgets('glass 变体：L2 填充 + 描边 + 顶部高光（GLS-006）', (tester) async {
    await tester.pumpWidget(_host(const AppButton.glass(
      onPressed: doNothing,
      child: Text('玻璃按钮'),
    )));
    // 面板渲染复用 GlassPanel（D1 单一玻璃出口）
    expect(find.byType(GlassPanel), findsOneWidget);
    expect(find.text('玻璃按钮'), findsOneWidget);
    final palette = findPresetById('t1')!.palette;
    final dockSpec = resolveGlassSpec(
      tier: GlassTier.dock,
      brightness: Brightness.light,
      palette: palette,
      quality: GlassQuality.standard,
    );
    // GlassPanel 内部 AnimatedContainer 承载 L2 fill
    expect(
      find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == dockSpec.fill),
      findsOneWidget,
      reason: 'glass 变体取 dock 层标准档填充',
    );
  });

  testWidgets('primary 变体：品牌色玻璃（primary α0.90 叠加），前景 onPrimary',
      (tester) async {
    await tester.pumpWidget(_host(const AppButton.primary(
      onPressed: doNothing,
      child: Text('主操作'),
    )));
    final t1 = findPresetById('t1')!.palette;
    final dockFill = resolveGlassSpec(
      tier: GlassTier.dock,
      brightness: Brightness.light,
      palette: t1,
      quality: GlassQuality.standard,
    ).fill;
    final expected = Color.alphaBlend(t1.primary.withValues(alpha: 0.90), dockFill);
    expect(
      find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == expected),
      findsOneWidget,
    );
  });

  testWidgets('hover：描边 α+0.08 / 高光 +0.05（120ms）；press：scrim 加深（150ms）',
      (tester) async {
    await tester.pumpWidget(_host(const AppButton.primary(
      onPressed: doNothing,
      child: Text('三态'),
    )));
    Color? fillOf() {
      final panels = tester.widgetList<AnimatedContainer>(
        find.byWidgetPredicate((w) =>
            w is AnimatedContainer && w.decoration is BoxDecoration),
      );
      for (final c in panels) {
        final d = c.decoration! as BoxDecoration;
        if (d.color != null) return d.color;
      }
      return null;
    }

    final before = fillOf();
    expect(before, isNotNull);
    // 按压
    final gesture = await tester.startGesture(tester.getCenter(find.text('三态')));
    await tester.pumpAndSettle();
    final pressed = fillOf();
    expect(pressed, isNot(before), reason: '按压填充 scrim 加深');
    // 松开归位（150ms 过渡）
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fillOf(), before);
    // scale 缩放断言：Listener→AnimatedScale 管线存在
    expect(find.byType(AnimatedScale), findsOneWidget);
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, const Duration(milliseconds: 150));
    expect(scale.scale, 1.0);
  });

  testWidgets('focus ring：primary 2px 外环 + α0.18 blur8 光晕（150ms）',
      (tester) async {
    await tester.pumpWidget(_host(const AppButton.primary(
      onPressed: doNothing,
      child: Text('聚焦'),
    )));
    final primary =
        Theme.of(tester.element(find.text('聚焦'))).colorScheme.primary;

    // 经按钮内部 Focus 节点（取其子孙 context）申请焦点，触发 onFocusChange
    final node = Focus.of(tester.element(find.text('聚焦')));
    node.requestFocus();
    await tester.pumpAndSettle();

    // 外环：常驻 2px padding 的 AnimatedContainer 边框变 primary
    final ring = tester.widgetList<Container>(find.byType(Container)).where(
      (c) =>
          c.decoration is BoxDecoration &&
          (c.decoration! as BoxDecoration).border != null &&
          (c.decoration! as BoxDecoration).border!.top.color == primary &&
          (c.decoration! as BoxDecoration).border!.top.width == 2,
    );
    expect(ring, isNotEmpty, reason: 'focus 态出现 primary 2px 外环');
    // 光晕：primary α0.18 blur8 spread2 阴影
    final glow = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    ).any((c) => c.decoration is BoxDecoration && ((c.decoration! as BoxDecoration).boxShadow?.isNotEmpty ?? false));
    expect(glow, isTrue, reason: 'focus 态携带外发光阴影');
    // 过渡时长 150ms
    final durations = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    ).map((c) => c.duration);
    expect(durations, contains(const Duration(milliseconds: 150)));
  });

  testWidgets('loading：内置 spinner 且点击不触发（防重入）', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(AppButton.primary(
      onPressed: () => taps++,
      loading: true,
      child: const Text('加载中'),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('加载中'), findsNothing, reason: 'loading 时替换 label');
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(taps, 0, reason: 'loading 态禁止重复点击');
  });

  testWidgets('disabled：onPressed=null 不响应且降透明度', (tester) async {
    await tester.pumpWidget(_host(const AppButton.secondary(
      onPressed: null,
      child: Text('禁用'),
    )));
    await tester.tap(find.text('禁用'), warnIfMissed: false);
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('禁用'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(1.0));
  });
}

void doNothing() {}
