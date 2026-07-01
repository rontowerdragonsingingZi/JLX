import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  static const String usersTable = 'users';
  static const String foldersTable = 'folders';
  static const String documentsTable = 'documents';

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<Database> _openDatabase() async {
    final String path;
    if (kIsWeb) {
      path = 'yuque_notes.db';
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'yuque_notes.db');
    }
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $foldersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        parent_id INTEGER,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id),
        FOREIGN KEY (parent_id) REFERENCES $foldersTable(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $documentsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        folder_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id),
        FOREIGN KEY (folder_id) REFERENCES $foldersTable(id)
      )
    ''');
  }

  Future<void> useInMemoryDatabase() async {
    await close();
    _database = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> resetForTest() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'yuque_notes.db');
    await deleteDatabase(path);
  }
}