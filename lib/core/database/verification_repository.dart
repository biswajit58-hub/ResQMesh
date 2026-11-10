import '../../models/verification_vote.dart';
import 'app_database.dart';

class VerificationRepository {
  VerificationRepository(this._db);
  final AppDatabase _db;

  Future<void> insert(VerificationVote vote) async {
    await _db.raw.insert(
      'verifications',
      vote.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VerificationVote>> forIncident(String incidentId) async {
    final rows = await _db.raw.query(
      'verifications',
      where: 'incident_id = ?',
      whereArgs: [incidentId],
      orderBy: 'created_at DESC',
    );
    return rows.map(VerificationVote.fromMap).toList(growable: false);
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('verifications', where: 'is_demo = 1');
  }
}
