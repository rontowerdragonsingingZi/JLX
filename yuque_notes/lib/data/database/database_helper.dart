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

  /// v4: folders/documents 增加 sort_order，支持拖拽排序。
  static const int schemaVersion = 4;

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
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        avatar TEXT
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
        sort_order INTEGER NOT NULL DEFAULT 0,
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
        synced_to_community INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id),
        FOREIGN KEY (folder_id) REFERENCES $foldersTable(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $usersTable ADD COLUMN avatar TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $documentsTable ADD COLUMN synced_to_community INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $foldersTable ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $documentsTable ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      // 用 id 回填，保持大致创建顺序
      await db.execute(
        'UPDATE $foldersTable SET sort_order = id',
      );
      await db.execute(
        'UPDATE $documentsTable SET sort_order = id',
      );
    }
  }

  Future<void> useInMemoryDatabase() async {
    await close();
    _database = await openDatabase(
      inMemoryDatabasePath,
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> resetForTest() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'yuque_notes.db');
    await deleteDatabase(path);
  }
}
