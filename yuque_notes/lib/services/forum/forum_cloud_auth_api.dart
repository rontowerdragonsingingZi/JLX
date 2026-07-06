import '../../data/models/cloud_auth_result.dart';
import '../cloud_auth_api.dart';
import 'forum_api_client.dart';

class ForumCloudAuthApi implements CloudAuthApi {
  ForumCloudAuthApi({ForumApiClient? client})
      : _client = client ?? ForumApiClient();

  final ForumApiClient _client;

  @override
  Future<CloudAuthResult> login({
    required String username,
    required String password,
  }) {
    return _authenticate(
      path: '/api/auth/login',
      username: username,
      password: password,
    );
  }

  @override
  Future<CloudAuthResult> register({
    required String username,
    required String password,
    required String email,
    required String verificationCode,
  }) {
    return _authenticate(
      path: '/api/auth/register',
      username: username,
      password: password,
      email: email,
      verificationCode: verificationCode,
    );
  }

  @override
  Future<int?> sendVerificationCode({required String email}) async {
    try {
      final json = await _client.postJson(
        '/api/auth/send-verification-code',
        body: {'email': email.trim()},
      );
      final retryAfterSeconds = json['retryAfterSeconds'];
      if (retryAfterSeconds == null) {
        return null;
      }
      if (retryAfterSeconds is num) {
        return retryAfterSeconds.toInt();
      }
      throw CloudAuthException('Unexpected verification response');
    } on ForumApiException catch (error) {
      throw CloudAuthException(error.message);
    }
  }

  @override
  Future<CloudAuthResult> refresh({required String refreshToken}) async {
    try {
      final json = await _client.postJson(
        '/api/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      return _parseAuthResult(json);
    } on ForumApiException catch (error) {
      throw CloudAuthException(error.message);
    }
  }

  @override
  Future<String?> updateAvatar({
    required String accessToken,
    required String? avatar,
  }) async {
    try {
      final json = await _client.patchJson(
        '/api/users/me/avatar',
        accessToken: accessToken,
        body: {'avatar': avatar},
      );
      final updatedAvatar = json['avatar'];
      if (updatedAvatar == null || updatedAvatar is String) {
        return updatedAvatar as String?;
      }
      throw CloudAuthException('Unexpected avatar response');
    } on ForumApiException catch (error) {
      throw CloudAuthException(error.message);
    }
  }

  Future<CloudAuthResult> _authenticate({
    required String path,
    required String username,
    required String password,
    String? email,
    String? verificationCode,
  }) async {
    try {
      final json = await _client.postJson(
        path,
        body: {
          'username': username.trim(),
          'password': password,
          if (email != null) 'email': email.trim(),
          if (verificationCode != null)
            'verificationCode': verificationCode.trim(),
        },
      );
      return _parseAuthResult(json);
    } on ForumApiException catch (error) {
      throw CloudAuthException(error.message);
    }
  }

  CloudAuthResult _parseAuthResult(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final userId = json['userId'];
    final username = json['username'];
    if (accessToken is! String || userId is! num || username is! String) {
      throw CloudAuthException('Unexpected auth response');
    }

    return CloudAuthResult(
      accessToken: accessToken,
      refreshToken: json['refreshToken'] as String?,
      userId: userId.toInt(),
      username: username,
      avatar: json['avatar'] as String?,
    );
  }
}
