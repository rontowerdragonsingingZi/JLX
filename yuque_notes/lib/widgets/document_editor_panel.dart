import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../data/models/document.dart' as models;
import '../editor/editor_persistence.dart';
import '../editor/image_storage.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import 'mobile_format_panel.dart';
import 'quill_image_embed.dart';

class DocumentEditorPanel extends StatefulWidget {
  const DocumentEditorPanel({
    super.key,
    required this.document,
    required this.onSave,
    this.canSyncToCommunity = false,
    this.isSyncedToCommunity,
    this.onSyncToCommunity,
    this.onBack,
    this.showTitleBar = true,
  });

  final models.Document document;
  final Future<void> Function(String markdown) onSave;

  /// 是否显示「上传云端」按钮（未登录时也应为 true，由回调内要求登录）。
  final bool canSyncToCommunity;

  /// 是否已同步；默认取 [document.syncedToCommunity]。
  final bool? isSyncedToCommunity;

  /// 返回 true 表示上传成功；取消登录 / 失败返回 false。
  final Future<bool> Function()? onSyncToCommunity;

  /// 手机端返回目录；桌面分栏布局传 null。
  final VoidCallback? onBack;

  /// 为 false 时标题栏由外层 AppBar 负责（手机端）。
  final bool showTitleBar;

  @override
  State<DocumentEditorPanel> createState() => _DocumentEditorPanelState();
}

class _DocumentEditorPanelState extends State<DocumentEditorPanel> {
  late QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  bool _saving = false;
  bool _syncing = false;
  bool _formatPanelOpen = false;
  int _selectedImageWidth = defaultImageWidth;
  final Map<String, int> _imageWidths = {};

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _imageWidths.addAll(parseAllImageWidths(widget.document.content));
    _controller = QuillController(
      document: markdownToDocument(widget.document.content),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void didUpdateWidget(DocumentEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _controller.dispose();
      _imageWidths
        ..clear()
        ..addAll(parseAllImageWidths(widget.document.content));
      _controller = QuillController(
        document: markdownToDocument(widget.document.content),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isSynced =>
      widget.isSyncedToCommunity ?? widget.document.syncedToCommunity;

  Future<void> _syncToCommunity() async {
    final onSync = widget.onSyncToCommunity;
    if (onSync == null) {
      return;
    }

    setState(() => _syncing = true);
    try {
      final ok = await onSync();
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已上传云端')),
        );
      }
    } catch (_) {
      // Workspace surfaces the error message.
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final markdown = deltaToMarkdown(
        _controller.document,
        imageWidths: _imageWidths,
      );
      await widget.onSave(markdown);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _insertImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取图片数据')),
        );
      }
      return;
    }

    final dataUri =
        encodeImageDataUri(bytes, mimeFromExtension(picked.extension));
    final index = _controller.selection.baseOffset;
    _imageWidths[dataUri] = _selectedImageWidth;
    _controller.replaceText(
      index,
      0,
      BlockEmbed.image(dataUri),
      null,
    );
    _controller.moveCursorToPosition(index + 1);
  }

  Future<void> _resizeSelectedImage() async {
    final offset = _controller.selection.baseOffset;
    final src = findImageSrcAtOffset(_controller.document, offset);
    if (src == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请将光标放在要调整的图片上')),
        );
      }
      return;
    }

    final currentWidth = _imageWidths[src] ??
        parseImageWidth(widget.document.content, src) ??
        _selectedImageWidth;
    final widthText = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '$currentWidth');
        return AlertDialog(
          title: const Text('调整图片宽度'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '宽度（像素）',
              suffixText: 'px',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    final width = int.tryParse(widthText ?? '');
    if (width == null || width <= 0) {
      return;
    }

    final result = applyImageWidthAtOffset(
      document: _controller.document,
      currentWidths: _imageWidths,
      offset: offset,
      newWidth: width,
    );
    if (result == null) {
      return;
    }

    setState(() {
      _selectedImageWidth = width;
      _imageWidths
        ..clear()
        ..addAll(result.imageWidths);
    });
    _controller.document = markdownToDocument(result.updatedMarkdown);
  }

  Widget _buildBusyIcon(bool busy, IconData icon) {
    if (busy) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(icon, size: 18);
  }

  List<Widget> _buildHeaderActions({required bool compact}) {
    final actions = <Widget>[];
    if (widget.canSyncToCommunity && widget.onSyncToCommunity != null) {
      if (_isSynced) {
        actions.add(
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Chip(
              key: Key('synced_to_community_badge'),
              label: Text('已上传'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      }
      // 手机 / 桌面都用带文字按钮，避免只剩图标时“功能不见了”。
      actions.add(
        TextButton.icon(
          key: const Key('sync_to_community_button'),
          onPressed: _syncing ? null : _syncToCommunity,
          icon: _buildBusyIcon(_syncing, Icons.cloud_upload_outlined),
          label: const Text('上传云端'),
        ),
      );
    }
    actions.add(
      TextButton.icon(
        onPressed: _saving ? null : _save,
        icon: _buildBusyIcon(_saving, Icons.save_outlined),
        label: const Text('保存'),
      ),
    );
    return actions;
  }

  /// Windows：完整 Quill 工具条（可用鼠标悬停看说明）。
  Widget _buildDesktopToolbar(AppThemeColors colors) {
    return Material(
      color: colors.sidebar,
      child: QuillSimpleToolbar(
        controller: _controller,
        config: QuillSimpleToolbarConfig(
          multiRowsDisplay: true,
          showFontFamily: false,
          showFontSize: true,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          showCodeBlock: false,
          showQuote: true,
          showInlineCode: false,
          showColorButton: true,
          showBackgroundColorButton: false,
          showClearFormat: true,
          showHeaderStyle: false,
          showLink: false,
          showUndo: true,
          showRedo: true,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showListNumbers: true,
          showListBullets: true,
          showIndent: true,
          customButtons: [
            QuillToolbarCustomButtonOptions(
              icon: const Icon(Icons.image_outlined, size: 20),
              tooltip: '插入图片',
              onPressed: _insertImage,
            ),
            QuillToolbarCustomButtonOptions(
              icon: const Icon(
                Icons.photo_size_select_large_outlined,
                size: 20,
              ),
              tooltip: '调整图片大小',
              onPressed: _resizeSelectedImage,
            ),
          ],
        ),
      ),
    );
  }

  /// 手机：仅保留入口条，完整格式项放进右侧可开关侧栏。
  Widget _buildMobileFormatBar(AppThemeColors colors) {
    return Material(
      color: colors.sidebar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            FilledButton.tonalIcon(
              key: const Key('mobile_format_panel_open'),
              onPressed: () {
                setState(() => _formatPanelOpen = !_formatPanelOpen);
              },
              icon: Icon(
                _formatPanelOpen
                    ? Icons.keyboard_double_arrow_right
                    : Icons.text_format,
              ),
              label: Text(_formatPanelOpen ? '收起格式' : '格式工具'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '撤销',
              onPressed: _controller.hasUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo, size: 20),
            ),
            IconButton(
              tooltip: '重做',
              onPressed: _controller.hasRedo ? _controller.redo : null,
              icon: const Icon(Icons.redo, size: 20),
            ),
            const Spacer(),
            Text(
              '点「格式工具」查看全部功能',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, {required bool compact}) {
    final editorPadding = compact ? 12.0 : 24.0;
    // 与 Win 端一致使用白底编辑区，保证文字对比度与点击命中区域清晰。
    // 外层是否 Expanded 由调用方决定（桌面单独 Expanded，手机在 Row 内 Expanded）。
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(editorPadding),
        child: QuillEditor(
          controller: _controller,
          focusNode: _focusNode,
          scrollController: _scrollController,
          config: QuillEditorConfig(
            placeholder: '开始记录...',
            padding: EdgeInsets.zero,
            autoFocus: false,
            expands: false,
            scrollable: true,
            showCursor: true,
            enableInteractiveSelection: true,
            embedBuilders: const [
              QuillImageEmbedBuilder(),
            ],
            customStyles: DefaultStyles(
              placeHolder: DefaultTextBlockStyle(
                TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                ),
                HorizontalSpacing.zero,
                VerticalSpacing.zero,
                VerticalSpacing.zero,
                null,
              ),
              paragraph: DefaultTextBlockStyle(
                const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF262626),
                ),
                HorizontalSpacing.zero,
                VerticalSpacing.zero,
                VerticalSpacing.zero,
                null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection({
    required AppThemeColors colors,
    required bool compact,
  }) {
    if (widget.showTitleBar) {
      return Material(
        color: colors.sidebar,
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 4 : 16,
            compact ? 4 : 8,
            compact ? 4 : 16,
            compact ? 4 : 8,
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  key: const Key('document_back_button'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '返回目录',
                  onPressed: widget.onBack,
                ),
              Expanded(
                child: Text(
                  widget.document.title,
                  style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._buildHeaderActions(compact: compact),
            ],
          ),
        ),
      );
    }

    // 标题在外层 AppBar；此处仅保留保存 / 同步操作。
    return Material(
      color: colors.sidebar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            const Spacer(),
            ..._buildHeaderActions(compact: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final compact = isCompactLayout(context);
    // 离开手机布局时自动收起侧栏，避免宽屏残留。
    if (!compact && _formatPanelOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _formatPanelOpen) {
          setState(() => _formatPanelOpen = false);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderSection(colors: colors, compact: compact),
        const Divider(height: 1),
        if (compact)
          _buildMobileFormatBar(colors)
        else
          _buildDesktopToolbar(colors),
        const Divider(height: 1),
        Expanded(
          child: compact
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildEditor(context, compact: true),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: _formatPanelOpen
                          ? (MediaQuery.sizeOf(context).width * 0.72)
                              .clamp(240.0, 320.0)
                          : 0,
                      child: _formatPanelOpen
                          ? MobileFormatPanel(
                              controller: _controller,
                              onClose: () =>
                                  setState(() => _formatPanelOpen = false),
                              onInsertImage: _insertImage,
                              onResizeImage: _resizeSelectedImage,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                )
              : _buildEditor(context, compact: false),
        ),
      ],
    );
  }
}
