import 'cloud_auth_result.dart';
import 'user.dart';

class CloudSession {
  const CloudSession({
    required this.accessToken,
    required this.userId,
    required this.username,
    this.refreshToken,
    this.avatar,
  });

  final String accessToken;
  final String? refreshToken;
  final int userId;
  final String username;
  final String? avatar;

  factory CloudSession.fromAuthResult(CloudAuthResult result) {
    return CloudSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.userId,
      username: result.username,
      avatar: result.avatar,
    );
  }

  User toDisplayUser() {
    return User(
      id: userId,
      username: username,
      createdAt: DateTime.now(),
      avatar: avatar,
    );
  }

  CloudSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? userId,
    String? username,
    String? avatar,
  }) {
    return CloudSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
    );
  }
}