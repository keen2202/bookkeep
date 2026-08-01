import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/domain/services/budget_progress_calculator.dart';

void main() {
  group('periodWindow（月起始日可配）', () {
    test('default month start on the 1st', () {
      final window = BudgetProgressCalculator.periodWindow(
        DateTime.utc(2026, 8, 15),
        monthStartDay: 1,
      );

      expect(window.start, DateTime.utc(2026, 8, 1));
      expect(window.end, DateTime.utc(2026, 9, 1));
    });

    test('month start on the 5th splits the month', () {
      final window = BudgetProgressCalculator.periodWindow(
        DateTime.utc(2026, 8, 20),
        monthStartDay: 5,
      );

      expect(window.start, DateTime.utc(2026, 8, 5));
      expect(window.end, DateTime.utc(2026, 9, 5));
    });

    test('before the month start day belongs to the previous window', () {
      final window = BudgetProgressCalculator.periodWindow(
        DateTime.utc(2026, 8, 4),
        monthStartDay: 5,
      );

      expect(window.start, DateTime.utc(2026, 7, 5));
      expect(window.end, DateTime.utc(2026, 8, 5));
    });

    test('month start on the 31st falls back to the last day of each month', () {
      final window = BudgetProgressCalculator.periodWindow(
        DateTime.utc(2026, 8, 31),
        monthStartDay: 31,
      );

      expect(window.start, DateTime.utc(2026, 7, 31));
      expect(window.end, DateTime.utc(2026, 8, 31));

      final febWindow = BudgetProgressCalculator.periodWindow(
        DateTime.utc(2026, 3, 1),
        monthStartDay: 31,
      );
      expect(febWindow.start, DateTime.utc(2026, 2, 28));
    });
  });

  group('progress', () {
    test('computes spent, remaining, percent and daily budget', () {
      final progress = BudgetProgressCalculator.progress(
        budgetMinor: 100000,
        spentMinor: 40000,
        daysRemaining: 10,
      );

      expect(progress.spentMinor, 40000);
      expect(progress.remainingMinor, 60000);
      expect(progress.percent, 40);
      expect(progress.dailyBudgetMinor, 6000);
      expect(progress.overThreshold, isFalse);
      expect(progress.exceeded, isFalse);
    });

    test('flags the 80% warning threshold', () {
      final progress = BudgetProgressCalculator.progress(
        budgetMinor: 100000,
        spentMinor: 80000,
        daysRemaining: 5,
      );

      expect(progress.overThreshold, isTrue);
      expect(progress.exceeded, isFalse);
    });

    test('flags over budget at 100%', () {
      final progress = BudgetProgressCalculator.progress(
        budgetMinor: 100000,
        spentMinor: 120000,
        daysRemaining: 3,
      );

      expect(progress.overThreshold, isTrue);
      expect(progress.exceeded, isTrue);
      expect(progress.remainingMinor, -20000);
    });

    test('daily budget clamps at zero when nothing remains', () {
      final progress = BudgetProgressCalculator.progress(
        budgetMinor: 10000,
        spentMinor: 10000,
        daysRemaining: 4,
      );

      expect(progress.dailyBudgetMinor, 0);
    });
  });
}
