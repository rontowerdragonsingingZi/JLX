import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../editor/snippet_block.dart';
import '../theme/app_theme.dart';

/// Quill 内嵌可复制块。
///
/// Windows 上 Quill 内部 [TextField] 几乎无法获焦，因此：
/// - 卡片内只做展示 + 复制
/// - 点击卡片用**浮层**（非 AlertDialog）就地编辑，浮层在路由层，可正常输入
/// - 写回严格按 [SnippetBlockData.id] 替换，避免在光标处复制出第二份
class QuillSnippetEmbedBuilder extends EmbedBuilder {
  const QuillSnippetEmbedBuilder({this.editorFocusNode});

  final FocusNode? editorFocusNode;

  @override
  String get key => kSnippetEmbedType;

  /// 块级整行渲染（一行仅含该 embed 时走 EmbedProxy）
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = SnippetBlockData.fromEmbedData(embedContext.node.value.data);
    return _SnippetCard(
      key: ValueKey('nn-snippet-${data.id}'),
      data: data,
      readOnly: embedContext.readOnly,
      quillController: embedContext.controller,
      editorFocusNode: editorFocusNode,
    );
  }
}

class _SnippetCard extends StatelessWidget {
  const _SnippetCard({
    super.key,
    required this.data,
    required this.readOnly,
    required this.quillController,
    this.editorFocusNode,
  });

  final SnippetBlockData data;
  final bool readOnly;
  final QuillController quillController;
  final FocusNode? editorFocusNode;

  Future<void> _copy(BuildContext context) async {
    final text = data.content.isEmpty ? data.title : data.content;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制内容')),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    if (readOnly) {
      return;
    }
    // 先收起正文焦点，避免浮层下仍闪烁正文光标
    quillController.skipRequestKeyboard = true;
    editorFocusNode?.unfocus();

    final result = await showSnippetOverlayEditor(
      context: context,
      anchorContext: context,
      initial: data,
    );

    quillController.skipRequestKeyboard = false;

    if (result == null) {
      return;
    }
    // 仅替换同一 id 的 embed
    replaceSnippetById(
      controller: quillController,
      id: data.id,
      next: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const radius = 4.0;
    final title = data.title.isEmpty ? '小标题' : data.title;
    final content = data.content.isEmpty ? '点击编辑内容…' : data.content;
    final placeholderTitle = data.title.isEmpty;
    final placeholderContent = data.content.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colors.selected.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: readOnly ? null : () => _openEditor(context),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.widgets_outlined,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: placeholderTitle
                              ? colors.textSecondary
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('snippet_copy_button'),
                      onPressed: () => _copy(context),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      label: const Text('复制', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 21, right: 4),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: placeholderContent
                          ? colors.textSecondary
                          : colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 锚定在组件位置附近的浮层编辑器（可正常显示光标与输入）。
Future<SnippetBlockData?> showSnippetOverlayEditor({
  required BuildContext context,
  required BuildContext anchorContext,
  required SnippetBlockData initial,
}) {
  final box = anchorContext.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  Rect? anchorRect;
  if (box != null && overlay != null && box.hasSize) {
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    anchorRect = topLeft & box.size;
  }

  return showGeneralDialog<SnippetBlockData>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, anim, secondary) {
      return SafeArea(
        child: Stack(
          children: [
            // 点击空白关闭
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            _AnchoredSnippetEditor(
              initial: initial,
              anchorRect: anchorRect,
              onCancel: () => Navigator.of(ctx).pop(),
              onSubmit: (data) => Navigator.of(ctx).pop(data),
            ),
          ],
        ),
      );
    },
  );
}

class _AnchoredSnippetEditor extends StatefulWidget {
  const _AnchoredSnippetEditor({
    required this.initial,
    required this.onCancel,
    required this.onSubmit,
    this.anchorRect,
  });

  final SnippetBlockData initial;
  final Rect? anchorRect;
  final VoidCallback onCancel;
  final ValueChanged<SnippetBlockData> onSubmit;

  @override
  State<_AnchoredSnippetEditor> createState() => _AnchoredSnippetEditorState();
}

class _AnchoredSnippetEditorState extends State<_AnchoredSnippetEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _contentController = TextEditingController(text: widget.initial.content);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final content = _contentController.text;
    widget.onSubmit(
      SnippetBlockData(
        id: widget.initial.id,
        title: title,
        content: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    // 尽量贴在原组件位置；空间不够则居中
    double top = 80 + padding.top;
    double left = 24;
    double width = size.width - 48;
    if (width > 480) {
      width = 480;
    }

    final anchor = widget.anchorRect;
    if (anchor != null) {
      left = anchor.left.clamp(12.0, size.width - width - 12.0);
      top = anchor.top;
      // 若下方空间不足，放到锚点上方
      final estimatedHeight = 220.0 + viewInsets.bottom;
      if (top + estimatedHeight > size.height - padding.bottom - 12) {
        top = (anchor.top - estimatedHeight + 40).clamp(
          padding.top + 12.0,
          size.height - estimatedHeight - 12.0,
        );
      }
      // 宽度尽量贴合锚点
      width = anchor.width.clamp(280.0, size.width - 24.0);
      if (left + width > size.width - 12) {
        left = size.width - width - 12;
      }
    } else {
      left = (size.width - width) / 2;
      top = size.height * 0.2;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(6),
        color: colors.sidebar,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.widgets_outlined, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '编辑可复制块',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '小标题',
                  hintText: '输入小标题',
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _contentFocus.requestFocus(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                focusNode: _contentFocus,
                minLines: 3,
                maxLines: 8,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '内容',
                  hintText: '输入内容（复制按钮将复制此处）',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('完成'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
