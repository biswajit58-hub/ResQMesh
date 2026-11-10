import 'enums.dart';

class PeerDevice {
  const PeerDevice({
    required this.endpointId,
    required this.displayName,
    required this.firstSeen,
    required this.lastSeen,
    required this.connected,
    required this.transport,
    this.deviceId,
    this.publicKey,
    this.isDemo = false,
    this.lastMessageAt,
  });

  final String endpointId;
  final String displayName;
  final String? deviceId;
  final String? publicKey;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final bool connected;
  final TransportKind transport;
  final bool isDemo;
  final DateTime? lastMessageAt;

  PeerDevice copyWith({
    String? displayName,
    String? deviceId,
    String? publicKey,
    DateTime? lastSeen,
    bool? connected,
    TransportKind? transport,
    bool? isDemo,
    DateTime? lastMessageAt,
  }) =>
      PeerDevice(
        endpointId: endpointId,
        displayName: displayName ?? this.displayName,
        deviceId: deviceId ?? this.deviceId,
        publicKey: publicKey ?? this.publicKey,
        firstSeen: firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
        connected: connected ?? this.connected,
        transport: transport ?? this.transport,
        isDemo: isDemo ?? this.isDemo,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      );

  Map<String, Object?> toMap() => {
        'endpoint_id': endpointId,
        'display_name': displayName,
        'device_id': deviceId,
        'public_key': publicKey,
        'first_seen': firstSeen.toUtc().millisecondsSinceEpoch,
        'last_seen': lastSeen.toUtc().millisecondsSinceEpoch,
        'connected': connected ? 1 : 0,
        'transport': transport.wire,
        'is_demo': isDemo ? 1 : 0,
        'last_message_at': lastMessageAt?.toUtc().millisecondsSinceEpoch,
      };

  factory PeerDevice.fromMap(Map<String, Object?> map) => PeerDevice(
        endpointId: map['endpoint_id'] as String,
        displayName: map['display_name'] as String? ?? 'Unknown device',
        deviceId: map['device_id'] as String?,
        publicKey: map['public_key'] as String?,
        firstSeen: DateTime.fromMillisecondsSinceEpoch(
          (map['first_seen'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(
          (map['last_seen'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        connected: ((map['connected'] as num?)?.toInt() ?? 0) == 1,
        transport: TransportKind.fromWire(map['transport'] as String?),
        isDemo: ((map['is_demo'] as num?)?.toInt() ?? 0) == 1,
        lastMessageAt: map['last_message_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (map['last_message_at'] as num).toInt(),
                isUtc: true,
              ),
      );

  static PeerDevice synthetic({
    required String endpointId,
    required String name,
    bool connected = true,
    TransportKind transport = TransportKind.simulated,
  }) =>
      PeerDevice(
        endpointId: endpointId,
        displayName: name,
        firstSeen: DateTime.now().toUtc().subtract(const Duration(minutes: 12)),
        lastSeen: DateTime.now().toUtc(),
        connected: connected,
        transport: transport,
        isDemo: true,
      );
}
