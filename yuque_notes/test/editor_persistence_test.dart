import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/editor/editor_persistence.dart';
import 'package:yuque_notes/editor/image_storage.dart';

void main() {
  test('markdownToDocument accepts empty markdown for new documents', () {
    final document = markdownToDocument('');
    expect(document.toDelta().isEmpty, isFalse);
    expect(deltaToMarkdown(document), isEmpty);
  });

  test('deltaToMarkdown and markdownToDocument round-trip bold and underline', () {
    const source = '**Hello** __world__';
    final document = markdownToDocument(source);
    final markdown = deltaToMarkdown(document);

    expect(markdown, contains('Hello'));
    expect(markdown, contains('world'));

    final restored = markdownToDocument(markdown);
    final restoredMarkdown = deltaToMarkdown(restored);
    expect(restoredMarkdown, contains('Hello'));
    expect(restoredMarkdown, contains('world'));
  });

  test('buildImageMarkdown and parseImageWidth handle width metadata', () {
    const source = 'data:image/png;base64,abc123';
    final markdown = buildImageMarkdown(source: source, width: 420);
    expect(markdown, contains('width="420"'));
    expect(markdown, contains('src="data:image/png;base64,abc123"'));

    final width = parseImageWidth(markdown, source);
    expect(width, 420);

    final updated = updateImageWidthInMarkdown(
      markdown: markdown,
      source: source,
      width: 200,
    );
    expect(parseImageWidth(updated, source), 200);
  });

  test('parseAllImageWidths extracts multiple image widths', () {
    const markdown = '''
text
<img src="data:image/png;base64,a" width="100" />
<img src="data:image/png;base64,b" width="250" />
''';
    final widths = parseAllImageWidths(markdown);
    expect(widths['data:image/png;base64,a'], 100);
    expect(widths['data:image/png;base64,b'], 250);
  });

  test('findImageSrcAtOffset detects image at embed index and after text', () {
    const src = 'data:image/png;base64,xyz';
    final document = Document()
      ..insert(0, 'abc')
      ..insert(3, BlockEmbed.image(src));

    expect(collectImageEmbedOffsets(document), {3: src});
    expect(findImageSrcAtOffset(document, 3), src);
    expect(findImageSrcAtOffset(document, 4), src);
    expect(findImageSrcAtOffset(document, 2), isNull);
  });

  test('findImageSrcAtOffset selects correct image among multiple embeds', () {
    const srcA = 'data:image/png;base64,a';
    const srcB = 'data:image/png;base64,b';
    final document = Document()
      ..insert(0, BlockEmbed.image(srcA))
      ..insert(1, '\n')
      ..insert(2, BlockEmbed.image(srcB));

    expect(findImageSrcAtOffset(document, 0), srcA);
    expect(findImageSrcAtOffset(document, 2), srcB);
    expect(findImageSrcAtOffset(document, 3), srcB);
  });

  test('updateImageWidthInMarkdown updates only targeted image', () {
    const srcA = 'data:image/png;base64,a';
    const srcB = 'data:image/png;base64,b';
    final markdown = '${buildImageMarkdown(source: srcA, width: 100)}\n'
        '${buildImageMarkdown(source: srcB, width: 200)}';
    final updated = updateImageWidthInMarkdown(
      markdown: markdown,
      source: srcB,
      width: 400,
    );
    expect(parseImageWidth(updated, srcA), 100);
    expect(parseImageWidth(updated, srcB), 400);
  });

  test('encodeImageDataUri produces portable data uri', () {
    final uri = encodeImageDataUri([0x89, 0x50, 0x4E, 0x47], 'image/png');
    expect(isPortableImageSource(uri), isTrue);
    expect(uri, startsWith('data:image/png;base64,'));
  });

  test('applyImageWidthAtOffset updates only image at cursor offset', () {
    const srcA = 'data:image/png;base64,a';
    const srcB = 'data:image/png;base64,b';
    final document = Document()
      ..insert(0, BlockEmbed.image(srcA))
      ..insert(1, '\n')
      ..insert(2, BlockEmbed.image(srcB));
    final widths = {srcA: 100, srcB: 200};

    final result = applyImageWidthAtOffset(
      document: document,
      currentWidths: widths,
      offset: 2,
      newWidth: 400,
    );

    expect(result, isNotNull);
    expect(result!.source, srcB);
    expect(parseImageWidth(result.updatedMarkdown, srcA), 100);
    expect(parseImageWidth(result.updatedMarkdown, srcB), 400);
    expect(result.imageWidths[srcB], 400);
  });

  test('deltaToMarkdown preserves per-image widths from map', () {
    const src = 'data:image/png;base64,img';
    final document = Document()..insert(0, BlockEmbed.image(src));
    final markdown = deltaToMarkdown(
      document,
      imageWidths: {src: 180},
    );
    expect(parseImageWidth(markdown, src), 180);
  });
}