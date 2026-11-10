import 'package:url_launcher/url_launcher.dart';

/// User-initiated links into Google Maps.
///
/// These are external links, not an embedded basemap. They require the Google
/// Maps app or a browser and may require internet. The offline ResQMesh map is
/// never replaced or made dependent on these links.
class MapLinks {
  const MapLinks._();

  static Uri searchUri(double latitude, double longitude) => Uri.https(
        'www.google.com',
        '/maps/search/',
        {
          'api': '1',
          'query': '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
        },
      );

  static Uri directionsUri(
    double latitude,
    double longitude, {
    String travelMode = 'walking',
  }) =>
      Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'destination':
              '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
          'travelmode': travelMode,
        },
      );

  static Future<bool> openSearch(double latitude, double longitude) =>
      _open(searchUri(latitude, longitude));

  static Future<bool> openDirections(
    double latitude,
    double longitude, {
    String travelMode = 'walking',
  }) =>
      _open(directionsUri(latitude, longitude, travelMode: travelMode));

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}