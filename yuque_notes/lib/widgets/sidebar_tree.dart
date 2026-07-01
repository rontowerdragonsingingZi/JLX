import 'package:flutter/material.dart';

import '../data/models/document.dart';
import '../data/models/folder.dart';
import '../theme/app_theme.dart';
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
    final roots = _childrenOf(null);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onCreateFolder(null),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('新建文件夹'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: roots.isEmpty
              ? const Center(
                  child: Text(
                    '暂无内容，请创建文件夹',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: roots.map(_buildFolderNode).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFolderNode(Folder folder) {
    final children = _childrenOf(folder.id);
    final documents = widget.documentsByFolder[folder.id] ?? [];
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final isSelected = widget.selectedFolderId == folder.id &&
        widget.selectedDocumentId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: isSelected ? AppColors.selected : Colors.transparent,
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const Icon(Icons.folder_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildMenu(
                    onRename: () async {
                      final name = await showNameDialog(
                        context: context,
                        title: '重命名文件夹',
                        hint: '文件夹名称',
                        initialValue: folder.name,
                      );
                      if (name != null && name.trim().isNotEmpty) {
                        await widget.onRename(folderId: folder.id, name: name.trim());
                      }
                    },
                    onDelete: () => widget.onDelete(folderId: folder.id),
                    onAddFolder: () => widget.onCreateFolder(folder.id),
                    onAddDocument: () => widget.onCreateDocument(folder.id),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _buildFolderNode(child),
            ),
          ),
          ...documents.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _buildDocumentTile(doc),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentTile(Document document) {
    final isSelected = widget.selectedDocumentId == document.id;
    return Material(
      color: isSelected ? AppColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => widget.onSelect(
          folderId: document.folderId,
          documentId: document.id,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  document.title,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildMenu(
                onRename: () async {
                  final name = await showNameDialog(
                    context: context,
                    title: '重命名文档',
                    hint: '文档标题',
                    initialValue: document.title,
                  );
                  if (name != null && name.trim().isNotEmpty) {
                    await widget.onRename(documentId: document.id, name: name.trim());
                  }
                },
                onDelete: () => widget.onDelete(documentId: document.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu({
    required VoidCallback onRename,
    required VoidCallback onDelete,
    VoidCallback? onAddFolder,
    VoidCallback? onAddDocument,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 18, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
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
      itemBuilder: (context) => [
        if (onAddFolder != null)
          const PopupMenuItem(value: 'add_folder', child: Text('新建子文件夹')),
        if (onAddDocument != null)
          const PopupMenuItem(value: 'add_document', child: Text('新建文档')),
        const PopupMenuItem(value: 'rename', child: Text('重命名')),
        const PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );
  }
}