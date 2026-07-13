import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/app.dart';
import 'package:yuque_notes/data/models/cloud_session.dart';
import 'package:yuque_notes/services/session_service.dart';

import 'helpers/test_setup.dart';

void main() {
  group('YuqueNotesApp cold start', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('opens workspace without login prompt when guest', (tester) async {
      await tester.pumpWidget(const YuqueNotesApp());
      await tester.pump();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });

      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('NoteYourNeed').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.text('NoteYourNeed'), findsOneWidget);
      expect(find.byKey(const Key('guest_login_prompt')), findsOneWidget);
      expect(find.text('请登录'), findsOneWidget);
    });

    testWidgets('restores cloud profile through app entry', (tester) async {
      await SessionService().saveCloudSession(
        CloudSession(
          accessToken: 'token',
          userId: 42,
          username: 'frank',
          avatar: kTestAvatarDataUri,
        ),
      );

      await tester.pumpWidget(const YuqueNotesApp());
      await tester.pump();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });

      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('frank').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.text('NoteYourNeed'), findsOneWidget);
      expect(find.text('frank'), findsOneWidget);
      expect(find.byKey(const Key('guest_login_prompt')), findsNothing);

      final avatar = readUserAvatar(tester);
      expect(avatar.backgroundImage, isA<MemoryImage>());
      expect(find.byKey(const Key('user_avatar_default')), findsNothing);
    });
  });
}