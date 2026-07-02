import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/screens/auth/auth_dialog.dart';

import 'helpers/test_setup.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('auth dialog shows login and register entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showAuthDialog(context),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('登录您的账号'), findsOneWidget);
  });
}