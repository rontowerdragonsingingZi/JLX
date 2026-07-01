import 'dart:convert';

String mimeFromExtension(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    default:
      return 'image/png';
  }
}

String encodeImageDataUri(List<int> bytes, String mime) {
  final encoded = base64Encode(bytes);
  return 'data:$mime;base64,$encoded';
}

bool isPortableImageSource(String source) {
  return source.startsWith('data:image/');
}