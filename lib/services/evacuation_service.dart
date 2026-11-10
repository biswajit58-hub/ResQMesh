import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/evacuation_route.dart';
import '../models/geo_fix.dart';
import '../models/incident.dart';
import '../models/shelter.dart';

class ShelterOption {
  const ShelterOption({
    required this.shelter,
    required this.distanceMeters,
    required this.available,
  });

  final Shelter shelter;
  final double distanceMeters;
  final int available;
}

/// Offline grid-based A* evacuation guidance.
///
/// This is an advisory path over locally known hazard points, NOT a verified
/// road network and NOT a safety guarantee. The UI must always show the
/// uncertainty warnings produced here.
class EvacuationService {
  const EvacuationService({this.maxGridCells = 72});

  final int maxGridCells;

  List<ShelterOption> rankShelters({
    required GeoFix origin,
    required List<Shelter> shelters,
    int? maxResults,
  }) {
    final options = shelters
        .map((shelter) => ShelterOption(
              shelter: shelter,
              distanceMeters: origin.distanceMetersTo(GeoFix(
                latitude: shelter.latitude,
                longitude: shelter.longitude,
                accuracyMeters: 50,
                source: LocationSource.computed,
                capturedAt: DateTime.now().toUtc(),
              )),
              available: shelter.available,
            ))
        .toList(growable: false);
    options.sort((a, b) {
      final aOpen = a.shelter.hasCapacity;
      final bOpen = b.shelter.hasCapacity;
      if (aOpen != bOpen) return aOpen ? -1 : 1;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    if (maxResults == null) return options;
    return options.take(maxResults).toList(growable: false);
  }

  EvacuationResult computeRoute({
    required GeoFix origin,
    required List<Shelter> shelters,
    required List<Incident> hazards,
    DateTime? now,
    String? preferredShelterId,
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    if (!origin.isValid) {
      return const EvacuationResult(
          error: 'Your origin location is invalid.');
    }
    if (shelters.isEmpty) {
      return const EvacuationResult(
        error:
            'No shelter records are cached. Add or import shelters before routing.',
      );
    }
    var candidates = rankShelters(origin: origin, shelters: shelters);
    if (preferredShelterId != null) {
      final preferred = candidates
          .where((e) => e.shelter.id == preferredShelterId)
          .toList(growable: false);
      if (preferred.isNotEmpty) {
        candidates = [
          preferred.first,
          ...candidates.where((e) => e.shelter.id != preferredShelterId),
        ];
      }
    }
    Object? lastError;
    for (final option in candidates.take(4)) {
      final result = _routeTo(
        origin: origin,
        shelter: option.shelter,
        hazards: hazards,
        now: clock,
      );
      if (result.isSuccess) return result;
      lastError = result.error;
    }
    return EvacuationResult(
      error:
          'No advisory path found around ${hazards.length} local hazard point(s). $lastError',
    );
  }

  EvacuationResult _routeTo({
    required GeoFix origin,
    required Shelter shelter,
    required List<Incident> hazards,
    required DateTime now,
  }) {
    final destination = GeoFix(
      latitude: shelter.latitude,
      longitude: shelter.longitude,
      accuracyMeters: 50,
      source: LocationSource.computed,
      capturedAt: now,
      description: shelter.name,
    );
    final directDistance = origin.distanceMetersTo(destination);
    if (directDistance > 25000) {
      return const EvacuationResult(
        error:
            'Shelter is more than 25 km away; offline grid routing is limited to 25 km.',
      );
    }

    final minLat = math.min(origin.latitude, destination.latitude);
    final maxLat = math.max(origin.latitude, destination.latitude);
    final minLng = math.min(origin.longitude, destination.longitude);
    final maxLng = math.max(origin.longitude, destination.longitude);
    final latPad = 1400 / 111320;
    final lngPad =
        1400 / (111320 * math.max(0.2, math.cos(origin.latitude * math.pi / 180)));
    final south = minLat - latPad;
    final north = maxLat + latPad;
    final west = minLng - lngPad;
    final east = maxLng + lngPad;
    final latSpan = north - south;
    final lngSpan = east - west;
    final maxSpan = math.max(latSpan, lngSpan);
    final step = math.max(maxSpan / maxGridCells, 0.0008);
    final rows = math.min(maxGridCells, (latSpan / step).ceil() + 1);
    final cols = math.min(maxGridCells, (lngSpan / step).ceil() + 1);
    if (rows < 2 || cols < 2) {
      return const EvacuationResult(error: 'Route area is too small.');
    }

    final blocked = <int>{};
    final penalty = <int, double>{};
    for (final hazard in hazards) {
      if (hazard.isExpired) continue;
      final radius = _blockRadius(hazard);
      if (radius <= 0) continue;
      final latRadius = radius / 111320;
      final lngRadius =
          radius / (111320 * math.max(0.2, math.cos(hazard.location.latitude * math.pi / 180)));
      final rMin = ((hazard.location.latitude - latRadius - south) / step)
          .floor()
          .clamp(0, rows - 1);
      final rMax = ((hazard.location.latitude + latRadius - south) / step)
          .ceil()
          .clamp(0, rows - 1);
      final cMin = ((hazard.location.longitude - lngRadius - west) / step)
          .floor()
          .clamp(0, cols - 1);
      final cMax = ((hazard.location.longitude + lngRadius - west) / step)
          .ceil()
          .clamp(0, cols - 1);
      for (var r = rMin; r <= rMax; r++) {
        for (var c = cMin; c <= cMax; c++) {
          final p = _pointFor(r, c, south, west, step);
          final distance = p.distanceMetersTo(hazard.location);
          if (distance <= radius) {
            if (_isBlocking(hazard)) {
              blocked.add(r * cols + c);
            } else {
              final existing = penalty[r * cols + c] ?? 0;
              penalty[r * cols + c] = math.max(existing, 1 + radius / 250);
            }
          } else if (distance <= radius * 1.8) {
            final existing = penalty[r * cols + c] ?? 0;
            penalty[r * cols + c] = math.max(existing, 0.5 + radius / 900);
          }
        }
      }
    }

    var startR = ((origin.latitude - south) / step).round().clamp(0, rows - 1);
    var startC = ((origin.longitude - west) / step).round().clamp(0, cols - 1);
    var goalR =
        ((destination.latitude - south) / step).round().clamp(0, rows - 1);
    var goalC =
        ((destination.longitude - west) / step).round().clamp(0, cols - 1);
    final startCell = _nearestFree(startR, startC, rows, cols, blocked);
    final goalCell = _nearestFree(goalR, goalC, rows, cols, blocked);
    if (startCell == null || goalCell == null) {
      return const EvacuationResult(
        error:
            'Origin or shelter falls inside a locally reported hazard area. Choose another shelter or use local guidance.',
      );
    }
    startR = startCell.$1;
    startC = startCell.$2;
    goalR = goalCell.$1;
    goalC = goalCell.$2;

    final startIndex = startR * cols + startC;
    final goalIndex = goalR * cols + goalC;
    final gScore = <int, double>{startIndex: 0};
    final cameFrom = <int, int>{};
    final closed = <int>{};
    final open = HeapPriorityQueue<_OpenNode>((a, b) {
      final f = a.f.compareTo(b.f);
      if (f != 0) return f;
      return a.index.compareTo(b.index);
    });
    open.add(_OpenNode(
      index: startIndex,
      f: _heuristic(startR, startC, goalR, goalC),
    ));

    while (open.isNotEmpty) {
      final current = open.removeFirst();
      if (current.index == goalIndex) {
        final path = _reconstruct(cameFrom, current.index);
        final points = <GeoFix>[];
        for (final index in path) {
          final r = index ~/ cols;
          final c = index % cols;
          points.add(_pointFor(r, c, south, west, step));
        }
        final routePoints = <GeoFix>[origin, ...points.skip(1), destination];
        var distance = 0.0;
        for (var i = 1; i < routePoints.length; i++) {
          distance += routePoints[i - 1].distanceMetersTo(routePoints[i]);
        }
        final warnings = _warnings(
          origin: origin,
          shelter: shelter,
          hazards: hazards,
          now: now,
        );
        final newestHazard = hazards.isEmpty
            ? null
            : hazards
                .map((e) => e.updatedAt.toUtc())
                .reduce((a, b) => a.isAfter(b) ? a : b);
        final dataAge = newestHazard == null
            ? 0
            : math.max(0, now.difference(newestHazard).inMinutes);
        return EvacuationResult(
          route: EvacuationRoute(
            id: const Uuid().v4(),
            origin: origin,
            shelter: shelter,
            waypoints: routePoints,
            distanceMeters: distance,
            estimatedMinutes: math.max(1, (distance / 70).ceil()),
            warnings: warnings,
            generatedAt: now,
            hazardsConsidered: hazards.length,
            dataAgeMinutes: dataAge,
          ),
        );
      }
      if (closed.contains(current.index)) continue;
      closed.add(current.index);
      final r = current.index ~/ cols;
      final c = current.index % cols;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          final neighbor = nr * cols + nc;
          if (blocked.contains(neighbor)) continue;
          if (dr != 0 && dc != 0) {
            if (blocked.contains(r * cols + nc) ||
                blocked.contains(nr * cols + c)) {
              continue;
            }
          }
          final base = dr != 0 && dc != 0 ? math.sqrt2 : 1.0;
          final stepCost = base * (penalty[neighbor] ?? 1.0);
          final tentative = (gScore[current.index] ?? double.infinity) + stepCost;
          if (tentative < (gScore[neighbor] ?? double.infinity)) {
            gScore[neighbor] = tentative;
            cameFrom[neighbor] = current.index;
            final h = _heuristic(nr, nc, goalR, goalC);
            open.add(_OpenNode(index: neighbor, f: tentative + h));
          }
        }
      }
    }
    return const EvacuationResult(
      error:
          'All advisory paths are blocked by local hazard reports. Do not attempt a route without local guidance.',
    );
  }

  (int, int)? _nearestFree(
    int r,
    int c,
    int rows,
    int cols,
    Set<int> blocked,
  ) {
    if (!blocked.contains(r * cols + c)) return (r, c);
    for (var radius = 1; radius <= 8; radius++) {
      for (var dr = -radius; dr <= radius; dr++) {
        for (var dc = -radius; dc <= radius; dc++) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          if (!blocked.contains(nr * cols + nc)) return (nr, nc);
        }
      }
    }
    return null;
  }

  double _heuristic(int r, int c, int gr, int gc) {
    final dr = (r - gr).abs();
    final dc = (c - gc).abs();
    return (dr + dc) + (math.sqrt2 - 2) * math.min(dr, dc);
  }

  List<int> _reconstruct(Map<int, int> cameFrom, int current) {
    final path = <int>[current];
    var cursor = current;
    while (cameFrom.containsKey(cursor)) {
      cursor = cameFrom[cursor]!;
      path.add(cursor);
    }
    return path.reversed.toList(growable: false);
  }

  GeoFix _pointFor(int r, int c, double south, double west, double step) =>
      GeoFix(
        latitude: south + r * step,
        longitude: west + c * step,
        accuracyMeters: 150,
        source: LocationSource.computed,
        capturedAt: DateTime.now().toUtc(),
        description: 'Computed grid waypoint',
      );

  double _blockRadius(Incident incident) {
    final disputed =
        incident.verification == VerificationState.disputed ? 0.55 : 1.0;
    final radius = switch (incident.category) {
      EmergencyCategory.flood => 420.0,
      EmergencyCategory.blockedRoad => 280.0,
      EmergencyCategory.landslide => 360.0,
      EmergencyCategory.collapsedBuilding => 240.0,
      EmergencyCategory.fire => 220.0,
      EmergencyCategory.infrastructure => 180.0,
      EmergencyCategory.earthquake => 300.0,
      EmergencyCategory.cyclone => 350.0,
      EmergencyCategory.medical => 0.0,
      EmergencyCategory.other => 120.0,
    };
    final severityScale = switch (incident.severity) {
      Severity.critical => 1.2,
      Severity.high => 1.0,
      Severity.moderate => 0.65,
      Severity.low => 0.4,
    };
    return radius * severityScale * disputed;
  }

  bool _isBlocking(Incident incident) {
    if (incident.category == EmergencyCategory.blockedRoad ||
        incident.category == EmergencyCategory.collapsedBuilding ||
        incident.category == EmergencyCategory.landslide) {
      return incident.severity.weight >= 2;
    }
    if (incident.category == EmergencyCategory.flood) {
      return incident.severity.weight >= 3;
    }
    return incident.severity == Severity.critical;
  }

  List<String> _warnings({
    required GeoFix origin,
    required Shelter shelter,
    required List<Incident> hazards,
    required DateTime now,
  }) {
    final warnings = <String>[
      'ADVISORY ROUTE ONLY — local reports may be incomplete, stale, or wrong. Conditions can change. This is not a guarantee of safety.',
    ];
    if (hazards.isEmpty) {
      warnings.add(
          'No local hazard points are available. The route cannot avoid unknown hazards.');
    } else {
      final unverified = hazards
          .where((e) => e.verification == VerificationState.unverified)
          .length;
      if (unverified > 0) {
        warnings.add(
            '$unverified hazard point(s) are unverified and may be inaccurate.');
      }
      final disputed = hazards
          .where((e) => e.verification == VerificationState.disputed)
          .length;
      if (disputed > 0) {
        warnings.add(
            '$disputed hazard point(s) are disputed; buffer radius reduced but risk remains.');
      }
    }
    if (shelter.isDemo) {
      warnings.add(
          'SHELTER RECORD IS SYNTHETIC DEMO DATA. Do not use for a real evacuation.');
    }
    if (shelter.status != ShelterStatus.open) {
      warnings.add(
          'Shelter status is ${shelter.status.wire}; confirm capacity before travelling.');
    }
    if (shelter.updatedAt.toUtc().isBefore(now.subtract(const Duration(hours: 6)))) {
      warnings.add(
          'Shelter record is more than 6 hours old and may be outdated.');
    }
    if (origin.source == LocationSource.lastKnown ||
        origin.source == LocationSource.computed) {
      warnings.add(
          'Start point is not a live GPS fix; verify your location before moving.');
    }
    return warnings;
  }
}

class _OpenNode {
  const _OpenNode({required this.index, required this.f});
  final int index;
  final double f;
}
