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
  }) async {
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
  }) async {
    return _authenticate(
      path: '/api/auth/register',
      username: username,
      password: password,
    );
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

  Future<CloudAuthResult> _authenticate({
    required String path,
    required String username,
    required String password,
  }) async {
    try {
      final json = await _client.postJson(
        path,
        body: {
          'username': username.trim(),
          'password': password,
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
    if (accessToken is! String ||
        userId is! num ||
        username is! String) {
      throw CloudAuthException('认证响应格式无效');
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