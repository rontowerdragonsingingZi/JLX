import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuque_notes/data/repositories/auth_repository.dart';
import 'package:yuque_notes/data/repositories/document_repository.dart';
import 'package:yuque_notes/data/repositories/folder_repository.dart';
import 'package:yuque_notes/services/community_sync_service.dart';
import 'package:yuque_notes/services/forum/forum_api_client.dart';

import 'helpers/test_setup.dart';

void main() {
  group('CommunitySyncService', () {
    late AuthRepository authRepository;
    late FolderRepository folderRepository;
    late DocumentRepository documentRepository;
    late int userId;

    setUp(() async {
      await setUpTestDatabase();
      authRepository = AuthRepository();
      folderRepository = FolderRepository();
      documentRepository = DocumentRepository();

      final user = await authRepository.register(
        username: 'sync_user',
        password: 'secret',
      );
      userId = user.id;
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    test('rejects __local__ owner before HTTP', () async {
      final localUser = await authRepository.ensureLocalUser();
      final folder = await folderRepository.createFolder(
        userId: localUser.id,
        parentId: null,
        name: '本地',
      );
      final document = await documentRepository.createDocument(
        userId: localUser.id,
        folderId: folder.id,
        title: '本地文档',
      );

      final service = CommunitySyncService(
        forumClient: ForumApiClient(
          baseUrl: 'https://forum.test',
          client: MockClient((request) async {
            fail('HTTP must not be called for __local__ documents');
          }),
        ),
        documentRepository: documentRepository,
        folderRepository: folderRepository,
        authRepository: authRepository,
      );

      expect(
        () => service.syncDocumentToCommunity(
          documentId: document.id,
          localUserId: localUser.id,
          forumUserId: 42,
          accessToken: 'token',
        ),
        throwsA(
          isA<CommunitySyncException>().having(
            (error) => error.message,
            'message',
            '本地游客文档无法同步到社区',
          ),
        ),
      );
    });

    test('builds sync payload and marks synced_to_community on 201', () async {
      final folder = await folderRepository.createFolder(
        userId: userId,
        parentId: null,
        name: '工作笔记',
      );
      final document = await documentRepository.createDocument(
        userId: userId,
        folderId: folder.id,
        title: '今日开发日志',
        content: '# 标题\n\n正文',
      );

      Map<String, dynamic>? capturedBody;
      final service = CommunitySyncService(
        forumClient: ForumApiClient(
          baseUrl: 'https://forum.test',
          client: MockClient((request) async {
            expect(request.url.path, '/api/posts/sync');
            expect(request.headers['Authorization'], 'Bearer token');
            capturedBody =
                jsonDecode(request.body) as Map<String, dynamic>;
            return jsonUtf8Response({
              'id': 1,
              'authorId': 1,
              'authorUsername': 'sync_user',
              'title': document.title,
              'content': document.content,
              'bssUserId': userId,
              'bssDocumentId': document.id,
              'bssFolderId': folder.id,
              'bssFolderName': '工作笔记',
              'bssDocumentUpdatedAt': document.updatedAt.toIso8601String(),
              'createdAt': '2026-07-02T16:00:00.000',
              'updatedAt': '2026-07-02T16:00:00.000',
            }, 201);
          }),
        ),
        documentRepository: documentRepository,
        folderRepository: folderRepository,
        authRepository: authRepository,
      );

      const forumUserId = 42;
      await service.syncDocumentToCommunity(
        documentId: document.id,
        localUserId: userId,
        forumUserId: forumUserId,
        accessToken: 'token',
      );

      expect(capturedBody, isNotNull);
      // bssUserId 必须是本机 SQLite users.id（服务端 baseID 绑定）
      expect(capturedBody!['bssUserId'], userId);
      // bssDocumentId 带论坛用户维度，避免全局撞 id
      expect(
        capturedBody!['bssDocumentId'],
        CommunitySyncService.encodeBssDocumentId(
          forumUserId: forumUserId,
          localDocumentId: document.id,
        ),
      );
      expect(capturedBody!['bssFolderId'], folder.id);
      expect(capturedBody!['bssFolderName'], '工作笔记');
      expect(capturedBody!['title'], '今日开发日志');
      expect(capturedBody!['content'], '# 标题\n\n正文');
      expect(
        capturedBody!['bssDocumentUpdatedAt'],
        document.updatedAt.toIso8601String(),
      );

      final reloaded = await documentRepository.getDocument(
        userId: userId,
        documentId: document.id,
      );
      expect(reloaded?.syncedToCommunity, isTrue);
    });

    test('allows re-sync after content update', () async {
      final folder = await folderRepository.createFolder(
        userId: userId,
        parentId: null,
        name: '工作笔记',
      );
      final document = await documentRepository.createDocument(
        userId: userId,
        folderId: folder.id,
        title: '日志',
        content: 'v1',
      );

      var callCount = 0;
      final service = CommunitySyncService(
        forumClient: ForumApiClient(
          baseUrl: 'https://forum.test',
          client: MockClient((request) async {
            callCount++;
            return jsonUtf8Response({'id': 1}, 201);
          }),
        ),
        documentRepository: documentRepository,
        folderRepository: folderRepository,
        authRepository: authRepository,
      );

      await service.syncDocumentToCommunity(
        documentId: document.id,
        localUserId: userId,
        forumUserId: 42,
        accessToken: 'token',
      );

      await documentRepository.updateDocumentContent(
        userId: userId,
        documentId: document.id,
        content: 'v2',
      );

      await service.syncDocumentToCommunity(
        documentId: document.id,
        localUserId: userId,
        forumUserId: 42,
        accessToken: 'token',
      );

      expect(callCount, 2);
      final reloaded = await documentRepository.getDocument(
        userId: userId,
        documentId: document.id,
      );
      expect(reloaded?.syncedToCommunity, isTrue);
      expect(reloaded?.content, 'v2');
    });
  });
}