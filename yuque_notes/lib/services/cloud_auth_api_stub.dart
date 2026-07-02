import '../data/models/cloud_auth_result.dart';
import 'cloud_auth_api.dart';

class UnconfiguredCloudAuthApi implements CloudAuthApi {
  @override
  Future<CloudAuthResult> login({
    required String username,
    required String password,
  }) {
    return Future.error(CloudAuthException('云端 API 尚未配置'));
  }

  @override
  Future<CloudAuthResult> register({
    required String username,
    required String password,
  }) {
    return Future.error(CloudAuthException('云端 API 尚未配置'));
  }
}