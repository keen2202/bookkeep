import '../models/remote_op.dart';

/// 同实体的 resolved 结果：最终生效的 op（删除优先）
class ResolvedOp {
  const ResolvedOp({
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payload,
  });

  final String entity;
  final String entityId;
  final String op; // c | u | d
  final Map<String, dynamic>? payload;
}

/// LWW + 删除优先冲突解决（Spec §1.3 / BK-T-007）：
/// - 相同 (lamport, client_id) 视为重复 op，去重；
/// - 任一 op 为删除 → 结果删除（删除优先于修改，无视 lamport 高低）；
/// - 否则按 (lamport, client_id) 字典序取最后写入者。
class LwwResolver {
  const LwwResolver();

  ResolvedOp? resolve(List<RemoteOp> ops) {
    if (ops.isEmpty) return null;

    final deduped = <String, RemoteOp>{};
    for (final op in ops) {
      deduped['${op.lamport}:${op.clientId}'] = op;
    }
    final unique = deduped.values.toList();

    final hasDelete = unique.any((o) => o.op == 'd');
    if (hasDelete) {
      return ResolvedOp(
        entity: ops.first.entity,
        entityId: ops.first.entityId,
        op: 'd',
        payload: null,
      );
    }

    unique.sort((a, b) {
      final byLamport = a.lamport.compareTo(b.lamport);
      return byLamport != 0 ? byLamport : a.clientId.compareTo(b.clientId);
    });
    final winner = unique.last;
    return ResolvedOp(
      entity: winner.entity,
      entityId: winner.entityId,
      op: winner.op,
      payload: winner.payload,
    );
  }
}
