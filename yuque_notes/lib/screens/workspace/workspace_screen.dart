import 'package:flutter/material.dart';

import '../../data/models/cloud_session.dart';
import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../../services/avatar_service.dart';
import '../../services/cloud_auth_api.dart';
import '../../services/community_sync_service.dart';
import '../../services/notebook_transfer_service.dart';
import '../../services/session_service.dart';
import '../../app_branding.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/contact_us_dialog.dart';
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
    CommunitySyncService? communitySyncService,
    this.initialSelectedDocument,
    this.themeMode = ThemeMode.light,
    this.onToggleTheme,
  })  : _cloudAuthApi = cloudAuthApi,
        _avatarService = avatarService,
        _communitySyncService = communitySyncService;

  final User localUser;
  final User? cloudUser;
  final Document? initialSelectedDocument;
  final ThemeMode themeMode;
  final VoidCallback? onToggleTheme;
  final Future<void> Function(User? cloudUser) onCloudAuthChanged;
  final CloudAuthApi? _cloudAuthApi;
  final AvatarService? _avatarService;
  final CommunitySyncService? _communitySyncService;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final _folderRepository = FolderRepository();
  final _documentRepository = DocumentRepository();
  late final AvatarService _avatarService =
      widget._avatarService ?? AvatarService();
  late final CommunitySyncService _communitySyncService =
      widget._communitySyncService ?? CommunitySyncService();
  final _sessionService = SessionService();
  final _notebookTransferService = NotebookTransferService();
  bool _transferBusy = false;

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
    final initialDocument = widget.initialSelectedDocument;
    if (initialDocument != null) {
      _selectedDocument = initialDocument;
      _selectedFolderId = initialDocument.folderId;
      _loading = false;
    } else {
      _loadTree();
    }
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
    // 文件夹重名等业务错误：弹窗更明确
    if (message.contains('不能重复') || message.contains('不能为空')) {
      _showErrorDialog('操作失败', message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportNotebook() async {
    if (_transferBusy) {
      return;
    }
    setState(() => _transferBusy = true);
    try {
      final path = await _notebookTransferService.exportNotebook(
        userId: _localUserId,
      );
      if (!mounted || path == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出：$path')),
      );
    } on NotebookTransferException catch (e) {
      await _showErrorDialog('导出失败', e.message);
    } catch (e) {
      await _showErrorDialog('导出失败', e.toString());
    } finally {
      if (mounted) {
        setState(() => _transferBusy = false);
      }
    }
  }

  Future<void> _importNotebook() async {
    if (_transferBusy) {
      return;
    }
    setState(() => _transferBusy = true);
    try {
      final result = await _notebookTransferService.importNotebook(
        userId: _localUserId,
      );
      if (!mounted || result == null) {
        return;
      }
      await _loadTree();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：新建文件夹 ${result.foldersImported} 个，文档 ${result.documentsImported} 篇',
          ),
        ),
      );
    } on NotebookTransferException catch (e) {
      await _showErrorDialog('导入失败', e.message);
    } on RepositoryException catch (e) {
      await _showErrorDialog('导入失败', e.message);
    } catch (e) {
      await _showErrorDialog('导入失败', e.toString());
    } finally {
      if (mounted) {
        setState(() => _transferBusy = false);
      }
    }
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
    await widget.onCloudAuthChanged(session.toDisplayUser());
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

    var session = await _sessionService.getCloudSession();
    if (session == null) {
      if (mounted) {
        _showError('Please sign in first');
      }
      return;
    }

    try {
      final updatedAvatar = await widget._cloudAuthApi?.updateAvatar(
        accessToken: session.accessToken,
        avatar: result.dataUri,
      );
      await _sessionService.updateCloudAvatar(updatedAvatar ?? result.dataUri);
    } on CloudAuthException catch (error) {
      _showError(error.message);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _avatar = result.dataUri);
    final cloudUser = widget.cloudUser!;
    await widget.onCloudAuthChanged(
      User(
        id: cloudUser.id,
        username: cloudUser.username,
        createdAt: cloudUser.createdAt,
        avatar: result.dataUri,
      ),
    );
  }

  Future<bool> _syncDocumentToCommunity() async {
    if (_selectedDocument == null) {
      return false;
    }

    // 未登录：先弹登录；登录成功后继续上传。
    if (!_isCloudLoggedIn) {
      await _showAuthDialog();
      if (!mounted) {
        return false;
      }
    }

    var session = await _sessionService.getCloudSession();
    if (session == null) {
      if (mounted) {
        _showError('请先登录后再上传云端');
      }
      return false;
    }

    // 登录后 localUser 可能已切换；游客文档仍不可上传。
    if (AuthRepository.isLocalGuest(widget.localUser)) {
      if (mounted) {
        _showError('当前为本地游客笔记，请登录社区账号后新建文档再上传');
      }
      return false;
    }

    try {
      await _syncDocumentWithSession(session.accessToken);
      return true;
    } on CommunitySyncException catch (error) {
      if (error.statusCode == 401 && widget._cloudAuthApi != null) {
        final refreshed = await _sessionService.refreshCloudSession(
          widget._cloudAuthApi!,
        );
        if (refreshed != null && refreshed.accessToken != session.accessToken) {
          try {
            await _syncDocumentWithSession(refreshed.accessToken);
            return true;
          } on CommunitySyncException catch (retryError) {
            _showError(retryError.message);
            rethrow;
          }
        }
        if (!mounted) {
          return false;
        }
        await widget.onCloudAuthChanged(null);
        _showError('登录已过期，请重新登录');
        return false;
      }
      _showError(error.message);
      rethrow;
    }
  }

  Future<void> _syncDocumentWithSession(String accessToken) async {
    await _communitySyncService.syncDocumentToCommunity(
      documentId: _selectedDocument!.id,
      localUserId: _localUserId,
      accessToken: accessToken,
    );
    await _refreshDocument(_selectedDocument!.id);
  }

  Future<void> _logout() async {
    await _sessionService.clearCloudSession();
    if (!mounted) {
      return;
    }
    await widget.onCloudAuthChanged(null);
  }

  Widget _buildProfileSection() {
    final colors = context.appColors;
    if (!_isCloudLoggedIn) {
      return InkWell(
        key: const Key('guest_login_prompt'),
        onTap: _showAuthDialog,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 36,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '请登录',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.primary,
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
              Text(
                '点击头像更换',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onTreeSelect({int? folderId, int? documentId}) async {
    setState(() => _selectedFolderId = folderId);
    if (documentId != null) {
      final doc = await _documentRepository.getDocument(
        userId: _localUserId,
        documentId: documentId,
      );
      if (!mounted) {
        return;
      }
      setState(() => _selectedDocument = doc);
    } else {
      setState(() => _selectedDocument = null);
    }
  }

  void _closeDocument() {
    setState(() => _selectedDocument = null);
  }

  Widget _buildLibraryHeader({required bool compact}) {
    final isDark = widget.themeMode == ThemeMode.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 8 : 16, 8, 8),
      child: Row(
        children: [
          AppLogo(size: compact ? 36 : 44),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // 应用内全名；手机桌面图标短名见 Android label「NN」。
              AppBranding.fullName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const Key('theme_toggle_button'),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            tooltip: isDark ? '日间模式' : '黑夜模式',
            onPressed: widget.onToggleTheme,
          ),
          if (_isCloudLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout, size: 20),
              tooltip: '退出登录',
              onPressed: _logout,
            ),
        ],
      ),
    );
  }

  Widget _buildLibraryPane({
    required bool compact,
    required bool showRightBorder,
  }) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: showRightBorder
            ? Border(right: BorderSide(color: colors.border))
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLibraryHeader(compact: compact),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildProfileSection(),
            ),
            Divider(height: compact ? 16 : 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SidebarTree(
                      folders: _folders,
                      documentsByFolder: _documentsByFolder,
                      selectedFolderId: _selectedFolderId,
                      selectedDocumentId: _selectedDocument?.id,
                      onSelect: _onTreeSelect,
                      onCreateFolder: _createFolder,
                      onCreateDocument: _createDocument,
                      onRename: _rename,
                      onDelete: _delete,
                    ),
            ),
            // Windows / Android 共用：底部「联系我们」
            _buildContactUsBar(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildContactUsBar(AppThemeColors colors) {
    return Material(
      color: colors.sidebar,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: colors.border),
            // 导入 / 导出：整库结构（.nnb JSON），Windows / Android 均可用
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('export_notebook_button'),
                      onPressed: _transferBusy ? null : _exportNotebook,
                      style: buildAppOutlinedButtonStyle(colors),
                      icon: _transferBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('导出'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('import_notebook_button'),
                      onPressed: _transferBusy ? null : _importNotebook,
                      style: buildAppOutlinedButtonStyle(colors),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('导入'),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              key: const Key('contact_us_entry'),
              onTap: () => showContactUsDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.support_agent_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '联系我们',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSelectedDocument(String markdown) async {
    await _documentRepository.updateDocumentContent(
      userId: _localUserId,
      documentId: _selectedDocument!.id,
      content: markdown,
    );
    await _refreshDocument(_selectedDocument!.id);
  }

  Widget _buildEditorPane({
    VoidCallback? onBack,
    bool showTitleBar = true,
  }) {
    if (_selectedDocument == null) {
      return const _WelcomePanel();
    }
    return DocumentEditorPanel(
      key: ValueKey(_selectedDocument!.id),
      document: _selectedDocument!,
      // 始终展示「上传云端」；未登录时由 onSyncToCommunity 内拉起登录。
      canSyncToCommunity: true,
      isSyncedToCommunity: _selectedDocument!.syncedToCommunity,
      onSyncToCommunity: _syncDocumentToCommunity,
      onBack: onBack,
      showTitleBar: showTitleBar,
      onSave: _saveSelectedDocument,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);
    final colors = context.appColors;

    if (compact) {
      final showingEditor = _selectedDocument != null;
      return PopScope(
        canPop: !showingEditor,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && showingEditor) {
            _closeDocument();
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: showingEditor
              ? AppBar(
                  leading: IconButton(
                    key: const Key('document_back_button'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '返回目录',
                    onPressed: _closeDocument,
                  ),
                  title: Text(
                    _selectedDocument!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: colors.sidebar,
                  foregroundColor: colors.textPrimary,
                )
              : null,
          body: showingEditor
              ? _buildEditorPane(
                  onBack: null,
                  showTitleBar: false,
                )
              : _buildLibraryPane(compact: true, showRightBorder: false),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: _buildLibraryPane(compact: false, showRightBorder: true),
          ),
          Expanded(child: _buildEditorPane()),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final compact = isCompactLayout(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: compact ? 96 : 140),
            const SizedBox(height: 16),
            Text(
              '选择或创建一个文档开始记录',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
