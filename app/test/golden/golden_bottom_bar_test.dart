import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/icons/bk_icons.dart';
import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass_tokens.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/glass_nav.dart';

/// BK-IC-014 / 34 AC-08：底栏浅/深与非默认主题 Golden。
///
/// 覆盖 selectedIndex 0/1 两帧，固定验证 tabs 选中 fill、未选中 outline
/// 与中央 `bk.act.entry` 圆内加号；容差 0.5% 与既有 golden 测试一致。
void main() {
  setUpAll(() {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/golden/golden_bottom_bar_test.dart'),
      precisionTolerance: 0.005,
    );
  });

  Future<void> pumpBottomBar(
      WidgetTester tester, AppThemePreset preset, int selectedIndex) async {
    tester.view.physicalSize = const Size(390, 220);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(preset),
        home: Scaffold(
          backgroundColor: preset.isDark
              ? GlassBackground.baseDark
              : GlassBackground.baseLight,
          body: const SizedBox.expand(),
          bottomNavigationBar: GlassBottomBar(
            selectedIndex: selectedIndex,
            onTap: (_) {},
            items: const [
              GlassNavItem(bkName: BkIcons.bills, label: '账单'),
              GlassNavItem(bkName: BkIcons.reports, label: '报表'),
            ],
            centerAction: const GlassCenterAction(
              bkName: BkIcons.entry,
              semanticLabel: '记一笔',
              onTap: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final presets = [
    kThemePresetsV2.firstWhere((p) => p.id == 't1'),
    kThemePresetsV2.firstWhere((p) => p.id == 't4'),
    kThemePresetsV2.firstWhere((p) => p.id == 't6'),
  ];

  for (final preset in presets) {
    for (final selectedIndex in [0, 1]) {
      final selectedName = selectedIndex == 0 ? 'bills' : 'reports';
      testWidgets('${preset.id} ${preset.name} 底栏 $selectedName selected',
          (tester) async {
        await pumpBottomBar(tester, preset, selectedIndex);
        await expectLater(
          find.byType(GlassBottomBar),
          matchesGoldenFile(
              'goldens/${preset.id}_bottom_bar_${selectedName}_selected.png'),
        );
      });
    }
  }
}

void _noop() {}

/// 0.5% 容差比较器（与 golden_ui_test / golden_tabs_test 同实现）
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         0 <= precisionTolerance && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (!passed) {
      throw TestFailure(
        'Golden 差异 ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        '> ${(_precisionTolerance * 100).toStringAsFixed(1)}%（$golden）',
      );
    }
    result.dispose();
    return true;
  }
}
