import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/quality_check.dart';

void main() {
  test('standalone CLI plan anchored to repo even from another cwd', () async {
    final path = File('tool/quality_check.dart').absolute.path;
    final result = await Process.run('dart', [
      path,
      '--plan',
      '--fetch',
    ], workingDirectory: Directory.systemTemp.path);
    expect(result.exitCode, 0);
    expect(result.stdout, contains('flutter pub get --enforce-lockfile'));
    expect(result.stdout, contains('flutter test --no-pub'));
    expect(result.stdout, isNot(contains('Code checks passed')));
  });
  test('unknown CLI option fails before launching a tool', () async {
    final result = await Process.run('dart', [
      File('tool/quality_check.dart').absolute.path,
      '--deploy',
    ]);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('Unknown option'));
    expect(result.stdout, isEmpty);
  });
  test('default plan no fetch, build, release or rewrite', () {
    final plan = qualityPlan();
    expect(plan.map((s) => s.executable), ['dart', 'flutter', 'flutter']);
    expect(
      plan.first.arguments,
      containsAll(['--output=none', '--set-exit-if-changed', 'tool']),
    );
    expect(plan[1].arguments, ['analyze', '--no-pub']);
    expect(plan.last.arguments, ['test', '--no-pub', '--reporter', 'expanded']);
  });
  test('dependency fetch explicit and lock enforced', () {
    final plan = qualityPlan(fetchDependencies: true);
    expect(plan.first.arguments, ['pub', 'get', '--enforce-lockfile']);
    expect(plan.length, 4);
  });
  test('plan and argv immutable snapshots', () {
    final args = ['test'];
    final step = QualityStep('test', 'flutter', args);
    args.clear();
    expect(step.arguments, ['test']);
    expect(() => step.arguments.add('build'), throwsUnsupportedError);
    expect(() => qualityPlan().clear(), throwsUnsupportedError);
  });
  test('success executes every step in order', () async {
    final calls = <String>[];
    final code = await executeQualityPlan(qualityPlan(), (step) async {
      calls.add(step.name);
      return 0;
    });
    expect(code, 0);
    expect(calls, qualityPlan().map((s) => s.name));
  });
  test('failure preserves exit code and never executes later checks', () async {
    for (var failedAt = 0; failedAt < 3; failedAt++) {
      var calls = 0;
      final code = await executeQualityPlan(qualityPlan(), (_) async {
        return calls++ == failedAt ? 17 : 0;
      });
      expect(code, 17);
      expect(calls, failedAt + 1);
    }
  });
  test('missing executable fails closed with no installation', () async {
    var calls = 0;
    final messages = <String>[];
    final code = await executeQualityPlan(qualityPlan(), (_) async {
      calls++;
      throw const ProcessException('flutter', [], 'missing');
    }, report: messages.add);
    expect(code, 127);
    expect(calls, 1);
    expect(messages.last, contains('no automatic installation'));
  });
  test('unexpected executor failure propagates rather than passing', () async {
    await expectLater(
      executeQualityPlan(qualityPlan(), (_) async {
        throw StateError('unexpected');
      }),
      throwsStateError,
    );
  });
  test('repository name check rejects Agora and partial names', () {
    expect(isHarmoniaPubspec('name: harmonia\nversion: 1'), isTrue);
    for (final text in [
      'name: agora',
      'name: harmonia_fake',
      '# name: harmonia',
      'xname: harmonia',
    ]) {
      expect(isHarmoniaPubspec(text), isFalse);
    }
  });
}
