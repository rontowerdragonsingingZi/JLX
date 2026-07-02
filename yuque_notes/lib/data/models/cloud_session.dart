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

  CloudSession copyWith({String? avatar}) {
    return CloudSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      username: username,
      avatar: avatar ?? this.avatar,
    );
  }
}