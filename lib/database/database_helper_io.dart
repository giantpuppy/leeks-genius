import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('paiqi_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        theater TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE performances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        show_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        seat TEXT,
        price REAL,
        created_at TEXT,
        FOREIGN KEY (show_id) REFERENCES shows (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cast_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        performance_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        actor_name TEXT NOT NULL,
        created_at TEXT,
        FOREIGN KEY (performance_id) REFERENCES performances (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE actors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        note TEXT,
        created_at TEXT
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // ========== Shows ==========
  Future<Show> createShow(Show show) async {
    final db = await instance.database;
    final id = await db.insert('shows', show.toMap());
    return show.copyWith(id: id);
  }

  Future<List<Show>> getAllShows() async {
    final db = await instance.database;
    final result = await db.query('shows', orderBy: 'created_at DESC');
    return result.map((json) => Show.fromMap(json)).toList();
  }

  Future<Show?> getShowById(int id) async {
    final db = await instance.database;
    final maps = await db.query('shows', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Show.fromMap(maps.first);
    return null;
  }

  Future<int> updateShow(Show show) async {
    final db = await instance.database;
    return db.update('shows', show.toMap(), where: 'id = ?', whereArgs: [show.id]);
  }

  Future<int> deleteShow(int id) async {
    final db = await instance.database;
    return db.delete('shows', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Performances ==========
  Future<Performance> createPerformance(Performance perf) async {
    final db = await instance.database;
    final id = await db.insert('performances', perf.toMap());
    return perf.copyWith(id: id);
  }

  Future<List<Performance>> getAllPerformances() async {
    final db = await instance.database;
    final result = await db.query('performances', orderBy: 'date ASC, time ASC');
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<List<Performance>> getPerformancesByDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'performances',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'time ASC',
    );
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<List<Performance>> getPerformancesByShowId(int showId) async {
    final db = await instance.database;
    final result = await db.query(
      'performances',
      where: 'show_id = ?',
      whereArgs: [showId],
      orderBy: 'date ASC, time ASC',
    );
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<List<Performance>> getPerformancesByDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    final result = await db.query(
      'performances',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, time ASC',
    );
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<Performance?> getPerformanceById(int id) async {
    final db = await instance.database;
    final maps = await db.query('performances', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Performance.fromMap(maps.first);
    return null;
  }

  Future<int> updatePerformance(Performance perf) async {
    final db = await instance.database;
    return db.update('performances', perf.toMap(), where: 'id = ?', whereArgs: [perf.id]);
  }

  Future<int> deletePerformance(int id) async {
    final db = await instance.database;
    return db.delete('performances', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Cast Members ==========
  Future<CastMember> createCastMember(CastMember cast) async {
    final db = await instance.database;
    final id = await db.insert('cast_members', cast.toMap());
    return cast.copyWith(id: id);
  }

  Future<List<CastMember>> getCastMembersByPerformanceId(int performanceId) async {
    final db = await instance.database;
    final result = await db.query(
      'cast_members',
      where: 'performance_id = ?',
      whereArgs: [performanceId],
    );
    return result.map((json) => CastMember.fromMap(json)).toList();
  }

  Future<int> deleteCastMembersByPerformanceId(int performanceId) async {
    final db = await instance.database;
    return db.delete('cast_members', where: 'performance_id = ?', whereArgs: [performanceId]);
  }

  // ========== Actors ==========
  Future<Actor> createActor(Actor actor) async {
    final db = await instance.database;
    try {
      final id = await db.insert('actors', actor.toMap());
      return actor.copyWith(id: id);
    } catch (e) {
      final existing = await getActorByName(actor.name);
      return existing ?? actor;
    }
  }

  Future<List<Actor>> getAllActors() async {
    final db = await instance.database;
    final result = await db.query('actors', orderBy: 'name ASC');
    return result.map((json) => Actor.fromMap(json)).toList();
  }

  Future<Actor?> getActorByName(String name) async {
    final db = await instance.database;
    final maps = await db.query('actors', where: 'name = ?', whereArgs: [name]);
    if (maps.isNotEmpty) return Actor.fromMap(maps.first);
    return null;
  }

  Future<int> deleteActor(int id) async {
    final db = await instance.database;
    return db.delete('actors', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Complex Queries ==========
  Future<List<Map<String, dynamic>>> getPerformancesWithShowByDate(String date) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      WHERE p.date = ?
      ORDER BY p.time ASC
    ''', [date]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllPerformancesWithShow() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      ORDER BY p.date ASC, p.time ASC
    ''');
    return result;
  }

  Future<Map<String, dynamic>?> getPerformanceDetail(int performanceId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      WHERE p.id = ?
    ''', [performanceId]);
    if (result.isNotEmpty) return result.first;
    return null;
  }
}
