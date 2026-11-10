import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/choir_store.dart';
import 'choir_backend.dart';

/// Server address from the build: `--dart-define=SUPABASE_URL=…` and
/// `--dart-define=SUPABASE_KEY=…` (the publishable key). Without both, the
/// online choir stays off and the module works on the device as before
/// (ADR-036).
class OnlineConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_KEY');
  static bool get enabled => url.isNotEmpty && key.isNotEmpty;
}

/// The signed-in person's choirs and requests, refreshed on sign-in/out and
/// after each change. Per-choir rosters are loaded by their screen.
class OnlineChoirController extends ChangeNotifier {
  OnlineChoirController(this.backend);
  final ChoirBackend backend;

  StreamSubscription<String?>? _auth;
  List<OnlineChoir> choirs = const [];
  List<JoinRequest> myRequests = const [];
  bool loading = false;
  BackendProblem? problem;

  /// A refresh has finished at least once, so [choirs] is the server's
  /// answer and not just the empty start.
  bool settled = false;

  /// Opens a web page (the Drive consent). Replaced in tests.
  Future<bool> Function(Uri url) openUrl = (url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  bool get signedIn => backend.userId != null;

  /// Pending requests (decided ones show only as a joined choir).
  List<JoinRequest> get waiting => [
    for (final r in myRequests)
      if (r.status == JoinStatus.pending) r,
  ];

  void start() {
    _auth ??= backend.userChanges.listen((_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    if (!signedIn) {
      choirs = const [];
      myRequests = const [];
      problem = null;
      settled = true;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        backend.myChoirs(),
        backend.myJoinRequests(),
      ]);
      choirs = results[0] as List<OnlineChoir>;
      myRequests = results[1] as List<JoinRequest>;
      problem = null;
      settled = true;
    } on ChoirBackendException catch (e) {
      problem = e.problem;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  OnlineChoir? choir(String id) {
    for (final c in choirs) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Runs a change, then reloads the lists. Errors reach the caller.
  Future<T> act<T>(Future<T> Function(ChoirBackend b) change) async {
    final result = await change(backend);
    await refresh();
    return result;
  }

  Future<void> signOut() => act((b) => b.signOut());

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }
}

/// Keeps the store's mirrored online choirs in step with membership: a choir
/// I left, was removed from or that was deleted, and every online choir on
/// sign-out, leaves this device.
class OnlineMirrorSync {
  OnlineMirrorSync(this.store, this.online) {
    online.addListener(_check);
  }
  final ChoirStore store;
  final OnlineChoirController online;

  Future<void> _check() async {
    if (!online.settled || online.loading) return;
    if (online.signedIn && online.problem != null) return;
    final keep = online.signedIn
        ? {for (final c in online.choirs) c.id}
        : const <String>{};
    for (final id in [...store.onlineChoirIds]) {
      if (!keep.contains(id)) await store.forgetOnline(id);
    }
  }

  void dispose() => online.removeListener(_check);
}

/// Puts the controller above the navigator. Absent when the build has no
/// server configured.
class OnlineChoirScope extends InheritedNotifier<OnlineChoirController> {
  const OnlineChoirScope({
    super.key,
    required OnlineChoirController controller,
    required super.child,
  }) : super(notifier: controller);

  OnlineChoirController get controller => notifier!;

  static OnlineChoirController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OnlineChoirScope>()
      ?.controller;

  static OnlineChoirController of(BuildContext context) => maybeOf(context)!;

  static OnlineChoirController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OnlineChoirScope>()!.controller;
}
