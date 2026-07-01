import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/database/database_verify.dart';

import 'helpers/test_setup.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('verifyDatabaseSchema returns users folders documents tables', () async {
    final tables = await verifyDatabaseSchema();
    expect(tables, containsAll(['documents', 'folders', 'users']));
  });
}