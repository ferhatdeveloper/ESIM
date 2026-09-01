import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/services/sqlite/sqlite_init.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initSqliteFactory();
  runApp(const ProviderScope(child: EsimApp()));
}
