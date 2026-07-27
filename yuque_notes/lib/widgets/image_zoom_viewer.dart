import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 单图放大查看：自由缩放/平移，无前后切换。
Future<void> showImageZoomViewer(
  BuildContext context, {
  required ImageProvider image,
  String? title,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    barrierDismissible: true,
    builder: (context) => ImageZoomViewer(
      image: image,
      title: title,
    ),
  );
}

/// 从文档/网络 Data URI 或 https 源打开。
Future<void> showImageZoomViewerFromSource(
  BuildContext context, {
  required String source,
  String? title,
}) {
  final provider = imageProviderFromSource(source);
  if (provider == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.cannotReadImage)),
    );
    return Future.value();
  }
  return showImageZoomViewer(context, image: provider, title: title);
}

/// 从 asset 路径打开（如联系我们二维码）。
Future<void> showImageZoomViewerFromAsset(
  BuildContext context, {
  required String assetPath,
  String? title,
}) {
  return showImageZoomViewer(
    context,
    image: AssetImage(assetPath),
    title: title,
  );
}

ImageProvider? imageProviderFromSource(String source) {
  final s = source.trim();
  if (s.isEmpty) {
    return null;
  }
  if (s.startsWith('data:image/')) {
    final comma = s.indexOf(',');
    if (comma <= 0) {
      return null;
    }
    try {
      final bytes = base64Decode(s.substring(comma + 1));
      if (bytes.isEmpty) {
        return null;
      }
      return MemoryImage(bytes);
    } on FormatException {
      return null;
    }
  }
  final uri = Uri.tryParse(s);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    return NetworkImage(s);
  }
  // 本地 asset 路径
  if (s.startsWith('assets/')) {
    return AssetImage(s);
  }
  return null;
}

class ImageZoomViewer extends StatefulWidget {
  const ImageZoomViewer({
    super.key,
    required this.image,
    this.title,
  });

  final ImageProvider image;
  final String? title;

  @override
  State<ImageZoomViewer> createState() => _ImageZoomViewerState();
}

class _ImageZoomViewerState extends State<ImageZoomViewer> {
  final TransformationController _transform = TransformationController();
  static const double _minScale = 0.5;
  static const double _maxScale = 8;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transform.value = Matrix4.identity();
  }

  void _zoomBy(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(_minScale, _maxScale);
    final ratio = next / current;
    final center = MediaQuery.sizeOf(context).center(Offset.zero);
    final matrix = Matrix4.copy(_transform.value);
    // 以视口中心为锚点缩放（兼容新 Matrix4 API）
    matrix
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _transform.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.title;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onDoubleTap: _resetZoom,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: _minScale,
                    maxScale: _maxScale,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin: const EdgeInsets.all(80),
                    clipBehavior: Clip.none,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Image(
                        image: widget.image,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            l10n.cannotReadImage,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 顶栏：标题 + 缩放 + 关闭（无前后切换）
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  if (title != null && title.isNotEmpty)
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    tooltip: l10n.zoomOut,
                    onPressed: () => _zoomBy(1 / 1.25),
                    icon: const Icon(Icons.zoom_out, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: l10n.zoomIn,
                    onPressed: () => _zoomBy(1.25),
                    icon: const Icon(Icons.zoom_in, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: l10n.zoomReset,
                    onPressed: _resetZoom,
                    icon: const Icon(Icons.fit_screen, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.imageZoomHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
