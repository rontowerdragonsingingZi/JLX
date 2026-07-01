import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

const int defaultImageWidth = 300;

final _mdToDelta = MarkdownToDelta(
  markdownDocument: md.Document(),
  customElementToEmbeddable: {
    'img': (attrs) => BlockEmbed.image(attrs['src'] ?? ''),
  },
);

String deltaToMarkdown(
  Document document, {
  Map<String, int>? imageWidths,
}) {
  final widths = imageWidths ?? const {};
  final converter = DeltaToMarkdown(
    customEmbedHandlers: {
      BlockEmbed.imageType: (embed, out) {
        final src = embed.value.data as String;
        final width = widths[src] ?? defaultImageWidth;
        out.write(buildImageMarkdown(source: src, width: width));
      },
    },
  );
  var markdown = converter.convert(document.toDelta());
  markdown = _normalizeImageTags(markdown);
  return markdown.trim();
}

Document markdownToDocument(String markdown) {
  if (markdown.trim().isEmpty) {
    return _emptyDocument();
  }
  final normalized = _denormalizeImageTags(markdown);
  final delta = _mdToDelta.convert(normalized);
  if (delta.isEmpty) {
    return _emptyDocument();
  }
  return Document.fromDelta(delta);
}

Document _emptyDocument() {
  return Document.fromJson(const [
    {'insert': '\n'},
  ]);
}

String buildImageMarkdown({
  required String source,
  required int width,
}) {
  return '<img src="$source" width="$width" />';
}

int? parseImageWidth(String markdown, String source) {
  final pattern = RegExp(
    r'<img\s+[^>]*src="'
    '${RegExp.escape(source)}'
    r'"[^>]*width="(\d+)"[^>]*/?>',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(markdown);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!);
}

Map<String, int> parseAllImageWidths(String markdown) {
  final pattern = RegExp(
    r'<img\s+[^>]*src="([^"]+)"[^>]*width="(\d+)"[^>]*/?>',
    caseSensitive: false,
  );
  final result = <String, int>{};
  for (final match in pattern.allMatches(markdown)) {
    final src = match.group(1)!;
    final width = int.tryParse(match.group(2)!);
    if (width != null) {
      result[src] = width;
    }
  }
  return result;
}

Map<int, String> collectImageEmbedOffsets(Document document) {
  final positions = <int, String>{};
  var index = 0;
  for (final op in document.toDelta().toList()) {
    if (!op.isInsert) {
      continue;
    }
    final data = op.data;
    if (data is Map && data.containsKey(BlockEmbed.imageType)) {
      positions[index] = data[BlockEmbed.imageType] as String;
      index += 1;
    } else if (data is String) {
      index += data.length;
    }
  }
  return positions;
}

String? embedImageSrc(Embeddable embed) {
  if (embed.type == BlockEmbed.imageType) {
    return embed.data as String;
  }
  return null;
}

String? findImageSrcAtOffset(Document document, int offset) {
  if (offset < 0) {
    return null;
  }

  final imagePositions = collectImageEmbedOffsets(document);
  if (imagePositions.containsKey(offset)) {
    return imagePositions[offset];
  }
  if (offset > 0 && imagePositions.containsKey(offset - 1)) {
    return imagePositions[offset - 1];
  }

  final embedSegments = document.collectAllIndividualStyleAndEmbed(offset, 1);
  for (final segment in embedSegments) {
    if (segment.value is Embeddable) {
      final src = embedImageSrc(segment.value as Embeddable);
      if (src != null) {
        return src;
      }
    }
  }

  if (offset > 0) {
    final beforeSegments =
        document.collectAllIndividualStyleAndEmbed(offset - 1, 1);
    for (final segment in beforeSegments) {
      if (segment.value is Embeddable) {
        final src = embedImageSrc(segment.value as Embeddable);
        if (src != null) {
          return src;
        }
      }
    }
  }

  return null;
}

class ImageWidthResizeResult {
  const ImageWidthResizeResult({
    required this.updatedMarkdown,
    required this.imageWidths,
    required this.source,
  });

  final String updatedMarkdown;
  final Map<String, int> imageWidths;
  final String source;
}

ImageWidthResizeResult? applyImageWidthAtOffset({
  required Document document,
  required Map<String, int> currentWidths,
  required int offset,
  required int newWidth,
}) {
  final src = findImageSrcAtOffset(document, offset);
  if (src == null) {
    return null;
  }

  final markdown = deltaToMarkdown(document, imageWidths: currentWidths);
  final updated = updateImageWidthInMarkdown(
    markdown: markdown,
    source: src,
    width: newWidth,
  );
  final widths = Map<String, int>.from(currentWidths)..[src] = newWidth;
  widths.addAll(parseAllImageWidths(updated));

  return ImageWidthResizeResult(
    updatedMarkdown: updated,
    imageWidths: widths,
    source: src,
  );
}

String updateImageWidthInMarkdown({
  required String markdown,
  required String source,
  required int width,
}) {
  final pattern = RegExp(
    r'<img\s+[^>]*src="'
    '${RegExp.escape(source)}'
    r'"[^>]*/?>',
    caseSensitive: false,
  );
  if (!pattern.hasMatch(markdown)) {
    return markdown;
  }
  return markdown.replaceFirst(
    pattern,
    buildImageMarkdown(source: source, width: width),
  );
}

String _normalizeImageTags(String markdown) {
  final pattern = RegExp(
    r'!\[([^\]]*)\]\(([^)]+)\)\{width=(\d+)\}',
  );
  return markdown.replaceAllMapped(pattern, (match) {
    final alt = match.group(1) ?? '';
    final src = match.group(2)!;
    final width = match.group(3)!;
    final altAttr = alt.isEmpty ? '' : ' alt="$alt"';
    return '<img src="$src" width="$width"$altAttr />';
  });
}

String _denormalizeImageTags(String markdown) {
  final pattern = RegExp(
    r'<img\s+[^>]*src="([^"]+)"[^>]*width="(\d+)"[^>]*/?>',
    caseSensitive: false,
  );
  return markdown.replaceAllMapped(pattern, (match) {
    final src = match.group(1)!;
    final width = match.group(2)!;
    return '![image]($src){width=$width}';
  });
}