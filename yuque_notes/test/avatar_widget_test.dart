import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/models/user.dart';
import 'package:yuque_notes/data/repositories/auth_repository.dart';
import 'package:yuque_notes/screens/workspace/workspace_screen.dart';
import 'package:yuque_notes/services/avatar_service.dart';

import 'helpers/test_setup.dart';

void main() {
  group('workspace avatar UI', () {
    late User localUser;
    late User cloudUserWithoutAvatar;
    late User cloudUserWithAvatar;

    setUp(() async {
      await setUpTestDatabase();
      final authRepository = AuthRepository();
      localUser = await authRepository.ensureLocalUser();
      cloudUserWithoutAvatar = User(
        id: 99,
        username: 'eve',
        createdAt: DateTime.parse('2026-01-01T00:00:00'),
      );
      cloudUserWithAvatar = User(
        id: 99,
        username: 'eve',
        createdAt: DateTime.parse('2026-01-01T00:00:00'),
        avatar: kTestAvatarDataUri,
      );
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('shows login prompt when cloud user is absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            localUser: localUser,
            onCloudAuthChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('guest_login_prompt')), findsOneWidget);
      expect(find.text('请登录'), findsOneWidget);
      expect(find.byKey(const Key('user_avatar')), findsNothing);
    });

    testWidgets('shows default icon when cloud user has no avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            localUser: localUser,
            cloudUser: cloudUserWithoutAvatar,
            onCloudAuthChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final avatar = readUserAvatar(tester);
      expect(avatar.backgroundImage, isNull);
      expect(find.byKey(const Key('user_avatar_default')), findsOneWidget);
    });

    testWidgets('renders MemoryImage when cloud user has avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            localUser: localUser,
            cloudUser: cloudUserWithAvatar,
            onCloudAuthChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final avatar = readUserAvatar(tester);
      expect(avatar.backgroundImage, isA<MemoryImage>());
      expect(find.byKey(const Key('user_avatar_default')), findsNothing);
      expect(find.text('eve'), findsOneWidget);
    });

    testWidgets('tap avatar saves picked image and updates sidebar', (tester) async {
      final bytes = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z5BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      );
      final avatarService = AvatarService(
        pickFiles: () async => FilePickerResult([
          PlatformFile(name: 'picked.png', size: bytes.length, bytes: bytes),
        ]),
      );
      User? updatedCloudUser;

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            localUser: localUser,
            cloudUser: cloudUserWithoutAvatar,
            onCloudAuthChanged: (user) => updatedCloudUser = user,
            avatarService: avatarService,
          ),
        ),
      );
      await tester.pump();

      expect(readUserAvatar(tester).backgroundImage, isNull);

      await tester.tap(find.byKey(const Key('user_avatar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatar = readUserAvatar(tester);
      expect(avatar.backgroundImage, isA<MemoryImage>());
      expect(find.byKey(const Key('user_avatar_default')), findsNothing);
      expect(updatedCloudUser?.avatar, startsWith('data:image/png;base64,'));
    });
  });
}