import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/icons/bk_icon.dart';
import 'package:bookkeep_app/shared/icons/bk_icon_registry.dart';
import 'package:bookkeep_app/shared/icons/bk_icons.dart';
import 'package:bookkeep_app/shared/icons/bk_icon_tokens.dart';
import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/theme/tokens.dart';

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
      late Color resolved;
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) {
            resolved = context.palette.textPrimary;
            return const BkIcon(BkIcons.bills, size: 24);
          },
        ),
      ));
      expect(resolved, _palette.textPrimary);
      expect(find.byType(BkIcon), findsOneWidget);
    });

    testWidgets('nav + selected=true 使用 palette.primary', (tester) async {
      // selected 进场动画 value 初始即为 1（initState value: selected ? 1 : 0）
      await tester.pumpWidget(_wrap(
        const BkIcon(BkIcons.bills, size: 24, selected: true),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BkIcon), findsOneWidget);
    });

    testWidgets('非 nav + selected 不崩溃（忽略 selected）', (tester) async {
      await tester.pumpWidget(_wrap(
        const BkIcon(BkIcons.billList, size: 24, selected: true),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BkIcon), findsOneWidget);
    });

    testWidgets('显式 color 优先于默认槽位', (tester) async {
      const override = Color(0xFF123456);
      await tester.pumpWidget(_wrap(
        const BkIcon(BkIcons.rptPie, size: 24, color: override),
      ));
      expect(find.byType(BkIcon), findsOneWidget);
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
}
