import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuque_notes/data/database/database_bootstrap.dart';
import 'package:yuque_notes/data/database/database_helper.dart';

const String kTestAvatarDataUri =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z5BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<void> setUpTestDatabase() async {
  SharedPreferences.setMockInitialValues({});
  await resetDatabaseBootstrap();
  await initializeDatabase(isWeb: false, isDesktop: true);
  await DatabaseHelper.instance.useInMemoryDatabase();
}

Future<void> tearDownTestDatabase() async {
  await resetDatabaseBootstrap();
}

CircleAvatar readUserAvatar(WidgetTester tester) {
  return tester.widget<CircleAvatar>(find.byKey(const Key('user_avatar')));
}

http.Response jsonUtf8Response(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}