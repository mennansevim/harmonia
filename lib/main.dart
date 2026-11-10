import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/error_handling.dart';
import 'application/error_log.dart';
import 'choir/online/online_choir_controller.dart';
import 'trainer/app/trainer_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = LocalErrorLog();
  installGlobalErrorHandlers(errors);
  // The online choir exists only in builds given a server (ADR-041).
  if (OnlineConfig.enabled) {
    await Supabase.initialize(
      url: OnlineConfig.url,
      publishableKey: OnlineConfig.key,
    );
  }
  runApp(const TrainerApp());
}
