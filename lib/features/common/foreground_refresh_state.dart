import 'package:flutter/material.dart';

/// Refreshes a read-only local projection once after a real app background.
///
/// `inactive` is deliberately ignored: permission sheets and short system
/// interruptions must not churn repository reads. This helper is for screens
/// that only rebuild local views; it must not be used to resume media or open
/// the microphone.
abstract class ForegroundRefreshState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      refreshAfterForeground();
    }
  }

  /// Must only replace the screen's local read future/state. Never starts
  /// playback, recording, navigation or a write operation.
  @protected
  void refreshAfterForeground();
}
