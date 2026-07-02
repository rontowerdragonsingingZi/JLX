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
      type: FileType.image,
      withData: true,
    );
  }

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

    return AvatarPickResult.success(
      encodeImageDataUri(bytes, mimeFromExtension(picked.extension)),
    );
  }
}