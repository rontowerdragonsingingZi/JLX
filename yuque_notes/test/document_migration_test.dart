import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/database/database_helper.dart';
import 'package:yuque_notes/data/repositories/document_repository.dart';
import 'package:yuque_notes/data/repositories/folder_repository.dart';
import 'package:yuque_notes/data/repositories/auth_repository.dart';

import 'helpers/test_setup.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('documents table includes synced_to_community column', () async {
    final db = await DatabaseHelper.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(documents)');
    final names = columns
        .map((row) => row['name'] as String)
        .toList();

    expect(names, contains('synced_to_community'));
  });

  test('new documents default synced_to_community to false', () async {
    final authRepository = AuthRepository();
    final folderRepository = FolderRepository();
    final documentRepository = DocumentRepository();

    final user = await authRepository.register(
      username: 'schema_user',
      password: 'secret',
    );
    final folder = await folderRepository.createFolder(
      userId: user.id,
      parentId: null,
      name: '笔记',
    );
    final document = await documentRepository.createDocument(
      userId: user.id,
      folderId: folder.id,
      title: '测试',
    );

    expect(document.syncedToCommunity, isFalse);
  });
}