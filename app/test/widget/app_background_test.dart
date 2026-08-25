import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/background/app_background.dart';
import 'package:bookkeep_app/shared/theme/glass_prefs.dart';
import 'package:bookkeep_app/shared/theme/glass_tokens.dart';
import 'package:bookkeep_app/shared/widgets/glass_panel.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

/// AppBackground（FGDS v1.0，BK-FG-002）：§2.2 纯净底色 + 降级偏好作用域
/// + 状态栏联动。旧背景图/遮罩/模糊三层结构已拆除（AC-02）。
void main() {
  Widget harness({bool blurEnabled = true, Brightness brightness = Brightness.light}) {
    return ProviderScope(
      overrides: [
        glassPrefsProvider.overrideWith(
            () => GlassPrefsController(initial: GlassPrefs(blurEnabled: blurEnabled))),
      ],
      child: MaterialApp(
        theme: buildTheme(findPresetById(brightness == Brightness.dark ? 't5' : 't1')!),
        builder: (context, child) => AppBackground(child: child!),
        home: const Scaffold(body: Center(child: Text('内容'))),
      ),
    );
  }

  testWidgets('渲染 §2.2 白名单底色（浅色 #F2F2F7），无图/无遮罩/无模糊层',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('内容'), findsOneWidget);
    expect(find.byType(Image), findsNothing, reason: '禁止背景图');
    expect(find.byType(BackdropFilter), findsNothing, reason: '背景层零模糊');
    expect(find.byType(AnnotatedRegion<SystemUiOverlayStyle>), findsOneWidget);

    // 底色 = 白名单 base
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(AppBackground),
        matching: find.byType(ColoredBox),
      ).first,
    );
    expect(box.color, GlassBackground.baseLight);
  });

  testWidgets('深色模式：底色为纯黑 #000000，状态栏图标反转', (tester) async {
    await tester.pumpWidget(harness(brightness: Brightness.dark));
    await tester.pump();

    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(AppBackground),
        matching: find.byType(ColoredBox),
      ).first,
    );
    expect(box.color, GlassBackground.baseDark);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('降级偏好经 GlassPrefsScope 下发：blurEnabled=false 时面板零模糊节点',
      (tester) async {
    await tester.pumpWidget(harness(blurEnabled: false));
    await tester.pump();
    // 内容层放一块 G2 面板验证作用域传导
    await tester.pumpWidget(ProviderScope(
      overrides: [
        glassPrefsProvider.overrideWith(
            () => GlassPrefsController(initial: const GlassPrefs(blurEnabled: false))),
      ],
      child: MaterialApp(
        theme: buildTheme(findPresetById('t1')!),
        builder: (context, child) => AppBackground(child: child!),
        home: const Scaffold(
          body: Center(child: GlassPanel(child: SizedBox(width: 80, height: 40))),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing,
        reason: '作用域关闭磨砂后玻璃面板跳过 BackdropFilter');
  });
}
