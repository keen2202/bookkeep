import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/features/reports/charts/report_charts.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('period bar chart renders month labels with year header on change',
      (tester) async {
    final buckets = [
      PeriodBucket(label: '2025-11', expenseMinor: 1000, incomeMinor: 500),
      PeriodBucket(label: '2025-12', expenseMinor: 1000, incomeMinor: 500),
      PeriodBucket(label: '2026-01', expenseMinor: 1000, incomeMinor: 500),
      PeriodBucket(label: '2026-02', expenseMinor: 1000, incomeMinor: 500),
    ];

    await tester.pumpWidget(harness(
      SizedBox(
        width: 320,
        child: PeriodBarChart(buckets: buckets, hideAmounts: false),
      ),
    ));
    await tester.pumpAndSettle();

    // 主标签「M月」；年份仅在首桶与跨年处顶行出现一次，避免窄屏标签重叠
    for (final m in ['11月', '12月', '1月', '2月']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('2025-11'), findsNothing);
  });

  testWidgets('period bar chart renders weekday labels for day comparison',
      (tester) async {
    final buckets = [
      for (final w in ['周一', '周二', '周三', '周四', '周五', '周六', '周日'])
        PeriodBucket(label: w, expenseMinor: 1000, incomeMinor: 500),
    ];

    await tester.pumpWidget(harness(
      SizedBox(
        width: 320,
        child: PeriodBarChart(buckets: buckets, hideAmounts: false),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
  });

  testWidgets('period bar chart shows expense/income legend for direct comparison',
      (tester) async {
    final buckets = [
      PeriodBucket(label: '8/3', expenseMinor: 1000, incomeMinor: 500),
      PeriodBucket(label: '8/10', expenseMinor: 2000, incomeMinor: 0),
    ];

    await tester.pumpWidget(harness(
      SizedBox(
        width: 320,
        child: PeriodBarChart(buckets: buckets, hideAmounts: false),
      ),
    ));
    await tester.pumpAndSettle();

    // 需求：x 轴每个周期下以「支出/收入」双柱 + 图例直观对比收支
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('8/3'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
  });
}
