import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/database/audit_repository.dart';
import '../core/database/incident_repository.dart';
import '../core/database/known_device_repository.dart';
import '../core/database/location_repository.dart';
import '../core/database/message_repository.dart';
import '../core/database/peer_repository.dart';
import '../core/database/shelter_repository.dart';
import '../core/database/transmission_repository.dart';
import '../core/database/verification_repository.dart';
import '../core/location/location_service.dart';
import '../core/networking/mesh_payloads.dart';
import '../core/networking/mesh_transport.dart';
import '../core/networking/nearby_transport.dart';
import '../core/security/mesh_crypto_service.dart';
import '../core/security/secret_store.dart';
import '../core/security/trust_service.dart';
import '../models/app_settings.dart';
import '../models/audit_event.dart';
import '../models/enums.dart';
import '../models/evacuation_route.dart';
import '../models/geo_fix.dart';
import '../models/incident.dart';
import '../models/message_record.dart';
import '../models/peer_device.dart';
import '../models/priority_assessment.dart';
import '../models/protocol_simulation.dart';
import '../models/rescue_team.dart';
import '../models/risk_zone.dart';
import '../models/shelter.dart';
import '../models/verification_vote.dart';
import 'audit_service.dart';
import 'demo_data_service.dart';
import 'evacuation_service.dart';
import 'intelligence_service.dart';
import 'mesh_service.dart';
import 'priority_service.dart';
import 'protocol_simulation_service.dart';
import 'responder_service.dart';
import 'settings_service.dart';
import 'verification_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    SettingsService? settingsService,
    LocationService? locationService,
    MeshTransport? transport,
    SecretStore? secretStore,
    this.enableRadio = true,
  })  : _settingsService = settingsService ?? SettingsService(),
        _locationService = locationService ?? LocationService(),
        _transport = transport ?? NearbyTransport(),
        _secretStore = secretStore ?? SecureSecretStore();

  final SettingsService _settingsService;
  final LocationService _locationService;
  final MeshTransport _transport;
  final SecretStore _secretStore;
  final bool enableRadio;
  final _uuid = const Uuid();

  bool initializing = true;
  bool ready = false;
  String? initError;
  AppSettings settings = AppSettings.defaults();

  AppDatabase? _db;
  IncidentRepository? _incidents;
  MessageRepository? _messages;
  ShelterRepository? _shelters;
  PeerRepository? _peers;
  VerificationRepository? _verifications;
  AuditRepository? _auditRepo;
  LocationRepository? _locations;
  AuditService? _audit;
  MeshCryptoService? _crypto;
  MeshService? _mesh;
  ResponderService? _responder;
  DemoDataService? _demoData;
  KnownDeviceRepository? _knownDevices;

  final VerificationService _verification = const VerificationService();
  final IntelligenceService _intelligence = const IntelligenceService();
  final PriorityService _priority = const PriorityService();
  final EvacuationService _evacuation = const EvacuationService();
  final ProtocolSimulationService _simulation = ProtocolSimulationService();

  List<Incident> incidents = const [];
  List<Shelter> shelters = const [];
  List<PeerDevice> peers = const [];
  List<MessageRecord> messages = const [];
  List<AuditEvent> events = const [];
  List<RiskZone> riskZones = const [];
  Map<String, PriorityAssessment> priorities = const {};
  Map<String, VerificationResult> verificationEvidence = const {};
  List<RescueTeam> rescueTeams = const [];
  DemoContent? demoContent;

  DemoContent? get currentDemoContent => demoContent ??
      (settings.demoMode && _demoData != null
          ? _demoData!.contentWithTeams(settings.demoScenario)
          : null);

  GeoFix? lastKnownLocation;
  String? locationMessage;
  bool locationBusy = false;
  DateTime? lastRefreshAt;
  bool online = false;
  String networkLabel = 'Checking network…';
  String? notice;
  String? lastMeshAction;
  bool meshBusy = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _refreshDebounce;
  Timer? _networkTimer;
  Future<void>? _refreshFuture;
  bool _disposed = false;

  MeshCryptoService get crypto => _crypto!;
  MeshService get mesh => _mesh!;
  ResponderService get responder => _responder!;
  AuditService get audit => _audit!;
  KnownDeviceRepository get knownDevices => _knownDevices!;
  IncidentRepository get incidentRepository => _incidents!;
  MessageRepository get messageRepository => _messages!;
  ShelterRepository get shelterRepository => _shelters!;
  VerificationRepository get verificationRepository => _verifications!;
  LocationRepository get locationRepository => _locations!;

  String get deviceName => settings.deviceName;
  String get deviceId => _crypto?.identity.deviceId ?? 'initializing';
  bool get isDemo => settings.demoMode;
  bool get isResponder => _responder?.isAuthenticated ?? false;

  List<Incident> get activeIncidents => incidents
      .where((i) =>
          !i.isExpired &&
          i.status != IncidentStatus.resolved &&
          i.status != IncidentStatus.closed)
      .toList(growable: false);

  List<Incident> get activeSos => activeIncidents
      .where((i) => i.kind == IncidentKind.sos)
      .toList(growable: false);

  List<Incident> get activeHazards => activeIncidents
      .where((i) => i.kind == IncidentKind.hazard)
      .toList(growable: false);

  int get criticalCount => activeIncidents
      .where((i) => i.severity == Severity.critical)
      .length;

  List<Shelter> get availableShelters =>
      shelters.where((s) => s.hasCapacity).toList(growable: false);

  GeoFix? get currentLocation {
    if (isDemo && demoContent != null) {
      return GeoFix(
        latitude: demoContent!.centerLatitude,
        longitude: demoContent!.centerLongitude,
        accuracyMeters: 30,
        source: LocationSource.computed,
        capturedAt: DateTime.now().toUtc(),
        description: 'Synthetic demo scenario centre',
      );
    }
    return lastKnownLocation;
  }

  bool get locationIsLive => lastKnownLocation?.isLive ?? false;

  bool get meshRunning => _mesh?.isRunning ?? false;
  bool get meshAvailable => _mesh?.isAvailable ?? false;
  int get connectedPeerCount => _mesh?.connectedPeers.length ?? 0;
  String get meshStatusMessage => _mesh?.statusMessage ?? 'Mesh not initialized';
  String? get meshError => _mesh?.lastError;

  Future<void> initialize() async {
    if (ready) return;
    initializing = true;
    _notify();
    try {
      settings = await _settingsService.load();
      if (settings.deviceName.trim().isEmpty) {
        final suffix = _uuid.v4().substring(0, 4).toUpperCase();
        settings = settings.copyWith(deviceName: 'ResQ-$suffix');
        await _settingsService.save(settings);
      }

      _db = await AppDatabase.open();
      _incidents = IncidentRepository(_db!);
      _messages = MessageRepository(_db!);
      _shelters = ShelterRepository(_db!);
      _peers = PeerRepository(_db!);
      _verifications = VerificationRepository(_db!);
      _auditRepo = AuditRepository(_db!);
      _locations = LocationRepository(_db!);
      _knownDevices = KnownDeviceRepository(_db!);
      _audit = AuditService(_auditRepo!);

      _crypto = MeshCryptoService(
        secretStore: _secretStore,
        deviceName: settings.deviceName,
      );
      await _crypto!.loadGroupPassphraseFromStore();
      await _crypto!.initialize();

      final trust = TrustService(_knownDevices!);
      _responder = ResponderService(_secretStore);
      _demoData = DemoDataService(
        db: _db!,
        incidents: _incidents!,
        messages: _messages!,
        shelters: _shelters!,
        peers: _peers!,
        verifications: _verifications!,
        audit: _auditRepo!,
      );

      _mesh = MeshService(
        crypto: _crypto!,
        trust: trust,
        peers: _peers!,
        messages: _messages!,
        incidents: _incidents!,
        transmissions: TransmissionRepository(_db!),
        audit: _audit!,
        transport: _transport,
        onChanged: _onMeshChanged,
        onIncomingIncident: _onIncomingIncident,
        onPeerConnected: _onPeerConnected,
      );
      await _mesh!.initialize();

      lastKnownLocation = await _locations!.latest();
      await _audit!.log(
        AuditEventType.appStarted,
        'ResQMesh started on ${Platform.operatingSystem}; identity $deviceId.',
      );
      await _mesh!.expireNow();

      if (settings.demoMode) {
        final scenario = settings.demoScenario == DemoScenario.none
            ? DemoScenario.flood
            : settings.demoScenario;
        final existingDemo = await _incidents!.list(
          demoOnly: true,
          limit: 1,
        );
        demoContent = existingDemo.isEmpty
            ? await _demoData!.seed(scenario)
            : _demoData!.contentWithTeams(scenario);
        settings = settings.copyWith(demoScenario: scenario);
        await _settingsService.save(settings);
      } else {
        await _demoData!.clear();
      }

      await refreshData();
      _startConnectivityMonitor();
      ready = true;
      initializing = false;
      _notify();

      if (!settings.demoMode &&
          settings.meshAutoStart &&
          settings.permissionsDone) {
        unawaited(startMesh(silent: true));
      }
    } catch (error, stack) {
      initError = 'Initialization failed: $error';
      initializing = false;
      ready = false;
      _notify();
      // ignore: avoid_print
      print(stack);
    }
  }

  void _startConnectivityMonitor() {
    final connectivity = Connectivity();
    _connectivitySub ??=
        connectivity.onConnectivityChanged.listen((results) {
      unawaited(_checkNetwork());
    });
    _networkTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_checkNetwork()),
    );
    unawaited(_checkNetwork());
  }

  Future<void> _checkNetwork() async {
    try {
      await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      online = true;
      networkLabel = 'ONLINE';
    } catch (_) {
      online = false;
      networkLabel = 'OFFLINE';
    }
    _notify();
  }

  void _onMeshChanged() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 180), () {
      unawaited(refreshData());
    });
  }

  Future<void> _onIncomingIncident(Incident incident) async {
    notice =
        'Mesh alert received: ${incident.severity.wire} ${incident.category.wire} · ${incident.id.substring(0, 8)}…';
    await refreshData();
  }

  void _onPeerConnected(PeerDevice peer) {
    settings = settings.copyWith(lastKnownPeerName: peer.displayName);
    unawaited(_settingsService.save(settings));
    unawaited(_audit!.log(
      AuditEventType.peerConnected,
      'Peer "${peer.displayName}" connected. Last-known mesh device updated.',
      peerId: peer.endpointId,
    ));
  }

  Future<void> refreshData() {
    final running = _refreshFuture;
    if (running != null) return running;
    final future = _doRefresh();
    _refreshFuture = future.whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<void> _doRefresh() async {
    if (_db == null) return;
    final demo = settings.demoMode;
    if (demo && demoContent == null) {
      demoContent = _demoData!.contentWithTeams(settings.demoScenario);
    }
    var loadedIncidents = await _incidents!.list(
      demoOnly: demo,
      includeDemo: false,
    );
    var changed = false;
    final evidence = <String, VerificationResult>{};
    for (var i = 0; i < loadedIncidents.length; i++) {
      final incident = loadedIncidents[i];
      final votes = await _verifications!.forIncident(incident.id);
      final result = _verification.evaluate(
        incident: incident,
        allIncidents: loadedIncidents,
        votes: votes,
      );
      evidence[incident.id] = result;
      if (result.state != incident.verification ||
          result.independentReporters != incident.independentReporters) {
        await _incidents!.updateVerification(
          incident.id,
          result.state.wire,
          result.independentReporters,
          DateTime.now().toUtc().millisecondsSinceEpoch,
        );
        loadedIncidents[i] = incident.copyWith(
          verification: result.state,
          independentReporters: result.independentReporters,
          updatedAt: DateTime.now().toUtc(),
        );
        changed = true;
        await _audit!.log(
          AuditEventType.verificationChanged,
          '${incident.id}: ${incident.verification.wire} → ${result.state.wire}. ${result.explanation}',
          messageId: incident.id,
          isDemo: incident.isDemo,
        );
      }
    }
    if (changed) {
      loadedIncidents = await _incidents!.list(
        demoOnly: demo,
        includeDemo: false,
      );
    }
    incidents = loadedIncidents;
    verificationEvidence = evidence;
    shelters = await _shelters!.list(demoOnly: demo);
    messages = await _messages!.inbox(
      demoOnly: demo,
      includeDemo: false,
      limit: 250,
    );
    events = await _audit!.list(demoOnly: demo, limit: 600);
    final repoPeers = await _peers!.list(demoOnly: demo);
    final meshPeers = demo ? <PeerDevice>[] : (_mesh?.peers ?? const []);
    final merged = <String, PeerDevice>{};
    for (final peer in repoPeers) {
      merged[peer.endpointId] = peer;
    }
    for (final peer in meshPeers) {
      merged[peer.endpointId] = peer;
    }
    peers = merged.values.toList(growable: false);
    rescueTeams = demo
        ? (demoContent?.rescueTeams ??
            _demoData!.teamsFor(settings.demoScenario))
        : const [];
    riskZones = _intelligence.analyze(incidents);
    final ranked = _priority.rank(
      incidents: activeIncidents,
      rescueTeams: rescueTeams,
    );
    priorities = {for (final item in ranked) item.incidentId: item};
    lastRefreshAt = DateTime.now().toUtc();
    _notify();
  }

  PriorityAssessment? assessmentFor(String incidentId) =>
      priorities[incidentId];

  RiskZone? zoneForIncident(String incidentId) {
    for (final zone in riskZones) {
      if (zone.incidentIds.contains(incidentId)) return zone;
    }
    return null;
  }

  Future<LocationAttempt> acquireLocation({
    bool requestPermission = true,
    bool announce = true,
  }) async {
    locationBusy = true;
    _notify();
    final attempt = await _locationService.acquire(
      cached: lastKnownLocation,
      requestPermission: requestPermission,
    );
    locationMessage = attempt.message;
    if (attempt.fix != null) {
      lastKnownLocation = attempt.fix;
      if (!attempt.usedFallback) {
        await _locations!.save(_uuid.v4(), attempt.fix!, isDemo: false);
      }
      if (announce) {
        await _audit!.log(
          AuditEventType.locationUpdated,
          'Location ${attempt.fix}. Source: ${attempt.fix!.source.wire}; live=${attempt.fix!.isLive}.',
        );
      }
    }
    locationBusy = false;
    _notify();
    return attempt;
  }

  GeoFix buildManualLocation({
    required double latitude,
    required double longitude,
    required String description,
  }) {
    final fix = GeoFix(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: 500,
      source: LocationSource.manual,
      capturedAt: DateTime.now().toUtc(),
      description: description.trim(),
    );
    lastKnownLocation = fix;
    locationMessage = 'Manual location set (±500 m uncertainty).';
    _notify();
    return fix;
  }

  Future<Incident> createIncident({
    required IncidentKind kind,
    required EmergencyCategory category,
    required Severity severity,
    required int peopleAffected,
    required String description,
    required GeoFix location,
    bool? synthetic,
  }) async {
    final demo = settings.demoMode;
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final incident = Incident(
      id: id,
      meshMessageId: id,
      kind: kind,
      category: category,
      severity: severity,
      peopleAffected: peopleAffected,
      description: description.trim(),
      location: location,
      status: IncidentStatus.active,
      verification: VerificationState.unverified,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
      originId: deviceId,
      originName: deviceName,
      isDemo: demo,
      synthetic: synthetic ?? demo,
    );
    await _incidents!.upsert(incident);
    await _locations!.save(_uuid.v4(), location, isDemo: demo);

    if (demo) {
      await _messages!.upsert(MessageRecord(
        id: id,
        type: kind == IncidentKind.sos ? MeshMessageType.sos : MeshMessageType.hazard,
        originId: deviceId,
        originName: deviceName,
        senderId: deviceId,
        senderName: deviceName,
        priority: priorityFor(severity, peopleAffected: peopleAffected),
        hopCount: 0,
        maxHops: 6,
        createdAt: now,
        receivedAt: now,
        expiresAt: incident.expiresAt,
        status: MeshDeliveryStatus.queued,
        transport: TransportKind.simulated,
        isDemo: true,
        envelopeJson: jsonEncode({
          'demo': true,
          'note': 'Synthetic incident created in demo mode; no radio used.',
        }),
        payloadJson: jsonEncode({
          'category': category.wire,
          'severity': severity.wire,
          'people': peopleAffected,
          'description': description,
        }),
        sizeBytes: 1024,
      ));
      await _audit!.log(
        kind == IncidentKind.sos
            ? AuditEventType.sosCreated
            : AuditEventType.hazardCreated,
        'DEMO ${kind.wire} $id saved locally. No mesh broadcast; synthetic training data.',
        messageId: id,
        isDemo: true,
      );
      lastMeshAction = 'Demo report stored locally — no radio transmission.';
    } else {
      try {
        await _mesh!.publishIncident(incident);
        lastMeshAction =
            'Encrypted and queued. Delivery is not guaranteed; watch receipt status.';
      } catch (error) {
        lastMeshAction = 'Saved locally. Mesh queue failed: $error';
      }
    }
    await refreshData();
    return incident;
  }

  Future<Incident> createSos({
    required EmergencyCategory category,
    required Severity severity,
    required int peopleAffected,
    required String description,
    required GeoFix location,
  }) =>
      createIncident(
        kind: IncidentKind.sos,
        category: category,
        severity: severity,
        peopleAffected: peopleAffected,
        description: description,
        location: location,
      );

  Future<Incident> createHazard({
    required EmergencyCategory category,
    required Severity severity,
    required String description,
    required GeoFix location,
    int peopleAffected = 0,
  }) =>
      createIncident(
        kind: IncidentKind.hazard,
        category: category,
        severity: severity,
        peopleAffected: peopleAffected,
        description: description,
        location: location,
      );

  Future<String> corroborateIncident(Incident incident) async {
    if (incident.originId == deviceId) {
      throw StateError('You cannot corroborate your own report.');
    }
    final location = currentLocation;
    if (location == null) {
      throw StateError(
          'A location is required. Acquire GPS or enter coordinates first.');
    }
    final distance = location.distanceMetersTo(incident.location);
    await createIncident(
      kind: IncidentKind.hazard,
      category: incident.category,
      severity: incident.severity,
      peopleAffected: 0,
      description:
          'Community corroboration from $deviceName. Device is ${distance.round()} m from the original report.',
      location: location,
      synthetic: incident.isDemo,
    );
    if (distance > 450) {
      return 'Report saved, but you are ${distance.round()} m away. It will not count as corroboration unless you are within 450 m.';
    }
    return 'Corroborating report saved. Verification will update if it is within 450 m and 90 minutes.';
  }

  Future<void> addResponderVote({
    required String incidentId,
    required VerificationState state,
    String note = '',
  }) async {
    if (!isResponder) {
      throw StateError('Responder session required.');
    }
    if (state != VerificationState.responderVerified &&
        state != VerificationState.disputed) {
      throw ArgumentError('Unsupported responder verification state.');
    }
    await _verifications!.insert(VerificationVote(
      id: _uuid.v4(),
      incidentId: incidentId,
      reporterId: deviceId,
      reporterName: '$deviceName (local responder)',
      state: state,
      note: note.trim(),
      isResponder: true,
      createdAt: DateTime.now().toUtc(),
      isDemo: settings.demoMode,
    ));
    await _audit!.log(
      AuditEventType.responderAction,
      'Responder marked $incidentId as ${state.wire}. Note: ${note.trim().isEmpty ? '(none)' : note.trim()}',
      messageId: incidentId,
      isDemo: settings.demoMode,
    );
    await refreshData();
  }

  Future<void> updateIncidentStatus(
    Incident incident,
    IncidentStatus status, {
    String note = '',
  }) async {
    if (!isResponder) throw StateError('Responder session required.');
    await _incidents!.updateStatus(
      incident.id,
      status.wire,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await _audit!.log(
      AuditEventType.responderAction,
      'Status changed to ${status.wire} for ${incident.id}. ${note.trim()}',
      messageId: incident.id,
      isDemo: incident.isDemo,
    );
    await refreshData();
  }

  Future<void> updateShelter(
    Shelter shelter, {
    required ShelterStatus status,
    required int occupancy,
  }) async {
    if (!isResponder) throw StateError('Responder session required.');
    final updated = shelter.copyWith(
      status: status,
      occupancy: occupancy.clamp(0, shelter.capacity),
      updatedAt: DateTime.now().toUtc(),
    );
    await _shelters!.upsert(updated);
    await _audit!.log(
      AuditEventType.shelterUpdated,
      '${shelter.name}: ${shelter.status.wire} → ${status.wire}; occupancy $occupancy/${shelter.capacity}.',
      isDemo: shelter.isDemo,
    );
    await refreshData();
  }

  Future<void> startMesh({bool silent = false}) async {
    if (_mesh == null || meshBusy) return;
    if (isDemo) {
      lastMeshAction = 'Demo mode has radios disabled. Exit demo mode for real P2P.';
      _notify();
      return;
    }
    if (!meshAvailable) {
      lastMeshAction = meshStatusMessage;
      _notify();
      return;
    }
    meshBusy = true;
    _notify();
    await _mesh!.start(
      deviceName: settings.deviceName,
      autoConnect: settings.autoConnect,
    );
    meshBusy = false;
    lastMeshAction = meshStatusMessage;
    _notify();
  }

  Future<void> stopMesh() async {
    if (_mesh == null) return;
    meshBusy = true;
    _notify();
    await _mesh!.stop();
    meshBusy = false;
    lastMeshAction = 'Mesh stopped. Emergency records remain on this device.';
    _notify();
  }

  Future<void> toggleMesh() async {
    if (meshRunning) {
      await stopMesh();
    } else {
      await startMesh();
    }
  }

  Future<void> connectToPeer(String endpointId) async {
    await _mesh?.connectToPeer(endpointId);
    lastMeshAction = 'Connection requested for $endpointId';
    _notify();
  }

  Future<void> activateDemo(DemoScenario scenario) async {
    if (scenario == DemoScenario.none) return;
    if (meshRunning) await stopMesh();
    settings = settings.copyWith(
      demoMode: true,
      demoScenario: scenario,
    );
    await _settingsService.save(settings);
    demoContent = await _demoData!.seed(scenario);
    await _audit!.log(
      AuditEventType.settingChanged,
      'Demo mode enabled: ${scenario.wire}. Real radio transport is disabled in demo mode.',
    );
    await refreshData();
    lastMeshAction =
        'DEMO MODE — synthetic data only. Radio transport is disabled.';
    _notify();
  }

  Future<void> exitDemo() async {
    await _demoData!.clear();
    demoContent = null;
    settings = settings.copyWith(
      demoMode: false,
      demoScenario: DemoScenario.none,
    );
    await _settingsService.save(settings);
    await refreshData();
    if (settings.meshAutoStart &&
        settings.permissionsDone &&
        meshAvailable) {
      await startMesh();
    }
    _notify();
  }

  Future<void> setLanguage(AppLanguage language) async {
    settings = settings.copyWith(language: language);
    await _settingsService.save(settings);
    await _audit!.log(
      AuditEventType.settingChanged,
      'UI language set to ${language.code}.',
    );
    _notify();
  }

  Future<void> setDeviceName(String name) async {
    final clean = name.trim();
    if (clean.length < 2 || clean.length > 32) {
      throw ArgumentError('Device name must be 2–32 characters.');
    }
    final wasRunning = meshRunning;
    if (wasRunning) await stopMesh();
    settings = settings.copyWith(deviceName: clean);
    await _settingsService.save(settings);
    _crypto!.updateDeviceName(clean);
    await _audit!.log(
      AuditEventType.settingChanged,
      'Device name changed to "$clean".',
    );
    if (wasRunning) await startMesh(silent: true);
    _notify();
  }

  Future<void> setAutoConnect(bool value) async {
    settings = settings.copyWith(autoConnect: value);
    await _settingsService.save(settings);
    if (meshRunning) {
      await stopMesh();
      await startMesh(silent: true);
    }
    _notify();
  }

  Future<void> setMeshAutoStart(bool value) async {
    settings = settings.copyWith(meshAutoStart: value);
    await _settingsService.save(settings);
    _notify();
  }

  Future<void> setGroupPassphrase(String passphrase) async {
    await _crypto!.updateGroupPassphrase(passphrase);
    await _audit!.log(
      AuditEventType.settingChanged,
      'Mesh group passphrase changed. Peers must use the same key to decrypt new incidents.',
    );
    _notify();
  }

  bool get usesDefaultMeshKey => _crypto?.usesDefaultPassphrase ?? true;

  Future<void> completeOnboarding() async {
    settings = settings.copyWith(onboardingDone: true);
    await _settingsService.save(settings);
    _notify();
  }

  Future<void> completePermissions() async {
    settings = settings.copyWith(permissionsDone: true);
    await _settingsService.save(settings);
    if (!isDemo && settings.meshAutoStart) {
      await startMesh(silent: true);
    }
    _notify();
  }

  Future<void> setResponderPin(String pin) async {
    await _responder!.setPin(pin);
    settings = settings.copyWith(responderPinConfigured: true);
    await _settingsService.save(settings);
    await _audit!.log(
      AuditEventType.settingChanged,
      'Local responder PIN configured.',
    );
    _notify();
  }

  Future<bool> loginResponder(String pin) async {
    final ok = await _responder!.login(pin);
    await _audit!.log(
      ok ? AuditEventType.responderLogin : AuditEventType.responderLoginFailed,
      ok
          ? 'Responder session opened for 20 minutes.'
          : 'Responder login failed.',
      isDemo: settings.demoMode,
    );
    _notify();
    return ok;
  }

  void logoutResponder() {
    _responder?.logout();
    _notify();
  }

  Future<ProtocolSimulationReport> runProtocolSimulation() async {
    final report = await _simulation.run();
    await _audit!.log(
      AuditEventType.simulationRun,
      'Protocol lab ${report.runId}: relay ${report.hopCount} hops, delivered=${report.deliveredToC}, duplicateDrop=${report.duplicateDropped}, tamperReject=${report.tamperedRejected}, expiryReject=${report.expiredRejected}. SIMULATION ONLY — no radios.',
      isDemo: settings.demoMode,
    );
    _notify();
    return report;
  }

  EvacuationResult evacuationRoute({
    Shelter? preferredShelter,
    GeoFix? origin,
  }) {
    final start = origin ?? currentLocation;
    if (start == null) {
      return const EvacuationResult(
        error: 'Acquire a GPS fix or enter coordinates first.',
      );
    }
    return _evacuation.computeRoute(
      origin: start,
      shelters: shelters,
      hazards: activeHazards,
      preferredShelterId: preferredShelter?.id,
    );
  }

  List<ShelterOption> shelterOptions() {
    final origin = currentLocation;
    if (origin == null) {
      return shelters
          .map((shelter) => ShelterOption(
                shelter: shelter,
                distanceMeters: double.nan,
                available: shelter.available,
              ))
          .toList(growable: false);
    }
    return _evacuation.rankShelters(origin: origin, shelters: shelters);
  }

  String buildBlackBoxJson() {
    final payload = {
      'schema': 'resqmesh.blackbox.v1',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'demoMode': settings.demoMode,
      'mesh': {
        'transport': _transport.kind.wire,
        'running': meshRunning,
        'availability': meshStatusMessage,
        'connectedPeers': connectedPeerCount,
      },
      'incidents': incidents.map((e) => e.toMap()).toList(),
      'messages': messages.map((e) => e.toMap()).toList(),
      'shelters': shelters.map((e) => e.toMap()).toList(),
      'events': events.map((e) => e.toMap()).toList(),
      'notice':
          'Local audit export. Radio delivery is best-effort and acknowledgements are not rescue guarantees.',
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<File> exportBlackBox() async {
    await _audit!.log(
      AuditEventType.exportCreated,
      'Black-box export created as JSON.',
      isDemo: settings.demoMode,
    );
    await refreshData();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${directory.path}/resqmesh_blackbox_$timestamp.json');
    await file.writeAsString(buildBlackBoxJson());
    return file;
  }

  void clearNotice() {
    notice = null;
    _notify();
  }

  void setLastMeshAction(String message) {
    lastMeshAction = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshDebounce?.cancel();
    _networkTimer?.cancel();
    _connectivitySub?.cancel();
    unawaited(_mesh?.shutdown());
    unawaited(_db?.close());
    super.dispose();
  }
}
