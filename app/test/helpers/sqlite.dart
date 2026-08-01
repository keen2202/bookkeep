import 'dart:ffi';

import 'package:sqlite3/open.dart';

/// Linux 测试环境通常只有 libsqlite3.so.0 而无 .so 符号链接，
/// 显式指定可加载的库名（设备端由 drift_flutter / sqlcipher_flutter_libs 提供）。
void ensureSqliteLoaded() {
  open.overrideFor(OperatingSystem.linux, () {
    return DynamicLibrary.open('libsqlite3.so.0');
  });
}
