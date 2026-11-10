import '../../models/incident.dart';
import 'app_database.dart';

class IncidentRepository {
  IncidentRepository(this._db);
  final AppDatabase _db;

  Future<void> upsert(Incident incident) async {
    await _db.raw.insert(
      'incidents',
      incident.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Incident?> byId(String id) async {
    final rows =
        await _db.raw.query('incidents', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Incident.fromMap(rows.first);
  }

  Future<List<Incident>> list({
    bool? demoOnly,
    bool includeDemo = true,
    bool activeOnly = false,
    int limit = 300,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (demoOnly == true) {
      clauses.add('is_demo = 1');
    } else if (!includeDemo) {
      clauses.add('is_demo = 0');
    }
    if (activeOnly) {
      clauses.add("status NOT IN ('resolved', 'closed')");
      clauses.add('verification != ?');
      args.add('expired');
    }
    final where = clauses.isEmpty ? null : clauses.join(' AND ');
    final rows = await _db.raw.query(
      'incidents',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(Incident.fromMap).toList(growable: false);
  }

  Future<List<Incident>> nearbyCandidates({
    required String category,
    required int sinceMs,
  }) async {
    final rows = await _db.raw.query(
      'incidents',
      where: 'category = ? AND created_at >= ?',
      whereArgs: [category, sinceMs],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return rows.map(Incident.fromMap).toList(growable: false);
  }

  Future<void> updateStatus(String id, String status, int updatedAtMs) async {
    await _db.raw.update(
      'incidents',
      {'status': status, 'updated_at': updatedAtMs},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateVerification(
    String id,
    String verification,
    int independentReporters,
    int updatedAtMs,
  ) async {
    await _db.raw.update(
      'incidents',
      {
        'verification': verification,
        'independent_reporters': independentReporters,
        'updated_at': updatedAtMs,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementRelay(String id) async {
    await _db.raw.rawUpdate(
      'UPDATE incidents SET relay_count = relay_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> incrementReceipt(String id) async {
    await _db.raw.rawUpdate(
      'UPDATE incidents SET receipt_count = receipt_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<int> countActive({bool demoOnly = false}) async {
    final rows = await _db.raw.rawQuery(
      "SELECT COUNT(*) AS n FROM incidents WHERE status NOT IN ('resolved','closed') AND verification != 'expired' AND is_demo = ?",
      [demoOnly ? 1 : 0],
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<void> expireOld(int nowMs) async {
    await _db.raw.update(
      'incidents',
      {'verification': 'expired'},
      where: "expires_at < ? AND verification != 'expired'",
      whereArgs: [nowMs],
    );
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('incidents', where: 'is_demo = 1');
  }
}
