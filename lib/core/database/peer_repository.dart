import '../../models/peer_device.dart';
import 'app_database.dart';

class PeerRepository {
  PeerRepository(this._db);
  final AppDatabase _db;

  Future<void> upsert(PeerDevice peer) async {
    await _db.raw.insert(
      'peers',
      peer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PeerDevice>> list({bool demoOnly = false}) async {
    final rows = await _db.raw.query(
      'peers',
      where: 'is_demo = ?',
      whereArgs: [demoOnly ? 1 : 0],
      orderBy: 'connected DESC, last_seen DESC',
    );
    return rows.map(PeerDevice.fromMap).toList(growable: false);
  }

  Future<void> setConnected(String endpointId, bool connected) async {
    await _db.raw.update(
      'peers',
      {
        'connected': connected ? 1 : 0,
        'last_seen': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'endpoint_id = ?',
      whereArgs: [endpointId],
    );
  }

  Future<void> markAllDisconnected() async {
    await _db.raw.update('peers', {'connected': 0});
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('peers', where: 'is_demo = 1');
  }
}
