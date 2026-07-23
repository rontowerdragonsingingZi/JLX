import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/cloud_auth_result.dart';
import '../data/models/cloud_session.dart';
import 'cloud_auth_api.dart';

class SessionService {
  static const String _cloudTokenKey = 'cloud_access_token';
  static const String _cloudRefreshTokenKey = 'cloud_refresh_token';
  static const String _cloudUserIdKey = 'cloud_user_id';
  static const String _cloudUsernameKey = 'cloud_username';
  static const String _cloudAvatarKey = 'cloud_avatar';

  Future<void> saveCloudSession(CloudSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cloudTokenKey, session.accessToken);
    await prefs.setInt(_cloudUserIdKey, session.userId);
    await prefs.setString(_cloudUsernameKey, session.username);
    if (session.refreshToken != null) {
      await prefs.setString(_cloudRefreshTokenKey, session.refreshToken!);
    } else {
      await prefs.remove(_cloudRefreshTokenKey);
    }
    if (session.avatar != null) {
      await prefs.setString(_cloudAvatarKey, session.avatar!);
    } else {
      await prefs.remove(_cloudAvatarKey);
    }
  }

  Future<CloudSession?> getCloudSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_cloudTokenKey);
    final userId = prefs.getInt(_cloudUserIdKey);
    final username = prefs.getString(_cloudUsernameKey);
    if (token == null || userId == null || username == null) {
      return null;
    }
    return CloudSession(
      accessToken: token,
      refreshToken: prefs.getString(_cloudRefreshTokenKey),
      userId: userId,
      username: username,
      avatar: prefs.getString(_cloudAvatarKey),
    );
  }

  /// 更新会话头像。必须使用服务端返回值（R2 URL 或 null），不要存本地 Base64。
  Future<void> updateCloudAvatar(String? avatar) async {
    final session = await getCloudSession();
    if (session == null) {
      return;
    }
    if (avatar == null) {
      await saveCloudSession(session.copyWith(clearAvatar: true));
    } else {
      await saveCloudSession(session.copyWith(avatar: avatar));
    }
  }

  Future<void> clearCloudSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cloudTokenKey);
    await prefs.remove(_cloudRefreshTokenKey);
    await prefs.remove(_cloudUserIdKey);
    await prefs.remove(_cloudUsernameKey);
    await prefs.remove(_cloudAvatarKey);
  }

  Future<bool> isCloudLoggedIn() async {
    return (await getCloudSession()) != null;
  }

  Future<CloudSession?> refreshCloudSession(CloudAuthApi cloudAuthApi) async {
    final session = await getCloudSession();
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null || refreshToken.isEmpty) {
      return session;
    }

    try {
      final result = await cloudAuthApi.refresh(refreshToken: refreshToken);
      final refreshed = _sessionFromAuthResult(session, result);
      await saveCloudSession(refreshed);
      return refreshed;
    } on CloudAuthException {
      await clearCloudSession();
      return null;
    }
  }

  CloudSession _sessionFromAuthResult(
    CloudSession previous,
    CloudAuthResult result,
  ) {
    // 刷新/登录响应以服务端为准（avatar 可能是 R2 URL 或 null）
    final next = CloudSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken ?? previous.refreshToken,
      userId: result.userId,
      username: result.username,
      avatar: result.avatar,
    );
    return next;
  }
}