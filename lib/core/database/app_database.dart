import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

export 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

/// SQLite schema and connection ownership.
///
/// Tests inject the FFI factory and [inMemoryDatabasePath]; Android uses the
/// platform sqflite implementation. All queries are parameterized.
class AppDatabase {
  AppDatabase._(this._db);

  static const int schemaVersion = 1;
  final Database _db;

  Database get raw => _db;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final selectedPath = path ??
        p.join(await selectedFactory.getDatabasesPath(), 'resqmesh.db');
    final db = await selectedFactory.openDatabase(
      selectedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE incidents (
        id TEXT PRIMARY KEY,
        mesh_message_id TEXT,
        kind TEXT NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        people_affected INTEGER NOT NULL DEFAULT 0,
        description TEXT NOT NULL DEFAULT '',
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy_m REAL NOT NULL DEFAULT 1000,
        location_source TEXT NOT NULL,
        location_ts INTEGER NOT NULL,
        location_description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        verification TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        origin_id TEXT NOT NULL,
        origin_name TEXT NOT NULL,
        relay_count INTEGER NOT NULL DEFAULT 0,
        receipt_count INTEGER NOT NULL DEFAULT 0,
        independent_reporters INTEGER NOT NULL DEFAULT 1,
        is_demo INTEGER NOT NULL DEFAULT 0,
        synthetic INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_incidents_created ON incidents(created_at DESC)');
    batch.execute(
        'CREATE INDEX idx_incidents_category ON incidents(category, created_at DESC)');
    batch.execute('CREATE INDEX idx_incidents_demo ON incidents(is_demo)');

    batch.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        origin_id TEXT NOT NULL,
        origin_name TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        priority INTEGER NOT NULL,
        hop_count INTEGER NOT NULL,
        max_hops INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        transport TEXT NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 0,
        envelope_json TEXT NOT NULL,
        payload_json TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_messages_received ON messages(received_at DESC)');
    batch.execute('CREATE INDEX idx_messages_expiry ON messages(expires_at)');

    batch.execute('''
      CREATE TABLE peers (
        endpoint_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        device_id TEXT,
        public_key TEXT,
        first_seen INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        connected INTEGER NOT NULL DEFAULT 0,
        transport TEXT NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 0,
        last_message_at INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE verifications (
        id TEXT PRIMARY KEY,
        incident_id TEXT NOT NULL,
        reporter_id TEXT NOT NULL,
        reporter_name TEXT NOT NULL,
        state TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        is_responder INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_verifications_incident ON verifications(incident_id)');

    batch.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        message_id TEXT,
        peer_id TEXT,
        detail TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_events_created ON events(created_at DESC)');

    batch.execute('''
      CREATE TABLE shelters (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        status TEXT NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 0,
        occupancy INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'local',
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE transmissions (
        id TEXT PRIMARY KEY,
        message_id TEXT NOT NULL,
        endpoint_id TEXT NOT NULL,
        peer_name TEXT NOT NULL,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        attempted_at INTEGER NOT NULL,
        completed_at INTEGER,
        error TEXT,
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_tx_message ON transmissions(message_id, endpoint_id)');
    batch.execute(
        'CREATE INDEX idx_tx_peer ON transmissions(endpoint_id, attempted_at DESC)');

    batch.execute('''
      CREATE TABLE location_history (
        id TEXT PRIMARY KEY,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy_m REAL NOT NULL,
        source TEXT NOT NULL,
        recorded_at INTEGER NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_location_recorded ON location_history(recorded_at DESC)');

    batch.execute('''
      CREATE TABLE known_devices (
        device_id TEXT PRIMARY KEY,
        public_key TEXT NOT NULL,
        display_name TEXT NOT NULL,
        first_seen INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        trust_state TEXT NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> clearDemoData() async {
    await _db.transaction((txn) async {
      for (final table in [
        'incidents',
        'messages',
        'peers',
        'verifications',
        'events',
        'shelters',
        'transmissions',
        'location_history',
        'known_devices',
      ]) {
        await txn.delete(table, where: 'is_demo = 1');
      }
    });
  }

  Future<void> close() => _db.close();
}
