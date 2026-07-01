import 'package:flutter/material.dart';

import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../../data/models/user.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/document_editor_panel.dart';
import '../../widgets/name_dialog.dart';
import '../../widgets/sidebar_tree.dart';
import '../auth/login_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.user});

  final User user;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final _folderRepository = FolderRepository();
  final _documentRepository = DocumentRepository();
  final _sessionService = SessionService();

  List<Folder> _folders = [];
  Map<int, List<Document>> _documentsByFolder = {};
  Document? _selectedDocument;
  int? _selectedFolderId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    setState(() => _loading = true);
    try {
      final folders = await _folderRepository.getAllFolders(userId: widget.user.id);
      final docsMap = <int, List<Document>>{};
      for (final folder in folders) {
        docsMap[folder.id] = await _documentRepository.getDocumentsInFolder(
          userId: widget.user.id,
          folderId: folder.id,
        );
      }
      setState(() {
        _folders = folders;
        _documentsByFolder = docsMap;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshDocument(int documentId) async {
    final doc = await _documentRepository.getDocument(
      userId: widget.user.id,
      documentId: documentId,
    );
    if (doc != null && mounted) {
      setState(() => _selectedDocument = doc);
    }
    await _loadTree();
  }

  Future<void> _createFolder(int? parentId) async {
    final name = await showNameDialog(
      context: context,
      title: '新建文件夹',
      hint: '文件夹名称',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    try {
      await _folderRepository.createFolder(
        userId: widget.user.id,
        parentId: parentId,
        name: name,
      );
      await _loadTree();
    } on RepositoryException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _createDocument(int folderId) async {
    final title = await showNameDialog(
      context: context,
      title: '新建文档',
      hint: '文档标题',
    );
    if (title == null || title.trim().isEmpty) {
      return;
    }
    try {
      final doc = await _documentRepository.createDocument(
        userId: widget.user.id,
        folderId: folderId,
        title: title,
      );
      await _loadTree();
      setState(() {
        _selectedFolderId = folderId;
        _selectedDocument = doc;
      });
    } on RepositoryException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _rename({int? folderId, int? documentId, required String name}) async {
    try {
      if (folderId != null) {
        await _folderRepository.renameFolder(
          userId: widget.user.id,
          folderId: folderId,
          name: name,
        );
      } else if (documentId != null) {
        final doc = await _documentRepository.renameDocument(
          userId: widget.user.id,
          documentId: documentId,
          title: name,
        );
        if (_selectedDocument?.id == documentId) {
          setState(() => _selectedDocument = doc);
        }
      }
      await _loadTree();
    } on RepositoryException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _delete({int? folderId, int? documentId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(folderId != null ? '删除文件夹' : '删除文档'),
        content: Text(folderId != null
            ? '确定删除该文件夹及其所有子内容？'
            : '确定删除该文档？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      if (folderId != null) {
        await _folderRepository.deleteFolder(
          userId: widget.user.id,
          folderId: folderId,
        );
        if (_selectedFolderId == folderId) {
          setState(() {
            _selectedFolderId = null;
            _selectedDocument = null;
          });
        }
      } else if (documentId != null) {
        await _documentRepository.deleteDocument(
          userId: widget.user.id,
          documentId: documentId,
        );
        if (_selectedDocument?.id == documentId) {
          setState(() => _selectedDocument = null);
        }
      }
      await _loadTree();
    } on RepositoryException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    await _sessionService.clearSession();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.sidebar,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '我的知识库',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 20),
                          tooltip: '退出登录',
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.user.username,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : SidebarTree(
                            folders: _folders,
                            documentsByFolder: _documentsByFolder,
                            selectedFolderId: _selectedFolderId,
                            selectedDocumentId: _selectedDocument?.id,
                            onSelect: ({folderId, documentId}) async {
                              setState(() => _selectedFolderId = folderId);
                              if (documentId != null) {
                                final doc = await _documentRepository.getDocument(
                                  userId: widget.user.id,
                                  documentId: documentId,
                                );
                                setState(() => _selectedDocument = doc);
                              } else {
                                setState(() => _selectedDocument = null);
                              }
                            },
                            onCreateFolder: _createFolder,
                            onCreateDocument: _createDocument,
                            onRename: _rename,
                            onDelete: _delete,
                          ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _selectedDocument != null
                ? DocumentEditorPanel(
                    key: ValueKey(_selectedDocument!.id),
                    document: _selectedDocument!,
                    onSave: (markdown) async {
                      await _documentRepository.updateDocumentContent(
                        userId: widget.user.id,
                        documentId: _selectedDocument!.id,
                        content: markdown,
                      );
                      await _refreshDocument(_selectedDocument!.id);
                    },
                  )
                : const _WelcomePanel(),
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            '选择或创建一个文档开始记录',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}