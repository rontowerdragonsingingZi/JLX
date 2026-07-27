import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../app_branding.dart';
import '../data/models/folder.dart';
import '../data/repositories/document_repository.dart';
import '../data/repositories/folder_repository.dart';

/// 笔记库导入/导出异常（需弹窗展示 [message]）。
class NotebookTransferException implements Exception {
  NotebookTransferException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 单文件导出格式：JSON，扩展名建议 `.nnb`（NoteYourNeed Notebook）。
/// 结构与云端同步类似，按文件夹树嵌套保留层级。
class NotebookTransferService {
  NotebookTransferService({
    FolderRepository? folderRepository,
    DocumentRepository? documentRepository,
  })  : _folderRepository = folderRepository ?? FolderRepository(),
        _documentRepository = documentRepository ?? DocumentRepository();

  static const String formatId = 'NoteYourNeed.notebook';
  static const int formatVersion = 1;
  static const String defaultExtension = 'nnb';

  final FolderRepository _folderRepository;
  final DocumentRepository _documentRepository;

  /// 导出笔记到用户选择的文件。
  ///
  /// 选择语义：
  /// - 勾选文件夹 → 导出该夹（及子夹）目录结构 + 其下勾选的文档
  /// - 仅勾选文档（所属夹未勾选）→ 扁平只导出这些文件
  /// - 可多选组合（夹 A + 单独文件 B）
  /// 返回保存路径；用户取消返回 null。
  Future<String?> exportNotebook({
    required int userId,
    Set<int>? selectedFolderIds,
    Set<int>? selectedDocumentIds,
  }) async {
    if (kIsWeb) {
      throw NotebookTransferException('当前平台不支持导出到本地文件');
    }

    final tree = await _buildExportTree(
      userId: userId,
      selectedFolderIds: selectedFolderIds ?? const <int>{},
      selectedDocumentIds: selectedDocumentIds ?? const <int>{},
    );
    if (tree.isEmpty) {
      throw NotebookTransferException('没有可导出的内容');
    }
    final hasFolderStructure = (selectedFolderIds ?? const <int>{}).isNotEmpty;
    final payload = <String, dynamic>{
      'format': formatId,
      'version': formatVersion,
      'app': AppBranding.fullName,
      'exportedAt': DateTime.now().toIso8601String(),
      // 供导入端识别：是否含文件夹结构节点
      'includeFolderStructure': hasFolderStructure,
      'tree': tree,
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final defaultName = 'NoteYourNeed_export_$stamp.$defaultExtension';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '导出笔记库',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const [defaultExtension, 'json'],
    );
    if (savePath == null || savePath.trim().isEmpty) {
      return null;
    }

    var path = savePath.trim();
    final lower = path.toLowerCase();
    if (!lower.endsWith('.$defaultExtension') && !lower.endsWith('.json')) {
      path = '$path.$defaultExtension';
    }

    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonText, encoding: utf8);
    } on FileSystemException catch (e) {
      throw NotebookTransferException('写入文件失败：${e.message}');
    } catch (e) {
      throw NotebookTransferException('导出失败：$e');
    }

    return path;
  }

  /// 从用户选择的 `.nnb` / `.json` 导入。
  ///
  /// - 携带目录结构：在主目录（根级）按树新建文件夹后导入；
  ///   同级已存在同名文件夹时中止并提示具体名称与路径。
  /// - 无目录结构：文档直接导入到 [targetFolderId]（主目录/当前所选文件夹）。
  /// 返回导入摘要；用户取消返回 null。
  Future<NotebookImportResult?> importNotebook({
    required int userId,
    int? targetFolderId,
  }) async {
    if (kIsWeb) {
      throw NotebookTransferException('当前平台不支持从本地文件导入');
    }

    final pick = await FilePicker.platform.pickFiles(
      dialogTitle: '导入笔记库',
      type: FileType.custom,
      allowedExtensions: const [defaultExtension, 'json'],
      withData: false,
    );
    if (pick == null || pick.files.isEmpty) {
      return null;
    }

    final path = pick.files.single.path;
    if (path == null || path.isEmpty) {
      throw NotebookTransferException('无法读取所选文件路径');
    }

    final String raw;
    try {
      raw = await File(path).readAsString(encoding: utf8);
    } on FileSystemException catch (e) {
      throw NotebookTransferException('读取文件失败：${e.message}');
    } catch (e) {
      throw NotebookTransferException('读取文件失败：$e');
    }

    final Map<String, dynamic> root;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw NotebookTransferException('文件内容不是有效的笔记库对象');
      }
      root = Map<String, dynamic>.from(decoded);
    } on NotebookTransferException {
      rethrow;
    } on FormatException catch (e) {
      throw NotebookTransferException('JSON 解析失败：${e.message}');
    } catch (e) {
      throw NotebookTransferException('文件格式无效：$e');
    }

    final format = root['format']?.toString();
    if (format != null &&
        format.isNotEmpty &&
        format != formatId &&
        format != 'NoteYourNeed.notebook.v1') {
      throw NotebookTransferException(
        '不支持的笔记库格式：$format（期望 $formatId）',
      );
    }

    final treeRaw = root['tree'];
    if (treeRaw is! List) {
      throw NotebookTransferException('缺少 tree 字段或类型错误，无法导入');
    }

    final treeNodes = <Map<String, dynamic>>[];
    for (final node in treeRaw) {
      if (node is! Map) {
        throw NotebookTransferException('tree 中存在无效节点');
      }
      treeNodes.add(Map<String, dynamic>.from(node));
    }

    final includeStructure = _resolveIncludeFolderStructure(root, treeNodes);

    if (includeStructure) {
      // 先校验同名冲突，避免导入一半失败
      await _validateFolderNameConflicts(
        userId: userId,
        parentId: null,
        nodes: treeNodes,
        pathSegments: const [],
      );

      var folderCount = 0;
      var documentCount = 0;
      for (final node in treeNodes) {
        final counts = await _importFolderNode(
          userId: userId,
          parentId: null,
          node: node,
          pathSegments: const [],
        );
        folderCount += counts.folders;
        documentCount += counts.documents;
      }
      return NotebookImportResult(
        foldersImported: folderCount,
        documentsImported: documentCount,
        sourcePath: path,
      );
    }

    // 无目录：文档导入到主目录（所选文件夹或校验后的目标文件夹）
    if (targetFolderId == null) {
      throw NotebookTransferException(
        '当前导出包不含文件夹结构，请先在左侧选择一个主目录文件夹，再执行导入',
      );
    }
    final target = await _folderRepository.getFolder(
      userId: userId,
      folderId: targetFolderId,
    );
    if (target == null) {
      throw NotebookTransferException('所选主目录文件夹不存在，请重新选择后再导入');
    }

    final flatDocs = _collectAllDocuments(treeNodes);
    if (flatDocs.isEmpty) {
      throw NotebookTransferException('导入包中没有可导入的文档');
    }

    var documentCount = 0;
    for (final map in flatDocs) {
      final title = (map['title'] ?? '').toString().trim();
      if (title.isEmpty) {
        throw NotebookTransferException('存在标题为空的文档，已中止导入');
      }
      final content = (map['content'] ?? '').toString();
      await _documentRepository.createDocument(
        userId: userId,
        folderId: targetFolderId,
        title: title,
        content: content,
      );
      documentCount += 1;
    }

    return NotebookImportResult(
      foldersImported: 0,
      documentsImported: documentCount,
      sourcePath: path,
    );
  }

  /// 优先读导出标记；旧包则根据是否含嵌套文件夹推断。
  bool _resolveIncludeFolderStructure(
    Map<String, dynamic> root,
    List<Map<String, dynamic>> treeNodes,
  ) {
    final flag = root['includeFolderStructure'];
    if (flag is bool) {
      return flag;
    }
    // 兼容旧文件：任一节点含非空子文件夹 → 视为携带目录
    for (final node in treeNodes) {
      if (_treeHasNestedFolders(node)) {
        return true;
      }
    }
    // 单层「导出」包裹多个文档 → 扁平
    if (treeNodes.length == 1) {
      final name = (treeNodes.first['name'] ?? '').toString().trim();
      final folders = treeNodes.first['folders'];
      final noNested = folders is! List || folders.isEmpty;
      if (noNested && (name == '导出' || name == 'Export')) {
        return false;
      }
    }
    // 默认按有目录处理（整库导出）
    return true;
  }

  bool _treeHasNestedFolders(Map<String, dynamic> node) {
    final folders = node['folders'];
    if (folders is! List || folders.isEmpty) {
      return false;
    }
    for (final child in folders) {
      if (child is Map) {
        return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _collectAllDocuments(
    List<Map<String, dynamic>> nodes,
  ) {
    final result = <Map<String, dynamic>>[];
    void walk(Map<String, dynamic> node) {
      final docsRaw = node['documents'];
      if (docsRaw is List) {
        for (final item in docsRaw) {
          if (item is Map) {
            result.add(Map<String, dynamic>.from(item));
          }
        }
      }
      final foldersRaw = node['folders'];
      if (foldersRaw is List) {
        for (final child in foldersRaw) {
          if (child is Map) {
            walk(Map<String, dynamic>.from(child));
          }
        }
      }
    }

    for (final node in nodes) {
      walk(node);
    }
    return result;
  }

  Future<void> _validateFolderNameConflicts({
    required int userId,
    required int? parentId,
    required List<Map<String, dynamic>> nodes,
    required List<String> pathSegments,
  }) async {
    final seenInPackage = <String>{};
    for (final node in nodes) {
      final name = (node['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        throw NotebookTransferException('存在名称为空的文件夹节点，已中止导入');
      }
      final key = name.toLowerCase();
      if (!seenInPackage.add(key)) {
        final pathLabel =
            pathSegments.isEmpty ? '主目录' : pathSegments.join(' / ');
        throw NotebookTransferException(
          '导入包内同级文件夹名称重复：「$name」（位置：$pathLabel），请修改导出包后再导入',
        );
      }

      final existing = await _folderRepository.findChildFolderByName(
        userId: userId,
        parentId: parentId,
        name: name,
      );
      if (existing != null) {
        final pathLabel =
            pathSegments.isEmpty ? '主目录' : pathSegments.join(' / ');
        throw NotebookTransferException(
          '文件夹「$name」已存在（路径：$pathLabel），请修改本地同名文件夹后再导入',
        );
      }

      final foldersRaw = node['folders'];
      if (foldersRaw is List && foldersRaw.isNotEmpty) {
        final childNodes = <Map<String, dynamic>>[
          for (final child in foldersRaw)
            if (child is Map)
              Map<String, dynamic>.from(child)
            else
              throw NotebookTransferException(
                '文件夹「$name」下存在无效子文件夹节点',
              ),
        ];
        // 子级冲突只检查导入包内重名（父级将新建，本地尚无对应路径）
        _validateSiblingNamesInPackage(
          nodes: childNodes,
          pathSegments: [...pathSegments, name],
        );
      }
    }
  }

  void _validateSiblingNamesInPackage({
    required List<Map<String, dynamic>> nodes,
    required List<String> pathSegments,
  }) {
    final seen = <String>{};
    for (final node in nodes) {
      final name = (node['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        throw NotebookTransferException('存在名称为空的文件夹节点，已中止导入');
      }
      if (!seen.add(name.toLowerCase())) {
        final pathLabel = pathSegments.join(' / ');
        throw NotebookTransferException(
          '导入包内同级文件夹名称重复：「$name」（位置：$pathLabel），请修改导出包后再导入',
        );
      }
      final foldersRaw = node['folders'];
      if (foldersRaw is List && foldersRaw.isNotEmpty) {
        final childNodes = <Map<String, dynamic>>[
          for (final child in foldersRaw)
            if (child is Map)
              Map<String, dynamic>.from(child)
            else
              throw NotebookTransferException(
                '文件夹「$name」下存在无效子文件夹节点',
              ),
        ];
        _validateSiblingNamesInPackage(
          nodes: childNodes,
          pathSegments: [...pathSegments, name],
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _buildExportTree({
    required int userId,
    required Set<int> selectedFolderIds,
    required Set<int> selectedDocumentIds,
  }) async {
    final allFolders = await _folderRepository.getAllFolders(userId: userId);
    final folderById = {for (final f in allFolders) f.id: f};

    final allDocsByFolder = <int, List<Map<String, dynamic>>>{};
    for (final folder in allFolders) {
      final docs = await _documentRepository.getDocumentsInFolder(
        userId: userId,
        folderId: folder.id,
      );
      allDocsByFolder[folder.id] = [
        for (final d in docs)
          {
            'id': d.id,
            'title': d.title,
            'content': d.content,
            'createdAt': d.createdAt.toIso8601String(),
            'updatedAt': d.updatedAt.toIso8601String(),
          },
      ];
    }

    Map<String, dynamic> stripId(Map<String, dynamic> d) => {
          'title': d['title'],
          'content': d['content'],
          'createdAt': d['createdAt'],
          'updatedAt': d['updatedAt'],
        };

    if (selectedFolderIds.isEmpty && selectedDocumentIds.isEmpty) {
      return [];
    }

    final docFolderId = <int, int>{};
    for (final entry in allDocsByFolder.entries) {
      for (final d in entry.value) {
        docFolderId[d['id'] as int] = entry.key;
      }
    }

    bool isUnderSelectedFolder(int folderId) {
      var current = folderById[folderId];
      while (current != null) {
        if (selectedFolderIds.contains(current.id)) {
          return true;
        }
        final parentId = current.parentId;
        current = parentId == null ? null : folderById[parentId];
      }
      return false;
    }

    // 游离文档：所属夹链上没有任何被勾选的文件夹 → 只导出文件
    final orphanDocIds = <int>{};
    for (final docId in selectedDocumentIds) {
      final folderId = docFolderId[docId];
      if (folderId == null || !isUnderSelectedFolder(folderId)) {
        orphanDocIds.add(docId);
      }
    }

    final result = <Map<String, dynamic>>[];

    // 选中夹的「根」：父夹未选中的夹，各自作为一棵子树根
    final rootSelectedFolders = selectedFolderIds.where((id) {
      final folder = folderById[id];
      if (folder == null) {
        return false;
      }
      final parentId = folder.parentId;
      if (parentId == null) {
        return true;
      }
      return !selectedFolderIds.contains(parentId);
    }).toList()
      ..sort((a, b) {
        final na = folderById[a]?.name.toLowerCase() ?? '';
        final nb = folderById[b]?.name.toLowerCase() ?? '';
        return na.compareTo(nb);
      });

    for (final rootId in rootSelectedFolders) {
      final node = _buildSelectedSubtree(
        folderId: rootId,
        allFolders: allFolders,
        folderById: folderById,
        allDocsByFolder: allDocsByFolder,
        selectedFolderIds: selectedFolderIds,
        selectedDocumentIds: selectedDocumentIds,
        stripId: stripId,
      );
      if (node != null) {
        result.add(node);
      }
    }

    if (orphanDocIds.isNotEmpty) {
      final flatDocs = <Map<String, dynamic>>[];
      for (final entry in allDocsByFolder.entries) {
        for (final d in entry.value) {
          if (orphanDocIds.contains(d['id'] as int)) {
            flatDocs.add(stripId(d));
          }
        }
      }
      if (flatDocs.isNotEmpty) {
        final now = DateTime.now().toIso8601String();
        result.add({
          'name': '导出',
          'createdAt': now,
          'updatedAt': now,
          'folders': <Map<String, dynamic>>[],
          'documents': flatDocs,
        });
      }
    }

    return result;
  }

  Map<String, dynamic>? _buildSelectedSubtree({
    required int folderId,
    required List<Folder> allFolders,
    required Map<int, Folder> folderById,
    required Map<int, List<Map<String, dynamic>>> allDocsByFolder,
    required Set<int> selectedFolderIds,
    required Set<int> selectedDocumentIds,
    required Map<String, dynamic> Function(Map<String, dynamic>) stripId,
  }) {
    final folder = folderById[folderId];
    if (folder == null) {
      return null;
    }

    final childFolders =
        allFolders.where((f) => f.parentId == folderId).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final nested = <Map<String, dynamic>>[];
    for (final child in childFolders) {
      final childSelected = selectedFolderIds.contains(child.id);
      final childHasSelectedDocs = _folderTreeHasSelectedDoc(
        folderId: child.id,
        allFolders: allFolders,
        allDocsByFolder: allDocsByFolder,
        selectedDocumentIds: selectedDocumentIds,
      );

      if (childSelected ||
          (selectedFolderIds.contains(folderId) && childHasSelectedDocs)) {
        final node = _buildSelectedSubtree(
          folderId: child.id,
          allFolders: allFolders,
          folderById: folderById,
          allDocsByFolder: allDocsByFolder,
          selectedFolderIds: selectedFolderIds,
          selectedDocumentIds: selectedDocumentIds,
          stripId: stripId,
        );
        if (node != null) {
          nested.add(node);
        }
      }
    }

    final docs = [
      for (final d
          in allDocsByFolder[folderId] ?? const <Map<String, dynamic>>[])
        if (selectedDocumentIds.contains(d['id'] as int)) stripId(d),
    ];

    if (!selectedFolderIds.contains(folderId) &&
        docs.isEmpty &&
        nested.isEmpty) {
      return null;
    }

    return {
      'name': folder.name,
      'createdAt': folder.createdAt.toIso8601String(),
      'updatedAt': folder.updatedAt.toIso8601String(),
      'folders': nested,
      'documents': docs,
    };
  }

  bool _folderTreeHasSelectedDoc({
    required int folderId,
    required List<Folder> allFolders,
    required Map<int, List<Map<String, dynamic>>> allDocsByFolder,
    required Set<int> selectedDocumentIds,
  }) {
    for (final d in allDocsByFolder[folderId] ?? const []) {
      if (selectedDocumentIds.contains(d['id'] as int)) {
        return true;
      }
    }
    for (final child in allFolders.where((f) => f.parentId == folderId)) {
      if (_folderTreeHasSelectedDoc(
        folderId: child.id,
        allFolders: allFolders,
        allDocsByFolder: allDocsByFolder,
        selectedDocumentIds: selectedDocumentIds,
      )) {
        return true;
      }
    }
    return false;
  }

  Future<({int folders, int documents})> _importFolderNode({
    required int userId,
    required int? parentId,
    required Map<String, dynamic> node,
    required List<String> pathSegments,
  }) async {
    final name = (node['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      throw NotebookTransferException('存在名称为空的文件夹节点，已中止导入');
    }

    final pathLabel =
        pathSegments.isEmpty ? '主目录' : pathSegments.join(' / ');

    // 同级同名：报错并指出具体文件夹，要求用户先修改
    final existing = await _folderRepository.findChildFolderByName(
      userId: userId,
      parentId: parentId,
      name: name,
    );
    if (existing != null) {
      throw NotebookTransferException(
        '文件夹「$name」已存在（路径：$pathLabel），请修改本地同名文件夹后再导入',
      );
    }

    final folder = await _folderRepository.createFolder(
      userId: userId,
      parentId: parentId,
      name: name,
    );
    var foldersCreated = 1;
    var documentsCreated = 0;

    final docsRaw = node['documents'];
    if (docsRaw is List) {
      for (final item in docsRaw) {
        if (item is! Map) {
          throw NotebookTransferException('文件夹「$name」下存在无效文档节点');
        }
        final map = Map<String, dynamic>.from(item);
        final title = (map['title'] ?? '').toString().trim();
        if (title.isEmpty) {
          throw NotebookTransferException('文件夹「$name」下存在标题为空的文档');
        }
        final content = (map['content'] ?? '').toString();
        await _documentRepository.createDocument(
          userId: userId,
          folderId: folder.id,
          title: title,
          content: content,
        );
        documentsCreated += 1;
      }
    }

    final foldersRaw = node['folders'];
    if (foldersRaw is List) {
      for (final child in foldersRaw) {
        if (child is! Map) {
          throw NotebookTransferException('文件夹「$name」下存在无效子文件夹节点');
        }
        final nested = await _importFolderNode(
          userId: userId,
          parentId: folder.id,
          node: Map<String, dynamic>.from(child),
          pathSegments: [...pathSegments, name],
        );
        foldersCreated += nested.folders;
        documentsCreated += nested.documents;
      }
    }

    return (folders: foldersCreated, documents: documentsCreated);
  }
}

class NotebookImportResult {
  const NotebookImportResult({
    required this.foldersImported,
    required this.documentsImported,
    required this.sourcePath,
  });

  final int foldersImported;
  final int documentsImported;
  final String sourcePath;
}
