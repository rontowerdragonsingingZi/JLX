import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/editor/image_storage.dart';

void main() {
  test('mimeFromExtension maps common extensions', () {
    expect(mimeFromExtension('png'), 'image/png');
    expect(mimeFromExtension('jpg'), 'image/jpeg');
    expect(mimeFromExtension('webp'), 'image/webp');
    expect(mimeFromExtension(null), 'image/png');
  });

  test('encodeImageDataUri round-trips bytes as base64', () {
    final uri = encodeImageDataUri([1, 2, 3], 'image/png');
    expect(uri, 'data:image/png;base64,AQID');
    expect(isPortableImageSource(uri), isTrue);
  });
}
