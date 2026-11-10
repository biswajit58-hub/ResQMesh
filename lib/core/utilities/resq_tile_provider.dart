import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/utilities/tile_cache_service.dart';

class ResqTileProvider extends TileProvider {
  ResqTileProvider() : super();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final primary = getTileUrl(coordinates, options);
    final fallback = _expandTemplate(
      TileCacheService.fallbackTileTemplate,
      coordinates,
    );
    return ResqTileImage(
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
      primaryUrl: primary,
      fallbackUrl: fallback,
    );
  }

  String _expandTemplate(String template, TileCoordinates coordinates) {
    return template
        .replaceAll('{z}', '${coordinates.z}')
        .replaceAll('{x}', '${coordinates.x}')
        .replaceAll('{y}', '${coordinates.y}');
  }
}

class ResqTileImage extends ImageProvider<ResqTileImage> {
  const ResqTileImage({
    required this.z,
    required this.x,
    required this.y,
    required this.primaryUrl,
    required this.fallbackUrl,
  });

  final int z;
  final int x;
  final int y;
  final String primaryUrl;
  final String fallbackUrl;

  @override
  Future<ResqTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ResqTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    ResqTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1,
      debugLabel: 'ResQMesh tile $z/$x/$y',
    );
  }

  Future<ui.Codec> _loadAsync(
    ResqTileImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await TileCacheService.instance.tile(
      z: key.z,
      x: key.x,
      y: key.y,
      urls: [key.primaryUrl, key.fallbackUrl],
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is ResqTileImage &&
      other.z == z &&
      other.x == x &&
      other.y == y &&
      other.primaryUrl == primaryUrl &&
      other.fallbackUrl == fallbackUrl;

  @override
  int get hashCode => Object.hash(z, x, y, primaryUrl, fallbackUrl);
}
