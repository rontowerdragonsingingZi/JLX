import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/repositories/auth_repository.dart';
import 'package:yuque_notes/data/repositories/document_repository.dart';
import 'package:yuque_notes/data/repositories/folder_repository.dart';

import 'helpers/test_setup.dart';

void main() {
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
      username: 'tree_user',
      password: 'pass',
    );
    userId = user.id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('creates nested folders and documents with rename and delete', () async {
    final folderA = await folderRepository.createFolder(
      userId: userId,
      parentId: null,
      name: 'A',
    );
    final folderB = await folderRepository.createFolder(
      userId: userId,
      parentId: folderA.id,
      name: 'B',
    );
    final folderC = await folderRepository.createFolder(
      userId: userId,
      parentId: folderB.id,
      name: 'C',
    );
    final folderZ = await folderRepository.createFolder(
      userId: userId,
      parentId: folderC.id,
      name: 'Z',
    );

    final childrenOfA = await folderRepository.getChildFolders(
      userId: userId,
      parentId: folderA.id,
    );
    expect(childrenOfA.single.id, folderB.id);

    final doc = await documentRepository.createDocument(
      userId: userId,
      folderId: folderZ.id,
      title: 'Note in Z',
      content: '# Hello',
    );

    final renamedFolder = await folderRepository.renameFolder(
      userId: userId,
      folderId: folderZ.id,
      name: 'Z-Renamed',
    );
    expect(renamedFolder.name, 'Z-Renamed');

    final renamedDoc = await documentRepository.renameDocument(
      userId: userId,
      documentId: doc.id,
      title: 'Renamed Note',
    );
    expect(renamedDoc.title, 'Renamed Note');

    await documentRepository.updateDocumentContent(
      userId: userId,
      documentId: doc.id,
      content: '**bold** text',
    );

    final loaded = await documentRepository.getDocument(
      userId: userId,
      documentId: doc.id,
    );
    expect(loaded?.content, '**bold** text');

    final docsInZ = await documentRepository.getDocumentsInFolder(
      userId: userId,
      folderId: folderZ.id,
    );
    expect(docsInZ, hasLength(1));

    await documentRepository.deleteDocument(
      userId: userId,
      documentId: doc.id,
    );
    final afterDelete = await documentRepository.getDocument(
      userId: userId,
      documentId: doc.id,
    );
    expect(afterDelete, isNull);

    await folderRepository.deleteFolder(userId: userId, folderId: folderA.id);
    final allFolders = await folderRepository.getAllFolders(userId: userId);
    expect(allFolders, isEmpty);
  });
}