/// Build channel (REL-09). `dev` shows developer diagnostics and
/// simulations; `beta` is what testers outside the team get. Chosen at
/// build time: `--dart-define=HARMONIA_CHANNEL=beta`.
enum AppChannel {
  dev,
  beta;

  static AppChannel parse(String value) => switch (value) {
    'beta' => AppChannel.beta,
    'dev' => AppChannel.dev,
    _ => throw ArgumentError('Unknown HARMONIA_CHANNEL $value'),
  };

  static final AppChannel current = parse(
    const String.fromEnvironment('HARMONIA_CHANNEL', defaultValue: 'dev'),
  );

  /// Audio lab, mock result scenarios and content placeholders.
  bool get showsDeveloperTools => this == AppChannel.dev;

  String get label => switch (this) {
    AppChannel.dev => 'Geliştirici sürümü',
    AppChannel.beta => 'Beta sürümü',
  };
}
