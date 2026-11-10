import 'dart:typed_data';

import '../../models/enums.dart';

enum TransportEventKind {
  availability,
  peerFound,
  peerLost,
  connected,
  disconnected,
  payload,
  error,
  status,
}

class TransportEvent {
  const TransportEvent({
    required this.kind,
    this.endpointId,
    this.displayName,
    this.data,
    this.detail,
  });

  final TransportEventKind kind;
  final String? endpointId;
  final String? displayName;
  final Uint8List? data;
  final String? detail;
}

class TransportAvailability {
  const TransportAvailability({
    required this.available,
    required this.reason,
    this.googlePlayServices = false,
    this.transport = TransportKind.none,
  });

  final bool available;
  final String reason;
  final bool googlePlayServices;
  final TransportKind transport;

  static const unavailable = TransportAvailability(
    available: false,
    reason: 'Nearby transport not initialized',
  );
}

/// Native transports move opaque bytes between endpoint IDs only. All relay,
/// validation, deduplication and persistence live in Dart.
abstract class MeshTransport {
  TransportKind get kind;
  bool get isSimulated;

  Future<TransportAvailability> initialize();

  Stream<TransportEvent> get events;

  Future<void> start({
    required String deviceName,
    required bool autoConnect,
  });

  Future<void> stop();

  Future<void> connect(String endpointId);

  /// Completes only when the native layer reports the payload as successfully
  /// handed to the transport. This is NOT proof of end-to-end delivery.
  Future<bool> send(String endpointId, Uint8List data);

  Future<void> dispose();
}
