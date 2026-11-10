import '../../models/enums.dart';
import 'app_database.dart';

class TransmissionRecord {
  const TransmissionRecord({
    required this.id,
    required this.messageId,
    required this.endpointId,
    required this.peerName,
    required this.status,
    required this.attemptedAt,
    this.completedAt,
    this.error,
    this.isDemo = false,
  });

  final String id;
  final String messageId;
  final String endpointId;
  final String peerName;
  final String status;
  final DateTime attemptedAt;
  final DateTime? completedAt;
  final String? error;
  final bool isDemo;

  Map<String, Object?> toMap() => {
        'id': id,
        'message_id': messageId,
        'endpoint_id': endpointId,
        'peer_name': peerName,
        'direction': 'out',
        'status': status,
        'attempted_at': attemptedAt.toUtc().millisecondsSinceEpoch,
        'completed_at': completedAt?.toUtc().millisecondsSinceEpoch,
        'error': error,
        'is_demo': isDemo ? 1 : 0,
      };
}

class TransmissionRepository {
  TransmissionRepository(this._db);
  final AppDatabase _db;

  Future<void> record(TransmissionRecord record) async {
    await _db.raw.insert(
      'transmissions',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> hasTransmitted(String messageId, String endpointId) async {
    final rows = await _db.raw.query(
      'transmissions',
      columns: ['id'],
      where: 'message_id = ? AND endpoint_id = ? AND status = ?',
      whereArgs: [messageId, endpointId, 'sent'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> latestStatus(String messageId) async {
    final rows = await _db.raw.query(
      'transmissions',
      columns: ['status'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      orderBy: 'attempted_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['status'] as String?;
  }

  Future<int> countForMessage(String messageId) async {
    final rows = await _db.raw.rawQuery(
      'SELECT COUNT(*) AS n FROM transmissions WHERE message_id = ? AND status = ?',
      [messageId, 'sent'],
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('transmissions', where: 'is_demo = 1');
  }

  static String queued() => MeshDeliveryStatus.queued.wire;
}
