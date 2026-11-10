import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../core/database/incident_repository.dart';
import '../core/database/message_repository.dart';
import '../core/database/peer_repository.dart';
import '../core/database/transmission_repository.dart';
import '../core/networking/mesh_payloads.dart';
import '../core/networking/mesh_rate_limiter.dart';
import '../core/networking/mesh_transport.dart';
import '../core/security/mesh_crypto_service.dart';
import '../core/security/trust_service.dart';
import '../models/enums.dart';
import '../models/geo_fix.dart';
import '../models/incident.dart';
import '../models/known_device.dart';
import '../models/mesh_envelope.dart';
import '../models/message_record.dart';
import '../models/peer_device.dart';
import 'audit_service.dart';

class MeshStatus {
  const MeshStatus({
    required this.running,
    required this.available,
    required this.connectedPeers,
    required this.discoveredPeers,
    required this.message,
    this.transport = TransportKind.none,
  });

  final bool running;
  final bool available;
  final int connectedPeers;
  final int discoveredPeers;
  final String message;
  final TransportKind transport;

  bool get offline => !running || connectedPeers == 0;
}

/// Owns the multi-hop relay state machine.
///
/// The native transport only moves bytes; this class validates, de-duplicates,
/// expires, rate-limits, persists, acknowledges and forwards envelopes. No
/// method claims guaranteed delivery: acknowledgements are explicitly
/// best-effort.
class MeshService {
  MeshService({
    required MeshCryptoService crypto,
    required TrustService trust,
    required PeerRepository peers,
    required MessageRepository messages,
    required IncidentRepository incidents,
    required TransmissionRepository transmissions,
    required AuditService audit,
    required MeshTransport transport,
    required this.onChanged,
    this.onIncomingIncident,
    this.onPeerConnected,
    MeshRateLimiter? rateLimiter,
  })  : _crypto = crypto,
        _trust = trust,
        _peers = peers,
        _messages = messages,
        _incidents = incidents,
        _transmissions = transmissions,
        _audit = audit,
        _transport = transport,
        _rateLimiter = rateLimiter ?? MeshRateLimiter();

  final MeshCryptoService _crypto;
  final TrustService _trust;
  final PeerRepository _peers;
  final MessageRepository _messages;
  final IncidentRepository _incidents;
  final TransmissionRepository _transmissions;
  final AuditService _audit;
  final MeshTransport _transport;
  final MeshRateLimiter _rateLimiter;
  final void Function() onChanged;
  final Future<void> Function(Incident incident)? onIncomingIncident;
  final void Function(PeerDevice peer)? onPeerConnected;
  final _uuid = const Uuid();

  StreamSubscription<TransportEvent>? _subscription;
  Future<void> _incomingChain = Future<void>.value();
  final Map<String, PeerDevice> _peersByEndpoint = {};
  final List<_SendJob> _outbox = [];
  final Set<String> _queuedKeys = {};

  TransportAvailability _availability = TransportAvailability.unavailable;
  bool _running = false;
  bool _draining = false;
  bool _initialized = false;
  String _statusMessage = 'Mesh idle';
  String? _lastError;
  int _receivedCount = 0;
  int _forwardedCount = 0;
  int _duplicateCount = 0;
  int _invalidCount = 0;

  bool get isRunning => _running;
  bool get isAvailable => _availability.available;
  bool get isSimulated => _transport.isSimulated;
  TransportAvailability get availability => _availability;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  int get receivedCount => _receivedCount;
  int get forwardedCount => _forwardedCount;
  int get duplicateCount => _duplicateCount;
  int get invalidCount => _invalidCount;

  List<PeerDevice> get peers => _peersByEndpoint.values.toList(growable: false)
    ..sort((a, b) {
      if (a.connected != b.connected) return a.connected ? -1 : 1;
      return b.lastSeen.compareTo(a.lastSeen);
    });

  List<PeerDevice> get connectedPeers =>
      peers.where((peer) => peer.connected).toList(growable: false);

  MeshStatus get status => MeshStatus(
        running: _running,
        available: _availability.available,
        connectedPeers: connectedPeers.length,
        discoveredPeers: peers.length,
        message: _statusMessage,
        transport: _transport.kind,
      );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = _transport.events.listen(_onTransportEvent);
    _availability = await _transport.initialize();
    if (!_availability.available) {
      _statusMessage = _availability.reason;
    }
    final stored = await _peers.list();
    for (final peer in stored) {
      _peersByEndpoint[peer.endpointId] = peer.connected
          ? peer.copyWith(connected: false)
          : peer;
    }
    _notify();
  }

  Future<void> start({
    required String deviceName,
    bool autoConnect = true,
  }) async {
    if (!_initialized) await initialize();
    if (!_availability.available) {
      _statusMessage = _availability.reason;
      await _audit.log(
        AuditEventType.meshUnavailable,
        _availability.reason,
      );
      _notify();
      return;
    }
    if (_running) return;
    try {
      await _transport.start(
        deviceName: deviceName,
        autoConnect: autoConnect,
      );
      _running = true;
      _lastError = null;
      _statusMessage = 'Discovering nearby devices';
      await _audit.log(
        AuditEventType.meshStarted,
        'Peer mesh started as "$deviceName" (auto-connect: $autoConnect).',
      );
    } catch (error) {
      _lastError = error.toString();
      _statusMessage = 'Could not start nearby transport';
      await _audit.log(
        AuditEventType.meshUnavailable,
        'Start failed: $error',
      );
    }
    _notify();
  }

  Future<void> stop({String reason = 'Mesh stopped by user'}) async {
    if (!_running) return;
    await _transport.stop();
    _running = false;
    _statusMessage = reason;
    await _peers.markAllDisconnected();
    for (final entry in _peersByEndpoint.entries.toList()) {
      _peersByEndpoint[entry.key] = entry.value.copyWith(connected: false);
    }
    await _audit.log(AuditEventType.meshStopped, reason);
    _notify();
  }

  Future<MeshEnvelope> publishIncident(Incident incident) async {
    if (incident.isDemo && !_transport.isSimulated) {
      throw StateError(
          'Synthetic demo incidents cannot be broadcast over a real radio transport.');
    }
    final payload = IncidentReportPayload(
      category: incident.category,
      severity: incident.severity,
      peopleAffected: incident.peopleAffected,
      latitude: incident.location.latitude,
      longitude: incident.location.longitude,
      accuracyMeters: incident.location.accuracyMeters,
      locationSource: incident.location.source,
      locationTimestamp: incident.location.capturedAt,
      createdAt: incident.createdAt,
      locationDescription: incident.location.description,
      description: incident.description,
    );
    final envelope = await _crypto.seal(
      type: incident.kind == IncidentKind.sos
          ? MeshMessageType.sos
          : MeshMessageType.hazard,
      payload: payload.toJson(),
      priority: priorityFor(incident.severity, peopleAffected: incident.peopleAffected),
      maxHops: 6,
      ttl: const Duration(hours: 12),
      isDemo: incident.isDemo,
      messageId: incident.id,
    );
    await _persistOutgoing(envelope, payloadJson: jsonEncode(payload.toJson()));
    await _audit.log(
      incident.kind == IncidentKind.sos
          ? AuditEventType.sosCreated
          : AuditEventType.hazardCreated,
      '${incident.kind.wire} ${incident.id} stored locally; queued for mesh broadcast.',
      messageId: envelope.id,
      isDemo: incident.isDemo,
    );
    _enqueueBroadcast(envelope, reason: 'local broadcast');
    _notify();
    return envelope;
  }

  Future<void> _persistOutgoing(
    MeshEnvelope envelope, {
    String? payloadJson,
  }) async {
    final record = MessageRecord(
      id: envelope.id,
      type: envelope.type,
      originId: envelope.originId,
      originName: envelope.originName,
      senderId: envelope.senderId,
      senderName: envelope.senderName,
      priority: envelope.priority,
      hopCount: envelope.hopCount,
      maxHops: envelope.maxHops,
      createdAt: envelope.createdAt,
      receivedAt: DateTime.now().toUtc(),
      expiresAt: envelope.expiresAt,
      status: MeshDeliveryStatus.queued,
      transport: _transport.kind,
      isDemo: envelope.isDemo,
      envelopeJson: envelope.toWireString(),
      payloadJson: payloadJson,
      sizeBytes: envelope.wireSizeBytes,
    );
    await _messages.upsert(record);
  }

  void _onTransportEvent(TransportEvent event) {
    switch (event.kind) {
      case TransportEventKind.availability:
        _statusMessage = event.detail ?? _statusMessage;
        _notify();
      case TransportEventKind.peerFound:
        unawaited(_onPeerFound(event));
      case TransportEventKind.peerLost:
        unawaited(_onPeerLost(event));
      case TransportEventKind.connected:
        unawaited(_onConnected(event));
      case TransportEventKind.disconnected:
        unawaited(_onDisconnected(event));
      case TransportEventKind.payload:
        if (event.data != null) {
          // Serialise frame handling so the duplicate check and the database
          // insert cannot interleave for two copies of the same message ID.
          _incomingChain = _incomingChain
              .then<void>((_) => _onPayload(event))
              .catchError((Object error, StackTrace stack) async {
            _invalidCount++;
            await _audit.log(
              AuditEventType.invalidDropped,
              'Incoming frame handler failed safely: $error',
              peerId: event.endpointId,
            );
            _lastError = 'Incoming frame rejected';
            _notify();
          });
        }
      case TransportEventKind.error:
        _lastError = event.detail;
        _statusMessage = event.detail ?? 'Transport error';
        unawaited(_audit.log(
          AuditEventType.meshUnavailable,
          event.detail ?? 'Unknown nearby transport error',
        ));
        _notify();
      case TransportEventKind.status:
        _statusMessage = event.detail ?? _statusMessage;
        _notify();
    }
  }

  Future<void> _onPeerFound(TransportEvent event) async {
    final endpoint = event.endpointId;
    if (endpoint == null) return;
    final now = DateTime.now().toUtc();
    final existing = _peersByEndpoint[endpoint];
    final peer = PeerDevice(
      endpointId: endpoint,
      displayName: event.displayName ?? existing?.displayName ?? 'Nearby device',
      deviceId: existing?.deviceId,
      publicKey: existing?.publicKey,
      firstSeen: existing?.firstSeen ?? now,
      lastSeen: now,
      connected: existing?.connected ?? false,
      transport: _transport.kind,
      lastMessageAt: existing?.lastMessageAt,
    );
    _peersByEndpoint[endpoint] = peer;
    await _peers.upsert(peer);
    await _audit.log(
      AuditEventType.peerDiscovered,
      'Discovered ${peer.displayName} ($endpoint).',
      peerId: endpoint,
    );
    _statusMessage = '${peers.length} nearby device(s) discovered';
    _notify();
  }

  Future<void> _onPeerLost(TransportEvent event) async {
    final endpoint = event.endpointId;
    if (endpoint == null) return;
    final peer = _peersByEndpoint[endpoint];
    if (peer == null) return;
    _statusMessage = 'Lost sight of ${peer.displayName}';
    // Discovery loss does not prove the transport link is down.
    _notify();
  }

  Future<void> _onConnected(TransportEvent event) async {
    final endpoint = event.endpointId;
    if (endpoint == null) return;
    final now = DateTime.now().toUtc();
    final existing = _peersByEndpoint[endpoint];
    final peer = PeerDevice(
      endpointId: endpoint,
      displayName: event.displayName ??
          existing?.displayName ??
          'Nearby device',
      deviceId: existing?.deviceId,
      publicKey: existing?.publicKey,
      firstSeen: existing?.firstSeen ?? now,
      lastSeen: now,
      connected: true,
      transport: _transport.kind,
      lastMessageAt: existing?.lastMessageAt,
    );
    _peersByEndpoint[endpoint] = peer;
    await _peers.upsert(peer);
    await _audit.log(
      AuditEventType.peerConnected,
      'Connected to ${peer.displayName} ($endpoint).',
      peerId: endpoint,
    );
    onPeerConnected?.call(peer);
    _statusMessage = '${connectedPeers.length} peer(s) connected';
    _notify();
    await _sendPresence(endpoint);
    await _storeAndForwardTo(endpoint);
  }

  Future<void> _onDisconnected(TransportEvent event) async {
    final endpoint = event.endpointId;
    if (endpoint == null) return;
    final peer = _peersByEndpoint[endpoint];
    if (peer == null) return;
    _peersByEndpoint[endpoint] = peer.copyWith(connected: false);
    await _peers.setConnected(endpoint, false);
    await _audit.log(
      AuditEventType.peerDisconnected,
      'Disconnected from ${peer.displayName} ($endpoint).',
      peerId: endpoint,
    );
    _statusMessage = '${connectedPeers.length} peer(s) connected';
    _notify();
  }

  Future<void> _sendPresence(String endpointId) async {
    try {
      final envelope = await _crypto.seal(
        type: MeshMessageType.presence,
        payload: {
          'deviceId': _crypto.identity.deviceId,
          'name': _crypto.identity.displayName,
          'protocol': MeshEnvelope.currentVersion,
          'capabilities': ['sos', 'hazard', 'ack', 'relay'],
        },
        priority: 2,
        maxHops: 1,
        ttl: const Duration(minutes: 10),
      );
      await _transport.send(endpointId, envelope.wireBytes);
    } catch (error) {
      _lastError = 'Presence failed: $error';
    }
  }

  Future<void> _onPayload(TransportEvent event) async {
    final endpoint = event.endpointId;
    final bytes = event.data;
    if (endpoint == null || bytes == null) return;
    if (bytes.length > MeshEnvelope.maxWireBytes) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.invalidDropped,
        'Oversized frame (${bytes.length} bytes) from $endpoint.',
        peerId: endpoint,
      );
      _notify();
      return;
    }
    MeshEnvelope envelope;
    try {
      envelope = MeshEnvelope.fromWireString(utf8.decode(bytes));
    } on FormatException catch (error) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.invalidDropped,
        'Malformed frame rejected: ${error.message}',
        peerId: endpoint,
      );
      _notify();
      return;
    } catch (error) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.invalidDropped,
        'Undecodable frame rejected: $error',
        peerId: endpoint,
      );
      _notify();
      return;
    }

    if (envelope.isDemo && !_transport.isSimulated) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.invalidDropped,
        'Demo envelope refused on real transport.',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _notify();
      return;
    }
    if (envelope.isExpired()) {
      await _audit.log(
        AuditEventType.messageExpired,
        'Expired envelope ${envelope.id} dropped.',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _notify();
      return;
    }
    try {
      await _crypto.verifyEnvelope(envelope);
    } on MeshSecurityException catch (error) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.invalidDropped,
        'Signature check failed: ${error.message}',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _notify();
      return;
    }

    final trust = await _trust.checkAndPin(envelope);
    if (trust == TrustDecision.keyChanged) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.securityWarning,
        'IDENTITY KEY CHANGED for ${envelope.originName} (${envelope.originId}). Message refused. Verify this device out of band before trusting it again.',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _lastError = 'Identity key changed for ${envelope.originName}';
      _notify();
      return;
    }

    if (!_rateLimiter.allow(envelope.originId, DateTime.now().toUtc())) {
      await _audit.log(
        AuditEventType.rateLimited,
        'Rate limit hit for ${envelope.originName}; message not relayed.',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _notify();
      return;
    }

    if (await _messages.exists(envelope.id)) {
      _duplicateCount++;
      await _audit.log(
        AuditEventType.duplicateDropped,
        'Duplicate ${envelope.id} from ${envelope.senderName}; not re-forwarded or re-counted.',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _notify();
      return;
    }

    OpenedMeshContent content;
    try {
      content = await _crypto.open(envelope);
    } on MeshSecurityException catch (error) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.invalidDropped,
        'Could not open envelope: ${error.message}',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _lastError = error.message;
      _notify();
      return;
    } on FormatException catch (error) {
      _invalidCount++;
      await _audit.log(
        AuditEventType.invalidDropped,
        'Invalid payload: ${error.message}',
        messageId: envelope.id,
        peerId: endpoint,
      );
      _notify();
      return;
    }

    _receivedCount++;
    if (envelope.senderId == envelope.originId) {
      await _updatePeerIdentity(endpoint, event.displayName, envelope);
    } else {
      await _touchPeer(endpoint, event.displayName);
    }
    await _audit.log(
      AuditEventType.messageReceived,
      '${envelope.type.wire} ${envelope.id} received from ${envelope.senderName} (hop ${envelope.hopCount}/${envelope.maxHops}).',
      messageId: envelope.id,
      peerId: endpoint,
      isDemo: envelope.isDemo,
    );

    if (envelope.type == MeshMessageType.presence) {
      _statusMessage = 'Peer ${envelope.originName} identified';
      _notify();
      return;
    }

    final record = MessageRecord(
      id: envelope.id,
      type: envelope.type,
      originId: envelope.originId,
      originName: envelope.originName,
      senderId: envelope.senderId,
      senderName: envelope.senderName,
      priority: envelope.priority,
      hopCount: envelope.hopCount,
      maxHops: envelope.maxHops,
      createdAt: envelope.createdAt,
      receivedAt: DateTime.now().toUtc(),
      expiresAt: envelope.expiresAt,
      status: MeshDeliveryStatus.transmitted,
      transport: _transport.kind,
      isDemo: envelope.isDemo,
      envelopeJson: envelope.toWireString(),
      payloadJson: jsonEncode(content.payload),
      sizeBytes: envelope.wireSizeBytes,
    );
    await _messages.upsert(record);

    if (envelope.type == MeshMessageType.ack) {
      await _handleAck(envelope, content.payload, endpoint);
      return;
    }

    if (envelope.type == MeshMessageType.sos ||
        envelope.type == MeshMessageType.hazard) {
      final incident = await _storeIncident(envelope, content.payload);
      if (incident != null) {
        await onIncomingIncident?.call(incident);
      }
      // Best-effort receipt acknowledgement sent back through the peer that
      // handed us the frame. It is not a guarantee of rescue response.
      unawaited(_sendAckFor(envelope, endpoint));
    }

    if (envelope.hopCount < envelope.maxHops &&
        !envelope.path.contains(_crypto.identity.deviceId) &&
        envelope.originId != _crypto.identity.deviceId) {
      _enqueueForward(envelope, exceptEndpoint: endpoint);
    }
    _notify();
  }

  Future<void> _touchPeer(String endpoint, String? nativeName) async {
    final existing = _peersByEndpoint[endpoint];
    if (existing == null) return;
    final peer = existing.copyWith(
      displayName: nativeName ?? existing.displayName,
      lastSeen: DateTime.now().toUtc(),
    );
    _peersByEndpoint[endpoint] = peer;
    await _peers.upsert(peer);
  }

  Future<void> connectToPeer(String endpointId) async {
    if (_running) {
      await _transport.connect(endpointId);
    }
  }

  Future<void> _updatePeerIdentity(
    String endpoint,
    String? nativeName,
    MeshEnvelope envelope,
  ) async {
    final existing = _peersByEndpoint[endpoint];
    final now = DateTime.now().toUtc();
    final peer = PeerDevice(
      endpointId: endpoint,
      displayName: envelope.originName.isNotEmpty
          ? envelope.originName
          : nativeName ?? existing?.displayName ?? 'Nearby device',
      deviceId: envelope.originId,
      publicKey: envelope.originPublicKey,
      firstSeen: existing?.firstSeen ?? now,
      lastSeen: now,
      connected: existing?.connected ?? true,
      transport: _transport.kind,
      lastMessageAt: now,
    );
    _peersByEndpoint[endpoint] = peer;
    await _peers.upsert(peer);
  }

  Future<Incident?> _storeIncident(
    MeshEnvelope envelope,
    Map<String, dynamic> payload,
  ) async {
    final existing = await _incidents.byId(envelope.id);
    if (existing != null) return existing;
    try {
      final parsed = IncidentReportPayload.fromJson(payload);
      final incident = Incident(
        id: envelope.id,
        meshMessageId: envelope.id,
        kind: envelope.type == MeshMessageType.sos
            ? IncidentKind.sos
            : IncidentKind.hazard,
        category: parsed.category,
        severity: parsed.severity,
        peopleAffected: parsed.peopleAffected,
        description: parsed.description,
        location: GeoFix(
          latitude: parsed.latitude,
          longitude: parsed.longitude,
          accuracyMeters: parsed.accuracyMeters,
          source: parsed.locationSource,
          capturedAt: parsed.locationTimestamp,
          description: parsed.locationDescription,
        ),
        status: IncidentStatus.active,
        verification: VerificationState.unverified,
        createdAt: parsed.createdAt,
        updatedAt: DateTime.now().toUtc(),
        expiresAt: envelope.expiresAt,
        originId: envelope.originId,
        originName: envelope.originName,
        isDemo: envelope.isDemo,
      );
      await _incidents.upsert(incident);
      return incident;
    } on FormatException catch (error) {
      await _audit.log(
        AuditEventType.invalidDropped,
        'Incident payload rejected: ${error.message}',
        messageId: envelope.id,
        isDemo: envelope.isDemo,
      );
      return null;
    }
  }

  Future<void> _handleAck(
    MeshEnvelope envelope,
    Map<String, dynamic> payload,
    String fromEndpoint,
  ) async {
    final ack = AckPayload.fromJson(payload);
    if (ack.targetDeviceId == _crypto.identity.deviceId) {
      await _messages.updateStatus(ack.ackFor, MeshDeliveryStatus.acknowledged);
      await _incidents.incrementReceipt(ack.ackFor);
      await _audit.log(
        AuditEventType.messageAcknowledged,
        '${ack.receiverName} confirmed receipt of ${ack.ackFor} (hop ${envelope.hopCount}). This is a receipt, not proof of rescue.',
        messageId: ack.ackFor,
        peerId: envelope.originId,
        isDemo: envelope.isDemo,
      );
      _statusMessage = 'Receipt confirmed by ${ack.receiverName}';
      _notify();
      return;
    }
    if (envelope.hopCount < envelope.maxHops &&
        !envelope.path.contains(_crypto.identity.deviceId)) {
      _enqueueForward(envelope, exceptEndpoint: fromEndpoint);
    }
  }

  Future<void> _sendAckFor(MeshEnvelope original, String toEndpoint) async {
    try {
      final ackEnvelope = await _crypto.seal(
        type: MeshMessageType.ack,
        payload: AckPayload(
          ackFor: original.id,
          targetDeviceId: original.originId,
          receiverId: _crypto.identity.deviceId,
          receiverName: _crypto.identity.displayName,
          receivedAt: DateTime.now().toUtc(),
        ).toJson(),
        priority: 5,
        maxHops: original.maxHops,
        ttl: const Duration(hours: 6),
        isDemo: original.isDemo,
      );
      await _persistOutgoing(ackEnvelope);
      _enqueueToEndpoint(
        ackEnvelope,
        toEndpoint,
        peerName: _peersByEndpoint[toEndpoint]?.displayName ?? 'Peer',
        reason: 'receipt acknowledgement',
      );
    } catch (error) {
      await _audit.log(
        AuditEventType.invalidDropped,
        'Could not create acknowledgement: $error',
        messageId: original.id,
        isDemo: original.isDemo,
      );
    }
  }

  void _enqueueBroadcast(MeshEnvelope envelope, {required String reason}) {
    final targets = connectedPeers;
    if (targets.isEmpty) {
      _statusMessage = 'Stored in outbox — no connected peers';
      _notify();
      return;
    }
    for (final peer in targets) {
      if (envelope.path.contains(peer.deviceId)) continue;
      _enqueueToEndpoint(
        envelope,
        peer.endpointId,
        peerName: peer.displayName,
        reason: reason,
      );
    }
  }

  void _enqueueForward(MeshEnvelope envelope, {required String exceptEndpoint}) {
    final forwarded = envelope.forwarded(
      relayId: _crypto.identity.deviceId,
      relayName: _crypto.identity.displayName,
    );
    final targets = connectedPeers
        .where((peer) => peer.endpointId != exceptEndpoint)
        .toList(growable: false);
    for (final peer in targets) {
      if (forwarded.path.contains(peer.deviceId)) continue;
      _enqueueToEndpoint(
        forwarded,
        peer.endpointId,
        peerName: peer.displayName,
        reason: 'relay',
      );
    }
    _forwardedCount += targets.length;
    unawaited(_audit.log(
      AuditEventType.messageForwarded,
      'Relayed ${envelope.id} to ${targets.length} peer(s) at hop ${forwarded.hopCount}/${forwarded.maxHops}.',
      messageId: envelope.id,
      isDemo: envelope.isDemo,
    ));
    _notify();
  }

  void _enqueueToEndpoint(
    MeshEnvelope envelope,
    String endpointId, {
    required String peerName,
    required String reason,
  }) {
    final key = '${envelope.id}|$endpointId';
    if (!_queuedKeys.add(key)) return;
    _outbox.add(_SendJob(
      envelope: envelope,
      endpointId: endpointId,
      peerName: peerName,
      reason: reason,
      key: key,
    ));
    _outbox.sort((a, b) {
      final priority = b.envelope.priority.compareTo(a.envelope.priority);
      if (priority != 0) return priority;
      return a.envelope.createdAtMs.compareTo(b.envelope.createdAtMs);
    });
    _statusMessage = '${_outbox.length} frame(s) queued for transmission';
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_outbox.isNotEmpty) {
        final job = _outbox.removeAt(0);
        final queuedAt = DateTime.now().toUtc();
        await _transmissions.record(TransmissionRecord(
          id: _uuid.v4(),
          messageId: job.envelope.id,
          endpointId: job.endpointId,
          peerName: job.peerName,
          status: 'queued',
          attemptedAt: queuedAt,
          isDemo: job.envelope.isDemo,
        ));
        final ok = await _transport.send(
          job.endpointId,
          job.envelope.wireBytes,
        );
        await _transmissions.record(TransmissionRecord(
          id: _uuid.v4(),
          messageId: job.envelope.id,
          endpointId: job.endpointId,
          peerName: job.peerName,
          status: ok ? 'sent' : 'failed',
          attemptedAt: queuedAt,
          completedAt: DateTime.now().toUtc(),
          error: ok ? null : 'Native transport rejected frame',
          isDemo: job.envelope.isDemo,
        ));
        if (ok) {
          final existing = await _messages.byId(job.envelope.id);
          if (existing?.status != MeshDeliveryStatus.acknowledged) {
            await _messages.updateStatus(
              job.envelope.id,
              MeshDeliveryStatus.transmitted,
            );
          }
          await _audit.log(
            AuditEventType.messageSent,
            'Frame ${job.envelope.id} handed to ${job.peerName} (${job.reason}). Transport-level success only.',
            messageId: job.envelope.id,
            peerId: job.endpointId,
            isDemo: job.envelope.isDemo,
          );
        } else {
          await _audit.log(
            AuditEventType.invalidDropped,
            'Frame ${job.envelope.id} failed to send to ${job.peerName}.',
            messageId: job.envelope.id,
            peerId: job.endpointId,
            isDemo: job.envelope.isDemo,
          );
        }
        _queuedKeys.remove(job.key);
      }
      _statusMessage = _running
          ? 'Mesh active — ${connectedPeers.length} peer(s) connected'
          : 'Mesh idle';
    } finally {
      _draining = false;
      _notify();
    }
  }

  Future<void> _storeAndForwardTo(String endpointId) async {
    final peer = _peersByEndpoint[endpointId];
    if (peer == null) return;
    final recent = await _messages.inbox(limit: 80);
    final now = DateTime.now().toUtc();
    for (final record in recent) {
      if (record.isExpired || record.expiresAt.isBefore(now)) continue;
      if (record.type == MeshMessageType.presence) continue;
      if (record.type == MeshMessageType.ack) {
        try {
          final decoded = jsonDecode(record.payloadJson ?? '{}');
          if (decoded is Map<String, dynamic> &&
              decoded['target'] == _crypto.identity.deviceId) {
            continue;
          }
        } catch (_) {
          continue;
        }
      }
      if (await _transmissions.hasTransmitted(record.id, endpointId)) continue;
      MeshEnvelope envelope;
      try {
        envelope = MeshEnvelope.fromWireString(record.envelopeJson);
      } catch (_) {
        continue;
      }
      if (envelope.path.contains(peer.deviceId)) continue;
      final outgoing = envelope.originId == _crypto.identity.deviceId
          ? envelope
          : envelope.forwarded(
              relayId: _crypto.identity.deviceId,
              relayName: _crypto.identity.displayName,
            );
      if (outgoing.hopCount > outgoing.maxHops) continue;
      _enqueueToEndpoint(
        outgoing,
        endpointId,
        peerName: peer.displayName,
        reason: 'store-and-forward',
      );
    }
  }

  Future<void> waitForIdle({Duration timeout = const Duration(seconds: 5)}) async {
    final end = DateTime.now().add(timeout);
    while ((_draining || _outbox.isNotEmpty) && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> expireNow() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _messages.expireOld(now);
    await _incidents.expireOld(now);
    _notify();
  }

  Future<void> refreshPeers() async {
    final stored = await _peers.list();
    for (final peer in stored) {
      _peersByEndpoint[peer.endpointId] = peer;
    }
    _notify();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _transport.dispose();
  }

  void _notify() {
    if (!_disposed) onChanged();
  }

  bool _disposed = false;

  Future<void> shutdown() async {
    _disposed = true;
    await dispose();
  }

  /// Test/diagnostic helper: the number of frames awaiting native transmission.
  int get queuedFrameCount => _outbox.length;
}

class _SendJob {
  const _SendJob({
    required this.envelope,
    required this.endpointId,
    required this.peerName,
    required this.reason,
    required this.key,
  });

  final MeshEnvelope envelope;
  final String endpointId;
  final String peerName;
  final String reason;
  final String key;
}
