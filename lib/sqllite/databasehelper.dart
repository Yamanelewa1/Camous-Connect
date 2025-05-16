import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'localevent.dart';
import 'localstudygroup.dart';
import 'localclass.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('campus_connect.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        creatorId TEXT NOT NULL,
        dateTime INTEGER NOT NULL,
        description TEXT,
        reminders TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE study_groups (
        id TEXT PRIMARY KEY,
        topic TEXT,
        session_time TEXT,
        created_at TEXT,
        creator_id TEXT,
        rsvps TEXT,
        synced INTEGER,
        class_id TEXT,
        firestore_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE local_classes (
        id TEXT PRIMARY KEY,
        name TEXT,
        professor TEXT,
        room TEXT,
        materials TEXT,
        schedule TEXT,
        userId TEXT
      )
    ''');
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE study_groups (
          id TEXT PRIMARY KEY,
          topic TEXT,
          session_time TEXT,
          created_at TEXT,
          creator_id TEXT,
          rsvps TEXT,
          synced INTEGER,
          class_id TEXT,
          firestore_id TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE local_classes (
          id TEXT PRIMARY KEY,
          name TEXT,
          professor TEXT,
          room TEXT,
          materials TEXT,
          schedule TEXT,
          userId TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE study_groups ADD COLUMN firestore_id TEXT
      ''');
    }
  }

  // EVENTS
  Future<void> insertEvent(LocalEvent e) async {
    final db = await database;
    await db.insert(
      'events',
      {
        'id': e.id,
        'title': e.title,
        'creatorId': e.creatorId,
        'dateTime': e.date.millisecondsSinceEpoch,
        'description': e.description,
        'reminders': jsonEncode(e.userReminders),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateEvent(LocalEvent e) async {
    final db = await database;
    await db.update(
      'events',
      {
        'title': e.title,
        'creatorId': e.creatorId,
        'dateTime': e.date.millisecondsSinceEpoch,
        'description': e.description,
        'reminders': jsonEncode(e.userReminders),
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<List<LocalEvent>> fetchEvents() async {
    final db = await database;
    final rows = await db.query('events', orderBy: 'dateTime ASC');

    return rows.map((row) {
      final reminders = jsonDecode(row['reminders'] as String? ?? '{}') as Map<String, dynamic>;
      final remMap = <String, int>{};
      reminders.forEach((k, v) => remMap[k] = v is int ? v : int.tryParse(v.toString()) ?? 0);

      return LocalEvent(
        id: row['id'] as String,
        title: row['title'] as String,
        creatorId: row['creatorId'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(row['dateTime'] as int),
        description: row['description'] as String? ?? '',
        userReminders: remMap,
      );
    }).toList();
  }

  Future<void> deleteEvent(String id) async {
    final db = await database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllEvents() async {
    final db = await database;
    await db.delete('events');
  }

  // STUDY GROUPS
  Future<void> insertStudyGroup(LocalStudyGroup group) async {
    final db = await database;
    await db.insert('study_groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStudyGroup(LocalStudyGroup group) async {
    final db = await database;
    await db.update('study_groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<List<LocalStudyGroup>> fetchStudyGroups() async {
    final db = await database;
    final result = await db.query('study_groups');
    return result.map((e) => LocalStudyGroup.fromMap(e)).toList();
  }

  Future<void> deleteStudyGroupByFirestoreId(String firestoreId) async {
    final db = await database;
    await db.delete('study_groups', where: 'firestore_id = ?', whereArgs: [firestoreId]);
  }

  Future<void> markStudyGroupAsSynced(String id) async {
    final db = await database;
    await db.update('study_groups', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllStudyGroups() async {
    final db = await database;
    await db.delete('study_groups');
  }

  // LOCAL CLASSES
  Future<void> insertClass(LocalClass cls) async {
    final db = await database;
    await db.insert(
      'local_classes',
      cls.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocalClass>> fetchUserClasses(String userId) async {
    final db = await database;
    final rows = await db.query('local_classes', where: 'userId = ?', whereArgs: [userId]);
    return rows.map((row) => LocalClass.fromMap(row)).toList();
  }

  Future<void> clearLocalClasses(String userId) async {
    final db = await database;
    await db.delete('local_classes', where: 'userId = ?', whereArgs: [userId]);
  }

  Future<void> deleteAssignedClassOnly(String userId, String classId) async {
    final db = await database;
    await db.delete(
      'local_classes',
      where: 'id = ? AND userId = ?',
      whereArgs: [classId, userId],
    );
  }
}
