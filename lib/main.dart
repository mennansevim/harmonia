import 'package:flutter/material.dart';

import 'app/error_handling.dart';
import 'app/harmonia_app.dart';
import 'application/error_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = LocalErrorLog();
  installGlobalErrorHandlers(errors);
  runApp(HarmoniaApp(errorLog: errors));
}
