import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

Future<List<String>> verifyDatabaseSchema() async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
  );
  return rows.map((row) => row['name'] as String).toList();
}

Future<String> sqliteVersion(Database db) async {
  final row = await db.rawQuery('SELECT sqlite_version() AS v');
  return row.first['v'] as String;
}