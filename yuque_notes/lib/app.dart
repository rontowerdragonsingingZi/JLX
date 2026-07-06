import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'data/models/user.dart';
import 'screens/workspace/workspace_screen.dart';
import 'services/cloud_auth_api.dart';
import 'services/local_user_service.dart';
import 'services/session_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';

class YuqueNotesApp extends StatefulWidget {
  const YuqueNotesApp({super.key, this.cloudAuthApi});

  final CloudAuthApi? cloudAuthApi;

  @override
  State<YuqueNotesApp> createState() => _YuqueNotesAppState();
}

class _YuqueNotesAppState extends State<YuqueNotesApp> {
  final _sessionService = SessionService();
  final _localUserService = LocalUserService();
  final _themeService = ThemeService();
  Widget _home = const _SplashScreen();
  User? _localUser;
  User? _cloudUser;
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final themeMode = await _themeService.getThemeMode();
    final cloudSession = await _sessionService.getCloudSession();
    final localUser = await _localUserService.resolveActiveLocalUser(
      cloudSession: cloudSession,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = themeMode;
      _localUser = localUser;
      _cloudUser = cloudSession?.toDisplayUser();
      _home = _buildWorkspace();
    });
  }

  WorkspaceScreen _buildWorkspace() {
    return WorkspaceScreen(
      localUser: _localUser!,
      cloudUser: _cloudUser,
      onCloudAuthChanged: _onCloudAuthChanged,
      cloudAuthApi: widget.cloudAuthApi,
      themeMode: _themeMode,
      onToggleTheme: _toggleTheme,
    );
  }

  Future<void> _toggleTheme() async {
    final next = _themeService.toggleThemeMode(_themeMode);
    await _themeService.saveThemeMode(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = next;
      _home = _buildWorkspace();
    });
  }

  Future<void> _onCloudAuthChanged(User? cloudUser) async {
    final cloudSession = cloudUser == null
        ? null
        : await _sessionService.getCloudSession();
    final localUser = await _localUserService.resolveActiveLocalUser(
      cloudSession: cloudSession,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _cloudUser = cloudUser;
      _localUser = localUser;
      _home = _buildWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '语雀笔记',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 104),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: context.appColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}