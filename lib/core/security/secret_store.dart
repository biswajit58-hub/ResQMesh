import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract secret persistence so protocol tests never need platform channels.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore-backed secure storage in the real app.
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Ephemeral store used by the in-app protocol simulation and tests.
/// NEVER used for a real device identity.
class InMemorySecretStore implements SecretStore {
  InMemorySecretStore([Map<String, String>? seed])
      : _values = Map<String, String>.of(seed ?? const {});

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
