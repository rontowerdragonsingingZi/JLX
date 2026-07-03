import '../data/models/cloud_auth_result.dart';

abstract class CloudAuthApi {
  Future<CloudAuthResult> login({
    required String username,
    required String password,
  });

  Future<CloudAuthResult> register({
    required String username,
    required String password,
  });

  Future<CloudAuthResult> refresh({required String refreshToken});
}

class CloudAuthException implements Exception {
  CloudAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}