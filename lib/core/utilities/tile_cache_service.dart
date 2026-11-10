import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Small disk-backed tile cache with provider fallback and a generated offline
/// fallback.
///
/// Online tiles are cached opportunistically; the app never depends on them.
/// A blocked or unavailable provider (for example a 403 from a public tile
/// server) falls through to the next provider and finally to a locally drawn
/// coordinate-grid tile, so markers and routes remain usable offline.
class TileCacheService {
  TileCacheService._();
  static final TileCacheService instance = TileCacheService._();

  /// CARTO's dark basemap is the primary online source. It is designed for dark
  /// interfaces and has stable tile URLs. Attribution is rendered by the map.
  static const primaryTileTemplate =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  /// OSM is the secondary source. If OSM returns 403 on a network, the tile is
  /// rendered locally instead of taking the whole map offline.
  static const fallbackTileTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const userAgent =
      'ResQMesh/1.0 (Android; offline disaster response; com.resqmesh.resqmesh)';

  final Map<String, Future<Uint8List>> _inFlight = {};
  final Map<String, Uint8List> _fallbackMemory = {};
  Directory? _directory;
  DateTime? _networkFailureUntil;
  final http.Client _client = http.Client();

  Future<Uint8List> tile({
    required int z,
    required int x,
    required int y,
    required List<String> urls,
  }) {
    final key = '$z/$x/$y';
    return _inFlight.putIfAbsent(key, () async {
      try {
        return await _loadTile(
          z,
          x,
          y,
          urls.where((u) => u.isNotEmpty).toList(growable: false),
        );
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  Future<Uint8List> _loadTile(int z, int x, int y, List<String> urls) async {
    final dir = await _cacheDirectory();
    final file = File(p.join(dir.path, '$z', '${x}_$y.png'));
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }
    final now = DateTime.now();
    if ((_networkFailureUntil == null || now.isAfter(_networkFailureUntil!)) &&
        urls.isNotEmpty) {
      var attempted = false;
      for (final url in urls) {
        attempted = true;
        try {
          final response = await _client
              .get(
                Uri.parse(url),
                headers: const {
                  'User-Agent': userAgent,
                  'Accept': 'image/png,image/webp,image/*;q=0.8,*/*;q=0.5',
                },
              )
              .timeout(const Duration(seconds: 4));
          if (response.statusCode == 200 &&
              response.bodyBytes.isNotEmpty &&
              _looksLikeImage(response.bodyBytes)) {
            await file.parent.create(recursive: true);
            await file.writeAsBytes(response.bodyBytes, flush: false);
            return response.bodyBytes;
          }
          // A 403/404 from one provider must not disable the next provider.
        } catch (_) {
          // Try the next provider.
        }
      }
      if (attempted) {
        // Both providers failed or were blocked. Avoid hammering public tile
        // servers for every tile; retry after a short cool-down.
        _networkFailureUntil = now.add(const Duration(minutes: 3));
      }
    }
    final key = '$z/$x/$y';
    final cachedFallback = _fallbackMemory[key];
    if (cachedFallback != null) return cachedFallback;
    final generated = await _drawOfflineTile(z, x, y);
    _fallbackMemory[key] = generated;
    return generated;
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 8) return false;
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    return bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  Future<Directory> _cacheDirectory() async {
    if (_directory != null) return _directory!;
    final base = await getTemporaryDirectory();
    final directory = Directory(p.join(base.path, 'resqmesh_map_tiles_v2'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _directory = directory;
    return directory;
  }

  Future<Uint8List> _drawOfflineTile(int z, int x, int y) async {
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final background = Paint()..color = const Color(0xFF0A1727);
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), background);
    final grid = Paint()
      ..color = const Color(0xFF132B42)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final offset = i * 64.0;
      canvas.drawLine(Offset(offset, 0), Offset(offset, size), grid);
      canvas.drawLine(Offset(0, offset), Offset(size, offset), grid);
    }
    final accent = Paint()
      ..color = const Color(0xFF1D4160)
      ..strokeWidth = 1.4;
    canvas.drawLine(const Offset(0, 128), const Offset(256, 128), accent);
    canvas.drawLine(const Offset(128, 0), const Offset(128, 256), accent);

    final label = TextPainter(
      text: const TextSpan(
        text: 'OFFLINE TILE',
        style: TextStyle(
          color: Color(0xFF547393),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset((size - label.width) / 2, (size - label.height) / 2 - 12),
    );
    final coords = TextPainter(
      text: TextSpan(
        text: 'z$z · $x · $y',
        style: const TextStyle(
          color: Color(0xFF35536F),
          fontSize: 9,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    coords.paint(
      canvas,
      Offset((size - coords.width) / 2, (size - coords.height) / 2 + 8),
    );

    final image = await recorder.endRecording().toImage(256, 256);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      return Uint8List.fromList(const [0]);
    }
    return data.buffer.asUint8List();
  }
}
