import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/audio/live_visual_feedback.dart';
import '../../domain/audio/visual_feedback_frame.dart';
import '../../domain/models/measurement_provenance.dart';
import 'pitch_feedback_field.dart';

/// Bounded UI-only consumer of recorder level events. Invalid events are
/// ignored and the last valid frame remains visible. No analyzer runs here.
class LivePitchFeedbackField extends StatefulWidget {
  const LivePitchFeedbackField({
    super.key,
    required this.sessionId,
    required this.phase,
    required this.levelsDb,
    required this.provenance,
    this.projector = const LiveVisualFeedbackProjector(),
  });

  final String sessionId;
  final VisualFeedbackPhase phase;
  final Stream<double> levelsDb;
  final MeasurementProvenance provenance;
  final LiveVisualFeedbackProjector projector;

  @override
  State<LivePitchFeedbackField> createState() => _LivePitchFeedbackFieldState();
}

class _LivePitchFeedbackFieldState extends State<LivePitchFeedbackField> {
  StreamSubscription<double>? _subscription;
  late VisualFeedbackFrame _frame = _waitingFrame();

  VisualFeedbackFrame _waitingFrame() => VisualFeedbackFrame(
    sessionId: widget.sessionId,
    phase: widget.phase,
    level01: 0,
    completedNotes: 0,
    provenance: widget.provenance,
  );

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LivePitchFeedbackField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levelsDb != widget.levelsDb ||
        oldWidget.sessionId != widget.sessionId ||
        oldWidget.phase != widget.phase ||
        oldWidget.provenance != widget.provenance) {
      _subscription?.cancel();
      _frame = _waitingFrame();
      _listen();
    }
  }

  void _listen() {
    _subscription = widget.levelsDb.listen((levelDb) {
      final next = widget.projector.project(
        sessionId: widget.sessionId,
        phase: widget.phase,
        levelDb: levelDb,
        provenance: widget.provenance,
      );
      if (next != null && mounted) setState(() => _frame = next);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PitchFeedbackField(
    key: const Key('live_visual_feedback_field'),
    frame: _frame,
  );
}
