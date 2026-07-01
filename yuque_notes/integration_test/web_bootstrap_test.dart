import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yuque_notes/bootstrap.dart';
import 'package:yuque_notes/data/database/database_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'web bootstrap opens ffiWeb sqlite and renders login screen',
    (tester) async {
      expect(kIsWeb, isTrue);
      expect(
        resolveDatabaseFactory(isWeb: true, isDesktop: false),
        DatabaseFactoryKind.ffiWeb,
      );

      final app = await bootstrapYuqueApp();
      await tester.pumpWidget(app);

      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (find.text('语雀笔记').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.text('语雀笔记'), findsOneWidget);
      expect(find.text('登录您的账号'), findsOneWidget);
      expect(find.text('登录'), findsWidgets);
      expect(find.text('注册'), findsWidgets);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}