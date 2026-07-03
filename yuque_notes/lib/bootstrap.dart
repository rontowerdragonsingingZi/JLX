import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database/database_bootstrap.dart';
import 'services/forum/forum_cloud_auth_api.dart';

Future<Widget> bootstrapYuqueApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDatabase();
  return YuqueNotesApp(cloudAuthApi: ForumCloudAuthApi());
}

Future<void> runYuqueApp() async {
  final app = await bootstrapYuqueApp();
  runApp(app);
}