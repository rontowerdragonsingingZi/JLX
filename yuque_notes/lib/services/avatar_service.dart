import 'package:file_picker/file_picker.dart';

import '../editor/image_storage.dart';

typedef PickFilesCallback = Future<FilePickerResult?> Function();

class AvatarPickResult {
  const AvatarPickResult._({this.dataUri, this.errorMessage});

  const AvatarPickResult.cancelled() : this._();

  const AvatarPickResult.failed(String message) : this._(errorMessage: message);

  const AvatarPickResult.success(String dataUri) : this._(dataUri: dataUri);

  final String? dataUri;
  final String? errorMessage;

  bool get isSuccess => dataUri != null;
}

class AvatarService {
  AvatarService({PickFilesCallback? pickFiles})
      : _pickFiles = pickFiles ?? _defaultPickFiles;

  final PickFilesCallback _pickFiles;

  static Future<FilePickerResult?> _defaultPickFiles() {
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      withData: true,
    );
  }

  /// 选择本地图片并编码为 Data URI（仅 jpeg/png/gif/webp，≤5MB）。
  /// 上传云端后必须以服务端返回的 R2 URL 为准，不要长期保存本 Data URI。
  Future<AvatarPickResult> pickAvatarDataUri() async {
    final result = await _pickFiles();
    if (result == null || result.files.isEmpty) {
      return const AvatarPickResult.cancelled();
    }

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      return const AvatarPickResult.failed('无法读取图片数据');
    }

    if (bytes.length > kMaxAvatarBytes) {
      return const AvatarPickResult.failed('头像不能超过 5 MB');
    }

    final mime = mimeFromExtension(picked.extension);
    if (!kAllowedAvatarMimes.contains(mime.toLowerCase())) {
      return const AvatarPickResult.failed(
        '仅支持 JPEG / PNG / GIF / WebP 格式头像',
      );
    }

    // bmp 等会落到 image/png 默认；扩展名已限制，这里再兜底
    final dataUri = encodeImageDataUri(bytes, mime);
    if (!isAllowedAvatarDataUri(dataUri)) {
      return const AvatarPickResult.failed(
        '头像格式无效，请使用 JPEG / PNG / GIF / WebP',
      );
    }

    return AvatarPickResult.success(dataUri);
  }
}
