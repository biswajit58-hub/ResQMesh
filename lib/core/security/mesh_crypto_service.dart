import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/mesh_envelope.dart';
import 'secret_store.dart';

class MeshIdentity {
  const MeshIdentity({
    required this.deviceId,
    required this.publicKeyBase64,
    required this.displayName,
  });

  final String deviceId;
  final String publicKeyBase64;
  final String displayName;
}

class OpenedMeshContent {
  const OpenedMeshContent({
    required this.envelope,
    required this.payload,
    required this.originDeviceId,
  });

  final MeshEnvelope envelope;
  final Map<String, dynamic> payload;
  final String originDeviceId;
}

class MeshSecurityException implements Exception {
  const MeshSecurityException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'MeshSecurityException($code): $message';
}

/// Signs origin metadata with Ed25519 and encrypts payloads with AES-256-GCM.
///
/// Threat model / honest limitations:
/// * Peers share a symmetric group passphrase, so any member can decrypt group
///   traffic and forge traffic as a new (previously unseen) identity. TOFU
///   pinning detects later key changes but is not a PKI.
/// * The demo default passphrase is public and MUST be changed for field use.
/// * Routing metadata (hop count/path/sender) is not origin-signed; expiry and
///   hop bounds are enforced independently at every receiver.
class MeshCryptoService {
  MeshCryptoService({
    required SecretStore secretStore,
    required String deviceName,
    String? groupPassphrase,
    this.keyPrefix = 'resqmesh',
    this.defaultGroupPassphrase = 'ResQMesh-field-demo-2026',
  })  : _secretStore = secretStore,
        _deviceName = deviceName,
        _passphrase = groupPassphrase ?? defaultGroupPassphrase;

  final SecretStore _secretStore;
  String _deviceName;
  final String keyPrefix;
  final String defaultGroupPassphrase;
  String _passphrase;

  static final _ed25519 = Ed25519();
  static final _aes = AesGcm.with256bits();
  static final Map<String, SecretKey> _groupKeyCache = {};
  static const int _pbkdf2Iterations = 60000;
  static const int _maxPayloadBytes = 48 * 1024;

  SimpleKeyPair? _keyPair;
  MeshIdentity? _identity;
  SecretKey? _groupKey;

  MeshIdentity get identity {
    final value = _identity;
    if (value == null) {
      throw StateError('MeshCryptoService.initialize() was not called');
    }
    return value;
  }

  bool get isInitialized => _identity != null;

  bool get usesDefaultPassphrase => _passphrase == defaultGroupPassphrase;

  String get groupPassphrase => _passphrase;

  Future<MeshIdentity> initialize() async {
    if (_identity != null) return _identity!;
    final seedKey = '${keyPrefix}_identity_seed_v1';
    var seedHex = await _secretStore.read(seedKey);
    List<int> seed;
    if (seedHex == null || seedHex.length != 64) {
      seed = _randomBytes(32);
      seedHex = _hex(seed);
      await _secretStore.write(seedKey, seedHex);
    } else {
      seed = _fromHex(seedHex);
    }
    final keyPair = await _ed25519.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    final id = deviceIdForPublicKey(publicKey.bytes);
    _keyPair = keyPair;
    _identity = MeshIdentity(
      deviceId: id,
      publicKeyBase64: base64Encode(publicKey.bytes),
      displayName: _deviceName,
    );
    _groupKey = await _deriveGroupKey(_passphrase);
    return _identity!;
  }

  void updateDeviceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _deviceName = trimmed;
    final current = _identity;
    if (current != null) {
      _identity = MeshIdentity(
        deviceId: current.deviceId,
        publicKeyBase64: current.publicKeyBase64,
        displayName: trimmed,
      );
    }
  }

  Future<void> updateGroupPassphrase(String passphrase) async {
    final trimmed = passphrase.trim();
    if (trimmed.length < 12) {
      throw const MeshSecurityException(
          'weak_key', 'Mesh passphrase must be at least 12 characters.');
    }
    _passphrase = trimmed;
    await _secretStore.write('${keyPrefix}_group_passphrase_v1', trimmed);
    _groupKey = await _deriveGroupKey(trimmed);
  }

  Future<void> loadGroupPassphraseFromStore() async {
    final saved = await _secretStore.read('${keyPrefix}_group_passphrase_v1');
    if (saved != null && saved.length >= 12) {
      _passphrase = saved;
      _groupKey = await _deriveGroupKey(saved);
    }
  }

  static String deviceIdForPublicKey(List<int> publicKeyBytes) {
    final digest = hash.sha256.convert(publicKeyBytes).bytes;
    return 'dev_${_hex(digest.sublist(0, 8))}';
  }

  static bool isValidDeviceId(String id) =>
      RegExp(r'^dev_[0-9a-f]{16}$').hasMatch(id);

  Future<MeshEnvelope> seal({
    required MeshMessageType type,
    required Map<String, Object?> payload,
    required int priority,
    int maxHops = 6,
    Duration ttl = const Duration(hours: 12),
    DateTime? now,
    bool isDemo = false,
    String? messageId,
  }) async {
    final me = identity;
    final keyPair = _keyPair!;
    final timestamp = (now ?? DateTime.now().toUtc()).toUtc();
    final payloadBytes = utf8.encode(jsonEncode(payload));
    if (payloadBytes.length > _maxPayloadBytes) {
      throw const MeshSecurityException(
          'payload_too_large', 'Payload exceeds 48 KiB.');
    }
    final groupKey = _groupKey ?? await _deriveGroupKey(_passphrase);
    _groupKey = groupKey;
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      payloadBytes,
      secretKey: groupKey,
      nonce: nonce,
    );
    final combined = Uint8List(box.cipherText.length + box.mac.bytes.length)
      ..setAll(0, box.cipherText)
      ..setAll(box.cipherText.length, box.mac.bytes);
    final unsigned = MeshEnvelope(
      id: messageId ?? const Uuid().v4(),
      type: type,
      originId: me.deviceId,
      originName: me.displayName,
      originPublicKey: me.publicKeyBase64,
      createdAtMs: timestamp.millisecondsSinceEpoch,
      expiresAtMs: timestamp.add(ttl).millisecondsSinceEpoch,
      maxHops: maxHops,
      priority: priority.clamp(0, 9),
      isDemo: isDemo,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(combined),
      signature: '',
      senderId: me.deviceId,
      senderName: me.displayName,
    );
    final signature = await _ed25519.sign(
      utf8.encode(unsigned.canonicalSigningText),
      keyPair: keyPair,
    );
    return MeshEnvelope(
      id: unsigned.id,
      type: unsigned.type,
      originId: unsigned.originId,
      originName: unsigned.originName,
      originPublicKey: unsigned.originPublicKey,
      createdAtMs: unsigned.createdAtMs,
      expiresAtMs: unsigned.expiresAtMs,
      maxHops: unsigned.maxHops,
      priority: unsigned.priority,
      isDemo: unsigned.isDemo,
      nonce: unsigned.nonce,
      ciphertext: unsigned.ciphertext,
      signature: base64Encode(signature.bytes),
      hopCount: 0,
      path: const [],
      senderId: me.deviceId,
      senderName: me.displayName,
    );
  }

  /// Validates the origin signature and identity binding. This does not need
  /// the payload key, so intermediate relays can call it.
  Future<void> verifyEnvelope(MeshEnvelope envelope) async {
    final publicKeyBytes = _decodeBase64(envelope.originPublicKey, 'public key');
    if (publicKeyBytes.length != 32) {
      throw const MeshSecurityException(
          'bad_public_key', 'Ed25519 public key must be 32 bytes.');
    }
    final derived = deviceIdForPublicKey(publicKeyBytes);
    if (derived != envelope.originId) {
      throw const MeshSecurityException(
          'identity_mismatch', 'Origin ID is not bound to its public key.');
    }
    final signatureBytes = _decodeBase64(envelope.signature, 'signature');
    if (signatureBytes.length != 64) {
      throw const MeshSecurityException(
          'bad_signature', 'Ed25519 signature must be 64 bytes.');
    }
    final valid = await _ed25519.verify(
      utf8.encode(envelope.canonicalSigningText),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(
          publicKeyBytes,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valid) {
      throw const MeshSecurityException(
          'invalid_signature', 'Message signature verification failed.');
    }
    if (envelope.isExpired()) {
      throw const MeshSecurityException(
          'expired', 'Message has expired and will not be processed.');
    }
  }

  /// Verifies and decrypts a message addressed to this mesh group.
  Future<OpenedMeshContent> open(MeshEnvelope envelope) async {
    await verifyEnvelope(envelope);
    if (envelope.ciphertext.length > 72000) {
      throw const MeshSecurityException(
          'ciphertext_too_large', 'Ciphertext exceeds protocol limit.');
    }
    final nonce = _decodeBase64(envelope.nonce, 'nonce');
    if (nonce.length != 12) {
      throw const MeshSecurityException('bad_nonce', 'AES-GCM nonce must be 12 bytes.');
    }
    final combined = _decodeBase64(envelope.ciphertext, 'ciphertext');
    if (combined.length < 17) {
      throw const MeshSecurityException('bad_ciphertext', 'Ciphertext is too short.');
    }
    final cipherText = combined.sublist(0, combined.length - 16);
    final mac = combined.sublist(combined.length - 16);
    final key = _groupKey ?? await _deriveGroupKey(_passphrase);
    _groupKey = key;
    List<int> clear;
    try {
      clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const MeshSecurityException(
        'undecryptable',
        'Message cannot be decrypted with this mesh key. Check that all devices use the same network key.',
      );
    }
    if (clear.length > _maxPayloadBytes) {
      throw const MeshSecurityException(
          'payload_too_large', 'Decrypted payload exceeds 48 KiB.');
    }
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map<String, dynamic>) {
      throw const MeshSecurityException(
          'malformed_payload', 'Payload must be a JSON object.');
    }
    return OpenedMeshContent(
      envelope: envelope,
      payload: decoded,
      originDeviceId: envelope.originId,
    );
  }

  Future<SecretKey> _deriveGroupKey(String passphrase) async {
    final cacheKey = base64Encode(utf8.encode(passphrase));
    final cached = _groupKeyCache[cacheKey];
    if (cached != null) return cached;
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: utf8.encode('resqmesh-group-v1'),
    );
    final derived = SecretKeyData(await key.extractBytes());
    _groupKeyCache[cacheKey] = derived;
    return derived;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _fromHex(String value) => [
        for (var i = 0; i < value.length; i += 2)
          int.parse(value.substring(i, i + 2), radix: 16),
      ];

  static List<int> _decodeBase64(String value, String field) {
    try {
      return base64Decode(value);
    } on FormatException {
      throw MeshSecurityException('bad_$field', 'Invalid base64 $field.');
    }
  }
}
