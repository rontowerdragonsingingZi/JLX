import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/screens/auth/login_screen.dart';

import 'helpers/test_setup.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('login screen shows login and register entry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('语雀笔记'), findsOneWidget);
  });
}