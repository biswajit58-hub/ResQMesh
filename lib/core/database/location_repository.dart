import '../../models/enums.dart';
import '../../models/geo_fix.dart';
import 'app_database.dart';

class LocationRepository {
  LocationRepository(this._db);
  final AppDatabase _db;

  Future<void> save(String id, GeoFix fix, {bool isDemo = false}) async {
    final map = fix.toJson();
    await _db.raw.insert(
      'location_history',
      {
        'id': id,
        'lat': map['lat'],
        'lng': map['lng'],
        'accuracy_m': map['acc'],
        'source': fix.source.wire,
        'recorded_at': fix.capturedAt.toUtc().millisecondsSinceEpoch,
        'description': fix.description,
        'is_demo': isDemo ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GeoFix?> latest({bool isDemo = false}) async {
    final rows = await _db.raw.query(
      'location_history',
      where: 'is_demo = ?',
      whereArgs: [isDemo ? 1 : 0],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GeoFix(
      latitude: (row['lat'] as num).toDouble(),
      longitude: (row['lng'] as num).toDouble(),
      accuracyMeters: (row['accuracy_m'] as num?)?.toDouble() ?? 1000,
      source: LocationSource.fromWire(row['source'] as String?),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['recorded_at'] as num).toInt(),
        isUtc: true,
      ),
      description: row['description'] as String? ?? '',
    );
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('location_history', where: 'is_demo = 1');
  }
}
