import 'dart:convert';

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
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  static String extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
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
        }
      }
    } on FormatException {
      // Fall through to generic message.
    }
    return 'Request failed';
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    List<int> expectedStatusCodes = const [200],
  }) async {
    final response = await _client.post(
      uri(path),
      headers: _headers(accessToken: accessToken),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response, expectedStatusCodes);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    List<int> expectedStatusCodes = const [200],
  }) async {
    final response = await _client.patch(
      uri(path),
      headers: _headers(accessToken: accessToken),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response, expectedStatusCodes);
  }

  Future<void> delete(
    String path, {
    String? accessToken,
    List<int> expectedStatusCodes = const [204],
  }) async {
    final response = await _client.delete(
      uri(path),
      headers: _headers(accessToken: accessToken),
    );
    _decodeResponse(response, expectedStatusCodes);
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    List<int> expectedStatusCodes,
  ) {
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw ForumApiException(
        extractDetail(response.body),
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
    throw ForumApiException('Unexpected response', statusCode: response.statusCode);
  }
}
