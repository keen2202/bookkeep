import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/ledger_version.dart';
import 'core/security/key_store.dart';
import 'data/local/database.dart';
import 'data/local/database_encryption.dart';
import 'data/local/database_provider.dart';
import 'data/local/tables/accounts_table.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/book_repository.dart';
import 'data/repositories/lock_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/auth_lock/biometric.dart';
import 'features/auth_lock/lock_controller.dart';
import 'features/books/books_providers.dart';
import 'features/recurring/recurring_service.dart';
import 'features/sync/sync_providers.dart';
import 'shared/theme/glass_prefs.dart';
import 'shared/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 中文本地化：TableCalendar 内部 DateFormat（月/星期）依赖 zh_CN 符号表
  Intl.defaultLocale = 'zh_CN';
  await initializeDateFormatting('zh_CN');
  // 系统栏图标对比度（审查 U-2：随系统亮暗联动）。targetSdk 36 下 Android 16
  // 强制 edge-to-edge，导航栏颜色对 API 36 不生效，本调用保证图标可辨并兜底旧设备；
  // 运行时亮暗切换由 buildTheme 的 AppBarTheme.systemOverlayStyle 接管
  final systemDark =
      WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: systemDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: systemDark ? Brightness.light : Brightness.dark,
  ));

  // SQLCipher 启动序列（审查 B-2）：KeyStore 密钥 → 明文检测/迁移 → 加密打开；
  // 密钥损坏（错误密钥/库损坏）走用户确认重置兜底
  final keyStore = SecureStorageKeyStore();
  final dbFile = await _databaseFile();
  final db = await _openDatabase(dbFile, keyStore);
  if (db == null) {
    runApp(_ResetDatabaseApp(dbFile: dbFile, keyStore: keyStore));
    return;
  }
  // 秒开模式：冷启动直达记账页（Spec §3.1 / BK-P0-001）
  final settingsRepo = SettingsRepository(db);
  final secondsOpen = await settingsRepo.secondsOpenMode();
  // 个性化主题：启动即注入持久化设置（秒开分支共用同一实例）
  final themeSettings = await settingsRepo.themeSettings();
  // 玻璃拟态 v3（GLS-014）：玻璃质感 + 环境光设置启动注入（5 个新键，
  // 缺失回退默认 standard）
  final glassPrefs = await settingsRepo.glassPrefs();
  // 隐私锁初始状态：进程被杀重进仍锁（Spec §3.6 / BK-P0-006 / BK-T-008）
  final lockRepo = LockRepository(db);
  final initialLock = await lockRepo.initialState();
  // 当前账本：启动即注入真实默认账本（Spec §4.1 / BK-T-010）
  final currentBook = await BookRepository(db).ensureDefaultBook();
  // 开箱即用：默认账本无账户时种子「现金」账户（幂等，含归档判定——
  // 用户归档唯一账户后重启不复活；createAccount 入队 op-log，登录后随首推同步）
  final accountRepo = AccountRepository(db, bookId: currentBook);
  if ((await accountRepo.listAccounts(includeArchived: true)).isEmpty) {
    await accountRepo.createAccount(name: '现金', type: AccountType.cash);
  }

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      currentBookIdProvider.overrideWith((ref) => currentBook),
      themeControllerProvider.overrideWith(() => ThemeController(initial: themeSettings)),
      glassPrefsProvider.overrideWith(() => GlassPrefsController(initial: glassPrefs)),
      lockControllerProvider.overrideWith((ref) => LockController(
            lockRepo,
            LocalAuthBiometric(),
            initiallyLocked: initialLock.configured,
            initiallyBiometric: initialLock.biometricEnabled,
          )),
    ],
    child: BookkeepApp(startInQuickEntry: secondsOpen),
  ));

  // 周期/分期自动补跑（审查 F-2）：首帧后异步执行，幂等（next_due 前移 +
  // 已生成流水存在性检查），失败仅记日志，不阻塞冷启动（≤3s 预算）
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runRecurringCatchup(db, currentBook));
  });

  // 同步引擎接线（审查 B-1）：读 refresh_token（引擎内 _ensureTokens），
  // 未登录纯本地降级（op-log 照常入队，登录后追平）；合并后经总线刷新 UI
  ensureSharedSyncEngine(
    db: db,
    bookId: currentBook,
    onMerged: () => syncMergeBus.value++,
  );
}

Future<void> _runRecurringCatchup(AppDatabase db, String bookId) async {
  try {
    final service = RecurringService(db, bookId: bookId);
    await service.runAll(bookId: bookId);
    await service.runInstallmentDues(bookId: bookId);
  } catch (e) {
    debugPrint('recurring catch-up failed: $e');
  }
}

/// 库文件路径（与 drift_flutter 默认布局一致：`<documents>/bookkeep.sqlite`）
Future<File> _databaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/bookkeep.sqlite');
}

/// SQLCipher 启动：密钥读取/生成 → 明文检测与迁移 → 加密打开。
/// 打开失败（密钥损坏/库损坏）返回 null，由调用方走重置兜底 UI。
Future<AppDatabase?> _openDatabase(File dbFile, KeyStore keyStore) async {
  final key = await keyStore.readOrCreateKey();
  try {
    if (isPlaintextDb(dbFile)) {
      // 旧明文库一次性迁移（行数校验失败即视为失败，走重置兜底）
      if (!migratePlaintextToEncrypted(dbFile, key)) return null;
    }
    return openEncryptedDatabase(dbFile.path, key);
  } catch (_) {
    // 密钥错误 / 库损坏：SQLCipher 打开抛 "file is not a database"
    return null;
  }
}

/// 密钥损坏兜底：明确提示数据丢失，用户确认后删除本地库与密钥并重启
class _ResetDatabaseApp extends StatefulWidget {
  const _ResetDatabaseApp({required this.dbFile, required this.keyStore});

  final File dbFile;
  final KeyStore keyStore;

  @override
  State<_ResetDatabaseApp> createState() => _ResetDatabaseAppState();
}

class _ResetDatabaseAppState extends State<_ResetDatabaseApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirmReset());
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('本地数据库无法解锁'),
        content: const Text(
          '本地数据库密钥损坏或数据库文件损坏，无法解密本地数据。\n'
          '重置本地库将删除全部本地数据（云端数据可重新同步恢复）。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('退出'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('重置本地库'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      exit(0);
    }
    // 删除库文件（含 -wal/-shm）与密钥，重启走全新初始化
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${widget.dbFile.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    await widget.keyStore.delete();
    await main();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const Scaffold(body: SizedBox.shrink()));
  }
}
