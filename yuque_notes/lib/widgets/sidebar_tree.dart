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

  List<Folder> _childrenOf(int? parentId) {
    return widget.folders.where((f) => f.parentId == parentId).toList();
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

    final row = Material(
      color: isSelected ? colors.selected : Colors.transparent,
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
                isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
                size: condensed ? 20 : 18,
                color: colors.textSecondary,
              ),
              if (!condensed) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    folder.name,
                    style: const TextStyle(fontSize: 14),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: condensed
              ? Tooltip(message: folder.name, waitDuration: const Duration(milliseconds: 400), child: row)
              : row,
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
    final row = Material(
      color: isSelected ? colors.selected : Colors.transparent,
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
                color: colors.textSecondary,
              ),
              if (!condensed) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    document.title,
                    style: const TextStyle(fontSize: 14),
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

    if (condensed) {
      return Tooltip(
        message: document.title,
        waitDuration: const Duration(milliseconds: 400),
        child: row,
      );
    }
    return row;
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