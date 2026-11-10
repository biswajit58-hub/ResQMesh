import 'enums.dart';

class MessageRecord {
  const MessageRecord({
    required this.id,
    required this.type,
    required this.originId,
    required this.originName,
    required this.senderId,
    required this.senderName,
    required this.priority,
    required this.hopCount,
    required this.maxHops,
    required this.createdAt,
    required this.receivedAt,
    required this.expiresAt,
    required this.status,
    required this.transport,
    required this.isDemo,
    required this.envelopeJson,
    this.payloadJson,
    this.sizeBytes = 0,
  });

  final String id;
  final MeshMessageType type;
  final String originId;
  final String originName;
  final String senderId;
  final String senderName;
  final int priority;
  final int hopCount;
  final int maxHops;
  final DateTime createdAt;
  final DateTime receivedAt;
  final DateTime expiresAt;
  final MeshDeliveryStatus status;
  final TransportKind transport;
  final bool isDemo;
  final String envelopeJson;
  final String? payloadJson;
  final int sizeBytes;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  MessageRecord copyWith({
    MeshDeliveryStatus? status,
    int? hopCount,
    String? payloadJson,
  }) =>
      MessageRecord(
        id: id,
        type: type,
        originId: originId,
        originName: originName,
        senderId: senderId,
        senderName: senderName,
        priority: priority,
        hopCount: hopCount ?? this.hopCount,
        maxHops: maxHops,
        createdAt: createdAt,
        receivedAt: receivedAt,
        expiresAt: expiresAt,
        status: status ?? this.status,
        transport: transport,
        isDemo: isDemo,
        envelopeJson: envelopeJson,
        payloadJson: payloadJson ?? this.payloadJson,
        sizeBytes: sizeBytes,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.wire,
        'origin_id': originId,
        'origin_name': originName,
        'sender_id': senderId,
        'sender_name': senderName,
        'priority': priority,
        'hop_count': hopCount,
        'max_hops': maxHops,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'received_at': receivedAt.toUtc().millisecondsSinceEpoch,
        'expires_at': expiresAt.toUtc().millisecondsSinceEpoch,
        'status': status.wire,
        'transport': transport.wire,
        'is_demo': isDemo ? 1 : 0,
        'envelope_json': envelopeJson,
        'payload_json': payloadJson,
        'size_bytes': sizeBytes,
      };

  factory MessageRecord.fromMap(Map<String, Object?> map) => MessageRecord(
        id: map['id'] as String,
        type: MeshMessageType.tryFromWire(map['type'] as String?) ??
            MeshMessageType.text,
        originId: map['origin_id'] as String? ?? '',
        originName: map['origin_name'] as String? ?? 'Unknown',
        senderId: map['sender_id'] as String? ?? '',
        senderName: map['sender_name'] as String? ?? 'Unknown',
        priority: (map['priority'] as num?)?.toInt() ?? 5,
        hopCount: (map['hop_count'] as num?)?.toInt() ?? 0,
        maxHops: (map['max_hops'] as num?)?.toInt() ?? 6,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['received_at'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (map['expires_at'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        status: MeshDeliveryStatus.fromWire(map['status'] as String?),
        transport: TransportKind.fromWire(map['transport'] as String?),
        isDemo: ((map['is_demo'] as num?)?.toInt() ?? 0) == 1,
        envelopeJson: map['envelope_json'] as String? ?? '{}',
        payloadJson: map['payload_json'] as String?,
        sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
      );
}
