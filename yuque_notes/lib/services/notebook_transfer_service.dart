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

  /// 导出当前用户全部文件夹 + 文档到用户选择的文件。
  /// 返回保存路径；用户取消返回 null。
  Future<String?> exportNotebook({required int userId}) async {
    if (kIsWeb) {
      throw NotebookTransferException('当前平台不支持导出到本地文件');
    }

    final tree = await _buildExportTree(userId: userId);
    final payload = <String, dynamic>{
      'format': formatId,
      'version': formatVersion,
      'app': AppBranding.fullName,
      'exportedAt': DateTime.now().toIso8601String(),
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

  /// 从用户选择的 `.nnb` / `.json` 导入，合并进当前用户库。
  /// 同级同名文件夹会复用并合并子内容，避免重复创建。
  /// 返回导入摘要；用户取消返回 null。
  Future<NotebookImportResult?> importNotebook({required int userId}) async {
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

    var folderCount = 0;
    var documentCount = 0;

    for (final node in treeRaw) {
      if (node is! Map) {
        throw NotebookTransferException('tree 中存在无效节点');
      }
      final counts = await _importFolderNode(
        userId: userId,
        parentId: null,
        node: Map<String, dynamic>.from(node),
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

  Future<List<Map<String, dynamic>>> _buildExportTree({
    required int userId,
  }) async {
    final allFolders = await _folderRepository.getAllFolders(userId: userId);
    return _exportChildren(userId: userId, parentId: null, allFolders: allFolders);
  }

  Future<List<Map<String, dynamic>>> _exportChildren({
    required int userId,
    required int? parentId,
    required List<Folder> allFolders,
  }) async {
    final children = allFolders
        .where((f) => f.parentId == parentId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final result = <Map<String, dynamic>>[];
    for (final folder in children) {
      final docs = await _documentRepository.getDocumentsInFolder(
        userId: userId,
        folderId: folder.id,
      );
      final nested = await _exportChildren(
        userId: userId,
        parentId: folder.id,
        allFolders: allFolders,
      );
      result.add({
        'name': folder.name,
        'createdAt': folder.createdAt.toIso8601String(),
        'updatedAt': folder.updatedAt.toIso8601String(),
        'folders': nested,
        'documents': [
          for (final d in docs)
            {
              'title': d.title,
              'content': d.content,
              'createdAt': d.createdAt.toIso8601String(),
              'updatedAt': d.updatedAt.toIso8601String(),
            },
        ],
      });
    }
    return result;
  }

  Future<({int folders, int documents})> _importFolderNode({
    required int userId,
    required int? parentId,
    required Map<String, dynamic> node,
  }) async {
    final name = (node['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      throw NotebookTransferException('存在名称为空的文件夹节点，已中止导入');
    }

    // 同级同名：复用已有文件夹，避免触发「名称不能重复」并合并结构
    var folder = await _folderRepository.findChildFolderByName(
      userId: userId,
      parentId: parentId,
      name: name,
    );
    var foldersCreated = 0;
    if (folder == null) {
      folder = await _folderRepository.createFolder(
        userId: userId,
        parentId: parentId,
        name: name,
      );
      foldersCreated = 1;
    }

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
