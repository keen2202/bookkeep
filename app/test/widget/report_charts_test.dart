import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/features/reports/charts/report_charts.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('period bar chart compacts cross-year X labels', (tester) async {
    final buckets = [
      for (final y in [2021, 2022, 2023, 2024, 2025, 2026])
        PeriodBucket(label: '$y-08-09', amountMinor: 1000),
    ];

    await tester.pumpWidget(harness(
      SizedBox(
        width: 320,
        child: PeriodBarChart(buckets: buckets, hideAmounts: false),
      ),
    ));
    await tester.pumpAndSettle();

    // 跨年对比仅保留年份（同期「-08-09」冗余部分被剥离），避免长标签重叠
    for (final y in [2021, 2022, 2023, 2024, 2025, 2026]) {
      expect(find.text('$y'), findsOneWidget);
    }
    expect(find.text('2021-08-09'), findsNothing);
  });

  testWidgets('period bar chart compacts month buckets to month only', (tester) async {
    final buckets = [
      for (var m = 1; m <= 6; m++)
        PeriodBucket(label: '2026-${m.toString().padLeft(2, '0')}', amountMinor: 1000),
    ];

    await tester.pumpWidget(harness(
      SizedBox(
        width: 320,
        child: PeriodBarChart(buckets: buckets, hideAmounts: false),
      ),
    ));
    await tester.pumpAndSettle();

    for (final m in ['01', '02', '03', '04', '05', '06']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.text('2026-01'), findsNothing);
  });
}
