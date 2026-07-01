import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/database_helper.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<User> register({
    required String username,
    required String password,
  }) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      throw AuthException('用户名和密码不能为空');
    }

    final db = await _databaseHelper.database;
    final existing = await db.query(
      DatabaseHelper.usersTable,
      where: 'username = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw AuthException('用户名已存在');
    }

    final now = DateTime.now().toIso8601String();
    final id = await db.insert(
      DatabaseHelper.usersTable,
      {
        'username': trimmed,
        'password_hash': hashPassword(password),
        'created_at': now,
      },
    );

    return User(id: id, username: trimmed, createdAt: DateTime.parse(now));
  }

  Future<User> login({
    required String username,
    required String password,
  }) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      throw AuthException('用户名和密码不能为空');
    }

    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.usersTable,
      where: 'username = ? AND password_hash = ?',
      whereArgs: [trimmed, hashPassword(password)],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw AuthException('用户名或密码错误');
    }

    return User.fromMap(rows.first);
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}