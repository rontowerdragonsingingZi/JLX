import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_theme.dart';

/// 文档内图片：按保存宽度显示；光标选中后可拖拽右边缘调整宽度。
class QuillImageEmbedBuilder extends EmbedBuilder {
  const QuillImageEmbedBuilder({
    required this.getWidth,
    required this.onWidthChanged,
  });

  final int Function(String src) getWidth;
  final void Function(String src, int width) onWidthChanged;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    return _ResizableQuillImage(
      src: url,
      controller: embedContext.controller,
      nodeOffset: embedContext.node.documentOffset,
      readOnly: embedContext.readOnly,
      width: getWidth(url),
      onWidthChanged: onWidthChanged,
    );
  }
}

class _ResizableQuillImage extends StatefulWidget {
  const _ResizableQuillImage({
    required this.src,
    required this.controller,
    required this.nodeOffset,
    required this.readOnly,
    required this.width,
    required this.onWidthChanged,
  });

  final String src;
  final QuillController controller;
  final int nodeOffset;
  final bool readOnly;
  final int width;
  final void Function(String src, int width) onWidthChanged;

  @override
  State<_ResizableQuillImage> createState() => _ResizableQuillImageState();
}

class _ResizableQuillImageState extends State<_ResizableQuillImage> {
  static const double _minWidth = 80;
  static const double _handleExtent = 12;

  double? _dragWidth;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSelection);
    _selected = _isSelected();
  }

  @override
  void didUpdateWidget(covariant _ResizableQuillImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncSelection);
      widget.controller.addListener(_syncSelection);
    }
    final nextSelected = _isSelected();
    if (nextSelected != _selected) {
      _selected = nextSelected;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSelection);
    super.dispose();
  }

  void _syncSelection() {
    final next = _isSelected();
    if (next != _selected && mounted) {
      setState(() => _selected = next);
    }
  }

  bool _isSelected() {
    final sel = widget.controller.selection;
    final o = widget.nodeOffset;
    if (sel.isCollapsed) {
      return sel.baseOffset == o || sel.baseOffset == o + 1;
    }
    return sel.start <= o && sel.end > o;
  }

  void _selectImage() {
    widget.controller.updateSelection(
      TextSelection.collapsed(offset: widget.nodeOffset),
      ChangeSource.local,
    );
  }

  ImageProvider? _provider() {
    final url = widget.src;
    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma > 0) {
        try {
          final bytes = base64Decode(url.substring(comma + 1));
          if (bytes.isNotEmpty) {
            return MemoryImage(bytes);
          }
        } on FormatException {
          return null;
        }
      }
      return null;
    }
    final uri = Uri.tryParse(url);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
  }

  double _maxWidth(BuildContext context) {
    final media = MediaQuery.sizeOf(context).width;
    return media.clamp(_minWidth, 1600);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayWidth =
        (_dragWidth ?? widget.width.toDouble()).clamp(_minWidth, _maxWidth(context));
    final provider = _provider();
    final showHandles = _selected && !widget.readOnly;

    final image = provider == null
        ? SizedBox(
            width: displayWidth,
            height: 80,
            child: Icon(Icons.broken_image_outlined, color: colors.textSecondary),
          )
        : Image(
            image: provider,
            width: displayWidth,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: widget.readOnly ? null : _selectImage,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: showHandles
                      ? Border.all(color: colors.primary, width: 1.5)
                      : null,
                ),
                child: image,
              ),
              if (showHandles)
                Positioned(
                  right: -_handleExtent / 2,
                  top: 0,
                  bottom: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (_) {
                        setState(() => _dragWidth = displayWidth);
                      },
                      onHorizontalDragUpdate: (details) {
                        final next =
                            ((_dragWidth ?? displayWidth) + details.delta.dx)
                                .clamp(_minWidth, _maxWidth(context));
                        setState(() => _dragWidth = next);
                      },
                      onHorizontalDragEnd: (_) {
                        final w = (_dragWidth ?? displayWidth).round();
                        setState(() => _dragWidth = null);
                        widget.onWidthChanged(widget.src, w);
                      },
                      onHorizontalDragCancel: () {
                        setState(() => _dragWidth = null);
                      },
                      child: SizedBox(
                        width: _handleExtent,
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
