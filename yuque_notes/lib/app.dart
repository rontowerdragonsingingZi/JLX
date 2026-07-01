import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'data/models/user.dart';
import 'screens/auth/login_screen.dart';
import 'screens/workspace/workspace_screen.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

class YuqueNotesApp extends StatefulWidget {
  const YuqueNotesApp({super.key});

  @override
  State<YuqueNotesApp> createState() => _YuqueNotesAppState();
}

class _YuqueNotesAppState extends State<YuqueNotesApp> {
  final _sessionService = SessionService();
  Widget _home = const _SplashScreen();

  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final userId = await _sessionService.getUserId();
    final username = await _sessionService.getUsername();
    if (!mounted) {
      return;
    }
    setState(() {
      if (userId != null && username != null) {
        _home = WorkspaceScreen(
          user: User(
            id: userId,
            username: username,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        _home = const LoginScreen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '语雀笔记',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: _home,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}