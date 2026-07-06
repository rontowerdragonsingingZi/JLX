import '../data/models/cloud_auth_result.dart';

abstract class CloudAuthApi {
  Future<CloudAuthResult> login({
    required String username,
    required String password,
  });

  Future<CloudAuthResult> register({
    required String username,
    required String password,
    required String email,
    required String verificationCode,
  });

  Future<int?> sendVerificationCode({required String email});

  Future<CloudAuthResult> refresh({required String refreshToken});

  Future<String?> updateAvatar({
    required String accessToken,
    required String? avatar,
  });
}

class CloudAuthException implements Exception {
  CloudAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
