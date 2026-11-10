import '../../models/shelter.dart';
import 'app_database.dart';

class ShelterRepository {
  ShelterRepository(this._db);
  final AppDatabase _db;

  Future<void> upsert(Shelter shelter) async {
    await _db.raw.insert(
      'shelters',
      shelter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Shelter>> list({bool demoOnly = false}) async {
    final rows = await _db.raw.query(
      'shelters',
      where: 'is_demo = ?',
      whereArgs: [demoOnly ? 1 : 0],
      orderBy: 'status, name',
    );
    return rows.map(Shelter.fromMap).toList(growable: false);
  }

  Future<void> deleteDemo() async {
    await _db.raw.delete('shelters', where: 'is_demo = 1');
  }
}
