import 'dart:async';
import 'dart:typed_data';

import 'package:resqmesh/core/networking/mesh_transport.dart';
import 'package:resqmesh/models/enums.dart';

/// In-memory byte transport used ONLY by tests.
///
/// It deliberately mimics the Android transport contract (opaque bytes,
/// endpoint IDs, asynchronous delivery) without touching radios. The real
/// relay/validation code under test is MeshService.
class FakeTransportHub {
  final Map<String, FakeTransport> nodes = {};
  final Map<String, Set<String>> links = {};

  void link(String a, String b) {
    links.putIfAbsent(a, () => {}).add(b);
    links.putIfAbsent(b, () => {}).add(a);
  }

  bool isLinked(String a, String b) => links[a]?.contains(b) ?? false;

  Set<String> neighbors(String id) => links[id] ?? {};

  void register(FakeTransport transport) {
    nodes[transport.nodeId] = transport;
  }

  void announceLinks() {
    for (final entry in links.entries) {
      for (final neighbor in entry.value) {
        final source = nodes[entry.key];
        final target = nodes[neighbor];
        if (source == null || target == null) continue;
        target.emitConnected(source.nodeId, source.deviceName);
        source.emitConnected(target.nodeId, target.deviceName);
      }
    }
  }
}

class FakeTransport implements MeshTransport {
  FakeTransport({
    required this.hub,
    required this.nodeId,
    required this.deviceName,
  });

  final FakeTransportHub hub;
  final String nodeId;
  final String deviceName;
  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast();
  final Set<String> _connected = {};
  bool started = false;

  @override
  TransportKind get kind => TransportKind.simulated;

  @override
  bool get isSimulated => true;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  Future<TransportAvailability> initialize() async {
    return const TransportAvailability(
      available: true,
      reason: 'Fake test transport ready',
      transport: TransportKind.simulated,
    );
  }

  @override
  Future<void> start({
    required String deviceName,
    required bool autoConnect,
  }) async {
    started = true;
    hub.register(this);
  }

  @override
  Future<void> connect(String endpointId) async {
    emitConnected(endpointId, hub.nodes[endpointId]?.deviceName ?? 'Peer');
  }

  @override
  Future<bool> send(String endpointId, Uint8List data) async {
    if (!started) return false;
    if (!hub.isLinked(nodeId, endpointId)) return false;
    final target = hub.nodes[endpointId];
    if (target == null) return false;
    if (!_connected.contains(endpointId)) return false;
    scheduleMicrotask(() {
      target.emitPayload(nodeId, deviceName, data);
    });
    return true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  void emitConnected(String endpointId, String name) {
    if (!started) return;
    _connected.add(endpointId);
    _controller.add(TransportEvent(
      kind: TransportEventKind.connected,
      endpointId: endpointId,
      displayName: name,
    ));
  }

  void emitPayload(String endpointId, String name, Uint8List data) {
    if (!started) return;
    _controller.add(TransportEvent(
      kind: TransportEventKind.payload,
      endpointId: endpointId,
      displayName: name,
      data: data,
    ));
  }

  void emitRawPayload(String endpointId, List<int> data) {
    if (!started) return;
    _controller.add(TransportEvent(
      kind: TransportEventKind.payload,
      endpointId: endpointId,
      data: Uint8List.fromList(data),
    ));
  }
}

Future<void> waitUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 8),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw TimeoutException(reason ?? 'Condition not reached');
}
