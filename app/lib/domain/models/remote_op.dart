/// 同步 op（OpenAPI sync-api.yaml Op schema）
class RemoteOp {
  const RemoteOp({
    required this.entity,
    required this.entityId,
    required this.op,
    required this.lamport,
    required this.clientId,
    this.payload,
  });

  factory RemoteOp.fromJson(Map<String, dynamic> json) {
    return RemoteOp(
      entity: json['entity'] as String,
      entityId: json['entity_id'] as String,
      op: json['op'] as String,
      lamport: json['lamport'] as int,
      clientId: json['client_id'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  final String entity;
  final String entityId;
  final String op; // c | u | d
  final int lamport;
  final String clientId;
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'entity_id': entityId,
        'op': op,
        'lamport': lamport,
        'client_id': clientId,
        'payload': payload,
      };
}
