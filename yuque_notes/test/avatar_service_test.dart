import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/services/avatar_service.dart';

void main() {
  test('pickAvatarDataUri encodes picked image bytes', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
    final service = AvatarService(
      pickFiles: () async => FilePickerResult([
        PlatformFile(name: 'avatar.png', size: bytes.length, bytes: bytes),
      ]),
    );

    final result = await service.pickAvatarDataUri();

    expect(result.isSuccess, isTrue);
    expect(result.dataUri, startsWith('data:image/png;base64,'));
  });

  test('pickAvatarDataUri returns cancelled when picker returns null', () async {
    final service = AvatarService(pickFiles: () async => null);

    final result = await service.pickAvatarDataUri();

    expect(result.isSuccess, isFalse);
    expect(result.dataUri, isNull);
    expect(result.errorMessage, isNull);
  });
}