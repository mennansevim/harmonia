import 'package:flutter/foundation.dart';

import '../domain/models/learner_profile.dart';
import 'profile_repository.dart';

enum AppShellPhase { loading, onboarding, ready, error }

/// Guest-first start: no account is required for first value. Storage errors
/// are shown with retry; a corrupt profile is never silently overwritten
/// unless the user explicitly starts over.
class AppShellController extends ChangeNotifier {
  AppShellController(this._repository, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final ProfileRepository _repository;
  final DateTime Function() _now;
  AppShellPhase phase = AppShellPhase.loading;
  ProfileStorageFailure? failure;
  LearnerProfile? profile;
  bool saving = false;
  int _generation = 0;
  bool _disposed = false;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final generation = ++_generation;
    phase = AppShellPhase.loading;
    failure = null;
    _emit();
    try {
      final loaded = await _repository.load();
      if (generation != _generation || _disposed) return;
      profile = loaded;
      phase = loaded == null ? AppShellPhase.onboarding : AppShellPhase.ready;
    } on ProfileStorageException catch (e) {
      if (generation != _generation || _disposed) return;
      failure = e.failure;
      phase = AppShellPhase.error;
    }
    _emit();
  }

  /// Creates or updates the local guest profile.
  Future<bool> chooseGoal(PracticeGoal goal) async {
    if (saving) return false;
    final generation = ++_generation;
    final next =
        profile?.copyWith(goal: goal) ??
        LearnerProfile(goal: goal, createdAt: _now().toUtc());
    saving = true;
    _emit();
    try {
      await _repository.save(next);
      if (generation != _generation || _disposed) return false;
      profile = next;
      failure = null;
      phase = AppShellPhase.ready;
      return true;
    } on ProfileStorageException catch (e) {
      if (generation != _generation || _disposed) return false;
      failure = e.failure;
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  /// Deletes only Resonia's local profile after explicit user confirmation.
  Future<bool> deleteLocalProfile() async {
    final generation = ++_generation;
    try {
      await _repository.delete();
      if (generation != _generation || _disposed) return false;
      profile = null;
      failure = null;
      phase = AppShellPhase.onboarding;
      _emit();
      return true;
    } on ProfileStorageException catch (e) {
      if (generation != _generation || _disposed) return false;
      failure = e.failure;
      _emit();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
