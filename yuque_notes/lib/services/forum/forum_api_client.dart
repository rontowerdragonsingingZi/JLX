import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ForumApiException implements Exception {
  ForumApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ForumApiClient {
  ForumApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl;

  static const String defaultBaseUrl = 'https://forum.mahoer.space';

  final http.Client _client;
  final String baseUrl;

  Uri uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({String? accessToken}) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  /// 从响应体提取可读错误；空 body / 非 JSON 时带上 HTTP 状态说明。
  static String extractDetail(String body, {int? statusCode}) {
    final trimmed = body.trim();
    if (trimmed.isNotEmpty) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String && detail.isNotEmpty) {
            return detail;
          }
          if (detail is List && detail.isNotEmpty) {
            final first = detail.first;
            if (first is Map<String, dynamic>) {
              final message = first['msg'];
              if (message is String && message.isNotEmpty) {
                return message;
              }
            }
            return detail.toString();
          }
          final message = decoded['message'];
          if (message is String && message.isNotEmpty) {
            return message;
          }
        }
      } on FormatException {
        // 非 JSON：截断展示正文
        if (trimmed.length <= 160) {
          return trimmed;
        }
        return '${trimmed.substring(0, 160)}…';
      }
    }

    return switch (statusCode) {
      400 => '请求参数错误',
      401 => '用户名或密码错误，或未授权',
      403 => '无权限访问',
      404 => '接口不存在（请检查服务地址）',
      502 => '网关错误 502：论坛服务未响应（请检查服务端进程/反代，应用日志可能无记录）',
      503 => '服务暂时不可用 503',
      504 => '网关超时 504',
      null => '网络请求失败',
      _ => '请求失败（HTTP $statusCode）',
    };
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    List<int> expectedStatusCodes = const [200],
  }) async {
    return _send(
      () => _client.post(
        uri(path),
        headers: _headers(accessToken: accessToken),
        body: body == null ? null : jsonEncode(body),
      ),
      expectedStatusCodes,
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    List<int> expectedStatusCodes = const [200],
  }) async {
    return _send(
      () => _client.patch(
        uri(path),
        headers: _headers(accessToken: accessToken),
        body: body == null ? null : jsonEncode(body),
      ),
      expectedStatusCodes,
    );
  }

  Future<void> delete(
    String path, {
    String? accessToken,
    List<int> expectedStatusCodes = const [204],
  }) async {
    await _send(
      () => _client.delete(
        uri(path),
        headers: _headers(accessToken: accessToken),
      ),
      expectedStatusCodes,
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
    List<int> expectedStatusCodes,
  ) async {
    try {
      final response = await request();
      return _decodeResponse(response, expectedStatusCodes);
    } on SocketException catch (e) {
      throw ForumApiException(
        '无法连接服务器（$baseUrl）：${e.message}',
      );
    } on HttpException catch (e) {
      throw ForumApiException('HTTP 错误：${e.message}');
    } on HandshakeException catch (e) {
      throw ForumApiException('TLS/证书错误：${e.message}');
    } on ForumApiException {
      rethrow;
    } catch (e) {
      throw ForumApiException('请求异常：$e');
    }
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    List<int> expectedStatusCodes,
  ) {
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw ForumApiException(
        extractDetail(response.body, statusCode: response.statusCode),
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ForumApiException(
      '响应格式异常',
      statusCode: response.statusCode,
    );
  }
}
