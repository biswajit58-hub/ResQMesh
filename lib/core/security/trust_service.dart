import '../../models/known_device.dart';
import '../../models/mesh_envelope.dart';
import '../database/known_device_repository.dart';

/// Trust-on-first-use identity pinning.
///
/// A later key change for an already-known origin is refused and surfaced in
/// the black box. This detects impersonation after first contact; it is not a
/// certificate authority or verified government identity.
class TrustService {
  TrustService(this._repository);
  final KnownDeviceRepository _repository;

  Future<TrustDecision> checkAndPin(
    MeshEnvelope envelope, {
    bool isDemo = false,
  }) async {
    final existing = await _repository.byId(envelope.originId);
    final now = DateTime.now().toUtc();
    if (existing == null) {
      await _repository.upsert(
        KnownDevice(
          deviceId: envelope.originId,
          publicKey: envelope.originPublicKey,
          displayName: envelope.originName,
          firstSeen: now,
          lastSeen: now,
          trustState: TrustState.trustOnFirstUse,
          isDemo: isDemo,
        ),
      );
      return TrustDecision.firstUse;
    }
    if (existing.publicKey != envelope.originPublicKey) {
      await _repository.upsert(
        KnownDevice(
          deviceId: existing.deviceId,
          publicKey: existing.publicKey,
          displayName: existing.displayName,
          firstSeen: existing.firstSeen,
          lastSeen: now,
          trustState: TrustState.keyChanged,
          isDemo: existing.isDemo,
        ),
      );
      return TrustDecision.keyChanged;
    }
    await _repository.upsert(
      KnownDevice(
        deviceId: existing.deviceId,
        publicKey: existing.publicKey,
        displayName: envelope.originName,
        firstSeen: existing.firstSeen,
        lastSeen: now,
        trustState: existing.trustState,
        isDemo: existing.isDemo,
      ),
    );
    return TrustDecision.known;
  }

  Future<List<KnownDevice>> list({bool demoOnly = false}) =>
      _repository.list(demoOnly: demoOnly);
}
