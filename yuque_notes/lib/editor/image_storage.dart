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

/// 头像可用的源：Data URI 或 https/http 公网 URL（R2）。
bool isAvatarImageSource(String source) {
  final s = source.trim();
  if (s.isEmpty) {
    return false;
  }
  if (isPortableImageSource(s)) {
    return true;
  }
  final uri = Uri.tryParse(s);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

/// 头像上传允许的 MIME（与云端论坛一致）。
const Set<String> kAllowedAvatarMimes = {
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
};

/// 头像最大 5 MB。
const int kMaxAvatarBytes = 5 * 1024 * 1024;

/// 是否为论坛接受的 Data URI 头像格式。
bool isAllowedAvatarDataUri(String dataUri) {
  final match = RegExp(
    r'^data:(image/(?:jpeg|png|gif|webp));base64,',
    caseSensitive: false,
  ).firstMatch(dataUri.trim());
  return match != null;
}