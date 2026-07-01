import 'package:yuque_notes/data/database/database_bootstrap.dart';
import 'package:yuque_notes/data/database/database_helper.dart';

Future<void> setUpTestDatabase() async {
  await resetDatabaseBootstrap();
  await initializeDatabase(isWeb: false, isDesktop: true);
  await DatabaseHelper.instance.useInMemoryDatabase();
}

Future<void> tearDownTestDatabase() async {
  await resetDatabaseBootstrap();
}