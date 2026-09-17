import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/icons/bk_icon.dart';
import 'package:bookkeep_app/shared/icons/bk_glass_icon.dart';
import 'package:bookkeep_app/shared/icons/bk_icon_registry.dart';
import 'package:bookkeep_app/shared/icons/bk_icons.dart';
import 'package:bookkeep_app/shared/icons/bk_icon_tokens.dart';
import 'package:bookkeep_app/shared/icons/painters/bk_painter_base.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/theme/tokens.dart';
import 'package:bookkeep_app/shared/widgets/glass_icon.dart';

/// 挂载最小 MaterialApp，注入默认浅色主题
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        extensions: [
          AppTokens(
            palette: kThemePresetsV2.first.palette,
            brightness: Brightness.light,
          ),
        ],
      ),
      home: Scaffold(body: Center(child: child)),
    );

ThemePalette get _palette => kThemePresetsV2.first.palette;

/// 取出 BkIcon 内部 CustomPaint 的实际 Painter，用于断言真实解析色。
BkPainterBase _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(BkIcon),
      matching: find.byType(CustomPaint),
    ),
  );
  return customPaint.painter! as BkPainterBase;
}

void main() {
  setUpAll(() {
    BkIconRegistry.ensureInitialized();
  });

  group('BK-IC-001 Token / 注册表', () {
    test('Token 与 34 §4.1 一致', () {
      expect(BkIconTokens.canvas, 24);
      expect(BkIconTokens.safe, 2);
      expect(BkIconTokens.strokeWidth, 1.75);
      expect(BkIconTokens.strokeCap, StrokeCap.round);
      expect(BkIconTokens.strokeJoin, StrokeJoin.round);
    });

    test('首期最小集全部可解析（34 §11）', () {
      for (final name in BkIcons.firstWave) {
        expect(
          BkIconRegistry.isRegistered(name),
          isTrue,
          reason: '$name 未注册',
        );
      }
    });

    test('nav 族判定', () {
      expect(BkIcons.isNav(BkIcons.bills), isTrue);
      expect(BkIcons.isNav(BkIcons.reports), isTrue);
      expect(BkIcons.isNav(BkIcons.entry), isFalse);
      expect(BkIcons.isNav(BkIcons.billList), isFalse);
    });
  });

  group('BK-IC-002 颜色绑定', () {
    testWidgets('无 color 参数时解析为 palette.textPrimary', (tester) async {
      await tester.pumpWidget(_wrap(const BkIcon(BkIcons.bills, size: 24)));
      expect(_painterOf(tester).color, _palette.textPrimary);
    });

    testWidgets('nav + selected=true 使用 palette.primary', (tester) async {
      // selected 进场动画 value 初始即为 1（initState value: selected ? 1 : 0）
      await tester.pumpWidget(_wrap(
        const BkIcon(BkIcons.bills, size: 24, selected: true),
      ));
      await tester.pumpAndSettle();
      expect(_painterOf(tester).color, _palette.primary);
    });

    testWidgets('非 nav + selected 忽略 selected，仍用 textPrimary', (tester) async {
      await tester.pumpWidget(_wrap(
        const BkIcon(BkIcons.billList, size: 24, selected: true),
      ));
      await tester.pumpAndSettle();
      expect(_painterOf(tester).color, _palette.textPrimary);
    });

    testWidgets('显式 color 优先于默认槽位', (tester) async {
      const override = Color(0xFF123456);
      await tester.pumpWidget(_wrap(
        const BkIcon(BkIcons.rptPie, size: 24, color: override),
      ));
      expect(_painterOf(tester).color, override);
    });
  });

  group('BK-IC-005 shouldRepaint', () {
    test('color 变化应 repaint', () {
      final a = BkIconRegistry.resolve(
        BkIcons.bills,
        color: const Color(0xFF000000),
        selected: false,
      )!;
      final b = BkIconRegistry.resolve(
        BkIcons.bills,
        color: const Color(0xFFFFFFFF),
        selected: false,
      )!;
      expect(a.shouldRepaint(b), isTrue);
    });

    test('selected 变化应 repaint', () {
      final a = BkIconRegistry.resolve(
        BkIcons.bills,
        color: const Color(0xFF000000),
        selected: false,
      )!;
      final b = BkIconRegistry.resolve(
        BkIcons.bills,
        color: const Color(0xFF000000),
        selected: true,
      )!;
      expect(a.shouldRepaint(b), isTrue);
    });

    test('字段不变不 repaint', () {
      final a = BkIconRegistry.resolve(
        BkIcons.reports,
        color: const Color(0xFF000000),
        selected: true,
      )!;
      final b = BkIconRegistry.resolve(
        BkIcons.reports,
        color: const Color(0xFF000000),
        selected: true,
      )!;
      expect(a.shouldRepaint(b), isFalse);
    });
  });

  group('BK-IC-003 BkGlassIcon 三档渲染', () {
    testWidgets('28/36/44 三档渲染无溢出', (tester) async {
      for (final size in GlassIconSize.values) {
        await tester.pumpWidget(_wrap(
          BkGlassIcon(name: BkIcons.bills, size: size),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size 渲染异常');
        expect(find.byType(BkGlassIcon), findsOneWidget);
      }
    });
  });

  group('BK-IC-013 selected 动画', () {
    testWidgets('nav selected 默认 200ms 色值过渡', (tester) async {
      await tester.pumpWidget(_wrap(const BkIcon(BkIcons.bills, size: 24)));
      expect(_painterOf(tester).color, _palette.textPrimary);

      await tester.pumpWidget(
        _wrap(const BkIcon(BkIcons.bills, size: 24, selected: true)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _painterOf(tester).color;
      expect(mid, isNot(_palette.textPrimary));
      expect(mid, isNot(_palette.primary));

      await tester.pumpAndSettle();
      expect(_painterOf(tester).color, _palette.primary);
    });

    testWidgets('disableAnimations 时 100ms 内完成过渡', (tester) async {
      Widget wrapReduced(Widget child) => MaterialApp(
            theme: ThemeData(
              extensions: [
                AppTokens(
                  palette: kThemePresetsV2.first.palette,
                  brightness: Brightness.light,
                ),
              ],
            ),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(body: Center(child: child)),
            ),
          );

      await tester.pumpWidget(
        wrapReduced(const BkIcon(BkIcons.bills, size: 24)),
      );
      await tester.pumpWidget(
        wrapReduced(
          const BkIcon(BkIcons.bills, size: 24, selected: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(_painterOf(tester).color, _palette.primary);
    });
  });
}
