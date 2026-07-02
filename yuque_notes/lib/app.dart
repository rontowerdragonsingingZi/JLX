import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'data/models/user.dart';
import 'screens/workspace/workspace_screen.dart';
import 'services/cloud_auth_api.dart';
import 'services/local_user_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

class YuqueNotesApp extends StatefulWidget {
  const YuqueNotesApp({super.key, this.cloudAuthApi});

  final CloudAuthApi? cloudAuthApi;

  @override
  State<YuqueNotesApp> createState() => _YuqueNotesAppState();
}

class _YuqueNotesAppState extends State<YuqueNotesApp> {
  final _sessionService = SessionService();
  final _localUserService = LocalUserService();
  Widget _home = const _SplashScreen();
  User? _localUser;
  User? _cloudUser;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final localUser = await _localUserService.ensureLocalUser();
    final cloudSession = await _sessionService.getCloudSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _localUser = localUser;
      _cloudUser = cloudSession?.toDisplayUser();
      _home = WorkspaceScreen(
        localUser: localUser,
        cloudUser: _cloudUser,
        onCloudAuthChanged: _onCloudAuthChanged,
        cloudAuthApi: widget.cloudAuthApi,
      );
    });
  }

  void _onCloudAuthChanged(User? cloudUser) {
    setState(() {
      _cloudUser = cloudUser;
      if (_localUser != null) {
        _home = WorkspaceScreen(
          localUser: _localUser!,
          cloudUser: _cloudUser,
          onCloudAuthChanged: _onCloudAuthChanged,
          cloudAuthApi: widget.cloudAuthApi,
        );
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