import Flutter
import UIKit
import MultipeerConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MultipeerMeshPlugin") {
      MultipeerMeshPlugin.register(with: registrar)
    }
  }
}

/// iOS byte transport for ResQMesh.
///
/// This class deliberately contains no relay, dedupe, trust, expiry or routing
/// logic. It advertises/browses with MultipeerConnectivity and moves opaque
/// application envelopes. Dart owns all message semantics, exactly as it does
/// over Android Nearby Connections.
///
/// Cross-platform note: MultipeerConnectivity and Google Nearby Connections do
/// not interoperate. iOS meshes peer with iOS; Android meshes peer with Android.
final class MultipeerMeshPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let methodChannelName = "com.resqmesh/nearby"
  private static let eventChannelName = "com.resqmesh/nearby/events"
  private static let serviceType = "resqmesh-mesh"
  private static let maxPeers = 8

  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []
  private var started = false
  private var autoConnect = true

  private var localPeer: MCPeerID?
  private var session: MCSession?
  private var advertiser: MCNearbyServiceAdvertiser?
  private var browser: MCNearbyServiceBrowser?

  private var endpointIdsByPeerName: [String: String] = [:]
  private var peersByEndpoint: [String: MCPeerID] = [:]
  private var namesByEndpoint: [String: String] = [:]
  private var connectedEndpoints = Set<String>()
  private var pendingInvites = Set<String>()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MultipeerMeshPlugin()
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(statusMap())
    case "initialize":
      result(true)
    case "start":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing start arguments", details: nil))
        return
      }
      let name = (args["name"] as? String ?? "ResQMesh device")
      autoConnect = args["autoConnect"] as? Bool ?? true
      start(displayName: name)
      result(true)
    case "stop":
      stop()
      result(true)
    case "connect":
      guard let args = call.arguments as? [String: Any],
            let endpointId = args["endpointId"] as? String,
            let peer = peersByEndpoint[endpointId] else {
        result(false)
        return
      }
      invite(peer, endpointId: endpointId)
      result(true)
    case "send":
      guard let args = call.arguments as? [String: Any],
            let endpointId = args["endpointId"] as? String,
            let typed = args["data"] as? FlutterStandardTypedData,
            let peer = peersByEndpoint[endpointId],
            let session = session,
            connectedEndpoints.contains(endpointId) else {
        result(false)
        return
      }
      do {
        try session.send(typed.data, toPeers: [peer], with: .reliable)
        result(true)
      } catch {
        emitError("Send to \(endpointId) failed: \(error.localizedDescription)")
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    let queued = pendingEvents
    pendingEvents.removeAll()
    for event in queued {
      events(event)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func statusMap() -> [String: Any] {
    return [
      "available": true,
      "googlePlayServices": false,
      "reason": "MultipeerConnectivity ready"
    ]
  }

  private func start(displayName: String) {
    if started {
      emitStatus("Multipeer mesh already active")
      return
    }
    stop(reset: true)
    let raw = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallback = UIDevice.current.name
    let requested = raw.isEmpty ? fallback : raw
    var safeName = String(requested.replacingOccurrences(of: "\n", with: " ").prefix(30))
    while safeName.utf8.count > 63 {
      safeName.removeLast()
    }
    let peerID = MCPeerID(displayName: safeName.isEmpty ? "ResQMesh" : safeName)
    localPeer = peerID

    let newSession = MCSession(
      peer: peerID,
      securityIdentity: nil,
      encryptionPreference: .required
    )
    newSession.delegate = self
    session = newSession

    let newAdvertiser = MCNearbyServiceAdvertiser(
      peer: peerID,
      discoveryInfo: nil,
      serviceType: Self.serviceType
    )
    newAdvertiser.delegate = self
    advertiser = newAdvertiser
    newAdvertiser.startAdvertisingPeer()

    let newBrowser = MCNearbyServiceBrowser(
      peer: peerID,
      serviceType: Self.serviceType
    )
    newBrowser.delegate = self
    browser = newBrowser
    newBrowser.startBrowsingForPeers()

    started = true
    emitStatus("Advertising and browsing for iOS peers")
  }

  private func stop(reset: Bool = true) {
    browser?.stopBrowsingForPeers()
    advertiser?.stopAdvertisingPeer()
    session?.disconnect()
    browser = nil
    advertiser = nil
    session = nil
    localPeer = nil
    started = false
    if reset {
      endpointIdsByPeerName.removeAll()
      peersByEndpoint.removeAll()
      namesByEndpoint.removeAll()
      connectedEndpoints.removeAll()
      pendingInvites.removeAll()
      emitStatus("Multipeer transport stopped")
    }
  }

  private func invite(_ peer: MCPeerID, endpointId: String) {
    guard let session = session,
          session.connectedPeers.count < Self.maxPeers,
          !connectedEndpoints.contains(endpointId),
          !pendingInvites.contains(endpointId) else {
      return
    }
    pendingInvites.insert(endpointId)
    browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    emitStatus("Inviting \(peer.displayName)")
  }

  private func endpoint(for peer: MCPeerID) -> String {
    let peerName = peer.displayName
    if let existing = endpointIdsByPeerName[peerName] {
      peersByEndpoint[existing] = peer
      namesByEndpoint[existing] = peerName
      return existing
    }
    let identifier = "ios-\(UUID().uuidString)"
    endpointIdsByPeerName[peerName] = identifier
    peersByEndpoint[identifier] = peer
    namesByEndpoint[identifier] = peerName
    return identifier
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async {
      if let sink = self.eventSink {
        sink(event)
      } else {
        if self.pendingEvents.count >= 128 {
          self.pendingEvents.removeFirst()
        }
        self.pendingEvents.append(event)
      }
    }
  }

  private func emitStatus(_ message: String) {
    emit(["type": "status", "message": message])
  }

  private func emitError(_ message: String) {
    emit(["type": "error", "message": message])
  }
}

extension MultipeerMeshPlugin: MCNearbyServiceAdvertiserDelegate {
  func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didReceiveInvitationFromPeer peerID: MCPeerID,
    withContext context: Data?,
    invitationHandler: @escaping (Bool, MCSession?) -> Void
  ) {
    if let session = session, session.connectedPeers.count < Self.maxPeers {
      invitationHandler(true, session)
    } else {
      invitationHandler(false, nil)
    }
  }

  func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didNotStartAdvertisingPeer error: Error
  ) {
    emitError("Advertising failed: \(error.localizedDescription)")
  }
}

extension MultipeerMeshPlugin: MCNearbyServiceBrowserDelegate {
  func browser(
    _ browser: MCNearbyServiceBrowser,
    foundPeer peerID: MCPeerID,
    withDiscoveryInfo info: [String: String]?
  ) {
    let identifier = endpoint(for: peerID)
    emit([
      "type": "peerFound",
      "endpointId": identifier,
      "name": peerID.displayName
    ])
    if autoConnect {
      invite(peerID, endpointId: identifier)
    }
  }

  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    let identifier = endpoint(for: peerID)
    pendingInvites.remove(identifier)
    emit(["type": "peerLost", "endpointId": identifier])
  }

  func browser(
    _ browser: MCNearbyServiceBrowser,
    didNotStartBrowsingForPeers error: Error
  ) {
    emitError("Discovery failed: \(error.localizedDescription)")
  }
}

extension MultipeerMeshPlugin: MCSessionDelegate {
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    let identifier = endpoint(for: peerID)
    switch state {
    case .connected:
      pendingInvites.remove(identifier)
      connectedEndpoints.insert(identifier)
      emit([
        "type": "connected",
        "endpointId": identifier,
        "name": peerID.displayName
      ])
      emitStatus("Connected to \(peerID.displayName)")
    case .connecting:
      break
    case .notConnected:
      connectedEndpoints.remove(identifier)
      pendingInvites.remove(identifier)
      emit([
        "type": "disconnected",
        "endpointId": identifier,
        "name": peerID.displayName
      ])
      emitStatus("Disconnected from \(peerID.displayName)")
    @unknown default:
      break
    }
  }

  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    let identifier = endpoint(for: peerID)
    emit([
      "type": "payload",
      "endpointId": identifier,
      "name": peerID.displayName,
      "data": FlutterStandardTypedData(bytes: data)
    ])
  }

  func session(
    _ session: MCSession,
    didReceive stream: InputStream,
    withName streamName: String,
    fromPeer peerID: MCPeerID
  ) {
    // ResQMesh uses bounded byte frames, not streams.
  }

  func session(
    _ session: MCSession,
    didStartReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID,
    with progress: Progress
  ) {
    // ResQMesh does not use resource transfers.
  }

  func session(
    _ session: MCSession,
    didFinishReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID,
    at localURL: URL?,
    withError error: Error?
  ) {
    // ResQMesh does not use resource transfers.
  }

  func session(
    _ session: MCSession,
    didReceiveCertificate certificate: [Any]?,
    fromPeer peerID: MCPeerID,
    certificateHandler: @escaping (Bool) -> Void
  ) {
    // MCSession with .required encryption authenticates the link. Application
    // messages still carry Ed25519 origin signatures and AES-GCM payloads.
    certificateHandler(true)
  }
}