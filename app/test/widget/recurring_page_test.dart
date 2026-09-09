import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/recurring/anchor_resolver.dart';
import 'package:bookkeep_app/features/recurring/recurring_page.dart';
import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/app_choice_chip.dart';
import 'package:bookkeep_app/shared/widgets/app_segmented_button.dart';

import '../helpers/fixtures.dart' show testBookId;

/// BK-DOC-31 需求2：周期记账（规则编辑弹层）取消「✔」选中效果
void main() {
  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            bookId: testBookId,
            accountType: AccountType.cash,
            name: '钱包',
            currency: 'CNY',
            createdAt: DateTime.utc(2026, 8, 1),
          ),
        );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
      ],
      child: MaterialApp(
        theme: buildTheme(kThemePresetsV2.first),
        home: const Scaffold(body: RuleEditSheet()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('分段控件（收支 / 频率）关闭 showSelectedIcon，不渲染 ✔', (tester) async {
    await pumpSheet(tester);

    // 收支与频率均为 AppSegmentedButton（内部 SegmentedButton 关 ✔）
    expect(find.byType(AppSegmentedButton<String>), findsOneWidget);
    expect(find.byType(AppSegmentedButton<RecurringFrequency>), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .showSelectedIcon,
      isFalse,
    );
    expect(
      tester
          .widget<SegmentedButton<RecurringFrequency>>(
              find.byType(SegmentedButton<RecurringFrequency>))
          .showSelectedIcon,
      isFalse,
    );
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('锚点选项用 AppChoiceChip：关 ✔、选中态改 primary 前景', (tester) async {
    await pumpSheet(tester);

    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips, isNotEmpty);
    expect(chips.every((c) => c.showCheckmark == false), isTrue);
    expect(find.byIcon(Icons.check), findsNothing);

    // 默认「月」频率 → 月初（1日）选中
    await tester.tap(find.text('月中（15日）'));
    await tester.pumpAndSettle();

    final selected = tester.widget<ChoiceChip>(find.ancestor(
      of: find.text('月中（15日）'),
      matching: find.byType(ChoiceChip),
    ));
    expect(selected.selected, isTrue);
    // 选中信号是颜色（primary 前景）+ selected 语义，而非 ✔
    final context = tester.element(find.byType(AppChoiceChip).first);
    expect(selected.labelStyle?.color, context.palette.primary);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('切到「周」频率的 7 个锚点 chip 同样无 ✔', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();

    expect(find.byType(AppChoiceChip), findsNWidgets(7));
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
