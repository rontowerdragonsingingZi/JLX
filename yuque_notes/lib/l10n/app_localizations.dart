import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 轻量 i18n：简体中文 / English（无第三方插件，Windows & Android 共用）。
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(l10n != null, 'AppLocalizations not found in context');
    return l10n!;
  }

  bool get isZh => locale.languageCode != 'en';

  String _t(String zh, String en) => isZh ? zh : en;

  // —— Common ——
  String get ok => _t('确定', 'OK');
  String get cancel => _t('取消', 'Cancel');
  String get close => _t('关闭', 'Close');
  String get save => _t('保存', 'Save');
  String get delete => _t('删除', 'Delete');
  String get rename => _t('重命名', 'Rename');
  String get copy => _t('复制', 'Copy');
  String get done => _t('完成', 'Done');
  String get language => _t('语言', 'Language');
  String get languageZh => '简体中文';
  String get languageEn => 'English';
  String get pleaseLogin => _t('请登录', 'Sign in');
  String get logout => _t('退出登录', 'Sign out');
  String get dayMode => _t('日间模式', 'Light mode');
  String get nightMode => _t('黑夜模式', 'Dark mode');
  String get backToLibrary => _t('返回目录', 'Back to library');

  // —— Auth ——
  String get loginForum => _t('登录NN论坛', 'Sign in to NN Forum');
  String get registerForum => _t('注册NN论坛', 'Register for NN Forum');
  String get username => _t('用户名', 'Username');
  String get password => _t('密码', 'Password');
  String get confirmPassword => _t('确认密码', 'Confirm password');
  String get email => _t('邮箱', 'Email');
  String get verificationCode => _t('邮箱验证码', 'Email code');
  String get sendCode => _t('发送验证码', 'Send code');
  String get login => _t('登录', 'Sign in');
  String get register => _t('注册', 'Register');
  String get noAccount => _t('还没有账号？', "Don't have an account?");
  String get hasAccount => _t('已有账号？', 'Already have an account?');
  String get passwordMismatch => _t('两次输入的密码不一致', 'Passwords do not match');
  String get enterEmail => _t('请输入邮箱', 'Please enter email');
  String get enterCode => _t('请输入验证码', 'Please enter verification code');
  String get codeSent => _t('验证码已发送', 'Verification code sent');
  String codeSentRetry(int seconds) =>
      _t('验证码已发送，$seconds 秒后可再次发送',
          'Code sent. Retry in $seconds s');
  String get loginSuccess => _t('登录成功', 'Signed in');
  String get loginFailed => _t('登录失败', 'Sign-in failed');
  String get registerSuccess => _t('注册成功', 'Registered');
  String get registerFailed => _t('注册失败', 'Registration failed');
  String welcomeBack(String name) =>
      _t('欢迎回来，$name！', 'Welcome back, $name!');
  String accountCreated(String name, String app) =>
      _t('账号 $name 已创建，欢迎使用 $app。',
          'Account $name created. Welcome to $app.');
  String get logoutSuccess => _t('退出登录成功', 'Signed out');
  String get logoutFailed => _t('退出登录失败', 'Sign-out failed');
  String get logoutSuccessMsg =>
      _t('您已退出云端账号，本地笔记仍保留在本机。',
          'You signed out of the cloud account. Local notes remain on this device.');
  String get loginExpired => _t('登录已过期，请重新登录', 'Session expired. Please sign in again.');
  String get pleaseLoginFirst => _t('请先登录', 'Please sign in first');
  String get cloudNotConfigured => _t('云端服务未配置', 'Cloud service is not configured');
  String get tapAvatarToChange => _t('点击头像更换', 'Tap avatar to change');

  // —— Workspace ——
  String get newFolder => _t('新建文件夹', 'New folder');
  String get newDocument => _t('新建文档', 'New document');
  String get newSubfolder => _t('新建子文件夹', 'New subfolder');
  String get folderName => _t('文件夹名称', 'Folder name');
  String get documentTitle => _t('文档标题', 'Document title');
  String get renameFolder => _t('重命名文件夹', 'Rename folder');
  String get renameDocument => _t('重命名文档', 'Rename document');
  String get deleteFolder => _t('删除文件夹', 'Delete folder');
  String get deleteDocument => _t('删除文档', 'Delete document');
  String get deleteFolderConfirm =>
      _t('确定删除该文件夹及其所有子内容？',
          'Delete this folder and all its contents?');
  String get deleteDocumentConfirm =>
      _t('确定删除该文档？', 'Delete this document?');
  String get emptyLibrary =>
      _t('暂无内容，请创建文件夹', 'No content yet. Create a folder.');
  String get selectOrCreateDoc =>
      _t('选择或创建一个文档开始记录',
          'Select or create a document to start writing');
  String get export => _t('导出', 'Export');
  String get import => _t('导入', 'Import');
  String get contactUs => _t('联系我们', 'Contact us');
  String get exportFailed => _t('导出失败', 'Export failed');
  String get importFailed => _t('导入失败', 'Import failed');
  String exportedTo(String path) => _t('已导出：$path', 'Exported: $path');
  String importDone(int folders, int docs) => _t(
        '导入完成：新建文件夹 $folders 个，文档 $docs 篇',
        'Import done: $folders folders, $docs documents',
      );
  String get operationFailed => _t('操作失败', 'Operation failed');
  String get pleaseLoginBeforeUpload =>
      _t('请先登录后再上传云端', 'Sign in before uploading to cloud');
  String get guestCannotUpload =>
      _t('当前为本地游客笔记，请登录社区账号后新建文档再上传',
          'Guest notes cannot be uploaded. Sign in and create new documents.');
  String get saved => _t('已保存', 'Saved');
  String get uploadedCloud => _t('已上传云端', 'Uploaded to cloud');
  String get uploadCloud => _t('上传云端', 'Upload');
  String get alreadyUploaded => _t('已上传', 'Uploaded');
  String get syncToCommunity => _t('同步到社区', 'Sync to community');

  // —— Editor ——
  String get insertImage => _t('插入图片', 'Insert image');
  String get resizeImage => _t('调整图片大小', 'Resize image');
  String get insertCopyBlock => _t('插入可复制块', 'Insert copy block');
  String get formatTools => _t('格式工具', 'Format tools');
  String get collapseFormat => _t('收起格式', 'Hide format');
  String get formatToolsHint =>
      _t('点「格式工具」查看全部功能', 'Open Format tools for all options');
  String get startWriting => _t('开始记录...', 'Start writing...');
  String get cannotReadImage => _t('无法读取图片数据', 'Cannot read image data');
  String get placeCursorOnImage =>
      _t('请将光标放在要调整的图片上', 'Place the cursor on the image to resize');
  String get imageWidth => _t('调整图片宽度', 'Image width');
  String get widthPx => _t('宽度（像素）', 'Width (px)');
  String get editCopyBlock => _t('编辑可复制块', 'Edit copy block');
  String get smallTitle => _t('小标题', 'Title');
  String get enterSmallTitle => _t('输入小标题', 'Enter a title');
  String get content => _t('内容', 'Content');
  String get contentHintCopy =>
      _t('输入内容（复制按钮将复制此处）', 'Content (Copy uses this text)');
  String get clickEditContent => _t('点击编辑内容…', 'Tap to edit content…');
  String get contentCopied => _t('已复制内容', 'Copied');
  String get unnamedSnippet => _t('未命名片段', 'Untitled snippet');

  // —— Format panel ——
  String get sectionEdit => _t('编辑', 'Edit');
  String get undo => _t('撤销', 'Undo');
  String get undoHint => _t('撤销上一步', 'Undo last action');
  String get redo => _t('重做', 'Redo');
  String get redoHint => _t('恢复上一步', 'Redo last action');
  String get sectionTextStyle => _t('文字样式', 'Text style');
  String get bold => _t('粗体', 'Bold');
  String get boldHint => _t('加粗选中文字', 'Bold selection');
  String get italic => _t('斜体', 'Italic');
  String get italicHint => _t('倾斜选中文字', 'Italic selection');
  String get underline => _t('下划线', 'Underline');
  String get underlineHint => _t('添加下划线', 'Underline selection');
  String get strikethrough => _t('删除线', 'Strikethrough');
  String get strikethroughHint => _t('添加删除线', 'Strike selection');
  String get clearFormat => _t('清除格式', 'Clear format');
  String get clearFormatHint => _t('去掉文字样式', 'Remove text styles');
  String get sectionFontSize => _t('字号', 'Font size');
  String get sizeDefault => _t('默认', 'Default');
  String get sizeDefaultHint => _t('恢复默认字号', 'Reset font size');
  String get sizeSmall => _t('较小', 'Smaller');
  String get sizeSmallHint => _t('字号变小', 'Decrease size');
  String get sizeLarge => _t('较大', 'Larger');
  String get sizeLargeHint => _t('字号变大', 'Increase size');
  String get sizeHuge => _t('特大', 'Huge');
  String get sizeHugeHint => _t('字号最大', 'Largest size');
  String get sectionColor => _t('文字颜色', 'Text color');
  String get colorDefault => _t('默认色', 'Default color');
  String get colorBlack => _t('黑', 'Black');
  String get colorRed => _t('红', 'Red');
  String get colorOrange => _t('橙', 'Orange');
  String get colorGreen => _t('绿', 'Green');
  String get colorBlue => _t('蓝', 'Blue');
  String get colorPurple => _t('紫', 'Purple');
  String get sectionParagraph => _t('段落', 'Paragraph');
  String get quote => _t('引用', 'Quote');
  String get quoteHint => _t('引用段落', 'Block quote');
  String get bulletList => _t('项目符号', 'Bullets');
  String get bulletListHint => _t('无序列表', 'Bullet list');
  String get numberedList => _t('编号列表', 'Numbers');
  String get numberedListHint => _t('有序列表', 'Numbered list');
  String get indentMore => _t('增加缩进', 'Indent');
  String get indentMoreHint => _t('段落向右缩进', 'Increase indent');
  String get indentLess => _t('减少缩进', 'Outdent');
  String get indentLessHint => _t('段落向左缩进', 'Decrease indent');
  String get sectionInsert => _t('插入', 'Insert');
  String get copyBlock => _t('可复制块', 'Copy block');
  String get copyBlockHint =>
      _t('小标题+内容，可一键复制', 'Title + body, one-tap copy');
  String get insertImageHint => _t('从相册选择图片', 'Pick an image');
  String get imageWidthHint => _t('调整选中图片宽度', 'Resize selected image');

  // —— Contact ——
  String get contactMethods => _t('联系方式', 'Contact');
  String get wechat => _t('微信', 'WeChat');
  String get qqMail => _t('QQ邮箱', 'QQ Mail');
  String get qrLoadFailed => _t('二维码加载失败', 'Failed to load QR');
  String copiedLabel(String label) => _t('已复制$label', 'Copied $label');
  String get contactAbout => _t(
        'NoteYourNeed（记你需）是一款个人开发的记事软件，如不登录论坛进行同步，则不会进行任何网络链接，保证您信息的安全性。'
            '但我们并不建议您在此存储助记词等极其极其重要的信息。'
            '如果有任何您想要加入的功能与建议，请联系我们，在确保该更新与反馈属实后我们会及时进行更新，欢迎您的使用。'
            '希望NN能够给您带来实际的生活便利。^_^',
        'NoteYourNeed is a personal note-taking app. Without signing in to sync, '
            'it makes no network connections, helping keep your data private. '
            'We do not recommend storing extremely sensitive secrets such as seed phrases. '
            'If you have feature ideas or feedback, contact us—we will update when verified. '
            'Hope NN makes daily life a bit easier. ^_^',
      );

  // —— Errors (common) ——
  String get folderNameEmpty => _t('文件夹名称不能为空', 'Folder name cannot be empty');
  String get folderNameDuplicate =>
      _t('该级文件夹名称不能重复，请创建一个次级文件夹',
          'A folder with this name already exists at this level. Create a subfolder instead.');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
