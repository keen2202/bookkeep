import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 同步合并完成信号（main() 构造引擎时接线 onMerged 回调；
/// 应用 shell 监听后 bump [ledgerVersionProvider]——引擎在 ProviderScope 外构建，
/// 无法直接访问 Ref）。
final ValueNotifier<int> syncMergeBus = ValueNotifier(0);

/// 账本数据版本总线（审查 F-1：记账保存后报表/日历不刷新）。
///
/// 所有依赖账本数据的 provider（报表/日历/账户/预算）watch 此值；
/// 写操作（记账/转账/CSV commit/备份恢复/同步合并）完成后自增，
/// 下游 provider 自动重建：
///
/// ```dart
/// ref.read(ledgerVersionProvider.notifier).state++;
/// ```
final ledgerVersionProvider = StateProvider<int>((_) => 0);
