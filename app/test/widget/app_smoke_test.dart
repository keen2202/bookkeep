import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/sqlite.dart';
import 'categories_page_test.dart' show testSeed;

void main() {
  ensureSqliteLoaded();

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
    expect(find.text('bookkeep'), findsOneWidget);
    expect(find.text('分类'), findsWidgets);
    expect(find.text('账户'), findsWidgets);
  });
}
