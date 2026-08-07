import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// 应用级数据库实例。设备端启动路径（main()）完成 SQLCipher 密钥注入与
/// 明文迁移后 override 本 provider（审查 B-2）；此处默认实现仅在
/// 测试/未 override 场景生效（测试中 override 为内存库）。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'bookkeep'));
  ref.onDispose(db.close);
  return db;
});
