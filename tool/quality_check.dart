import 'dart:io';

/// Local code checks only. No build, upload, deployment or device acceptance.
class QualityStep {
  QualityStep(this.name, this.executable, List<String> arguments)
    : arguments = List.unmodifiable(arguments);
  final String name, executable;
  final List<String> arguments;
}

List<QualityStep> qualityPlan({bool fetchDependencies = false}) =>
    List.unmodifiable([
      if (fetchDependencies)
        QualityStep('Locked dependencies', 'flutter', [
          'pub',
          'get',
          '--enforce-lockfile',
        ]),
      QualityStep('Format (read-only)', 'dart', [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        'lib',
        'test',
        'tool',
      ]),
      QualityStep('Static analysis', 'flutter', ['analyze', '--no-pub']),
      QualityStep('Code tests (not device QA)', 'flutter', [
        'test',
        '--no-pub',
        '--concurrency',
        '4',
        '--reporter',
        'expanded',
      ]),
    ]);

typedef StepExecutor = Future<int> Function(QualityStep step);

/// Fail fast: preserve the first tool exit code. A spawn error is unavailable,
/// never a successful check or an invitation to install/update the SDK.
Future<int> executeQualityPlan(
  List<QualityStep> steps,
  StepExecutor execute, {
  void Function(String)? report,
}) async {
  for (final step in steps) {
    report?.call(step.name);
    final int code;
    try {
      code = await execute(step);
    } on ProcessException {
      report?.call('Required tool unavailable; no automatic installation.');
      return 127;
    }
    if (code != 0) return code;
  }
  return 0;
}

bool isHarmoniaPubspec(String contents) =>
    RegExp(r'^name:\s*harmonia\s*$', multiLine: true).hasMatch(contents);

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.writeln(
      'dart tool/quality_check.dart [--plan] [--fetch]\n'
      'Default: format + analyze + tests; no implicit pub/network fetch.\n'
      '--plan: show commands without executing.\n'
      '--fetch: explicit locked pub get (may access network/cache).',
    );
    return;
  }
  if (args.any((arg) => arg != '--plan' && arg != '--fetch')) {
    stderr.writeln('Unknown option. Use --help.');
    exitCode = 64;
    return;
  }
  // Anchored to the script, never the invoking cwd (which may be Agora).
  final root = File.fromUri(Platform.script).parent.parent;
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!await pubspec.exists() ||
      !isHarmoniaPubspec(await pubspec.readAsString())) {
    stderr.writeln('Expected Harmonia repository; no checks executed.');
    exitCode = 64;
    return;
  }
  final steps = qualityPlan(fetchDependencies: args.contains('--fetch'));
  if (args.contains('--plan')) {
    for (final step in steps) {
      stdout.writeln('${step.executable} ${step.arguments.join(' ')}');
    }
    return;
  }
  exitCode = await executeQualityPlan(steps, (step) async {
    final process = await Process.start(
      step.executable,
      step.arguments,
      workingDirectory: root.path,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }, report: stdout.writeln);
  stdout.writeln(
    exitCode == 0
        ? 'Code checks passed. Device/voice/teaching/release gates remain separate.'
        : 'Code checks failed; release acceptance is not granted.',
  );
}
