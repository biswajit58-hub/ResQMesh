enum TrustState {
  trustOnFirstUse('tofu'),
  trusted('trusted'),
  keyChanged('key_changed');

  const TrustState(this.wire);
  final String wire;

  static TrustState fromWire(String? value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => TrustState.trustOnFirstUse,
      );
}

class KnownDevice {
  const KnownDevice({
    required this.deviceId,
    required this.publicKey,
    required this.displayName,
    required this.firstSeen,
    required this.lastSeen,
    required this.trustState,
    this.isDemo = false,
  });

  final String deviceId;
  final String publicKey;
  final String displayName;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final TrustState trustState;
  final bool isDemo;

  Map<String, Object?> toMap() => {
        'device_id': deviceId,
        'public_key': publicKey,
        'display_name': displayName,
        'first_seen': firstSeen.toUtc().millisecondsSinceEpoch,
        'last_seen': lastSeen.toUtc().millisecondsSinceEpoch,
        'trust_state': trustState.wire,
        'is_demo': isDemo ? 1 : 0,
      };

  factory KnownDevice.fromMap(Map<String, Object?> map) => KnownDevice(
        deviceId: map['device_id'] as String,
        publicKey: map['public_key'] as String,
        displayName: map['display_name'] as String? ?? 'Unknown',
        firstSeen: DateTime.fromMillisecondsSinceEpoch(
          (map['first_seen'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(
          (map['last_seen'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        trustState: TrustState.fromWire(map['trust_state'] as String?),
        isDemo: ((map['is_demo'] as num?)?.toInt() ?? 0) == 1,
      );
}

enum TrustDecision {
  firstUse('first_use'),
  known('known'),
  keyChanged('key_changed');

  const TrustDecision(this.wire);
  final String wire;
}
