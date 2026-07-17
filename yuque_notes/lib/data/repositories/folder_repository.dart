import '../database/database_helper.dart';
import '../models/folder.dart';

class FolderRepository {
  FolderRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  /// 同级（同一 parentId）下是否已存在同名文件夹（不区分大小写）。
  Future<bool> hasSiblingFolderName({
    required int userId,
    int? parentId,
    required String name,
    int? excludeFolderId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final siblings = await getChildFolders(userId: userId, parentId: parentId);
    final lower = trimmed.toLowerCase();
    for (final sibling in siblings) {
      if (excludeFolderId != null && sibling.id == excludeFolderId) {
        continue;
      }
      if (sibling.name.trim().toLowerCase() == lower) {
        return true;
      }
    }
    return false;
  }

  Future<Folder> createFolder({
    required int userId,
    int? parentId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('文件夹名称不能为空');
    }

    final db = await _databaseHelper.database;
    if (parentId != null) {
      final parent = await getFolder(userId: userId, folderId: parentId);
      if (parent == null) {
        throw RepositoryException('父文件夹不存在');
      }
    }

    if (await hasSiblingFolderName(
      userId: userId,
      parentId: parentId,
      name: trimmed,
    )) {
      throw RepositoryException('该级文件夹名称不能重复，请创建一个次级文件夹');
    }

    final now = DateTime.now();
    final id = await db.insert(
      DatabaseHelper.foldersTable,
      {
        'user_id': userId,
        'parent_id': parentId,
        'name': trimmed,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );

    return Folder(
      id: id,
      userId: userId,
      parentId: parentId,
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Folder?> getFolder({
    required int userId,
    required int folderId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.foldersTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [folderId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Folder.fromMap(rows.first);
  }

  Future<List<Folder>> getFolderChain({
    required int userId,
    required int folderId,
  }) async {
    final chain = <Folder>[];
    var current = await getFolder(userId: userId, folderId: folderId);
    final visitedIds = <int>{};

    while (current != null) {
      if (!visitedIds.add(current.id)) {
        throw RepositoryException('Folder tree contains a cycle');
      }
      chain.insert(0, current);

      final parentId = current.parentId;
      if (parentId == null) {
        break;
      }
      current = await getFolder(userId: userId, folderId: parentId);
    }

    return chain;
  }

  Future<List<Folder>> getChildFolders({
    required int userId,
    int? parentId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.foldersTable,
      where: parentId == null
          ? 'user_id = ? AND parent_id IS NULL'
          : 'user_id = ? AND parent_id = ?',
      whereArgs: parentId == null ? [userId] : [userId, parentId],
      orderBy: 'name ASC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<Folder>> getAllFolders({required int userId}) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.foldersTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<Folder> renameFolder({
    required int userId,
    required int folderId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('文件夹名称不能为空');
    }

    final folder = await getFolder(userId: userId, folderId: folderId);
    if (folder == null) {
      throw RepositoryException('文件夹不存在');
    }

    if (await hasSiblingFolderName(
      userId: userId,
      parentId: folder.parentId,
      name: trimmed,
      excludeFolderId: folderId,
    )) {
      throw RepositoryException('该级文件夹名称不能重复，请创建一个次级文件夹');
    }

    final now = DateTime.now();
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.foldersTable,
      {
        'name': trimmed,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [folderId, userId],
    );

    return folder.copyWith(name: trimmed, updatedAt: now);
  }

  /// 按名称查找同级文件夹；用于导入时合并同名路径。
  Future<Folder?> findChildFolderByName({
    required int userId,
    int? parentId,
    required String name,
  }) async {
    final trimmed = name.trim();
    final siblings = await getChildFolders(userId: userId, parentId: parentId);
    final lower = trimmed.toLowerCase();
    for (final sibling in siblings) {
      if (sibling.name.trim().toLowerCase() == lower) {
        return sibling;
      }
    }
    return null;
  }

  Future<void> deleteFolder({
    required int userId,
    required int folderId,
  }) async {
    final folder = await getFolder(userId: userId, folderId: folderId);
    if (folder == null) {
      throw RepositoryException('文件夹不存在');
    }

    final db = await _databaseHelper.database;
    final childFolders = await getChildFolders(userId: userId, parentId: folderId);
    for (final child in childFolders) {
      await deleteFolder(userId: userId, folderId: child.id);
    }

    await db.delete(
      DatabaseHelper.documentsTable,
      where: 'folder_id = ? AND user_id = ?',
      whereArgs: [folderId, userId],
    );

    await db.delete(
      DatabaseHelper.foldersTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [folderId, userId],
    );
  }
}

class RepositoryException implements Exception {
  RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
