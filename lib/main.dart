import 'package:flutter/material.dart';

import 'app/error_handling.dart';
import 'application/error_log.dart';
import 'trainer/app/trainer_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = LocalErrorLog();
  installGlobalErrorHandlers(errors);
  runApp(const TrainerApp());
}
