import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/glass_tokens.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/glass_selection.dart';

/// BK-DOC-31 需求3：GlassSelection 光晕可覆盖，默认档语义不变
void main() {
  List<BoxShadow> shadowsOf(WidgetTester tester) {
    final result = <BoxShadow>[];
    for (final container in tester.widgetList<Container>(find.byType(Container))) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.boxShadow != null) {
        result.addAll(decoration.boxShadow!);
      }
    }
    return result;
  }

  Future<void> pump(
    WidgetTester tester, {
    required bool selected,
    double? glowAlpha,
    double? glowBlur,
  }) {
    return tester.pumpWidget(MaterialApp(
      theme: buildTheme(kThemePresetsV2.first),
      home: Scaffold(
        body: Center(
          child: GlassSelection(
            selected: selected,
            glowAlpha: glowAlpha,
            glowBlur: glowBlur,
            child: const SizedBox(width: 80, height: 32),
          ),
        ),
      ),
    ));
  }

  testWidgets('不传参 → 走 FG-SEL 默认档（blur 20 / α0.25）', (tester) async {
    await pump(tester, selected: true);

    final shadows = shadowsOf(tester);
    expect(shadows, hasLength(1));
    expect(shadows.single.blurRadius, GlassSelectionTokens.glowBlur);
    expect(
      shadows.single.color,
      tester
          .element(find.byType(GlassSelection))
          .palette
          .primary
          .withValues(alpha: GlassSelectionTokens.glowAlpha),
    );
  });

  testWidgets('传入紧凑档 → 覆盖 blur 与 α（分类弹窗用法）', (tester) async {
    await pump(
      tester,
      selected: true,
      glowAlpha: GlassSelectionTokens.compactGlowAlpha,
      glowBlur: GlassSelectionTokens.compactGlowBlur,
    );

    final shadows = shadowsOf(tester);
    expect(shadows, hasLength(1));
    expect(shadows.single.blurRadius, 8);
    expect(
      shadows.single.color,
      tester
          .element(find.byType(GlassSelection))
          .palette
          .primary
          .withValues(alpha: 0.30),
    );
  });

  testWidgets('未选中 → 四层整体不存在（无光晕）', (tester) async {
    await pump(tester, selected: false);

    expect(shadowsOf(tester), isEmpty);
  });
}
