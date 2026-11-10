import '../../models/known_device.dart';
import 'app_database.dart';

class KnownDeviceRepository {
  KnownDeviceRepository(this._db);
  final AppDatabase _db;

  Future<KnownDevice?> byId(String id) async {
    final rows = await _db.raw.query(
      'known_devices',
      where: 'device_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KnownDevice.fromMap(rows.first);
  }

  Future<void> upsert(KnownDevice device) async {
    await _db.raw.insert(
      'known_devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<KnownDevice>> list({bool demoOnly = false}) async {
    final rows = await _db.raw.query(
      'known_devices',
      where: 'is_demo = ?',
      whereArgs: [demoOnly ? 1 : 0],
      orderBy: 'last_seen DESC',
    );
    return rows.map(KnownDevice.fromMap).toList(growable: false);
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('known_devices', where: 'is_demo = 1');
  }
}
