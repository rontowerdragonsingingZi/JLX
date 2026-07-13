import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/models/document.dart' as models;
import 'package:yuque_notes/data/models/user.dart';
import 'package:yuque_notes/data/repositories/auth_repository.dart';
import 'package:yuque_notes/data/repositories/document_repository.dart';
import 'package:yuque_notes/data/repositories/folder_repository.dart';
import 'package:yuque_notes/screens/workspace/workspace_screen.dart';

import 'helpers/test_setup.dart';

Widget _wrapWorkspace(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', 'CN')],
    home: Scaffold(
      body: SizedBox(
        height: 900,
        width: 1200,
        child: child,
      ),
    ),
  );
}

void main() {
  group('WorkspaceScreen sync integration', () {
    late User linkedLocalUser;
    late User cloudUser;
    late models.Document document;

    setUp(() async {
      await setUpTestDatabase();
      final authRepository = AuthRepository();
      linkedLocalUser = await authRepository.ensureCloudLinkedLocalUser(
        cloudUsername: 'alice',
      );
      final folderRepository = FolderRepository();
      final documentRepository = DocumentRepository();
      final folder = await folderRepository.createFolder(
        userId: linkedLocalUser.id,
        parentId: null,
        name: '工作笔记',
      );
      document = await documentRepository.createDocument(
        userId: linkedLocalUser.id,
        folderId: folder.id,
        title: '今日开发日志',
        content: '# 标题\n\n正文',
      );
      cloudUser = User(
        id: 42,
        username: 'alice',
        createdAt: DateTime.parse('2026-01-01T00:00:00'),
      );
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('shows sync control for linked local user with cloud session',
        (tester) async {
      await tester.pumpWidget(
        _wrapWorkspace(
          WorkspaceScreen(
            localUser: linkedLocalUser,
            cloudUser: cloudUser,
            initialSelectedDocument: document,
            onCloudAuthChanged: (_) async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('sync_to_community_button')), findsOneWidget);
      expect(find.text('上传云端'), findsOneWidget);
      expect(find.text('今日开发日志'), findsOneWidget);
    });

    testWidgets('shows synced badge when document already synced', (tester) async {
      final syncedDocument = document.copyWith(syncedToCommunity: true);

      await tester.pumpWidget(
        _wrapWorkspace(
          WorkspaceScreen(
            localUser: linkedLocalUser,
            cloudUser: cloudUser,
            initialSelectedDocument: syncedDocument,
            onCloudAuthChanged: (_) async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('synced_to_community_badge')), findsOneWidget);
      expect(find.text('已上传'), findsOneWidget);
    });

  });

  group('WorkspaceScreen guest sync integration', () {
    late User guestUser;
    late User cloudUser;
    late models.Document guestDocument;

    setUp(() async {
      await setUpTestDatabase();
      final authRepository = AuthRepository();
      guestUser = await authRepository.ensureLocalUser();
      final folderRepository = FolderRepository();
      final documentRepository = DocumentRepository();
      final folder = await folderRepository.createFolder(
        userId: guestUser.id,
        parentId: null,
        name: '游客',
      );
      guestDocument = await documentRepository.createDocument(
        userId: guestUser.id,
        folderId: folder.id,
        title: '游客文档',
      );
      cloudUser = User(
        id: 42,
        username: 'alice',
        createdAt: DateTime.parse('2026-01-01T00:00:00'),
      );
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('shows upload control for guest so user can login to upload',
        (tester) async {
      await tester.pumpWidget(
        _wrapWorkspace(
          WorkspaceScreen(
            localUser: guestUser,
            cloudUser: cloudUser,
            initialSelectedDocument: guestDocument,
            onCloudAuthChanged: (_) async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('sync_to_community_button')), findsOneWidget);
      expect(find.text('上传云端'), findsOneWidget);
    });
  });
}