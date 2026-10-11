import 'package:flutter/material.dart';

/// Aurora brand + Konservatuvar result clarity (ADR-013). Tokens are a first
/// pass; final acceptance needs the planned user/contrast tests.
abstract final class HarmoniaSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class HarmoniaRadius {
  static const card = 20.0;
  static const chip = 12.0;
}

/// Result semantics. Wrong octave is NEVER the success colour and an invalid
/// measurement is neutral, not the error red: it is not a student mistake.
@immutable
class HarmoniaResultColors extends ThemeExtension<HarmoniaResultColors> {
  const HarmoniaResultColors({
    required this.correct,
    required this.nearMiss,
    required this.incorrect,
    required this.wrongOctave,
    required this.notMeasured,
  });

  final Color correct;
  final Color nearMiss;
  final Color incorrect;
  final Color wrongOctave;
  final Color notMeasured;

  static const light = HarmoniaResultColors(
    correct: Color(0xFF1B6E47),
    nearMiss: Color(0xFF8A5A00),
    incorrect: Color(0xFFB3261E),
    wrongOctave: Color(0xFF9C4A00),
    notMeasured: Color(0xFF515A6B),
  );

  static const dark = HarmoniaResultColors(
    correct: Color(0xFF6BDBA4),
    nearMiss: Color(0xFFF2C46B),
    incorrect: Color(0xFFF2B8B5),
    wrongOctave: Color(0xFFFFB37A),
    notMeasured: Color(0xFFB4BCCB),
  );

  @override
  HarmoniaResultColors copyWith({
    Color? correct,
    Color? nearMiss,
    Color? incorrect,
    Color? wrongOctave,
    Color? notMeasured,
  }) => HarmoniaResultColors(
    correct: correct ?? this.correct,
    nearMiss: nearMiss ?? this.nearMiss,
    incorrect: incorrect ?? this.incorrect,
    wrongOctave: wrongOctave ?? this.wrongOctave,
    notMeasured: notMeasured ?? this.notMeasured,
  );

  @override
  HarmoniaResultColors lerp(HarmoniaResultColors? other, double t) {
    if (other == null) return this;
    return HarmoniaResultColors(
      correct: Color.lerp(correct, other.correct, t)!,
      nearMiss: Color.lerp(nearMiss, other.nearMiss, t)!,
      incorrect: Color.lerp(incorrect, other.incorrect, t)!,
      wrongOctave: Color.lerp(wrongOctave, other.wrongOctave, t)!,
      notMeasured: Color.lerp(notMeasured, other.notMeasured, t)!,
    );
  }
}

abstract final class HarmoniaTheme {
  static const _auroraIndigo = Color(0xFF4B3FB8);
  static const _auroraTeal = Color(0xFF0E7C72);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: _auroraIndigo,
      secondary: _auroraTeal,
      brightness: Brightness.light,
    ),
    HarmoniaResultColors.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: _auroraIndigo,
      secondary: const Color(0xFF5FD3C6),
      brightness: Brightness.dark,
    ),
    HarmoniaResultColors.dark,
  );

  static ThemeData _build(ColorScheme scheme, HarmoniaResultColors results) =>
      ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        extensions: [results],
        cardTheme: CardThemeData(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HarmoniaRadius.card),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      );
}

extension HarmoniaThemeX on BuildContext {
  HarmoniaResultColors get resultColors =>
      Theme.of(this).extension<HarmoniaResultColors>() ??
      HarmoniaResultColors.light;
}
