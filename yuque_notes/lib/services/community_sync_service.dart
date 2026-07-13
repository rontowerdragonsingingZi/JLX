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
      throw CommunitySyncException('Document not found');
    }

    final owner = await _authRepository.getUserById(document.userId);
    if (owner == null) {
      throw CommunitySyncException('Document owner not found');
    }
    if (AuthRepository.isLocalGuest(owner)) {
      throw CommunitySyncException('Local guest documents cannot be synced');
    }

    final folder = await _folderRepository.getFolder(
      userId: document.userId,
      folderId: document.folderId,
    );
    final folderChain = await _folderRepository.getFolderChain(
      userId: document.userId,
      folderId: document.folderId,
    );
    final folderPath = folderChain.isEmpty
        ? null
        : folderChain.map((folder) => folder.name).join(' / ');

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
          if (folderPath != null) 'bssFolderPath': folderPath,
          if (folderChain.isNotEmpty)
            'bssFolderChain': [
              for (var index = 0; index < folderChain.length; index += 1)
                {
                  'id': folderChain[index].id,
                  'parentId': folderChain[index].parentId,
                  'name': folderChain[index].name,
                  'depth': index,
                },
            ],
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

  Future<void> deleteCommunityPost({
    required int postId,
    required String accessToken,
  }) async {
    try {
      await _forumClient.delete(
        '/api/posts/$postId',
        accessToken: accessToken,
      );
    } on ForumApiException catch (error) {
      throw CommunitySyncException(
        error.message,
        statusCode: error.statusCode,
      );
    }
  }
}
