import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass_tokens.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/glass_panel.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: buildTheme(
        findPresetById(brightness == Brightness.dark ? 't5' : 't1')!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('默认（blurEnabled）：G2 面板渲染 ClipRRect + BackdropFilter 节点',
      (tester) async {
    await tester.pumpWidget(_host(const GlassPanel(child: SizedBox(width: 100, height: 60))));
    final blurFinder = find.byKey(const ValueKey('glass-blur'));
    expect(blurFinder, findsOneWidget);
    // BackdropFilter 的祖先必须是 ClipRRect（采样边界裁剪）
    expect(
      find.ancestor(of: blurFinder, matching: find.byType(ClipRRect)),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('降级作用域（GlassPrefsScope.blurEnabled=false）：零模糊节点 + fill α+0.10 补偿',
      (tester) async {
    await tester.pumpWidget(_host(GlassPrefsScope(
      blurEnabled: false,
      child: const GlassPanel(child: SizedBox(width: 100, height: 60)),
    )));
    expect(find.byType(BackdropFilter), findsNothing,
        reason: '禁用磨砂后跳过 BackdropFilter 节点');
    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('glass-surface')),
    );
    final fill = (surface.decoration! as BoxDecoration).color!;
    expect(fill.a,
        closeTo(GlassLevel.g2.fillAlphaLight + kBlurDegradeFillCompensation, 0.0001),
        reason: 'fill α +0.10 补偿（Spec §3 派生规则）');
  });

  testWidgets('双层描边：外层深色勾边 + 前景白色高光（各 0.5px）', (tester) async {
    await tester.pumpWidget(_host(const GlassPanel(child: SizedBox(width: 100, height: 60))));
    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('glass-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final fg = surface.foregroundDecoration! as BoxDecoration;
    final spec = resolveGlassSpec(level: GlassLevel.g2, brightness: Brightness.light);
    expect(decoration.border!.top.width, 0.5);
    expect(decoration.border!.top.color, spec.borderOuter);
    expect(fg.border!.top.color, spec.borderInnerHighlight);
    expect(fg.border!.top.width, 0.5);
  });

  testWidgets('顶部内高光：前景渐变覆盖高度 40%（Spec §3 内高光覆盖行）', (tester) async {
    await tester.pumpWidget(_host(const GlassPanel(child: SizedBox(width: 100, height: 60))));
    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('glass-surface')),
    );
    final fg = surface.foregroundDecoration! as BoxDecoration;
    final gradient = fg.gradient! as LinearGradient;
    expect(gradient.colors.first, Colors.white.withValues(alpha: 0.20));
    expect(gradient.colors.last, Colors.transparent);
    expect((gradient.end as Alignment).y, closeTo(0.40, 0.0001));
  });

  testWidgets('按压态：fill→0.48 + scale 0.98 + 150ms 过渡（FG-CARD 点击反馈）', (tester) async {
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
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('inner'))));
    await tester.pumpAndSettle();
    final after = fillOf();
    expect(after.a, closeTo(0.48, 0.005), reason: 'pressed fill 0.48（浅）');
    expect(after, isNot(before));
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 0.98);
    expect(scale.duration, GlassMotion.micro);
    await gesture.up();
    await tester.pumpAndSettle();
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

  testWidgets('嵌套构造：GlassPanel.nested 零新增模糊节点且取下一档填充', (tester) async {
    await tester.pumpWidget(_host(Column(children: [
      GlassPanel(level: GlassLevel.g2, child: const SizedBox(width: 80, height: 40)),
      GlassPanel.nested(host: GlassLevel.g2, child: const SizedBox(width: 80, height: 40)),
    ])));
    // 宿主面板 1 个模糊节点；嵌套层不叠加
    expect(find.byType(BackdropFilter), findsOneWidget);
    final surfaces = tester.widgetList<AnimatedContainer>(
      find.byKey(const ValueKey('glass-surface')),
    );
    final nestedFill =
        surfaces.last.decoration! as BoxDecoration;
    expect(nestedFill.color!.a, closeTo(GlassLevel.g3.fillAlphaLight, 0.0001),
        reason: '内层用 G3 填充值（Spec §4.5 嵌套行）');
  });
}
