import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/widgets/app_segmented_button.dart';

/// BK-DOC-28 需求7（Spec §2.7，AC7-1 ~ AC7-4）：分段控件去 ✔，改颜色突显
void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// 无 AppTokens 主题扩展时 `context.palette` 回落到首个主题预设，
  /// 组件与用例两侧取到同一份调色板，故可直接断言派生色值
  Widget themed(Widget Function(BuildContext context) builder) =>
      harness(Builder(builder: builder));

  testWidgets('selected segment drops the check icon and highlights by color',
      (tester) async {
    late Color primary;
    await tester.pumpWidget(themed((context) {
      primary = context.palette.primary;
      return AppSegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'a', label: Text('甲')),
          ButtonSegment(value: 'b', label: Text('乙')),
        ],
        selected: const {'a'},
        onSelectionChanged: (_) {},
      );
    }));
    await tester.pumpAndSettle();

    // AC7-1：框架默认 ✔ 不再渲染
    expect(find.byIcon(Icons.check), findsNothing);
    final segmented = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(segmented.showSelectedIcon, isFalse);

    // AC7-2 / AC7-4：选中色收敛在共享组件内——primary α0.12 底（玻璃规范
    // AC-07 禁实色填充）+ primary 前景
    expect(
      segmented.style?.selectedBackgroundColor?.resolve({WidgetState.selected}),
      primary.withValues(alpha: 0.12),
    );
    expect(
      segmented.style?.selectedForegroundColor?.resolve({WidgetState.selected}),
      primary,
    );
  });

  testWidgets('selection still fires and disabled segments stay inert',
      (tester) async {
    String? picked;
    await tester.pumpWidget(harness(
      AppSegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'a', label: Text('甲')),
          ButtonSegment(value: 'b', label: Text('乙')),
          // 记账页「转账」锁定态同此语义：禁用段不参与选中着色
          ButtonSegment(value: 'c', label: Text('丙'), enabled: false),
        ],
        selected: const {'a'},
        onSelectionChanged: (s) => picked = s.first,
      ),
    ));
    await tester.pumpAndSettle();

    // AC7-3：选中行为不回归
    await tester.tap(find.text('乙'));
    await tester.pumpAndSettle();
    expect(picked, 'b');

    // AC7-3：禁用态不回归（点按无回调）
    await tester.tap(find.text('丙'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, 'b');
  });

  testWidgets('omitting the callback leaves every segment inert',
      (tester) async {
    await tester.pumpWidget(harness(
      const AppSegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'a', label: Text('甲')),
          ButtonSegment(value: 'b', label: Text('乙')),
        ],
        selected: {'a'},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsNothing);
    expect(tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    ).onSelectionChanged, isNull);
  });
}
