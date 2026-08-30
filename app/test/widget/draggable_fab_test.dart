import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/features/settings/fab_position.dart';
import 'package:bookkeep_app/shared/widgets/draggable_fab.dart';

/// BK-DOC-26 需求4：记账按钮长按拖拽 + 位置持久化。
/// 覆盖：默认底部正中 / 拖拽移动与回传 / 锚点还原与越界钳制 / 持久化往返。
void main() {
  Finder fabIcon() => find.byIcon(Icons.add);

  /// 模拟主壳：宿主持有锚点状态，回传即更新（同 fabAnchorProvider 行为）
  Widget host({({double ax, double ay})? anchor, ValueChanged<({double ax, double ay})>? onPlaced}) {
    return MaterialApp(
      home: Scaffold(
        body: _FabHost(anchor: anchor, onPlaced: onPlaced),
      ),
    );
  }

  testWidgets('默认位置 = 内容区底部水平居中', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // 默认测试表面 800×600：中心 = (400, 600 - 28 - 16)
    final center = tester.getCenter(fabIcon());
    expect(center.dx, closeTo(400, 0.5));
    expect(center.dy, closeTo(600 - 56 / 2 - 16, 0.5));
  });

  testWidgets('长按拖拽：按钮跟随移动，松手回传归一化锚点', (tester) async {
    ({double ax, double ay})? placed;
    await tester.pumpWidget(host(onPlaced: (a) => placed = a));
    await tester.pump();

    final from = tester.getCenter(fabIcon());
    final gesture = await tester.startGesture(from);
    // 超过长按阈值（500ms）进入拖拽态
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-120, -200));
    await tester.pump();

    // 拖拽中按钮实时跟随
    final moved = tester.getCenter(fabIcon());
    expect(moved.dx, closeTo(from.dx - 120, 1));
    expect(moved.dy, closeTo(from.dy - 200, 1));

    await gesture.up();
    await tester.pump();

    // 松手回传归一化锚点（像素中心 / 区域宽高）
    expect(placed, isNotNull);
    expect(placed!.ax, closeTo((from.dx - 120) / 800, 0.01));
    expect(placed!.ay, closeTo((from.dy - 200) / 600, 0.01));
  });

  testWidgets('普通点按触发 onTap，不产生拖拽回传', (tester) async {
    var tapped = 0;
    ({double ax, double ay})? placed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableGlassFab(
            icon: Icons.add,
            onTap: () => tapped++,
            onPlacementChanged: (a) => placed = a,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(fabIcon());
    await tester.pump();

    expect(tapped, 1);
    expect(placed, isNull);
  });

  testWidgets('持久化锚点还原；越界锚点钳制回内容区', (tester) async {
    // 正常锚点：按比例还原
    await tester.pumpWidget(host(anchor: (ax: 0.25, ay: 0.4)));
    await tester.pump();
    final center = tester.getCenter(fabIcon());
    expect(center.dx, closeTo(800 * 0.25, 0.5));
    expect(center.dy, closeTo(600 * 0.4, 0.5));

    // 越界锚点：钳制到安全边距内
    await tester.pumpWidget(host(anchor: (ax: 5, ay: -3)));
    await tester.pump();
    final clamped = tester.getCenter(fabIcon());
    expect(clamped.dx, closeTo(800 - 56 / 2 - 16, 0.5));
    expect(clamped.dy, closeTo(56 / 2 + 16, 0.5));
  });

  testWidgets('宿主更新锚点后按钮停留在拖拽落点（重启还原同路径）', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final from = tester.getCenter(fabIcon());
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-120, -200));
    await tester.pump();
    await gesture.up();
    // _FabHost 将回传锚点写入 state → 重建后按钮保持在落点
    await tester.pump();

    final settled = tester.getCenter(fabIcon());
    expect(settled.dx, closeTo(from.dx - 120, 1));
    expect(settled.dy, closeTo(from.dy - 200, 1));
  });

  // ── 持久化层 ──

  test('fab_anchor 读写往返；缺失回落 (null, null)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    expect(await repo.fabAnchor(), (null, null));

    await repo.setFabAnchor(0.25, 0.75);
    expect(await repo.fabAnchor(), (0.25, 0.75));

    // 覆盖更新
    await repo.setFabAnchor(0.5, 0.5);
    expect(await repo.fabAnchor(), (0.5, 0.5));
  });

  test('FabAnchorController.save：state 更新并落库', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(container.read(fabAnchorProvider), isNull);

    await container.read(fabAnchorProvider.notifier).save((ax: 0.3, ay: 0.6));

    expect(container.read(fabAnchorProvider), (ax: 0.3, ay: 0.6));
    expect(await SettingsRepository(db).fabAnchor(), (0.3, 0.6));
  });

  test('启动注入：持久化锚点经 FabAnchorController(initial) 还原', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(db).setFabAnchor(0.11, 0.22);

    final (ax, ay) = await SettingsRepository(db).fabAnchor();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fabAnchorProvider.overrideWith(
          () => FabAnchorController(initial: (ax: ax!, ay: ay!)),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(fabAnchorProvider), (ax: 0.11, ay: 0.22));
  });
}

/// 锚点宿主：回传即更新（模拟 fabAnchorProvider 的 state 流转）
class _FabHost extends StatefulWidget {
  const _FabHost({this.anchor, this.onPlaced});

  final ({double ax, double ay})? anchor;
  final ValueChanged<({double ax, double ay})>? onPlaced;

  @override
  State<_FabHost> createState() => _FabHostState();
}

class _FabHostState extends State<_FabHost> {
  ({double ax, double ay})? _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = widget.anchor;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableGlassFab(
      icon: Icons.add,
      anchor: _anchor,
      onTap: () {},
      onPlacementChanged: (a) {
        setState(() => _anchor = a);
        widget.onPlaced?.call(a);
      },
    );
  }
}
