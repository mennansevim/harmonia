import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/app_shell_controller.dart';
import 'package:harmonia/application/profile_repository.dart';
import 'package:harmonia/domain/models/learner_profile.dart';

class FlakyProfileRepository implements ProfileRepository {
  ProfileStorageFailure? loadFailure;
  ProfileStorageFailure? saveFailure;
  ProfileStorageFailure? deleteFailure;
  Completer<LearnerProfile?>? loadGate;
  LearnerProfile? stored;
  @override
  Future<LearnerProfile?> load() async {
    if (loadFailure != null) throw ProfileStorageException(loadFailure!);
    return loadGate == null ? stored : loadGate!.future;
  }

  @override
  Future<void> save(LearnerProfile profile) async {
    if (saveFailure != null) throw ProfileStorageException(saveFailure!);
    stored = profile;
  }

  @override
  Future<void> delete() async {
    if (deleteFailure != null) throw ProfileStorageException(deleteFailure!);
    stored = null;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 11, 10);
  late FlakyProfileRepository repo;
  late AppShellController shell;
  setUp(() {
    repo = FlakyProfileRepository();
    shell = AppShellController(repo, clock: () => now);
  });
  tearDown(() => shell.dispose());

  test('first launch goes to guest onboarding, no account needed', () async {
    await shell.load();
    expect(shell.phase, AppShellPhase.onboarding);
    expect(await shell.chooseGoal(PracticeGoal.conservatory), isTrue);
    expect(shell.phase, AppShellPhase.ready);
    expect(repo.stored!.createdAt, now);
  });

  test('changing goal keeps original creation time', () async {
    repo.stored = LearnerProfile(
      goal: PracticeGoal.foundations,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await shell.load();
    expect(shell.phase, AppShellPhase.ready);
    await shell.chooseGoal(PracticeGoal.choir);
    expect(repo.stored!.goal, PracticeGoal.choir);
    expect(repo.stored!.createdAt, DateTime.utc(2026, 1, 1));
  });

  test('storage error shows retry; retry recovers', () async {
    repo.loadFailure = ProfileStorageFailure.unavailable;
    await shell.load();
    expect(shell.phase, AppShellPhase.error);
    expect(shell.failure, ProfileStorageFailure.unavailable);
    repo.loadFailure = null;
    await shell.load();
    expect(shell.phase, AppShellPhase.onboarding);
    expect(shell.failure, isNull);
  });

  test('failed save keeps onboarding and reports, no fake ready', () async {
    await shell.load();
    repo.saveFailure = ProfileStorageFailure.unavailable;
    expect(await shell.chooseGoal(PracticeGoal.choir), isFalse);
    expect(shell.phase, AppShellPhase.onboarding);
    expect(shell.failure, ProfileStorageFailure.unavailable);
    expect(shell.saving, isFalse);
  });

  test('delete returns to onboarding; delete failure keeps profile', () async {
    await shell.load();
    await shell.chooseGoal(PracticeGoal.choir);
    repo.deleteFailure = ProfileStorageFailure.unavailable;
    expect(await shell.deleteLocalProfile(), isFalse);
    expect(shell.profile, isNotNull);
    repo.deleteFailure = null;
    expect(await shell.deleteLocalProfile(), isTrue);
    expect(shell.phase, AppShellPhase.onboarding);
    expect(repo.stored, isNull);
  });

  test('stale load cannot override a newer user choice', () async {
    repo.loadGate = Completer();
    final pending = shell.load();
    await shell.chooseGoal(PracticeGoal.foundations);
    repo.loadGate!.complete(null);
    await pending;
    expect(shell.phase, AppShellPhase.ready);
    expect(shell.profile!.goal, PracticeGoal.foundations);
  });
}
