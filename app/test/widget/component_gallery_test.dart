import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/settings/component_gallery_page.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/app_choice_chip.dart';

/// BK-DOC-31 需求2 遗留项：组件样板间的主题切换 chip 去 ✔
void main() {
  testWidgets('主题切换 chip 用 AppChoiceChip 且不渲染 ✔', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ComponentGalleryPage()));
    await tester.pumpAndSettle();

    expect(find.byType(AppChoiceChip), findsNWidgets(kThemePresetsV2.length));
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.showCheckmark, isFalse);
    }
    expect(find.byIcon(Icons.check), findsNothing);

    // 切换主题后仍无 ✔，且选中态切到新主题
    final next = kThemePresetsV2[1];
    await tester.tap(find.text(next.name));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsNothing);
    final selected = tester.widget<ChoiceChip>(find.ancestor(
      of: find.text(next.name),
      matching: find.byType(ChoiceChip),
    ));
    expect(selected.selected, isTrue);
  });
}
