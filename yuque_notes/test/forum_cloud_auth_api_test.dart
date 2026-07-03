import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuque_notes/services/cloud_auth_api.dart';
import 'package:yuque_notes/services/forum/forum_api_client.dart';
import 'package:yuque_notes/services/forum/forum_cloud_auth_api.dart';

import 'helpers/test_setup.dart';

void main() {
  group('ForumCloudAuthApi', () {
    test('login parses camelCase auth response', () async {
      final client = ForumApiClient(
        baseUrl: 'https://forum.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/auth/login');
          expect(request.headers['Content-Type'], 'application/json');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['username'], 'alice');
          expect(body['password'], 'secret123');
          return http.Response(
            jsonEncode({
              'accessToken': 'access',
              'refreshToken': 'refresh',
              'userId': 7,
              'username': 'alice',
              'avatar': null,
            }),
            200,
          );
        }),
      );

      final api = ForumCloudAuthApi(client: client);
      final result = await api.login(username: 'alice', password: 'secret123');

      expect(result.accessToken, 'access');
      expect(result.refreshToken, 'refresh');
      expect(result.userId, 7);
      expect(result.username, 'alice');
      expect(result.avatar, isNull);
    });

    test('register surfaces FastAPI detail errors', () async {
      final client = ForumApiClient(
        baseUrl: 'https://forum.test',
        client: MockClient((request) async {
          return jsonUtf8Response({'detail': '用户名已存在'}, 409);
        }),
      );

      final api = ForumCloudAuthApi(client: client);

      await expectLater(
        api.register(username: 'alice', password: 'secret123'),
        throwsA(
          isA<CloudAuthException>().having(
            (error) => error.message,
            'message',
            '用户名已存在',
          ),
        ),
      );
    });

    test('login surfaces 401 detail errors', () async {
      final client = ForumApiClient(
        baseUrl: 'https://forum.test',
        client: MockClient((request) async {
          return jsonUtf8Response({'detail': '用户名或密码错误'}, 401);
        }),
      );

      final api = ForumCloudAuthApi(client: client);

      await expectLater(
        api.login(username: 'alice', password: 'wrong'),
        throwsA(
          isA<CloudAuthException>().having(
            (error) => error.message,
            'message',
            '用户名或密码错误',
          ),
        ),
      );
    });
  });
}