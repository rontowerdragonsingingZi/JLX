import 'package:flutter/material.dart';

import '../data/models/document.dart';
import '../data/models/folder.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 导出选择结果（由勾选决定结构，无额外开关）。
///
/// - 仅勾选文档 → 扁平只导出这些文件
/// - 勾选文件夹 → 导出该文件夹目录结构，并带上其下仍勾选的文档
/// - 可多选：例如 A 整夹 + B 单独文件
class ExportSelectionResult {
  const ExportSelectionResult({
    required this.selectedFolderIds,
    required this.selectedDocumentIds,
  });

  /// 用户勾选过、且仍保留在集合中的文件夹（含半选父夹，用于保留目录结构）。
  final Set<int> selectedFolderIds;
  final Set<int> selectedDocumentIds;
}

/// 弹出悬浮框：勾选文件夹/文档进行导出。
Future<ExportSelectionResult?> showExportSelectionDialog({
  required BuildContext context,
  required List<Folder> folders,
  required Map<int, List<Document>> documentsByFolder,
}) {
  return showDialog<ExportSelectionResult>(
    context: context,
    barrierDismissible: true,
    builder: (context) => ExportSelectionDialog(
      folders: folders,
      documentsByFolder: documentsByFolder,
    ),
  );
}

class ExportSelectionDialog extends StatefulWidget {
  const ExportSelectionDialog({
    super.key,
    required this.folders,
    required this.documentsByFolder,
  });

  final List<Folder> folders;
  final Map<int, List<Document>> documentsByFolder;

  @override
  State<ExportSelectionDialog> createState() => _ExportSelectionDialogState();
}

class _ExportSelectionDialogState extends State<ExportSelectionDialog> {
  final Set<int> _selectedFolderIds = {};
  final Set<int> _selectedDocumentIds = {};
  final Set<int> _expandedFolderIds = {};

  List<Folder> _childrenOf(int? parentId) {
    return widget.folders.where((f) => f.parentId == parentId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<int> _descendantFolderIds(int folderId) {
    final result = <int>[];
    void walk(int id) {
      for (final child in _childrenOf(id)) {
        result.add(child.id);
        walk(child.id);
      }
    }

    walk(folderId);
    return result;
  }

  List<int> _documentIdsInFolderTree(int folderId) {
    final ids = <int>[
      for (final d in widget.documentsByFolder[folderId] ?? const <Document>[])
        d.id,
    ];
    for (final childId in _descendantFolderIds(folderId)) {
      for (final d in widget.documentsByFolder[childId] ?? const <Document>[]) {
        ids.add(d.id);
      }
    }
    return ids;
  }

  /// 勾选文件夹：默认选中其下全部子夹与文件；取消则全部去掉。
  void _toggleFolder(int folderId, bool select) {
    final folderIds = [folderId, ..._descendantFolderIds(folderId)];
    final docIds = _documentIdsInFolderTree(folderId);
    setState(() {
      if (select) {
        _selectedFolderIds.addAll(folderIds);
        _selectedDocumentIds.addAll(docIds);
        _expandedFolderIds.add(folderId);
      } else {
        _selectedFolderIds.removeAll(folderIds);
        _selectedDocumentIds.removeAll(docIds);
      }
    });
  }

  /// 单独勾选/取消文档；取消后若文件夹下已无选中项则移除该文件夹结构标记。
  void _toggleDocument(int documentId, Document document, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedDocumentIds.add(documentId);
      } else {
        _selectedDocumentIds.remove(documentId);
        _pruneEmptyFolderSelections(document.folderId);
      }
    });
  }

  void _pruneEmptyFolderSelections(int startFolderId) {
    var currentId = startFolderId;
    while (true) {
      final treeDocs = _documentIdsInFolderTree(currentId);
      final hasSelectedDoc = treeDocs.any(_selectedDocumentIds.contains);
      final childFolders = _descendantFolderIds(currentId);
      final hasSelectedChildFolder =
          childFolders.any(_selectedFolderIds.contains);
      if (!hasSelectedDoc && !hasSelectedChildFolder) {
        _selectedFolderIds.remove(currentId);
      } else {
        break;
      }
      Folder? folder;
      for (final f in widget.folders) {
        if (f.id == currentId) {
          folder = f;
          break;
        }
      }
      if (folder?.parentId == null) {
        break;
      }
      currentId = folder!.parentId!;
    }
  }

  bool? _folderCheckValue(int folderId) {
    final treeDocs = _documentIdsInFolderTree(folderId);
    final childFolders = _descendantFolderIds(folderId);
    final allDocsSelected = treeDocs.isEmpty ||
        treeDocs.every(_selectedDocumentIds.contains);
    final allFoldersSelected = childFolders.isEmpty ||
        childFolders.every(_selectedFolderIds.contains);
    final anyDoc = treeDocs.any(_selectedDocumentIds.contains);
    final anyFolder = childFolders.any(_selectedFolderIds.contains) ||
        _selectedFolderIds.contains(folderId);

    if (_selectedFolderIds.contains(folderId) &&
        allDocsSelected &&
        allFoldersSelected) {
      return true;
    }
    if (anyDoc || anyFolder || _selectedFolderIds.contains(folderId)) {
      return null; // 半选：仍导出该夹结构 + 已勾文件
    }
    return false;
  }

  bool get _hasSelection =>
      _selectedFolderIds.isNotEmpty || _selectedDocumentIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final roots = _childrenOf(null);

    return Dialog(
      backgroundColor: colors.sidebar,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.exportSelectTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.exportSelectHint,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: roots.isEmpty
                      ? Center(
                          child: Text(
                            l10n.emptyLibrary,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          children: [
                            for (final folder in roots)
                              _buildFolderNode(folder, colors, depth: 0),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: !_hasSelection
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              ExportSelectionResult(
                                selectedFolderIds:
                                    Set<int>.from(_selectedFolderIds),
                                selectedDocumentIds:
                                    Set<int>.from(_selectedDocumentIds),
                              ),
                            );
                          },
                    child: Text(l10n.export),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderNode(
    Folder folder,
    AppThemeColors colors, {
    required int depth,
  }) {
    final children = _childrenOf(folder.id);
    final docs = List<Document>.from(
      widget.documentsByFolder[folder.id] ?? const <Document>[],
    )..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final expanded = _expandedFolderIds.contains(folder.id);
    final checkValue = _folderCheckValue(folder.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedFolderIds.remove(folder.id);
              } else {
                _expandedFolderIds.add(folder.id);
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.only(left: depth * 12.0),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: colors.textSecondary,
                ),
                Checkbox(
                  tristate: true,
                  value: checkValue,
                  onChanged: (v) {
                    // true → 全选夹；false/null → 取消夹
                    _toggleFolder(folder.id, v == true);
                  },
                ),
                Icon(Icons.folder_outlined, size: 18, color: colors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    folder.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          for (final child in children)
            _buildFolderNode(child, colors, depth: depth + 1),
          for (final doc in docs)
            Padding(
              padding: EdgeInsets.only(left: (depth + 1) * 12.0 + 18),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectedDocumentIds.contains(doc.id),
                    onChanged: (v) => _toggleDocument(doc.id, doc, v),
                  ),
                  Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      doc.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
