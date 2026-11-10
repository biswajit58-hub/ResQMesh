import '../../models/enums.dart';
import '../../models/message_record.dart';
import 'app_database.dart';

class MessageRepository {
  MessageRepository(this._db);
  final AppDatabase _db;

  Future<bool> exists(String id) async {
    final rows = await _db.raw.query(
      'messages',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsert(MessageRecord record) async {
    await _db.raw.insert(
      'messages',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MessageRecord?> byId(String id) async {
    final rows = await _db.raw
        .query('messages', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return MessageRecord.fromMap(rows.first);
  }

  Future<List<MessageRecord>> inbox({
    bool demoOnly = false,
    bool includeDemo = true,
    int limit = 200,
  }) async {
    final where = demoOnly
        ? 'is_demo = 1'
        : includeDemo
            ? null
            : 'is_demo = 0';
    final rows = await _db.raw.query(
      'messages',
      where: where,
      orderBy: 'received_at DESC',
      limit: limit,
    );
    return rows.map(MessageRecord.fromMap).toList(growable: false);
  }

  Future<void> updateStatus(String id, MeshDeliveryStatus status) async {
    await _db.raw.update(
      'messages',
      {'status': status.wire},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePayload(String id, String payloadJson) async {
    await _db.raw.update(
      'messages',
      {'payload_json': payloadJson},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> expireOld(int nowMs) async {
    await _db.raw.update(
      'messages',
      {'status': MeshDeliveryStatus.expired.wire},
      where: 'expires_at < ?',
      whereArgs: [nowMs],
    );
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('messages', where: 'is_demo = 1');
  }

  Future<int> countSince(int sinceMs, {required bool demo}) async {
    final rows = await _db.raw.rawQuery(
      'SELECT COUNT(*) AS n FROM messages WHERE received_at >= ? AND is_demo = ?',
      [sinceMs, demo ? 1 : 0],
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }
}
