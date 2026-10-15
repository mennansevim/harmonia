import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Design direction A+C (DESIGN_STUDIES 2026-10-14): A's path, chunky
/// controls and answer sheet for everyday practice; C's thin cards, mono
/// data labels and evidence layout for results and reports. Platform fonts
/// (SF Pro / Roboto) keep native rendering, Dynamic Type and offline use.
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
  static const button = 16.0;
}

abstract final class HarmoniaMotion {
  static const quick = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
  static const emphasized = Curves.easeOutCubic;

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
    correct: Color(0xFF137A52),
    nearMiss: Color(0xFF8A5A00),
    incorrect: Color(0xFFB42318),
    wrongOctave: Color(0xFF9C4A00),
    notMeasured: Color(0xFF545871),
  );

  static const dark = HarmoniaResultColors(
    correct: Color(0xFF5FD6A0),
    nearMiss: Color(0xFFF2C46B),
    incorrect: Color(0xFFFFB4A8),
    wrongOctave: Color(0xFFFFB37A),
    notMeasured: Color(0xFFB3B6CB),
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

/// Brand palette beyond the Material scheme: the chunky-button shadow,
/// streak/achievement sun, recording coral, success mint and hairlines.
@immutable
class HarmoniaPalette extends ThemeExtension<HarmoniaPalette> {
  const HarmoniaPalette({
    required this.primaryDeep,
    required this.sun,
    required this.onSun,
    required this.coral,
    required this.mint,
    required this.mintSoft,
    required this.coralSoft,
    required this.line,
    required this.muted,
    required this.wave,
    required this.waveSecond,
  });

  final Color primaryDeep;
  final Color sun;
  final Color onSun;
  final Color coral;
  final Color mint;
  final Color mintSoft;
  final Color coralSoft;
  final Color line;
  final Color muted;
  final Color wave;
  final Color waveSecond;

  static const light = HarmoniaPalette(
    primaryDeep: Color(0xFF3B2BBF),
    sun: Color(0xFFFFC531),
    onSun: Color(0xFF3D2C00),
    coral: Color(0xFFE5483A),
    mint: Color(0xFF1AA874),
    mintSoft: Color(0xFFDDF6EC),
    coralSoft: Color(0xFFFDE5E1),
    line: Color(0xFFE4E3EF),
    muted: Color(0xFF5E6285),
    wave: Color(0xFF5B46F5),
    waveSecond: Color(0xFFE5483A),
  );

  static const dark = HarmoniaPalette(
    primaryDeep: Color(0xFF2A1F86),
    sun: Color(0xFFFFCF5C),
    onSun: Color(0xFF2A1E00),
    coral: Color(0xFFFF7A6B),
    mint: Color(0xFF4FD49C),
    mintSoft: Color(0xFF113A2B),
    coralSoft: Color(0xFF45201B),
    line: Color(0xFF2E2F4A),
    muted: Color(0xFFA6A9C6),
    wave: Color(0xFFA899FF),
    waveSecond: Color(0xFFFF8F80),
  );

  @override
  HarmoniaPalette copyWith() => this;

  @override
  HarmoniaPalette lerp(HarmoniaPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return HarmoniaPalette(
      primaryDeep: l(primaryDeep, other.primaryDeep),
      sun: l(sun, other.sun),
      onSun: l(onSun, other.onSun),
      coral: l(coral, other.coral),
      mint: l(mint, other.mint),
      mintSoft: l(mintSoft, other.mintSoft),
      coralSoft: l(coralSoft, other.coralSoft),
      line: l(line, other.line),
      muted: l(muted, other.muted),
      wave: l(wave, other.wave),
      waveSecond: l(waveSecond, other.waveSecond),
    );
  }
}

abstract final class HarmoniaTheme {
  static const _indigo = Color(0xFF5B46F5);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: _indigo,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    ).copyWith(
      primary: _indigo,
      onPrimary: Colors.white,
      surface: const Color(0xFFF7F7FC),
      onSurface: const Color(0xFF17183A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF0EFF8),
      surfaceContainerHigh: const Color(0xFFE9E8F4),
      surfaceContainerHighest: const Color(0xFFE2E1F0),
      onSurfaceVariant: const Color(0xFF5E6285),
      outlineVariant: const Color(0xFFE4E3EF),
    ),
    HarmoniaResultColors.light,
    HarmoniaPalette.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: _indigo,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    ).copyWith(
      primary: const Color(0xFFA899FF),
      onPrimary: const Color(0xFF1A0E73),
      surface: const Color(0xFF0F1022),
      onSurface: const Color(0xFFECEBFA),
      surfaceContainerLowest: const Color(0xFF0B0C1B),
      surfaceContainerLow: const Color(0xFF17182E),
      surfaceContainer: const Color(0xFF1C1D36),
      surfaceContainerHigh: const Color(0xFF23243F),
      surfaceContainerHighest: const Color(0xFF2B2C4A),
      onSurfaceVariant: const Color(0xFFA6A9C6),
      outlineVariant: const Color(0xFF2E2F4A),
    ),
    HarmoniaResultColors.dark,
    HarmoniaPalette.dark,
  );

  static ThemeData _build(
    ColorScheme scheme,
    HarmoniaResultColors results,
    HarmoniaPalette palette,
  ) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: scheme.brightness,
    );
    final t = base.textTheme;
    final text = t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: t.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
    );
    final isIos =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [results, palette],
      splashFactory: isIos ? NoSplash.splashFactory : InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        centerTitle: isIos,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HarmoniaRadius.card),
          side: BorderSide(color: palette.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.line, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HarmoniaRadius.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.line, width: 2),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HarmoniaRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HarmoniaRadius.chip),
        ),
        side: BorderSide(color: palette.line),
        labelStyle: text.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.line, width: 1.5),
          textStyle: text.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: palette.line,
        linearMinHeight: 6,
      ),
    );
  }
}

/// Data label style (C): small caps-like utility text with tabular digits.
TextStyle harmoniaDataLabel(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
    letterSpacing: 0.4,
    fontWeight: FontWeight.w700,
    color: context.palette.muted,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

extension HarmoniaThemeX on BuildContext {
  HarmoniaResultColors get resultColors =>
      Theme.of(this).extension<HarmoniaResultColors>() ??
      HarmoniaResultColors.light;
  HarmoniaPalette get palette =>
      Theme.of(this).extension<HarmoniaPalette>() ?? HarmoniaPalette.light;
}
