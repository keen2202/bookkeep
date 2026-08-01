import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/domain/models/remote_op.dart';
import 'package:bookkeep_app/domain/services/lww_resolver.dart';

const entity = 'transaction';
const entityId = '99999999-9999-4999-8999-999999999999';
const clientA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const clientB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

RemoteOp op({
  required String op,
  int lamport = 1,
  String clientId = clientA,
  Map<String, dynamic>? payload,
}) {
  return RemoteOp(
    entity: entity,
    entityId: entityId,
    op: op,
    lamport: lamport,
    clientId: clientId,
    payload: payload,
  );
}

void main() {
  const resolver = LwwResolver();

  test('u/u 冲突：lamport 高者胜出（LWW）', () {
    final resolved = resolver.resolve([
      op(op: 'u', lamport: 3, clientId: clientA, payload: {'note': 'from-A'}),
      op(op: 'u', lamport: 5, clientId: clientB, payload: {'note': 'from-B'}),
    ]);
    expect(resolved!.op, 'u');
    expect(resolved.payload, {'note': 'from-B'});
  });

  test('u/u 冲突：lamport 相同按 client_id 字典序较大者胜出（(lamport, client_id) 元组 LWW）', () {
    final resolved = resolver.resolve([
      op(op: 'u', lamport: 4, clientId: clientB, payload: {'note': 'B'}),
      op(op: 'u', lamport: 4, clientId: clientA, payload: {'note': 'A'}),
    ]);
    expect(resolved!.payload, {'note': 'B'});
  });

  test('u/d 冲突：删除优先，即使 update 的 lamport 更高', () {
    final resolved = resolver.resolve([
      op(op: 'u', lamport: 10, clientId: clientB, payload: {'note': 'late-update'}),
      op(op: 'd', lamport: 2, clientId: clientA),
    ]);
    expect(resolved!.op, 'd');
    expect(resolved.payload, isNull);
  });

  test('d/d 冲突：结果为删除', () {
    final resolved = resolver.resolve([
      op(op: 'd', lamport: 3, clientId: clientB),
      op(op: 'd', lamport: 1, clientId: clientA),
    ]);
    expect(resolved!.op, 'd');
  });

  test('c/u 同客户端连续 op：取最终 update', () {
    final resolved = resolver.resolve([
      op(op: 'c', lamport: 1, payload: {'amount_minor': -100}),
      op(op: 'u', lamport: 2, payload: {'amount_minor': -200}),
    ]);
    expect(resolved!.op, 'u');
    expect(resolved.payload, {'amount_minor': -200});
  });

  test('相同 (lamport, client_id) 重复 op 去重', () {
    final resolved = resolver.resolve([
      op(op: 'u', lamport: 5, payload: {'note': 'x'}),
      op(op: 'u', lamport: 5, payload: {'note': 'x'}),
    ]);
    expect(resolved!.payload, {'note': 'x'});
  });

  test('空输入返回 null', () {
    expect(resolver.resolve(const []), isNull);
  });
}
