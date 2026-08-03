import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../editor/image_storage.dart';
import 'forum/forum_api_client.dart';

/// 笔记内图片上传到 Cloudflare R2（经论坛服务端）。
///
/// ## 路径约定（服务端按 JWT 用户写入，客户端用返回 URL）
/// `notes/{forumUserId}/{sha256}.{ext}`
/// 头像为 `avatars/{forumUserId}/{sha256}.{ext}`
///
/// ## 笔记图 API（主流程）
/// - `POST /api/images/upload`
/// - body: `{ "image": "data:image/...;base64,...", "purpose": "note", "folder": "notes" }`
/// - 200: `{ "url": "https://....r2.dev/notes/{userId}/{sha256}.ext" }`
///
/// ## 客户端策略
/// - **未登录**：本地可用 Data URI
/// - **已登录**：保存/同步时 upload，本地只存 R2 URL（换设备可见）；
///   文本与文件夹结构走 `posts/sync`，由 CommunitySyncService 统一处理
class CloudImageService {
  CloudImageService({ForumApiClient? forumClient})
      : _forumClient = forumClient ?? ForumApiClient();

  final ForumApiClient _forumClient;

  /// 会话内缓存：Data URI 内容 SHA256 → R2 URL，避免同一张图重复上传。
  final Map<String, String> _urlByContentHash = {};

  static final RegExp dataImageUriPattern = RegExp(
    r'data:image/(jpeg|jpg|png|gif|webp);base64,[A-Za-z0-9+/=]+',
    caseSensitive: false,
  );

  /// 从 Markdown/HTML 中提取所有 Data URI 图片。
  static List<String> extractDataImageUris(String markdown) {
    final found = <String>{};
    for (final match in dataImageUriPattern.allMatches(markdown)) {
      final uri = match.group(0)!;
      if (isAllowedNoteDataUri(uri)) {
        found.add(uri);
      }
    }
    return found.toList();
  }

  static bool isAllowedNoteDataUri(String dataUri) {
    return RegExp(
      r'^data:image/(?:jpeg|jpg|png|gif|webp);base64,',
      caseSensitive: false,
    ).hasMatch(dataUri.trim());
  }

  /// 内容哈希（与服务端「相同二进制同一 key」思路一致，用于客户端去重）。
  static String contentHashOfDataUri(String dataUri) {
    final trimmed = dataUri.trim();
    final comma = trimmed.indexOf(',');
    final payload = comma > 0 ? trimmed.substring(comma + 1) : trimmed;
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// 上传单张 Data URI，返回 R2 公网 URL。
  Future<String> uploadNoteImage({
    required String accessToken,
    required String dataUri,
  }) async {
    final trimmed = dataUri.trim();
    if (!isAllowedNoteDataUri(trimmed)) {
      throw ForumApiException('不支持的图片格式（仅 jpeg/png/gif/webp Data URI）');
    }

    final hash = contentHashOfDataUri(trimmed);
    final cached = _urlByContentHash[hash];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final comma = trimmed.indexOf(',');
    if (comma > 0) {
      final b64 = trimmed.substring(comma + 1);
      final approxBytes = (b64.length * 3) ~/ 4;
      if (approxBytes > kMaxAvatarBytes) {
        throw ForumApiException('图片不能超过 5 MB');
      }
    }

    final json = await _forumClient.postJson(
      '/api/images/upload',
      accessToken: accessToken,
      body: {
        'image': trimmed,
        'purpose': 'note',
        'folder': 'notes',
      },
    );

    final url = json['url'];
    if (url is! String || url.trim().isEmpty) {
      throw ForumApiException('图片上传响应缺少有效 url');
    }
    final u = url.trim();
    if (!u.startsWith('https://') && !u.startsWith('http://')) {
      throw ForumApiException('图片上传返回的 url 无效');
    }

    _urlByContentHash[hash] = u;
    return u;
  }

  /// 将 Markdown 中所有 Data URI 图片上传到 R2（notes/{userId}/…）并替换为 URL。
  /// 已是 http(s) 的地址保持不变。无 Data URI 时原样返回。
  Future<String> uploadDataImagesInMarkdown({
    required String markdown,
    required String accessToken,
  }) async {
    final uris = extractDataImageUris(markdown);
    if (uris.isEmpty) {
      return markdown;
    }

    var result = markdown;
    for (final dataUri in uris) {
      final remoteUrl = await uploadNoteImage(
        accessToken: accessToken,
        dataUri: dataUri,
      );
      result = result.replaceAll(dataUri, remoteUrl);
    }
    return result;
  }

  void clearCache() => _urlByContentHash.clear();
}
