import 'enums.dart';

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.type,
    required this.detail,
    required this.createdAt,
    this.messageId,
    this.peerId,
    this.isDemo = false,
  });

  final String id;
  final AuditEventType type;
  final String detail;
  final DateTime createdAt;
  final String? messageId;
  final String? peerId;
  final bool isDemo;

  Map<String, Object?> toMap() => {
        'id': id,
        'event_type': type.wire,
        'message_id': messageId,
        'peer_id': peerId,
        'detail': detail,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'is_demo': isDemo ? 1 : 0,
      };

  factory AuditEvent.fromMap(Map<String, Object?> map) => AuditEvent(
        id: map['id'] as String,
        type: AuditEventType.fromWire(map['event_type'] as String?),
        messageId: map['message_id'] as String?,
        peerId: map['peer_id'] as String?,
        detail: map['detail'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        isDemo: ((map['is_demo'] as num?)?.toInt() ?? 0) == 1,
      );
}
