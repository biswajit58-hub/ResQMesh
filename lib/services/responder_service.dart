import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../core/security/secret_store.dart';

class ResponderSession {
  const ResponderSession({
    required this.role,
    required this.startedAt,
    required this.expiresAt,
  });

  final String role;
  final DateTime startedAt;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().toUtc().isBefore(expiresAt);
}

/// Local responder role gate. This authenticates a session on this device; it
/// is NOT a government identity or agency credential verification system.
class ResponderService {
  ResponderService(this._store);
  final SecretStore _store;

  static const _hashKey = 'resqmesh_responder_pin_hash_v1';
  static const _saltKey = 'resqmesh_responder_salt_v1';
  static const _iterations = 60000;

  ResponderSession? _session;

  ResponderSession? get session =>
      (_session?.isValid ?? false) ? _session : null;

  bool get isAuthenticated => session != null;

  Future<bool> hasPin() async {
    final hash = await _store.read(_hashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 12) {
      throw ArgumentError('Responder PIN must be 4–12 characters.');
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      throw ArgumentError('Choose a less predictable PIN.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = await _derive(pin, salt);
    await _store.write(_saltKey, base64Encode(salt));
    await _store.write(_hashKey, base64Encode(hash));
  }

  Future<bool> login(String pin) async {
    final storedHash = await _store.read(_hashKey);
    final storedSalt = await _store.read(_saltKey);
    if (storedHash == null || storedSalt == null) return false;
    final salt = base64Decode(storedSalt);
    final candidate = await _derive(pin, salt);
    final expected = base64Decode(storedHash);
    if (candidate.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate[i] ^ expected[i];
    }
    if (diff != 0) return false;
    final now = DateTime.now().toUtc();
    _session = ResponderSession(
      role: 'responder',
      startedAt: now,
      expiresAt: now.add(const Duration(minutes: 20)),
    );
    return true;
  }

  void logout() => _session = null;

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }
}
