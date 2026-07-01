import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database/database_bootstrap.dart';

Future<Widget> bootstrapYuqueApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDatabase();
  return const YuqueNotesApp();
}

Future<void> runYuqueApp() async {
  final app = await bootstrapYuqueApp();
  runApp(app);
}