import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/ledger_version.dart';

void main() {
  test('watch 总线的下游 provider 在版本自增后自动重建（审查 F-1）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var buildCount = 0;
    final downstream = Provider<int>((ref) {
      ref.watch(ledgerVersionProvider);
      buildCount++;
      return buildCount;
    });
    expect(container.read(downstream), 1);
    expect(container.read(downstream), 1); // 缓存未失效

    container.read(ledgerVersionProvider.notifier).state++;
    expect(container.read(downstream), 2); // 写操作 bump 后重建
    container.read(ledgerVersionProvider.notifier).state++;
    expect(container.read(downstream), 3);
  });

  test('初始版本为 0，多次 bump 单调递增', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(ledgerVersionProvider), 0);
    container.read(ledgerVersionProvider.notifier).state++;
    container.read(ledgerVersionProvider.notifier).state++;
    expect(container.read(ledgerVersionProvider), 2);
  });
}
