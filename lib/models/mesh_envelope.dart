import 'dart:convert';
import 'dart:typed_data';

import 'enums.dart';

/// Immutable wire envelope. Only immutable origin fields are signed. Routing
/// fields ([hopCount], [senderId], [senderName], [path]) are mutated by relays;
/// they are bounded by the receiver and cannot extend [expiresAt].
class MeshEnvelope {
  const MeshEnvelope({
    this.version = currentVersion,
    required this.id,
    required this.type,
    required this.originId,
    required this.originName,
    required this.originPublicKey,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.maxHops,
    required this.priority,
    required this.isDemo,
    required this.nonce,
    required this.ciphertext,
    required this.signature,
    this.hopCount = 0,
    this.path = const [],
    required this.senderId,
    required this.senderName,
  });

  static const int currentVersion = 1;
  static const int maxWireBytes = 96 * 1024;
  static const int maxHopsAllowed = 12;

  final int version;
  final String id;
  final MeshMessageType type;
  final String originId;
  final String originName;
  final String originPublicKey;
  final int createdAtMs;
  final int expiresAtMs;
  final int maxHops;
  final int priority;
  final bool isDemo;
  final String nonce;
  final String ciphertext;
  final String signature;
  final int hopCount;
  final List<String> path;
  final String senderId;
  final String senderName;

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true);
  DateTime get expiresAt =>
      DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true);

  bool isExpired([DateTime? now]) =>
      (now ?? DateTime.now().toUtc()).isAfter(expiresAt);

  int get remainingHops => (maxHops - hopCount).clamp(0, maxHopsAllowed);

  /// The exact byte sequence signed by the origin. A relay must not alter any
  /// of these fields.
  String get canonicalSigningText => [
        'RQM$version',
        id,
        type.wire,
        originId,
        originName,
        originPublicKey,
        createdAtMs.toString(),
        expiresAtMs.toString(),
        maxHops.toString(),
        priority.toString(),
        isDemo ? '1' : '0',
        nonce,
        ciphertext,
      ].join('\u001f');

  MeshEnvelope forwarded({
    required String relayId,
    required String relayName,
    String? substitutedCiphertext,
    String? substitutedNonce,
    String? substitutedSignature,
  }) {
    final nextPath = [...path, originId];
    if (nextPath.length > maxHopsAllowed) {
      throw const FormatException('Path exceeds protocol limit');
    }
    return MeshEnvelope(
      version: version,
      id: id,
      type: type,
      originId: originId,
      originName: originName,
      originPublicKey: originPublicKey,
      createdAtMs: createdAtMs,
      expiresAtMs: expiresAtMs,
      maxHops: maxHops,
      priority: priority,
      isDemo: isDemo,
      nonce: substitutedNonce ?? nonce,
      ciphertext: substitutedCiphertext ?? ciphertext,
      signature: substitutedSignature ?? signature,
      hopCount: hopCount + 1,
      path: nextPath,
      senderId: relayId,
      senderName: relayName,
    );
  }

  Map<String, Object?> toJson() => {
        'v': version,
        'id': id,
        'type': type.wire,
        'originId': originId,
        'originName': originName,
        'originPublicKey': originPublicKey,
        'createdAt': createdAtMs,
        'expiresAt': expiresAtMs,
        'maxHops': maxHops,
        'priority': priority,
        'demo': isDemo,
        'nonce': nonce,
        'ciphertext': ciphertext,
        'signature': signature,
        'hopCount': hopCount,
        'path': path,
        'senderId': senderId,
        'senderName': senderName,
      };

  Uint8List get wireBytes => Uint8List.fromList(utf8.encode(toWireString()));

  String toWireString() => jsonEncode(toJson());

  int get wireSizeBytes => jsonEncode(toJson()).length;

  static MeshEnvelope fromWireString(String raw) {
    if (raw.length > maxWireBytes) {
      throw const FormatException('Envelope too large');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Envelope must be a JSON object');
    }
    return MeshEnvelope.fromJson(decoded);
  }

  factory MeshEnvelope.fromJson(Map<String, Object?> json) {
    final version = (json['v'] as num?)?.toInt();
    if (version != currentVersion) {
      throw FormatException('Unsupported envelope version: $version');
    }
    final id = _string(json['id'], 'id', min: 8, max: 80);
    final type = MeshMessageType.tryFromWire(json['type'] as String?);
    if (type == null) throw const FormatException('Unknown message type');
    final originId = _string(json['originId'], 'originId', min: 8, max: 80);
    final originName =
        _string(json['originName'], 'originName', min: 1, max: 80);
    final publicKey =
        _string(json['originPublicKey'], 'originPublicKey', min: 40, max: 120);
    final createdAt = _int(json['createdAt'], 'createdAt');
    final expiresAt = _int(json['expiresAt'], 'expiresAt');
    if (expiresAt <= createdAt) {
      throw const FormatException('Expiry must be after creation');
    }
    if (createdAt > DateTime.now().toUtc().add(const Duration(days: 2)).millisecondsSinceEpoch) {
      throw const FormatException('Creation time is implausibly far ahead');
    }
    final maxHops = _int(json['maxHops'], 'maxHops');
    if (maxHops < 1 || maxHops > maxHopsAllowed) {
      throw const FormatException('maxHops outside allowed range');
    }
    final priority = _int(json['priority'], 'priority');
    if (priority < 0 || priority > 9) {
      throw const FormatException('priority outside allowed range');
    }
    final demo = json['demo'];
    if (demo is! bool) throw const FormatException('demo must be bool');
    final nonce = _string(json['nonce'], 'nonce', min: 12, max: 64);
    final ciphertext =
        _string(json['ciphertext'], 'ciphertext', min: 16, max: 72000);
    final signature =
        _string(json['signature'], 'signature', min: 40, max: 200);
    final hopCount = (json['hopCount'] as num?)?.toInt() ?? 0;
    if (hopCount < 0 || hopCount > maxHops) {
      throw const FormatException('hopCount outside allowed range');
    }
    final rawPath = json['path'];
    if (rawPath is! List || rawPath.length > maxHopsAllowed) {
      throw const FormatException('Invalid path');
    }
    final path = <String>[];
    for (final item in rawPath) {
      if (item is! String || item.length < 8 || item.length > 80) {
        throw const FormatException('Invalid path entry');
      }
      path.add(item);
    }
    final senderId = _string(json['senderId'], 'senderId', min: 8, max: 80);
    final senderName =
        _string(json['senderName'], 'senderName', min: 1, max: 80);
    return MeshEnvelope(
      version: version!,
      id: id,
      type: type,
      originId: originId,
      originName: originName,
      originPublicKey: publicKey,
      createdAtMs: createdAt,
      expiresAtMs: expiresAt,
      maxHops: maxHops,
      priority: priority,
      isDemo: demo,
      nonce: nonce,
      ciphertext: ciphertext,
      signature: signature,
      hopCount: hopCount,
      path: List.unmodifiable(path),
      senderId: senderId,
      senderName: senderName,
    );
  }

  static String _string(Object? value, String field,
      {required int min, required int max}) {
    if (value is! String || value.length < min || value.length > max) {
      throw FormatException('Invalid $field');
    }
    return value;
  }

  static int _int(Object? value, String field) {
    if (value is! num) throw FormatException('Invalid $field');
    final parsed = value.toInt();
    if (parsed <= 0) throw FormatException('Invalid $field');
    return parsed;
  }
}
