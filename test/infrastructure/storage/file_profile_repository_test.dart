import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/profile_repository.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/infrastructure/storage/file_profile_repository.dart';
import 'package:harmonia/infrastructure/storage/json_file_store.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('harmonia-'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final profile = LearnerProfile(
    goal: PracticeGoal.choir,
    createdAt: DateTime.utc(2026, 10, 11, 9),
  );

  test('profile JSON is strict and round-trips', () {
    expect(
      LearnerProfile.fromJson(profile.toJson()).toJson(),
      profile.toJson(),
    );
    for (final bad in [
      {...profile.toJson(), 'schemaVersion': 2},
      {...profile.toJson(), 'goal': 'opera'},
      {...profile.toJson(), 'createdAt': 'yesterday'},
    ]) {
      expect(() => LearnerProfile.fromJson(bad), throwsFormatException);
    }
  });

  test('store writes atomically, reads back and deletes', () async {
    final store = JsonFileStore(() async => dir, 'doc');
    expect(await store.read(), isNull);
    await store.write({'a': 1});
    expect(await store.read(), {'a': 1});
    expect(File('${dir.path}/doc.json.tmp').existsSync(), isFalse);
    await store.delete();
    expect(await store.read(), isNull);
  });

  test('store rejects corrupt, non-object and oversized documents', () async {
    final store = JsonFileStore(() async => dir, 'doc', maxBytes: 64);
    File('${dir.path}/doc.json').writeAsStringSync('{not json');
    expect(store.read(), throwsFormatException);
    File('${dir.path}/doc.json').writeAsStringSync('[1,2]');
    expect(store.read(), throwsFormatException);
    File('${dir.path}/doc.json').writeAsStringSync('{"a":"${'x' * 80}"}');
    expect(store.read(), throwsFormatException);
    expect(store.write({'a': 'x' * 80}), throwsFormatException);
    expect(
      () => JsonFileStore(() async => dir, '../escape'),
      throwsArgumentError,
    );
  });

  test('repository persists profile across instances', () async {
    await FileProfileRepository(directory: () async => dir).save(profile);
    final loaded = await FileProfileRepository(
      directory: () async => dir,
    ).load();
    expect(loaded!.goal, PracticeGoal.choir);
  });

  test('corrupt profile is reported, not silently deleted', () async {
    final file = File('${dir.path}/learner_profile.json')
      ..writeAsStringSync('{"schemaVersion":99}');
    final repo = FileProfileRepository(directory: () async => dir);
    await expectLater(
      repo.load(),
      throwsA(
        isA<ProfileStorageException>().having(
          (e) => e.failure,
          'failure',
          ProfileStorageFailure.corrupt,
        ),
      ),
    );
    expect(file.existsSync(), isTrue);
  });

  test('unavailable storage maps to unavailable failure', () async {
    final repo = FileProfileRepository(
      directory: () async => throw const FileSystemException('denied'),
    );
    await expectLater(
      repo.load(),
      throwsA(
        isA<ProfileStorageException>().having(
          (e) => e.failure,
          'failure',
          ProfileStorageFailure.unavailable,
        ),
      ),
    );
  });
}
