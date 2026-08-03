import '../database/database_helper.dart';
import '../models/document.dart';
import 'folder_repository.dart';

class DocumentRepository {
  DocumentRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<Document> createDocument({
    required int userId,
    required int folderId,
    required String title,
    String content = '',
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('Document title is required');
    }

    final db = await _databaseHelper.database;
    final folderRows = await db.query(
      DatabaseHelper.foldersTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [folderId, userId],
      limit: 1,
    );
    if (folderRows.isEmpty) {
      throw RepositoryException('Folder not found');
    }

    final now = DateTime.now();
    final sortOrder = await _nextDocumentSortOrder(
      userId: userId,
      folderId: folderId,
    );
    final id = await db.insert(
      DatabaseHelper.documentsTable,
      {
        'user_id': userId,
        'folder_id': folderId,
        'title': trimmed,
        'content': content,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'synced_to_community': 0,
        'sort_order': sortOrder,
      },
    );

    return Document(
      id: id,
      userId: userId,
      folderId: folderId,
      title: trimmed,
      content: content,
      createdAt: now,
      updatedAt: now,
      syncedToCommunity: false,
      sortOrder: sortOrder,
    );
  }

  Future<int> _nextDocumentSortOrder({
    required int userId,
    required int folderId,
  }) async {
    final docs = await getDocumentsInFolder(userId: userId, folderId: folderId);
    if (docs.isEmpty) {
      return 0;
    }
    var maxOrder = docs.first.sortOrder;
    for (final d in docs) {
      if (d.sortOrder > maxOrder) {
        maxOrder = d.sortOrder;
      }
    }
    return maxOrder + 1;
  }

  Future<Document?> getDocument({
    required int userId,
    required int documentId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.documentsTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [documentId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Document.fromMap(rows.first);
  }

  Future<List<Document>> getDocumentsInFolder({
    required int userId,
    required int folderId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.documentsTable,
      where: 'user_id = ? AND folder_id = ?',
      whereArgs: [userId, folderId],
      orderBy: 'sort_order ASC, title ASC',
    );
    return rows.map(Document.fromMap).toList();
  }

  /// 当前用户命名空间下的全部文档（登录后全量上云用）。
  Future<List<Document>> getAllDocuments({required int userId}) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.documentsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );
    return rows.map(Document.fromMap).toList();
  }

  Future<Document> updateDocumentContent({
    required int userId,
    required int documentId,
    required String content,
  }) async {
    final document = await getDocument(userId: userId, documentId: documentId);
    if (document == null) {
      throw RepositoryException('Document not found');
    }

    final now = DateTime.now();
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.documentsTable,
      {
        'content': content,
        'updated_at': now.toIso8601String(),
        'synced_to_community': 0,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [documentId, userId],
    );

    return document.copyWith(
      content: content,
      updatedAt: now,
      syncedToCommunity: false,
    );
  }

  /// 将 [documentId] 放到 [targetFolderId] 中；
  /// [beforeDocumentId] 为 null 表示夹内末尾，否则插到该文档之前。
  Future<Document> reorderDocument({
    required int userId,
    required int documentId,
    required int targetFolderId,
    int? beforeDocumentId,
  }) async {
    final document = await getDocument(userId: userId, documentId: documentId);
    if (document == null) {
      throw RepositoryException('Document not found');
    }

    final db = await _databaseHelper.database;
    final folderRows = await db.query(
      DatabaseHelper.foldersTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [targetFolderId, userId],
      limit: 1,
    );
    if (folderRows.isEmpty) {
      throw RepositoryException('Folder not found');
    }

    if (beforeDocumentId != null && beforeDocumentId == documentId) {
      return document;
    }

    // 先移到目标夹（若需要），再统一重写 sort_order
    if (document.folderId != targetFolderId) {
      await db.update(
        DatabaseHelper.documentsTable,
        {
          'folder_id': targetFolderId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [documentId, userId],
      );
    }

    final siblings = await getDocumentsInFolder(
      userId: userId,
      folderId: targetFolderId,
    );
    final ordered = siblings.where((d) => d.id != documentId).toList();
    var insertAt = ordered.length;
    if (beforeDocumentId != null) {
      final idx = ordered.indexWhere((d) => d.id == beforeDocumentId);
      if (idx >= 0) {
        insertAt = idx;
      }
    }
    final moving = document.copyWith(folderId: targetFolderId);
    ordered.insert(insertAt, moving);

    final now = DateTime.now().toIso8601String();
    for (var i = 0; i < ordered.length; i++) {
      await db.update(
        DatabaseHelper.documentsTable,
        {'sort_order': i, 'updated_at': now},
        where: 'id = ? AND user_id = ?',
        whereArgs: [ordered[i].id, userId],
      );
    }

    return moving.copyWith(sortOrder: insertAt, updatedAt: DateTime.now());
  }

  /// 兼容旧调用：移到目标夹末尾。
  Future<Document> moveDocument({
    required int userId,
    required int documentId,
    required int targetFolderId,
  }) {
    return reorderDocument(
      userId: userId,
      documentId: documentId,
      targetFolderId: targetFolderId,
      beforeDocumentId: null,
    );
  }

  Future<Document> renameDocument({
    required int userId,
    required int documentId,
    required String title,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('Document title is required');
    }

    final document = await getDocument(userId: userId, documentId: documentId);
    if (document == null) {
      throw RepositoryException('Document not found');
    }

    final now = DateTime.now();
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.documentsTable,
      {
        'title': trimmed,
        'updated_at': now.toIso8601String(),
        'synced_to_community': 0,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [documentId, userId],
    );

    return document.copyWith(
      title: trimmed,
      updatedAt: now,
      syncedToCommunity: false,
    );
  }

  Future<void> deleteDocument({
    required int userId,
    required int documentId,
  }) async {
    final document = await getDocument(userId: userId, documentId: documentId);
    if (document == null) {
      throw RepositoryException('Document not found');
    }

    final db = await _databaseHelper.database;
    await db.delete(
      DatabaseHelper.documentsTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [documentId, userId],
    );
  }
}
