import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

/// 桌面端默认路径在项目 `.dart_tool/...`，`flutter clean` 会清掉数据。
/// 改为用户应用支持目录，升级/重新编译后仍可复用同一份 SQLite。
Future<void> _configureDesktopDatabasePath() async {
  final supportDir = await getApplicationSupportDirectory();
  final dbDirPath = p.join(supportDir.path, 'databases');
  await Directory(dbDirPath).create(recursive: true);

  // 尽量迁移旧路径（仅当新库不存在且旧库在当前工作目录下存在时）
  final newDbFile = File(p.join(dbDirPath, 'yuque_notes.db'));
  final oldDbFile = File(
    p.join('.dart_tool', 'sqflite_common_ffi', 'databases', 'yuque_notes.db'),
  );
  if (!await newDbFile.exists() && await oldDbFile.exists()) {
    await oldDbFile.copy(newDbFile.path);
  }

  await databaseFactory.setDatabasesPath(dbDirPath);
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
  if (kind == DatabaseFactoryKind.ffiDesktop) {
    try {
      await _configureDesktopDatabasePath();
    } catch (_) {
      // 单元测试等环境可能无 path_provider，保留 ffi 默认路径即可。
    }
  }
  _initialized = true;
}

Future<void> resetDatabaseBootstrap() async {
  await DatabaseHelper.instance.close();
  _initialized = false;
}