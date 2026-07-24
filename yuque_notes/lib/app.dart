import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'app_branding.dart';
import 'data/models/user.dart';
import 'l10n/app_localizations.dart';
import 'screens/workspace/workspace_screen.dart';
import 'services/cloud_auth_api.dart';
import 'services/local_user_service.dart';
import 'services/locale_service.dart';
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
  final _localeService = LocaleService();
  bool _ready = false;
  User? _localUser;
  User? _cloudUser;
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = LocaleService.zhCN;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final themeMode = await _themeService.getThemeMode();
    final locale = await _localeService.getLocale();
    final cloudSession = await _sessionService.getCloudSession();
    final localUser = await _localUserService.resolveActiveLocalUser(
      cloudSession: cloudSession,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = themeMode;
      _locale = locale;
      _localUser = localUser;
      _cloudUser = cloudSession?.toDisplayUser();
      _ready = true;
    });
  }

  Future<void> _toggleTheme() async {
    final next = _themeService.toggleThemeMode(_themeMode);
    await _themeService.saveThemeMode(next);
    if (!mounted) {
      return;
    }
    setState(() => _themeMode = next);
  }

  Future<void> _setLocale(Locale locale) async {
    await _localeService.saveLocale(locale);
    if (!mounted) {
      return;
    }
    setState(() => _locale = locale);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBranding.fullName,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: LocaleService.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: !_ready || _localUser == null
          ? const _SplashScreen()
          : WorkspaceScreen(
              localUser: _localUser!,
              cloudUser: _cloudUser,
              onCloudAuthChanged: _onCloudAuthChanged,
              cloudAuthApi: widget.cloudAuthApi,
              themeMode: _themeMode,
              onToggleTheme: _toggleTheme,
              locale: _locale,
              onLocaleChanged: _setLocale,
            ),
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
