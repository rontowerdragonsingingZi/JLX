/// 跨平台品牌文案（Windows / Android 共用逻辑，展示名由平台配置配合）。
class AppBranding {
  AppBranding._();

  /// 完整应用名（窗口标题、应用内标题、桌面端显示名）。
  static const String fullName = 'NoteYourNeed';

  /// 手机桌面图标下的短名。
  static const String shortName = 'NN';

  /// 论坛名称（登录/注册文案）。
  static const String forumName = 'NN论坛';

  static String get loginTitle => '登录$forumName';

  static String get registerTitle => '注册$forumName';
}
