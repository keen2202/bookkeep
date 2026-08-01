import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// 应用级数据库实例（设备端经 drift_flutter 定位数据目录；
/// 测试中 override 为内存库）。SQLCipher 密钥注入见 BK-T-008。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'bookkeep'));
  ref.onDispose(db.close);
  return db;
});
