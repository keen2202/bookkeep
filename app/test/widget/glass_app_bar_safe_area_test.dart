import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/widgets/glass_nav.dart';

/// GlassAppBar 状态栏避让回归（edge-to-edge 修复）：
///
/// targetSdk 36 下 Android 15+/16 强制 edge-to-edge，应用内容绘制在系统
/// 状态栏之下。GlassAppBar 曾以固定 `kToolbarHeight` 高度渲染，导致标题/
/// 动作按钮与状态栏图标重合；修复后玻璃层通铺到状态栏下方（磨砂观感），
/// 工具栏行经 SafeArea 下移——对齐内建 AppBar 的 primary 行为。
void main() {
  const bodyKey = ValueKey('test-body');

  Future<void> pumpBar(WidgetTester tester, double topInset) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: topInset)),
        child: MaterialApp(
          home: GlassScaffold(
            title: const Text('账单'),
            body: Container(key: bodyKey),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('有状态栏高度时：工具栏行下移，玻璃层总高 = 状态栏 + 工具栏',
      (tester) async {
    const topInset = 40.0;
    await pumpBar(tester, topInset);

    // 工具栏总高 = 状态栏高度 + kToolbarHeight
    final barHeight = tester.getSize(find.byType(GlassAppBar)).height;
    expect(barHeight, topInset + kToolbarHeight);

    // 标题绘制在状态栏之下（不与状态栏图标重合）
    final titleTop = tester.getTopLeft(find.text('账单')).dy;
    expect(titleTop, greaterThanOrEqualTo(topInset));

    // 正文起点 = 玻璃层底缘（不被顶栏遮挡）
    final bodyTop = tester.getTopLeft(find.byKey(bodyKey)).dy;
    expect(bodyTop, topInset + kToolbarHeight);
  });

  testWidgets('无状态栏高度时：行为与修复前一致（总高 = kToolbarHeight）',
      (tester) async {
    await pumpBar(tester, 0);

    final barHeight = tester.getSize(find.byType(GlassAppBar)).height;
    expect(barHeight, kToolbarHeight);
    final bodyTop = tester.getTopLeft(find.byKey(bodyKey)).dy;
    expect(bodyTop, kToolbarHeight);
  });
}
