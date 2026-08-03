import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/models/document.dart' as models;
import 'package:yuque_notes/widgets/document_editor_panel.dart';

Widget _wrapEditor(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', 'CN')],
    home: Scaffold(
      body: SizedBox(
        height: 900,
        width: 1200,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('editor header has save only, no manual cloud upload UI',
      (tester) async {
    final document = models.Document(
      id: 1,
      userId: 2,
      folderId: 3,
      title: '测试文档',
      content: 'hello',
      createdAt: DateTime.parse('2026-01-01T00:00:00'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00'),
      syncedToCommunity: true,
    );

    await tester.pumpWidget(
      _wrapEditor(
        DocumentEditorPanel(
          document: document,
          onSave: (md) async => md,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('sync_to_community_button')), findsNothing);
    expect(find.byKey(const Key('synced_to_community_badge')), findsNothing);
    expect(find.text('上传云端'), findsNothing);
    expect(find.text('已上传'), findsNothing);
    expect(find.text('已上传云端'), findsNothing);
    expect(find.text('保存'), findsOneWidget);
  });
}
