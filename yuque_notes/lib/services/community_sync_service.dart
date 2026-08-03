import '../data/repositories/auth_repository.dart';
import '../data/repositories/document_repository.dart';
import '../data/repositories/folder_repository.dart';
import 'cloud_image_service.dart';
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
    CloudImageService? cloudImageService,
  })  : _forumClient = forumClient ?? ForumApiClient(),
        _documentRepository = documentRepository ?? DocumentRepository(),
        _folderRepository = folderRepository ?? FolderRepository(),
        _authRepository = authRepository ?? AuthRepository(),
        _cloudImageService = cloudImageService ?? CloudImageService();

  final ForumApiClient _forumClient;
  final DocumentRepository _documentRepository;
  final FolderRepository _folderRepository;
  final AuthRepository _authRepository;
  final CloudImageService _cloudImageService;

  /// 生成跨用户唯一的云端文档键，避免各端本地 `documents.id` 从 1 自增互相抢帖。
  /// 仍落在 JSON 安全整数范围内（< 2^53）。
  static int encodeBssDocumentId({
    required int forumUserId,
    required int localDocumentId,
  }) {
    if (forumUserId <= 0 || localDocumentId <= 0) {
      throw CommunitySyncException('Invalid document identity');
    }
    // forumUserId * 1e9 + localDocumentId
    const stride = 1000000000;
    if (localDocumentId >= stride) {
      throw CommunitySyncException('Local document id out of range');
    }
    final encoded = forumUserId * stride + localDocumentId;
    // JSON number 安全上限约 2^53-1
    if (encoded > 9007199254740991) {
      throw CommunitySyncException('Encoded document id out of range');
    }
    return encoded;
  }

  Future<void> syncDocumentToCommunity({
    required int documentId,
    required int localUserId,
    /// 论坛账号 id（JWT）。用于生成唯一 bssDocumentId，避免全局文档 id 撞车。
    required int forumUserId,
    required String accessToken,
  }) async {
    if (forumUserId <= 0) {
      throw CommunitySyncException('Invalid forum user id');
    }

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
      throw CommunitySyncException('本地游客文档无法同步到社区');
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

    // 服务端 baseID / bss_user_id 绑定的是「本机 SQLite users.id」，
    // 不能改成论坛 userId，否则会报 baseID 不匹配。
    final bssUserId = document.userId;
    // 文档键加入论坛用户维度，避免仅用本地自增 document.id 与他人撞车
    // （否则会出现「只能更新自己的帖子」）。
    final bssDocumentId = encodeBssDocumentId(
      forumUserId: forumUserId,
      localDocumentId: document.id,
    );

    // 同步前把仍残留的 Data URI 图片上传到 R2（notes/{userId}/…）
    var content = document.content;
    try {
      content = await _cloudImageService.uploadDataImagesInMarkdown(
        markdown: content,
        accessToken: accessToken,
      );
      if (content != document.content) {
        await _documentRepository.updateDocumentContent(
          userId: document.userId,
          documentId: document.id,
          content: content,
        );
      }
    } on ForumApiException catch (error) {
      throw CommunitySyncException(
        error.message,
        statusCode: error.statusCode,
      );
    }

    try {
      await _forumClient.postJson(
        '/api/posts/sync',
        accessToken: accessToken,
        expectedStatusCodes: const [200, 201],
        body: {
          'bssUserId': bssUserId,
          'bssDocumentId': bssDocumentId,
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
          'content': content,
          'bssDocumentUpdatedAt': document.updatedAt.toIso8601String(),
        },
      );
    } on ForumApiException catch (error) {
      throw CommunitySyncException(
        error.message,
        statusCode: error.statusCode,
      );
    }
  }

  /// 登录后：当前本地用户下全部文档上云（正文 + 文件夹链结构）。
  /// 单篇失败会抛出；调用方可改为逐篇 try/catch。
  Future<void> syncAllDocumentsForUser({
    required int localUserId,
    required int forumUserId,
    required String accessToken,
  }) async {
    final documents =
        await _documentRepository.getAllDocuments(userId: localUserId);
    for (final document in documents) {
      await syncDocumentToCommunity(
        documentId: document.id,
        localUserId: localUserId,
        forumUserId: forumUserId,
        accessToken: accessToken,
      );
    }
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
