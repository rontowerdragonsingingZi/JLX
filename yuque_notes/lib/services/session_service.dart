import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _userIdKey = 'current_user_id';
  static const String _usernameKey = 'current_username';

  Future<void> saveSession({
    required int userId,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }

  Future<bool> isLoggedIn() async {
    return (await getUserId()) != null;
  }
}