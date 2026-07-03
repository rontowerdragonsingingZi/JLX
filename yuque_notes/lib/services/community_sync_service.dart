import '../data/repositories/auth_repository.dart';
import '../data/repositories/document_repository.dart';
import '../data/repositories/folder_repository.dart';
import 'forum/forum_api_client.dart';

class CommunitySyncException implements Exception {
  CommunitySyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CommunitySyncService {
  CommunitySyncService({
    ForumApiClient? forumClient,
    DocumentRepository? documentRepository,
    FolderRepository? folderRepository,
    AuthRepository? authRepository,
  })  : _forumClient = forumClient ?? ForumApiClient(),
        _documentRepository = documentRepository ?? DocumentRepository(),
        _folderRepository = folderRepository ?? FolderRepository(),
        _authRepository = authRepository ?? AuthRepository();

  final ForumApiClient _forumClient;
  final DocumentRepository _documentRepository;
  final FolderRepository _folderRepository;
  final AuthRepository _authRepository;

  Future<void> syncDocumentToCommunity({
    required int documentId,
    required int localUserId,
    required String accessToken,
  }) async {
    final document = await _documentRepository.getDocument(
      userId: localUserId,
      documentId: documentId,
    );
    if (document == null) {
      throw CommunitySyncException('文档不存在');
    }

    final owner = await _authRepository.getUserById(document.userId);
    if (owner == null) {
      throw CommunitySyncException('文档所属用户不存在');
    }
    if (owner.username == AuthRepository.localUsername) {
      throw CommunitySyncException('本地游客文档无法同步到社区');
    }

    final folder = await _folderRepository.getFolder(
      userId: document.userId,
      folderId: document.folderId,
    );

    try {
      await _forumClient.postJson(
        '/api/posts/sync',
        accessToken: accessToken,
        expectedStatusCodes: const [200, 201],
        body: {
          'bssUserId': document.userId,
          'bssDocumentId': document.id,
          'bssFolderId': document.folderId,
          if (folder != null) 'bssFolderName': folder.name,
          'title': document.title,
          'content': document.content,
          'bssDocumentUpdatedAt': document.updatedAt.toIso8601String(),
        },
      );
    } on ForumApiException catch (error) {
      throw CommunitySyncException(
        error.message,
        statusCode: error.statusCode,
      );
    }

    await _documentRepository.markSyncedToCommunity(
      userId: document.userId,
      documentId: document.id,
    );
  }
}