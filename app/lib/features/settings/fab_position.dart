import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import '../../data/repositories/settings_repository.dart';

/// FAB 归一化锚点（按钮中心相对内容区宽高的比例，0~1）；
/// `null` = 默认位置「屏幕底部正中间」（BK-DOC-26 需求4）。
typedef FabAnchor = ({double ax, double ay});

/// FAB 位置状态（BK-DOC-26 需求4）：`main()` 启动读取持久化锚点后
/// 经 `overrideWith(() => FabAnchorController(initial: …))` 注入
/// （与 `themeControllerProvider` 的启动注入模式一致）；拖拽结束后
/// [save] 即时落库，重启保持。
class FabAnchorController extends Notifier<FabAnchor?> {
  FabAnchorController({FabAnchor? initial}) : _initial = initial;

  final FabAnchor? _initial;

  @override
  FabAnchor? build() => _initial;

  /// 拖拽松手后调用：内存即时生效 + app_meta 持久化
  Future<void> save(FabAnchor anchor) async {
    state = anchor;
    final repo = SettingsRepository(ref.read(databaseProvider));
    await repo.setFabAnchor(anchor.ax, anchor.ay);
  }
}

final fabAnchorProvider =
    NotifierProvider<FabAnchorController, FabAnchor?>(FabAnchorController.new);
