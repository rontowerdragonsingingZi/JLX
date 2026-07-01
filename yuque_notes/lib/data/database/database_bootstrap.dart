import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_helper.dart';
import 'web_sqlite_assets.dart';

enum DatabaseFactoryKind { native, ffiDesktop, ffiWeb }

bool _initialized = false;

bool get isDesktopPlatform {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Web SQLite asset URIs (files in web/sqlite3.wasm and web/sqflite_sw.js).
SqfliteFfiWebOptions get webDatabaseOptions => SqfliteFfiWebOptions(
      sqlite3WasmUri: Uri.parse(kSqlite3WasmFile),
      sharedWorkerUri: Uri.parse(kSqfliteSharedWorkerJsFile),
    );

DatabaseFactoryKind resolveDatabaseFactory({
  required bool isWeb,
  required bool isDesktop,
}) {
  if (isWeb) {
    return DatabaseFactoryKind.ffiWeb;
  }
  if (isDesktop) {
    return DatabaseFactoryKind.ffiDesktop;
  }
  return DatabaseFactoryKind.native;
}

void applyDatabaseFactory(DatabaseFactoryKind kind) {
  switch (kind) {
    case DatabaseFactoryKind.ffiWeb:
      databaseFactory = createDatabaseFactoryFfiWeb(
        options: webDatabaseOptions,
        noWebWorker: true,
      );
    case DatabaseFactoryKind.ffiDesktop:
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    case DatabaseFactoryKind.native:
      break;
  }
}

Future<void> initializeDatabase({
  bool? isWeb,
  bool? isDesktop,
}) async {
  if (_initialized) {
    return;
  }

  final kind = resolveDatabaseFactory(
    isWeb: isWeb ?? kIsWeb,
    isDesktop: isDesktop ?? isDesktopPlatform,
  );
  applyDatabaseFactory(kind);
  _initialized = true;
}

Future<void> resetDatabaseBootstrap() async {
  await DatabaseHelper.instance.close();
  _initialized = false;
}