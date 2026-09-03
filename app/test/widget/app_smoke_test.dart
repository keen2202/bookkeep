import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/features/auth_lock/lock_gate.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/shared/theme/background/app_background.dart';
import 'package:bookkeep_app/shared/theme/theme_transition.dart';
import 'package:bookkeep_app/shared/widgets/glass_nav.dart';

import 'categories_page_test.dart' show testSeed;

void main() {
  testWidgets('app shell boots with bottom navigation', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const BookkeepApp(),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BookkeepApp), findsOneWidget);
    // 默认主页为账单详情页：G3 吸顶玻璃栏标题为「账单」（FG-NAV）
    expect(
      find.descendant(of: find.byType(GlassAppBar), matching: find.text('账单')),
      findsOneWidget,
    );
    // BK-DOC-28 需求6：主导航收敛为 账单 / 报表 两 Tab + 底栏中央记一笔动作按钮
    expect(
      find.descendant(of: find.byType(GlassBottomBar), matching: find.text('报表')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(GlassBottomBar), matching: find.text('分类')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(GlassBottomBar),
        matching: find.byIcon(Icons.add),
      ),
      findsOneWidget,
    );
    // BK-DOC-26：周期记账下沉设置、日历并入报表（均不作为主导航项）
    expect(find.text('周期记账'), findsNothing);
    expect(find.text('日历'), findsNothing);

    // 分类入口移至设置弹层（需求6 AC6-3）
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('分类管理'), findsOneWidget);
  });

  testWidgets('秒开分支：appShellBuilder 拼装 ThemeTransition + AppBackground + LockGate',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // 与 main.dart 秒开分支同构：MaterialApp.builder 直接挂 appShellBuilder
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        builder: appShellBuilder,
        home: const Scaffold(body: Center(child: Text('秒开内容'))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    // 内容可达且 shell 链完整（背景/隐私锁与主入口同构，审核 F7/A2）
    expect(find.text('秒开内容'), findsOneWidget);
    expect(find.byType(ThemeTransition), findsOneWidget);
    expect(find.byType(AppBackground), findsOneWidget);
    expect(find.byType(LockGate), findsOneWidget);
  });
}
