import 'package:flutter/material.dart';

import '../../data/models/cloud_session.dart';
import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../../data/models/user.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../../services/avatar_service.dart';
import '../../services/cloud_auth_api.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/document_editor_panel.dart';
import '../../widgets/name_dialog.dart';
import '../../widgets/sidebar_tree.dart';
import '../../widgets/user_avatar.dart';
import '../auth/auth_dialog.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.localUser,
    required this.onCloudAuthChanged,
    this.cloudUser,
    CloudAuthApi? cloudAuthApi,
    AvatarService? avatarService,
  })  : _cloudAuthApi = cloudAuthApi,
        _avatarService = avatarService;

  final User localUser;
  final User? cloudUser;
  final void Function(User? cloudUser) onCloudAuthChanged;
  final CloudAuthApi? _cloudAuthApi;
  final AvatarService? _avatarService;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final _folderRepository = FolderRepository();
  final _documentRepository = DocumentRepository();
  late final AvatarService _avatarService =
      widget._avatarService ?? AvatarService();
  final _sessionService = SessionService();

  List<Folder> _folders = [];
  Map<int, List<Document>> _documentsByFolder = {};
  Document? _selectedDocument;
  int? _selectedFolderId;
  bool _loading = true;
  String? _avatar;

  int get _localUserId => widget.localUser.id;

  bool get _isCloudLoggedIn => widget.cloudUser != null;

  @override
  void initState() {
    super.initState();
    _avatar = widget.cloudUser?.avatar;
    _loadTree();
  }

  @override
  void didUpdateWidget(WorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloudUser?.avatar != widget.cloudUser?.avatar ||
        oldWidget.cloudUser?.id != widget.cloudUser?.id) {
      _avatar = widget.cloudUser?.avatar;
    }
    if (oldWidget.localUser.id != widget.localUser.id) {
      _loadTree();
    }
  }

  Future<void> _loadTree() async {
    if (!mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      final folders =
          await _folderRepository.getAllFolders(userId: _localUserId);
      final docsMap = <int, List<Document>>{};
      for (final folder in folders) {
        docsMap[folder.id] = await _documentRepository.getDocumentsInFolder(
          userId: _localUserId,
          folderId: folder.id,
        );
      }
      if (!mounted) {
        return;
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
      userId: _localUserId,
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
        userId: _localUserId,
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
        userId: _localUserId,
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
          userId: _localUserId,
          folderId: folderId,
          name: name,
        );
      } else if (documentId != null) {
        final doc = await _documentRepository.renameDocument(
          userId: _localUserId,
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
          userId: _localUserId,
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
          userId: _localUserId,
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

  Future<void> _showAuthDialog() async {
    final result = await showAuthDialog(
      context,
      cloudAuthApi: widget._cloudAuthApi,
    );
    if (result == null || !mounted) {
      return;
    }
    final session = CloudSession.fromAuthResult(result);
    await _sessionService.saveCloudSession(session);
    if (!mounted) {
      return;
    }
    widget.onCloudAuthChanged(session.toDisplayUser());
  }

  Future<void> _pickAvatar() async {
    if (!_isCloudLoggedIn) {
      return;
    }

    final result = await _avatarService.pickAvatarDataUri();
    if (!result.isSuccess) {
      if (result.errorMessage != null && mounted) {
        _showError(result.errorMessage!);
      }
      return;
    }

    await _sessionService.updateCloudAvatar(result.dataUri);
    if (!mounted) {
      return;
    }
    setState(() => _avatar = result.dataUri);
    final cloudUser = widget.cloudUser!;
    widget.onCloudAuthChanged(
      User(
        id: cloudUser.id,
        username: cloudUser.username,
        createdAt: cloudUser.createdAt,
        avatar: result.dataUri,
      ),
    );
  }

  Future<void> _logout() async {
    await _sessionService.clearCloudSession();
    if (!mounted) {
      return;
    }
    widget.onCloudAuthChanged(null);
  }

  Widget _buildProfileSection() {
    if (!_isCloudLoggedIn) {
      return InkWell(
        key: const Key('guest_login_prompt'),
        onTap: _showAuthDialog,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 36,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '请登录',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cloudUser = widget.cloudUser!;
    return Row(
      children: [
        UserAvatar(
          avatar: _avatar,
          onTap: _pickAvatar,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cloudUser.username,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                '点击头像更换',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
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
                        if (_isCloudLoggedIn)
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
                    child: _buildProfileSection(),
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
                                  userId: _localUserId,
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
                        userId: _localUserId,
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