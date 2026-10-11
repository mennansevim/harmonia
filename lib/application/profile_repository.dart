import '../domain/models/learner_profile.dart';

enum ProfileStorageFailure { corrupt, unavailable }

class ProfileStorageException implements Exception {
  const ProfileStorageException(this.failure);
  final ProfileStorageFailure failure;
  @override
  String toString() => 'ProfileStorageException(${failure.name})';
}

/// Local-only guest profile store. Implementations throw
/// [ProfileStorageException]; corrupt data is reported, never auto-deleted.
abstract interface class ProfileRepository {
  Future<LearnerProfile?> load();
  Future<void> save(LearnerProfile profile);
  Future<void> delete();
}

class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository([this._profile]);
  LearnerProfile? _profile;
  @override
  Future<LearnerProfile?> load() async => _profile;
  @override
  Future<void> save(LearnerProfile profile) async => _profile = profile;
  @override
  Future<void> delete() async => _profile = null;
}
