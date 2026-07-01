import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/database/database_bootstrap.dart';
import 'package:yuque_notes/data/database/web_sqlite_assets.dart';

void main() {
  test('resolveDatabaseFactory selects ffiWeb on web', () {
    expect(
      resolveDatabaseFactory(isWeb: true, isDesktop: false),
      DatabaseFactoryKind.ffiWeb,
    );
    expect(
      resolveDatabaseFactory(isWeb: true, isDesktop: true),
      DatabaseFactoryKind.ffiWeb,
    );
  });

  test('resolveDatabaseFactory selects ffiDesktop on desktop non-web', () {
    expect(
      resolveDatabaseFactory(isWeb: false, isDesktop: true),
      DatabaseFactoryKind.ffiDesktop,
    );
  });

  test('resolveDatabaseFactory selects native on mobile', () {
    expect(
      resolveDatabaseFactory(isWeb: false, isDesktop: false),
      DatabaseFactoryKind.native,
    );
  });

  test('webDatabaseOptions references shipped wasm and worker assets', () {
    final options = webDatabaseOptions;
    expect(options.sqlite3WasmUri, Uri.parse(kSqlite3WasmFile));
    expect(options.sharedWorkerUri, Uri.parse(kSqfliteSharedWorkerJsFile));
  });
}