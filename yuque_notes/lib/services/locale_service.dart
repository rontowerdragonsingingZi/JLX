import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 持久化界面语言（zh_CN / en_US）。
class LocaleService {
  static const String _localeKey = 'app_locale';

  static const Locale zhCN = Locale('zh', 'CN');
  static const Locale enUS = Locale('en', 'US');

  static const List<Locale> supportedLocales = [zhCN, enUS];

  Future<Locale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localeKey);
    switch (value) {
      case 'en':
      case 'en_US':
        return enUS;
      case 'zh':
      case 'zh_CN':
      default:
        return zhCN;
    }
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    final value = locale.languageCode == 'en' ? 'en' : 'zh';
    await prefs.setString(_localeKey, value);
  }

  Locale toggleLocale(Locale current) {
    return current.languageCode == 'en' ? zhCN : enUS;
  }
}
