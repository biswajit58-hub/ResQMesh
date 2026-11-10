import 'dart:async';

import 'package:flutter/services.dart';

import '../../models/enums.dart';
import 'mesh_transport.dart';

/// Peer transport over Android Nearby Connections or iOS MultipeerConnectivity.
///
/// The native side advertises/discovers, accepts connections and moves opaque
/// bytes. It has no routing, deduplication, trust or message semantics.
class NearbyTransport implements MeshTransport {
  NearbyTransport({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _method = methodChannel ??
            const MethodChannel('com.resqmesh/nearby'),
        _events = eventChannel ??
            const EventChannel('com.resqmesh/nearby/events');

  final MethodChannel _method;
  final EventChannel _events;
  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  bool _initialized = false;
  TransportAvailability _availability = TransportAvailability.unavailable;

  @override
  TransportKind get kind => TransportKind.nearby;

  @override
  bool get isSimulated => false;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  Future<TransportAvailability> initialize() async {
    if (_initialized) return _availability;
    _initialized = true;
    _subscription = _events.receiveBroadcastStream().listen(
          _onNativeEvent,
          onError: (Object error) {
            _availability = TransportAvailability(
              available: false,
              reason: 'Nearby event channel error: $error',
              transport: TransportKind.nearby,
            );
            _controller.add(TransportEvent(
              kind: TransportEventKind.availability,
              detail: _availability.reason,
            ));
          },
        );
    try {
      final raw = await _method.invokeMapMethod<String, dynamic>('status');
      final available = raw?['available'] as bool? ?? false;
      final reason = raw?['reason'] as String? ??
          (available ? 'Nearby ready' : 'Nearby unavailable');
      _availability = TransportAvailability(
        available: available,
        reason: reason,
        googlePlayServices: raw?['googlePlayServices'] as bool? ?? false,
        transport: TransportKind.nearby,
      );
      if (available) {
        await _method.invokeMethod<void>('initialize');
      }
    } on MissingPluginException {
      _availability = const TransportAvailability(
        available: false,
        reason: 'Native Nearby plugin is not available on this platform.',
        transport: TransportKind.nearby,
      );
    } on PlatformException catch (error) {
      _availability = TransportAvailability(
        available: false,
        reason: error.message ?? 'Nearby initialization failed.',
        transport: TransportKind.nearby,
      );
    }
    _controller.add(TransportEvent(
      kind: TransportEventKind.availability,
      detail: _availability.reason,
    ));
    return _availability;
  }

  @override
  Future<void> start({
    required String deviceName,
    required bool autoConnect,
  }) async {
    if (!_availability.available) {
      throw StateError(_availability.reason);
    }
    await _method.invokeMethod<void>('start', {
      'name': deviceName,
      'autoConnect': autoConnect,
    });
  }

  @override
  Future<void> stop() async {
    if (!_availability.available) return;
    try {
      await _method.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Platform is shutting down or unsupported.
    }
  }

  @override
  Future<void> connect(String endpointId) async {
    await _method.invokeMethod<void>('connect', {
      'endpointId': endpointId,
    });
  }

  @override
  Future<bool> send(String endpointId, Uint8List data) async {
    try {
      final result = await _method.invokeMethod<bool>('send', {
        'endpointId': endpointId,
        'data': data,
      });
      return result ?? false;
    } on PlatformException catch (error) {
      _controller.add(TransportEvent(
        kind: TransportEventKind.error,
        endpointId: endpointId,
        detail: error.message,
      ));
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await stop();
    await _controller.close();
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final map = raw.cast<Object?, Object?>();
    final type = map['type'] as String?;
    switch (type) {
      case 'peerFound':
        _controller.add(TransportEvent(
          kind: TransportEventKind.peerFound,
          endpointId: map['endpointId'] as String?,
          displayName: map['name'] as String?,
        ));
      case 'peerLost':
        _controller.add(TransportEvent(
          kind: TransportEventKind.peerLost,
          endpointId: map['endpointId'] as String?,
        ));
      case 'connected':
        _controller.add(TransportEvent(
          kind: TransportEventKind.connected,
          endpointId: map['endpointId'] as String?,
          displayName: map['name'] as String?,
        ));
      case 'disconnected':
        _controller.add(TransportEvent(
          kind: TransportEventKind.disconnected,
          endpointId: map['endpointId'] as String?,
        ));
      case 'payload':
        final data = map['data'];
        if (data is Uint8List) {
          _controller.add(TransportEvent(
            kind: TransportEventKind.payload,
            endpointId: map['endpointId'] as String?,
            displayName: map['name'] as String?,
            data: data,
          ));
        } else if (data is List<int>) {
          _controller.add(TransportEvent(
            kind: TransportEventKind.payload,
            endpointId: map['endpointId'] as String?,
            displayName: map['name'] as String?,
            data: Uint8List.fromList(data),
          ));
        }
      case 'status':
        _controller.add(TransportEvent(
          kind: TransportEventKind.status,
          detail: map['message'] as String?,
        ));
      case 'error':
        _controller.add(TransportEvent(
          kind: TransportEventKind.error,
          detail: map['message'] as String?,
        ));
    }
  }
}
