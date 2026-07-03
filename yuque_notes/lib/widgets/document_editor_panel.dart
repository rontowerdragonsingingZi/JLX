import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../data/models/document.dart' as models;
import '../editor/editor_persistence.dart';
import '../editor/image_storage.dart';
import '../theme/app_theme.dart';
import 'quill_image_embed.dart';

class DocumentEditorPanel extends StatefulWidget {
  const DocumentEditorPanel({
    super.key,
    required this.document,
    required this.onSave,
    this.canSyncToCommunity = false,
    this.onSyncToCommunity,
  });

  final models.Document document;
  final Future<void> Function(String markdown) onSave;
  final bool canSyncToCommunity;
  final Future<void> Function()? onSyncToCommunity;

  @override
  State<DocumentEditorPanel> createState() => _DocumentEditorPanelState();
}

class _DocumentEditorPanelState extends State<DocumentEditorPanel> {
  late QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  bool _saving = false;
  bool _syncing = false;
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

  Future<void> _syncToCommunity() async {
    final onSync = widget.onSyncToCommunity;
    if (onSync == null) {
      return;
    }

    setState(() => _syncing = true);
    try {
      await onSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已同步到社区')),
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

    final dataUri = encodeImageDataUri(bytes, mimeFromExtension(picked.extension));
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

    final currentWidth = _imageWidths[src] ?? parseImageWidth(widget.document.content, src) ?? _selectedImageWidth;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.sidebar,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.document.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.canSyncToCommunity) ...[
                if (widget.document.syncedToCommunity)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(
                      key: Key('synced_to_community_badge'),
                      label: Text('已同步'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                TextButton.icon(
                  key: const Key('sync_to_community_button'),
                  onPressed: _syncing ? null : _syncToCommunity,
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('同步到社区'),
                ),
              ],
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('保存'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        QuillSimpleToolbar(
          controller: _controller,
          config: QuillSimpleToolbarConfig(
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
            customButtons: [
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.image_outlined, size: 20),
                tooltip: '插入图片',
                onPressed: _insertImage,
              ),
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.photo_size_select_large_outlined, size: 20),
                tooltip: '调整图片大小',
                onPressed: _resizeSelectedImage,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: QuillEditor(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: QuillEditorConfig(
                placeholder: '开始记录...',
                padding: EdgeInsets.zero,
                embedBuilders: const [
                  QuillImageEmbedBuilder(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}