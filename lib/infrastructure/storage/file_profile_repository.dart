import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/profile_repository.dart';
import '../../domain/models/learner_profile.dart';
import 'json_file_store.dart';

class FileProfileRepository implements ProfileRepository {
  FileProfileRepository({Future<Directory> Function()? directory})
    : _store = JsonFileStore(
        directory ?? getApplicationSupportDirectory,
        'learner_profile',
        maxBytes: 16 * 1024,
      );

  final JsonFileStore _store;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const ProfileStorageException(ProfileStorageFailure.corrupt);
    } on ProfileStorageException {
      rethrow;
    } catch (_) {
      throw const ProfileStorageException(ProfileStorageFailure.unavailable);
    }
  }

  @override
  Future<LearnerProfile?> load() => _guard(() async {
    final json = await _store.read();
    return json == null ? null : LearnerProfile.fromJson(json);
  });

  @override
  Future<void> save(LearnerProfile profile) =>
      _guard(() => _store.write(profile.toJson()));

  @override
  Future<void> delete() => _guard(_store.delete);
}
