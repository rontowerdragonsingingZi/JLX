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
  testWidgets('shows sync control when cloud sync is enabled', (tester) async {
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
          canSyncToCommunity: true,
          onSyncToCommunity: () async {},
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('sync_to_community_button')), findsOneWidget);
    expect(find.text('同步到社区'), findsOneWidget);
    expect(find.byKey(const Key('synced_to_community_badge')), findsOneWidget);
    expect(find.text('已同步'), findsOneWidget);
  });

  testWidgets('hides sync control for guest documents', (tester) async {
    final document = models.Document(
      id: 1,
      userId: 2,
      folderId: 3,
      title: '测试文档',
      content: 'hello',
      createdAt: DateTime.parse('2026-01-01T00:00:00'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00'),
    );

    await tester.pumpWidget(
      _wrapEditor(
        DocumentEditorPanel(
          document: document,
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('sync_to_community_button')), findsNothing);
  });
}