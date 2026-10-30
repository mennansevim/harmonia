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

/// One assignment. Singers work through its pieces; a conductor follows who
/// sent what. "Not sent" stays a neutral state.
class AssignmentScreen extends StatelessWidget {
  const AssignmentScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final a = store.assignments.where((x) => x.id == assignmentId).firstOrNull;
    if (a == null) return const ChoirPage(title: '', children: []);
    final choir = store.choir(a.choirId)!;
    final conductor = store.isConductor(choir);
    final materials = MaterialLocalizations.of(context);
    final due = a.dueAt?.toLocal();
    return ChoirPage(
      title: a.title,
      children: [
        if (due != null)
          ChoirRow(
            icon: Icons.event_rounded,
            title: text.dueLabel(store.now, a.dueAt!),
            subtitle:
                '${materials.formatMediumDate(due)} · '
                '${materials.formatTimeOfDay(TimeOfDay.fromDateTime(due))}',
          ),
        if (a.note.isNotEmpty) ...[
          Text(a.note, style: TT.body),
          const SizedBox(height: 10),
        ],
        for (final piece in a.pieces)
          conductor
              ? _ConductorPiece(assignment: a, piece: piece)
              : _SingerPiece(assignment: a, piece: piece),
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
            Text(piece.title, style: TT.title),
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
                title: Text(_name(store, s)),
                subtitle: Text(
                  '${text.statusName(s.status)}'
                  '${s.sentLate(a) ? ' · ${text.lateTag}' : ''}',
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

class _SingerPiece extends StatefulWidget {
  const _SingerPiece({required this.assignment, required this.piece});
  final Assignment assignment;
  final AssignmentPiece piece;
  @override
  State<_SingerPiece> createState() => _SingerPieceState();
}

class _SingerPieceState extends State<_SingerPiece> {
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
    final canRecord =
        status == null ||
        status == SubmissionStatus.draft ||
        status == SubmissionStatus.revisionRequested;
    final feedback = s?.latestFeedback;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: Key('piece_${piece.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(piece.title, style: TT.h3),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Tag(text.statusName(status), color: TC.primary),
            ),
            const SizedBox(height: 4),
            Text(
              '${text.modeName(piece.mode)} · ${text.sectionText(piece)} · '
              '${piece.withAccompaniment ? text.accompanied : text.unaccompanied}',
              style: TT.small,
            ),
            const SizedBox(height: 2),
            Text(text.modeHint(piece.mode), style: TT.small),
            if (s != null && s.sentLate(a)) ...[
              const SizedBox(height: 2),
              Text(text.lateTag, style: TT.small),
            ],
            const SizedBox(height: 12),
            if (piece.midiReferenceId != null) ...[
              OutlinedButton.icon(
                key: Key('piece_practise_${piece.id}'),
                onPressed: () =>
                    _push(PracticeScreen(piece: piece, part: me?.part)),
                icon: const Icon(Icons.queue_music_rounded),
                label: Text(text.practise),
              ),
              const SizedBox(height: 8),
            ],
            if (canRecord)
              BigButton(
                key: Key('piece_record_${piece.id}'),
                label: hasDraft ? text.recordAgain : text.record,
                icon: Icons.mic_rounded,
                color: hasDraft ? TC.primary : TC.coral,
                onPressed: () => _push(TakeScreen(assignment: a, piece: piece)),
              ),
            if (hasDraft) ...[
              const SizedBox(height: 8),
              _FilePlayButton(mediaId: s.recordingId!, label: text.listen),
              const SizedBox(height: 8),
              Builder(
                builder: (button) => BigButton(
                  key: Key('piece_send_${piece.id}'),
                  label: text.sendToConductor,
                  icon: Icons.ios_share_rounded,
                  busy: _sending,
                  onPressed: () => _send(button, s),
                ),
              ),
              TextLink(text.deleteTake, onTap: () => store.discardTake(s)),
            ],
            if (feedback != null) ...[
              const Divider(height: 26),
              FeedbackView(feedback: feedback),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the conductor said, in the order a singer needs it, with the way on
/// to Personal practice for labels that have one (the conductor's judgement,
/// nothing the app detected).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text.feedbackTitle, style: TT.title),
        if (feedback.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(feedback.text, style: TT.body),
        ],
        if (feedback.voiceNoteId != null) ...[
          const SizedBox(height: 8),
          _FilePlayButton(
            key: const Key('feedback_voice'),
            mediaId: feedback.voiceNoteId!,
            label: text.playVoiceNote,
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tags) Tag(text.tagName(t), color: TC.koro),
            ],
          ),
        ],
        for (final m in feedback.marks)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${clockText(Duration(milliseconds: m.atMs))} · '
              '${text.tagName(m.tag)}'
              '${m.text.isEmpty ? '' : ' · ${m.text}'}',
              style: TT.small,
            ),
          ),
        for (final area in areas.entries)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => _practise(context, area.key),
              child: Text('${text.practiseThis}: ${text.tagName(area.value)}'),
            ),
          ),
      ],
    );
  }
}

class _FilePlayButton extends StatefulWidget {
  const _FilePlayButton({
    super.key,
    required this.mediaId,
    required this.label,
  });
  final String mediaId;
  final String label;
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
    onPressed: _toggle,
    icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    label: Text(widget.label),
  );
}
