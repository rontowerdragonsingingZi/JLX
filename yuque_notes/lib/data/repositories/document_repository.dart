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
    );
  }

  Future<void> markSyncedToCommunity({
    required int userId,
    required int documentId,
  }) async {
    final document = await getDocument(userId: userId, documentId: documentId);
    if (document == null) {
      throw RepositoryException('Document not found');
    }

    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.documentsTable,
      {'synced_to_community': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [documentId, userId],
    );
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
      orderBy: 'title ASC',
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
