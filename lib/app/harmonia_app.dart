import 'package:flutter/material.dart';

import '../features/single_tone_exercise/single_tone_exercise_screen.dart';

/// App shell (ARCHITECTURE.md § Katmanlar: "App shell / navigation").
///
/// Faz 1 only has the single-tone exercise, so it is the app's home screen
/// directly; real navigation/routing is added once more exercises exist.
class HarmoniaApp extends StatelessWidget {
  const HarmoniaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harmonia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SingleToneExerciseScreen(),
    );
  }
}
