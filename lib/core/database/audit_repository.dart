import '../../models/audit_event.dart';
import 'app_database.dart';

class AuditRepository {
  AuditRepository(this._db);
  final AppDatabase _db;

  Future<void> insert(AuditEvent event) async {
    await _db.raw.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<AuditEvent>> list({
    bool demoOnly = false,
    bool includeDemo = true,
    int limit = 500,
  }) async {
    final where = demoOnly
        ? 'is_demo = 1'
        : includeDemo
            ? null
            : 'is_demo = 0';
    final rows = await _db.raw.query(
      'events',
      where: where,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(AuditEvent.fromMap).toList(growable: false);
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('events', where: 'is_demo = 1');
  }
}
