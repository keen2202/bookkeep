import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/app_choice_chip.dart';

/// BK-DOC-31 需求2：ChoiceChip 收敛出口——选中态去 ✔，改 primary 前景突显
void main() {
  Widget harness({
    required bool selected,
    ValueChanged<bool>? onSelected,
  }) {
    return MaterialApp(
      theme: buildTheme(kThemePresetsV2.first),
      home: Scaffold(
        body: Center(
          child: AppChoiceChip(
            label: const Text('月初（1日）'),
            selected: selected,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('选中态关闭 M3 默认 ✔', (tester) async {
    await tester.pumpWidget(harness(selected: true));

    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip)).showCheckmark,
        isFalse);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('选中态以 primary 前景 + 加粗突显（颜色不是唯一通道：仍有 selected 语义）',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(kThemePresetsV2.first),
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold(
              body: Center(
                child: AppChoiceChip(label: Text('月初（1日）'), selected: true),
              ),
            );
          },
        ),
      ),
    );

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.selected, isTrue);
    expect(chip.labelStyle?.color, context.palette.primary);
    expect(chip.labelStyle?.fontWeight, FontWeight.w600);
  });

  testWidgets('未选中态回落主文字色、不加粗', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(kThemePresetsV2.first),
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold(
              body: Center(
                child: AppChoiceChip(label: Text('月初（1日）'), selected: false),
              ),
            );
          },
        ),
      ),
    );

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.labelStyle?.color, context.palette.textPrimary);
    // 未选中不加重字重（bodyMedium 自身的字重保留）
    expect(chip.labelStyle?.fontWeight, isNot(FontWeight.w600));
  });

  testWidgets('点按回调携带目标选中值；onSelected 为空则不可点', (tester) async {
    bool? picked;
    await tester.pumpWidget(harness(selected: false, onSelected: (v) => picked = v));
    await tester.tap(find.byType(AppChoiceChip));
    expect(picked, isTrue);

    await tester.pumpWidget(harness(selected: false));
    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip)).onSelected,
      isNull,
    );
  });
}
