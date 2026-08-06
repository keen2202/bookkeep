import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'data/local/database.dart';
import 'data/local/database_provider.dart';
import 'data/repositories/book_repository.dart';
import 'data/repositories/lock_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/auth_lock/biometric.dart';
import 'features/auth_lock/lock_controller.dart';
import 'features/auth_lock/lock_gate.dart';
import 'features/books/books_providers.dart';
import 'features/quick_entry/quick_entry_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 中文本地化：TableCalendar 内部 DateFormat（月/星期）依赖 zh_CN 符号表
  Intl.defaultLocale = 'zh_CN';
  await initializeDateFormatting('zh_CN');
  // 系统栏图标对比度（浅色主题深色图标）。targetSdk 36 下 Android 16 强制
  // edge-to-edge，导航栏颜色对 API 36 不生效，本调用保证图标可辨并兜底旧设备
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  final db = AppDatabase(driftDatabase(name: 'bookkeep'));
  // 秒开模式：冷启动直达记账页（Spec §3.1 / BK-P0-001）
  final secondsOpen = await SettingsRepository(db).secondsOpenMode();
  // 隐私锁初始状态：进程被杀重进仍锁（Spec §3.6 / BK-P0-006 / BK-T-008）
  final lockRepo = LockRepository(db);
  final initialLock = await lockRepo.initialState();
  // 当前账本：启动即注入真实默认账本（Spec §4.1 / BK-T-010）
  final currentBook = await BookRepository(db).ensureDefaultBook();

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      currentBookIdProvider.overrideWith((ref) => currentBook),
      lockControllerProvider.overrideWith((ref) => LockController(
            lockRepo,
            LocalAuthBiometric(),
            initiallyLocked: initialLock.configured,
            initiallyBiometric: initialLock.biometricEnabled,
          )),
    ],
    child: secondsOpen
        ? MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: bookkeepLocalizationsDelegates,
            supportedLocales: bookkeepSupportedLocales,
            builder: lockGateBuilder,
            home: const QuickEntrySheet(),
          )
        : const BookkeepApp(),
  ));
}
