import 'package:flutter/material.dart';

import '../data/models/document.dart';
import '../data/models/folder.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import 'name_dialog.dart';

typedef FolderAction = Future<void> Function(int? parentId);
typedef DocumentAction = Future<void> Function(int folderId);
typedef ItemSelect = void Function({int? folderId, int? documentId});
typedef RenameAction = Future<void> Function({int? folderId, int? documentId, required String name});
typedef DeleteAction = Future<void> Function({int? folderId, int? documentId});
/// 文档落到某夹；[beforeDocumentId] 为 null 表示夹内末尾，否则插到该文档前。
typedef ReorderDocumentAction = Future<void> Function({
  required int documentId,
  required int targetFolderId,
  int? beforeDocumentId,
});
/// 文件夹插到同级 [beforeFolderId] 之前；null 表示末尾。
typedef ReorderFolderAction = Future<void> Function({
  required int folderId,
  int? beforeFolderId,
});

/// 侧栏文档拖拽载荷。
class SidebarDocumentDragData {
  const SidebarDocumentDragData({
    required this.documentId,
    required this.sourceFolderId,
    required this.title,
  });

  final int documentId;
  final int sourceFolderId;
  final String title;
}

/// 侧栏文件夹拖拽载荷（同级互换顺序）。
class SidebarFolderDragData {
  const SidebarFolderDragData({
    required this.folderId,
    required this.parentId,
    required this.name,
  });

  final int folderId;
  final int? parentId;
  final String name;
}

class SidebarTree extends StatefulWidget {
  const SidebarTree({
    super.key,
    required this.folders,
    required this.documentsByFolder,
    required this.selectedFolderId,
    required this.selectedDocumentId,
    required this.onSelect,
    required this.onCreateFolder,
    required this.onCreateDocument,
    required this.onRename,
    required this.onDelete,
    this.onReorderDocument,
    this.onReorderFolder,
    this.onExport,
    this.onImport,
    this.transferBusy = false,
    this.condensed = false,
  });

  final List<Folder> folders;
  final Map<int, List<Document>> documentsByFolder;
  final int? selectedFolderId;
  final int? selectedDocumentId;
  final ItemSelect onSelect;
  final FolderAction onCreateFolder;
  final DocumentAction onCreateDocument;
  final RenameAction onRename;
  final DeleteAction onDelete;
  final ReorderDocumentAction? onReorderDocument;
  final ReorderFolderAction? onReorderFolder;
  final VoidCallback? onExport;
  final VoidCallback? onImport;
  final bool transferBusy;
  /// 左侧栏缩窄时：仅显示图标，文字进 Tooltip。
  final bool condensed;

  @override
  State<SidebarTree> createState() => _SidebarTreeState();
}

class _SidebarTreeState extends State<SidebarTree> {
  final Set<int> _expandedFolderIds = {};
  /// 拖拽悬停时插入指示：在该 id 上方腾空位。
  int? _insertBeforeDocumentId;
  int? _insertBeforeFolderId;

  List<Folder> _childrenOf(int? parentId) {
    final list = widget.folders.where((f) => f.parentId == parentId).toList();
    // folders 已按 sort_order 从仓库取出，保持相对顺序
    return list;
  }

  Widget _insertionGap(AppThemeColors colors) {
    return Container(
      height: 28,
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.primary.withValues(alpha: 0.45)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final compact = isCompactLayout(context);
    final condensed = widget.condensed;
    final roots = _childrenOf(null);
    final transferBusy = widget.transferBusy;
    // 仅图标、无边框、紧凑点击区；导入导出合计约占行宽 1/4。
    Widget transferIconButton({
      required Key key,
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
      bool showBusy = false,
    }) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          key: key,
          onPressed: transferBusy ? null : onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 18,
          icon: showBusy && transferBusy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : Icon(icon, color: colors.primary),
        ),
      );
    }

    final exportButton = transferIconButton(
      key: const Key('export_notebook_button'),
      tooltip: l10n.export,
      icon: Icons.file_upload_outlined,
      onPressed: widget.onExport,
      showBusy: true,
    );
    final importButton = transferIconButton(
      key: const Key('import_notebook_button'),
      tooltip: l10n.import,
      icon: Icons.file_download_outlined,
      onPressed: widget.onImport,
    );

    final transferActions = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (widget.onExport != null) Expanded(child: exportButton),
        if (widget.onImport != null) Expanded(child: importButton),
      ],
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            condensed ? 6 : 12,
            compact ? 8 : 12,
            condensed ? 6 : 12,
            8,
          ),
          child: condensed
              ? Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: l10n.newFolder,
                          child: IconButton(
                            key: const Key('new_folder_icon_button'),
                            onPressed: () => widget.onCreateFolder(null),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: Icon(
                              Icons.create_new_folder_outlined,
                              size: 20,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(flex: 1, child: transferActions),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onCreateFolder(null),
                        style: buildAppOutlinedButtonStyle(colors),
                        icon: const Icon(
                          Icons.create_new_folder_outlined,
                          size: 18,
                        ),
                        label: Text(l10n.newFolder),
                      ),
                    ),
                    Expanded(flex: 1, child: transferActions),
                  ],
                ),
        ),
        Expanded(
          child: roots.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: condensed ? 8 : 24,
                    ),
                    child: condensed
                        ? Tooltip(
                            message: l10n.emptyLibrary,
                            child: Icon(
                              Icons.folder_off_outlined,
                              color: colors.textSecondary,
                            ),
                          )
                        : Text(
                            l10n.emptyLibrary,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    condensed ? 4 : 8,
                    0,
                    condensed ? 4 : 8,
                    compact ? 16 : 8,
                  ),
                  children: roots
                      .map(
                        (folder) =>
                            _buildFolderNode(folder, colors, compact, depth: 0),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFolderNode(
    Folder folder,
    AppThemeColors colors,
    bool compact, {
    required int depth,
  }) {
    final condensed = widget.condensed;
    final children = _childrenOf(folder.id);
    final documents = widget.documentsByFolder[folder.id] ?? [];
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final isSelected = widget.selectedFolderId == folder.id &&
        widget.selectedDocumentId == null;
    final rowPadding = EdgeInsets.symmetric(
      horizontal: condensed ? 2 : 4,
      vertical: compact ? 8 : (condensed ? 6 : 2),
    );
    final indent = condensed ? (depth > 0 ? 8.0 : 0.0) : 0.0;

    Widget buildFolderRow({required bool hovering}) {
      return Material(
        color: hovering
            ? colors.primary.withValues(alpha: 0.12)
            : (isSelected ? colors.selected : Colors.transparent),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedFolderIds.remove(folder.id);
              } else {
                _expandedFolderIds.add(folder.id);
              }
            });
            widget.onSelect(folderId: folder.id);
          },
          child: Padding(
            padding: rowPadding,
            child: Row(
              children: [
                if (!condensed)
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                Icon(
                  isExpanded
                      ? Icons.folder_open_outlined
                      : Icons.folder_outlined,
                  size: condensed ? 20 : 18,
                  color: hovering ? colors.primary : colors.textSecondary,
                ),
                if (!condensed) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: hovering ? colors.primary : colors.textPrimary,
                        fontWeight:
                            hovering ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMenu(
                    colors: colors,
                    onRename: () async {
                      final name = await showNameDialog(
                        context: context,
                        title: context.l10n.renameFolder,
                        hint: context.l10n.folderName,
                        initialValue: folder.name,
                      );
                      if (name != null && name.trim().isNotEmpty) {
                        await widget.onRename(
                          folderId: folder.id,
                          name: name.trim(),
                        );
                      }
                    },
                    onDelete: () => widget.onDelete(folderId: folder.id),
                    onAddFolder: () => widget.onCreateFolder(folder.id),
                    onAddDocument: () => widget.onCreateDocument(folder.id),
                  ),
                ] else
                  Expanded(
                    child: _buildMenu(
                      colors: colors,
                      iconSize: 16,
                      onRename: () async {
                        final name = await showNameDialog(
                          context: context,
                          title: context.l10n.renameFolder,
                          hint: context.l10n.folderName,
                          initialValue: folder.name,
                        );
                        if (name != null && name.trim().isNotEmpty) {
                          await widget.onRename(
                            folderId: folder.id,
                            name: name.trim(),
                          );
                        }
                      },
                      onDelete: () => widget.onDelete(folderId: folder.id),
                      onAddFolder: () => widget.onCreateFolder(folder.id),
                      onAddDocument: () => widget.onCreateDocument(folder.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // 文件夹：接文档（移入/夹内）与同级文件夹（插到自己前面）；悬停自动展开
    final folderDropTarget = DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data is SidebarDocumentDragData) {
          return true;
        }
        if (data is SidebarFolderDragData) {
          return data.folderId != folder.id && data.parentId == folder.parentId;
        }
        return false;
      },
      onMove: (details) {
        final data = details.data;
        // 文档拖到文件夹上：自动展开以便看清内部位置
        if (data is SidebarDocumentDragData) {
          if (!_expandedFolderIds.contains(folder.id)) {
            setState(() => _expandedFolderIds.add(folder.id));
          }
          if (_insertBeforeFolderId != null ||
              _insertBeforeDocumentId != null) {
            setState(() {
              _insertBeforeFolderId = null;
              _insertBeforeDocumentId = null;
            });
          }
        } else if (data is SidebarFolderDragData) {
          if (_insertBeforeFolderId != folder.id) {
            setState(() {
              _insertBeforeFolderId = folder.id;
              _insertBeforeDocumentId = null;
            });
          }
        }
      },
      onLeave: (data) {
        if (_insertBeforeFolderId == folder.id) {
          setState(() => _insertBeforeFolderId = null);
        }
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          _insertBeforeFolderId = null;
          _insertBeforeDocumentId = null;
        });
        if (data is SidebarDocumentDragData) {
          setState(() => _expandedFolderIds.add(folder.id));
          // 落到文件夹本体：放入该夹末尾
          widget.onReorderDocument?.call(
            documentId: data.documentId,
            targetFolderId: folder.id,
            beforeDocumentId: null,
          );
        } else if (data is SidebarFolderDragData) {
          // 插到本夹前面（同级让位）
          widget.onReorderFolder?.call(
            folderId: data.folderId,
            beforeFolderId: folder.id,
          );
        }
      },
      builder: (context, candidate, rejected) {
        // 仅在插入位显示绿色空隙，目标文件夹本身不高亮描边
        final showGap =
            _insertBeforeFolderId == folder.id && candidate.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showGap) _insertionGap(colors),
            buildFolderRow(hovering: false),
          ],
        );
      },
    );

    final folderDraggable = LongPressDraggable<SidebarFolderDragData>(
      data: SidebarFolderDragData(
        folderId: folder.id,
        parentId: folder.parentId,
        name: folder.name,
      ),
      delay: const Duration(milliseconds: 280),
      onDragEnd: (_) {
        if (_insertBeforeFolderId != null || _insertBeforeDocumentId != null) {
          setState(() {
            _insertBeforeFolderId = null;
            _insertBeforeDocumentId = null;
          });
        }
      },
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(6),
        color: colors.sidebar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: buildFolderRow(hovering: false),
      ),
      child: folderDropTarget,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: condensed
              ? Tooltip(
                  message: folder.name,
                  waitDuration: const Duration(milliseconds: 400),
                  child: folderDraggable,
                )
              : folderDraggable,
        ),
        if (isExpanded) ...[
          ...children.map(
            (child) => Padding(
              padding: EdgeInsets.only(left: condensed ? 0 : 16),
              child: _buildFolderNode(
                child,
                colors,
                compact,
                depth: depth + 1,
              ),
            ),
          ),
          ...documents.map(
            (doc) => Padding(
              padding: EdgeInsets.only(left: condensed ? indent + 8 : 24),
              child: _buildDocumentTile(doc, colors, compact),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentTile(
    Document document,
    AppThemeColors colors,
    bool compact,
  ) {
    final condensed = widget.condensed;
    final isSelected = widget.selectedDocumentId == document.id;

    Widget buildDocRow({required bool hovering}) {
      return Material(
        color: hovering
            ? colors.primary.withValues(alpha: 0.12)
            : (isSelected ? colors.selected : Colors.transparent),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => widget.onSelect(
            folderId: document.folderId,
            documentId: document.id,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: condensed ? 2 : 4,
              vertical: compact ? 10 : (condensed ? 6 : 4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: condensed ? 20 : 18,
                  color: hovering ? colors.primary : colors.textSecondary,
                ),
                if (!condensed) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      document.title,
                      style: TextStyle(
                        fontSize: 14,
                        color: hovering ? colors.primary : null,
                        fontWeight:
                            hovering ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMenu(
                    colors: colors,
                    onRename: () async {
                      final name = await showNameDialog(
                        context: context,
                        title: context.l10n.renameDocument,
                        hint: context.l10n.documentTitle,
                        initialValue: document.title,
                      );
                      if (name != null && name.trim().isNotEmpty) {
                        await widget.onRename(
                          documentId: document.id,
                          name: name.trim(),
                        );
                      }
                    },
                    onDelete: () => widget.onDelete(documentId: document.id),
                  ),
                ] else
                  Expanded(
                    child: _buildMenu(
                      colors: colors,
                      iconSize: 16,
                      onRename: () async {
                        final name = await showNameDialog(
                          context: context,
                          title: context.l10n.renameDocument,
                          hint: context.l10n.documentTitle,
                          initialValue: document.title,
                        );
                        if (name != null && name.trim().isNotEmpty) {
                          await widget.onRename(
                            documentId: document.id,
                            name: name.trim(),
                          );
                        }
                      },
                      onDelete: () => widget.onDelete(documentId: document.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // 文档：接收其他文档，插到自己前面（同夹让位；跨夹则移动到本夹并插到前面）
    final docDropTarget = DragTarget<SidebarDocumentDragData>(
      onWillAcceptWithDetails: (details) {
        return details.data.documentId != document.id;
      },
      onMove: (details) {
        if (_insertBeforeDocumentId != document.id) {
          setState(() {
            _insertBeforeDocumentId = document.id;
            _insertBeforeFolderId = null;
          });
        }
      },
      onLeave: (data) {
        if (_insertBeforeDocumentId == document.id) {
          setState(() => _insertBeforeDocumentId = null);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _insertBeforeDocumentId = null;
          _insertBeforeFolderId = null;
        });
        widget.onReorderDocument?.call(
          documentId: details.data.documentId,
          targetFolderId: document.folderId,
          beforeDocumentId: document.id,
        );
      },
      builder: (context, candidate, rejected) {
        // 仅在插入位显示绿色空隙，下一文档本身不高亮描边
        final showGap =
            _insertBeforeDocumentId == document.id && candidate.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showGap) _insertionGap(colors),
            buildDocRow(hovering: false),
          ],
        );
      },
    );

    // 长按拖动：夹内插位 / 跨夹移动
    final draggable = LongPressDraggable<SidebarDocumentDragData>(
      data: SidebarDocumentDragData(
        documentId: document.id,
        sourceFolderId: document.folderId,
        title: document.title,
      ),
      delay: const Duration(milliseconds: 280),
      onDragEnd: (_) {
        if (_insertBeforeFolderId != null || _insertBeforeDocumentId != null) {
          setState(() {
            _insertBeforeFolderId = null;
            _insertBeforeDocumentId = null;
          });
        }
      },
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(6),
        color: colors.sidebar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: buildDocRow(hovering: false),
      ),
      child: docDropTarget,
    );

    if (condensed) {
      return Tooltip(
        message: document.title,
        waitDuration: const Duration(milliseconds: 400),
        child: draggable,
      );
    }
    return draggable;
  }

  Widget _buildMenu({
    required AppThemeColors colors,
    required VoidCallback onRename,
    required VoidCallback onDelete,
    VoidCallback? onAddFolder,
    VoidCallback? onAddDocument,
    double iconSize = 18,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: iconSize, color: colors.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onSelected: (value) {
        switch (value) {
          case 'rename':
            onRename();
          case 'delete':
            onDelete();
          case 'add_folder':
            onAddFolder?.call();
          case 'add_document':
            onAddDocument?.call();
        }
      },
      itemBuilder: (context) {
        final l10n = context.l10n;
        return [
          if (onAddFolder != null)
            PopupMenuItem(value: 'add_folder', child: Text(l10n.newSubfolder)),
          if (onAddDocument != null)
            PopupMenuItem(value: 'add_document', child: Text(l10n.newDocument)),
          PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ];
      },
    );
  }
}