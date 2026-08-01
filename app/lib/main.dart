import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/database.dart';
import 'data/local/database_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/quick_entry/quick_entry_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase(driftDatabase(name: 'bookkeep'));
  // 秒开模式：冷启动直达记账页（Spec §3.1 / BK-P0-001）
  final secondsOpen = await SettingsRepository(db).secondsOpenMode();

  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: secondsOpen
        ? const MaterialApp(home: QuickEntrySheet())
        : const BookkeepApp(),
  ));
}
