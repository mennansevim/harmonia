import 'dart:async';

import 'package:flutter/material.dart';

import '../../trainer/domain/trainers.dart';
import '../../trainer/koro/koro_hub.dart';
import '../../trainer/learn/skill_screen.dart';
import '../../trainer/prepare/breath_screen.dart';
import '../../trainer/ui/kit.dart';
import '../audio/take_engine.dart';
import '../data/choir_store.dart';
import '../domain/assignment.dart';
import '../domain/submission.dart' hide Feedback;
import '../domain/submission.dart' as choir show Feedback;
import 'choir_scope.dart';
import 'choir_text.dart';
import 'practice_screen.dart';
import 'review_screen.dart';
import 'take_screen.dart';

bool _open(Submission? s) =>
    s == null ||
    s.status == SubmissionStatus.draft ||
    s.status == SubmissionStatus.revisionRequested;

/// One assignment. For a singer one piece stands out, the next thing to do;
/// a conductor follows who sent what. "Not sent" stays a neutral state.
class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key, required this.assignmentId});
  final String assignmentId;
  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final a = store.assignments
        .where((x) => x.id == widget.assignmentId)
        .firstOrNull;
    if (a == null) return const ChoirPage(title: '', children: []);
    final choir = store.choir(a.choirId)!;
    final conductor = store.isConductor(choir);
    final materials = MaterialLocalizations.of(context);
    final due = a.dueAt?.toLocal();
    final next = a.pieces
        .where((p) => _open(store.mySubmission(a.id, p.id)))
        .firstOrNull;
    final focused = _chosen ?? next?.id ?? a.pieces.first.id;
    return ChoirPage(
      title: a.title,
      trailing: a.dueAt == null
          ? null
          : DueShape(now: store.now, due: a.dueAt!),
      children: [
        if (due != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              '${text.dueDate}: ${materials.formatMediumDate(due)} · '
              '${materials.formatTimeOfDay(TimeOfDay.fromDateTime(due))}',
              style: TT.small,
            ),
          ),
        if (a.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(a.note, style: TT.body),
          ),
        for (final piece in a.pieces)
          if (conductor)
            _ConductorPiece(assignment: a, piece: piece)
          else if (piece.id == focused)
            _FocusedPiece(assignment: a, piece: piece)
          else
            _QuietPiece(
              assignment: a,
              piece: piece,
              onTap: () => setState(() => _chosen = piece.id),
            ),
      ],
    );
  }
}

class _ConductorPiece extends StatelessWidget {
  const _ConductorPiece({required this.assignment, required this.piece});
  final Assignment assignment;
  final AssignmentPiece piece;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final a = assignment;
    final rows = assignmentProgress(
      assignment: a,
      pieceId: piece.id,
      members: store.singersOf(a.choirId),
      submissions: store.submissionsOf(a.id),
    );
    final takes = store.submissionsOf(a.id).where((s) => s.pieceId == piece.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(piece.title, style: TT.h3),
            Text(
              '${text.modeName(piece.mode)} · ${text.sectionText(piece)}',
              style: TT.small,
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${text.partName(row.part)}: ${text.partProgress(row)}',
                  style: TT.small,
                ),
              ),
            Text(text.rosterLimit, style: TT.small),
            for (final s in takes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_name(store, s), style: TT.title),
                subtitle: Text(
                  '${text.statusName(s.status)}'
                  '${s.sentLate(a) ? ' · ${text.lateTag}' : ''}',
                  style: TT.small,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(submissionId: s.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _name(ChoirStore store, Submission s) {
    for (final m in store.singersOf(s.choirId)) {
      if (m.userId == s.memberId) return m.displayName;
    }
    return s.part.title;
  }
}

/// A piece that is not the current step: one tonal line, tap to bring it up.
class _QuietPiece extends StatelessWidget {
  const _QuietPiece({
    required this.assignment,
    required this.piece,
    required this.onTap,
  });
  final Assignment assignment;
  final AssignmentPiece piece;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final s = store.mySubmission(assignment.id, piece.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('piece_${piece.id}'),
        color: TC.primarySoft,
        border: TC.primarySoft,
        radius: 28,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(piece.title, style: TT.h3),
                  Text(
                    '${text.modeName(piece.mode)} · ${text.sectionText(piece)}'
                    ' · '
                    '${piece.withAccompaniment ? text.accompanied : text.unaccompanied}',
                    style: const TextStyle(color: TC.body, fontSize: 13.5),
                  ),
                  Text(
                    text.statusName(s?.status),
                    style: const TextStyle(
                      color: TC.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: TC.ink),
          ],
        ),
      ),
    );
  }
}

/// The current piece: violet, with the conductor's words first and one lime
/// action.
class _FocusedPiece extends StatefulWidget {
  const _FocusedPiece({required this.assignment, required this.piece});
  final Assignment assignment;
  final AssignmentPiece piece;
  @override
  State<_FocusedPiece> createState() => _FocusedPieceState();
}

class _FocusedPieceState extends State<_FocusedPiece> {
  var _sending = false;

  Future<void> _send(BuildContext button, Submission draft) async {
    final scope = ChoirScope.read(context);
    setState(() => _sending = true);
    final origin = shareOrigin(button);
    try {
      final sent = draft.submit(scope.store.now.toUtc());
      final path = await scope.bundles.exportSubmission(sent);
      if (await scope.files.share(path, origin: origin)) {
        await scope.store.markSent(draft);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final a = widget.assignment;
    final piece = widget.piece;
    final me = store.meIn(a.choirId);
    final s = store.mySubmission(a.id, piece.id);
    final status = s?.status;
    final hasDraft = status == SubmissionStatus.draft && s!.recordingId != null;
    final feedback = s?.latestFeedback;
    final hasMidi = piece.midiReferenceId != null;
    void record() => _push(TakeScreen(assignment: a, piece: piece));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: ColoredBox(
          key: Key('piece_${piece.id}'),
          color: TC.primary,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text.statusName(status),
                  style: const TextStyle(
                    color: Color(0xFFEFE8FF),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  piece.title,
                  style: TT.h1.copyWith(color: Colors.white, fontSize: 34),
                ),
                const SizedBox(height: 2),
                Text(
                  '${text.modeName(piece.mode)} · ${text.sectionText(piece)} · '
                  '${piece.withAccompaniment ? text.accompanied : text.unaccompanied}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  text.modeHint(piece.mode),
                  style: const TextStyle(
                    color: Color(0xFFEFE8FF),
                    fontSize: 13.5,
                  ),
                ),
                if (s != null && s.sentLate(a))
                  Text(
                    text.lateTag,
                    style: const TextStyle(
                      color: Color(0xFFEFE8FF),
                      fontSize: 13.5,
                    ),
                  ),
                if (feedback != null) ...[
                  const SizedBox(height: 14),
                  FeedbackView(feedback: feedback),
                ],
                const SizedBox(height: 14),
                if (hasDraft) ...[
                  _FilePlayButton(mediaId: s.recordingId!, label: text.listen),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (button) => BigButton(
                      key: Key('piece_send_${piece.id}'),
                      label: text.sendToConductor,
                      icon: Icons.ios_share_rounded,
                      color: TC.sun,
                      busy: _sending,
                      onPressed: () => _send(button, s),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LightLink(text.recordAgain, record),
                      _LightLink(text.deleteTake, () => store.discardTake(s)),
                    ],
                  ),
                ] else if (_open(s))
                  Row(
                    children: [
                      Expanded(
                        child: BigButton(
                          key: Key('piece_record_${piece.id}'),
                          label: status == SubmissionStatus.revisionRequested
                              ? text.recordAgain
                              : text.record,
                          icon: Icons.mic_rounded,
                          color: TC.sun,
                          onPressed: record,
                        ),
                      ),
                      if (hasMidi) ...[
                        const SizedBox(width: 8),
                        _PractiseButton(
                          key: Key('piece_practise_${piece.id}'),
                          label: text.practise,
                          onTap: () => _push(
                            PracticeScreen(piece: piece, part: me?.part),
                          ),
                        ),
                      ],
                    ],
                  )
                else if (hasMidi)
                  _PractiseButton(
                    key: Key('piece_practise_${piece.id}'),
                    label: text.practise,
                    onTap: () =>
                        _push(PracticeScreen(piece: piece, part: me?.part)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LightLink extends StatelessWidget {
  const _LightLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: Colors.white),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

/// The round "practise" control beside the main action.
class _PractiseButton extends StatelessWidget {
  const _PractiseButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      child: Material(
        color: TC.primaryDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.queue_music_rounded, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

/// What the conductor said, as a speech bubble, with the way on to Personal
/// practice for labels that have one (the conductor's judgement, nothing the
/// app detected).
class FeedbackView extends StatelessWidget {
  const FeedbackView({super.key, required this.feedback});
  final choir.Feedback feedback;

  void _practise(BuildContext context, String area) {
    if (area == 'pitch') {
      openSkill(context, TrainerKind.pitch);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => area == 'breath'
            ? const BreathScreen(totalSeconds: 120, stepLabel: '')
            : const KoroHub(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final tags = {...feedback.tags, ...feedback.marks.map((m) => m.tag)};
    final areas = {
      for (final t in tags)
        if (t.personalArea != null) t.personalArea!: t,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.feedbackTitle,
            style: const TextStyle(
              color: TC.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (feedback.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(feedback.text, style: TT.title.copyWith(height: 1.35)),
          ],
          for (final m in feedback.marks)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '${clockText(Duration(milliseconds: m.atMs))} · '
                '${text.tagName(m.tag)}'
                '${m.text.isEmpty ? '' : ' · ${m.text}'}',
                style: TT.small,
              ),
            ),
          if (feedback.voiceNoteId != null) ...[
            const SizedBox(height: 10),
            _FilePlayButton(
              key: const Key('feedback_voice'),
              mediaId: feedback.voiceNoteId!,
              label: text.playVoiceNote,
              onLight: true,
            ),
          ],
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text.practiseThis, style: TT.small),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final area in areas.entries)
                  ActionChip(
                    label: Text(text.tagName(area.value)),
                    onPressed: () => _practise(context, area.key),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilePlayButton extends StatefulWidget {
  const _FilePlayButton({
    super.key,
    required this.mediaId,
    required this.label,
    this.onLight = false,
  });
  final String mediaId;
  final String label;
  final bool onLight;
  @override
  State<_FilePlayButton> createState() => _FilePlayButtonState();
}

class _FilePlayButtonState extends State<_FilePlayButton> {
  ChoirPlayer? _player;
  StreamSubscription<bool>? _sub;
  var _playing = false;

  Future<void> _toggle() async {
    final scope = ChoirScope.read(context);
    if (_player == null) {
      final player = _player = scope.newPlayer();
      _sub = player.playingChanges.listen((p) {
        if (mounted) setState(() => _playing = p);
      });
      await player.open(await scope.store.mediaPath(widget.mediaId));
    }
    if (_playing) {
      await _player!.pause();
    } else {
      await _player!.play();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: widget.onLight
        ? null
        : OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
          ),
    onPressed: _toggle,
    icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    label: Text(widget.label),
  );
}
