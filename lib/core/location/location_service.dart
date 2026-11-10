import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../models/enums.dart';
import '../../models/geo_fix.dart';

class LocationAttempt {
  const LocationAttempt({
    required this.fix,
    required this.message,
    required this.permissionDenied,
    required this.serviceDisabled,
    required this.usedFallback,
  });

  final GeoFix? fix;
  final String message;
  final bool permissionDenied;
  final bool serviceDisabled;
  final bool usedFallback;
}

/// Thin GPS wrapper that never invents a live fix.
///
/// If GPS is unavailable this service may return a cached [GeoFix] with
/// [LocationSource.lastKnown] and its original timestamp.
class LocationService {
  LocationService({GeolocatorPlatform? geolocator})
      : _geolocator = geolocator ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _geolocator;

  Future<bool> ensurePermission() async {
    try {
      var permission = await _geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<LocationAttempt> acquire({
    GeoFix? cached,
    bool requestPermission = true,
  }) async {
    bool serviceEnabled;
    try {
      serviceEnabled = await _geolocator.isLocationServiceEnabled();
    } catch (error) {
      return LocationAttempt(
        fix: cached == null ? null : _asLastKnown(cached),
        message: 'GPS service check failed. Using any saved location.',
        permissionDenied: false,
        serviceDisabled: true,
        usedFallback: cached != null,
      );
    }
    if (!serviceEnabled) {
      return LocationAttempt(
        fix: cached == null ? null : _asLastKnown(cached),
        message: 'Location services are off. Enable GPS or enter a location manually.',
        permissionDenied: false,
        serviceDisabled: true,
        usedFallback: cached != null,
      );
    }

    var permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await _geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return LocationAttempt(
        fix: cached == null ? null : _asLastKnown(cached),
        message: permission == LocationPermission.deniedForever
            ? 'Location permission is permanently denied. Enter coordinates manually.'
            : 'Location permission was not granted. Enter coordinates manually.',
        permissionDenied: true,
        serviceDisabled: false,
        usedFallback: cached != null,
      );
    }

    try {
      final position = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 14),
        ),
      );
      return LocationAttempt(
        fix: GeoFix(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          source: LocationSource.gps,
          capturedAt: position.timestamp.toUtc(),
        ),
        message: 'GPS fix acquired (±${position.accuracy.round()} m).',
        permissionDenied: false,
        serviceDisabled: false,
        usedFallback: false,
      );
    } on TimeoutException {
      return LocationAttempt(
        fix: cached == null ? null : _asLastKnown(cached),
        message: 'GPS timed out. Using the last saved location if available.',
        permissionDenied: false,
        serviceDisabled: false,
        usedFallback: cached != null,
      );
    } catch (error) {
      return LocationAttempt(
        fix: cached == null ? null : _asLastKnown(cached),
        message: 'Could not obtain GPS: $error',
        permissionDenied: false,
        serviceDisabled: false,
        usedFallback: cached != null,
      );
    }
  }

  GeoFix _asLastKnown(GeoFix cached) => cached.copyWith(
        source: LocationSource.lastKnown,
      );
}
