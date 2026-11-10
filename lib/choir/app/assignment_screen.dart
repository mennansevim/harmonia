import 'dart:async';

import 'package:flutter/material.dart';

import '../online/choir_backend.dart';
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

bool pieceOpen(Submission? s) =>
    s == null ||
    s.status == SubmissionStatus.draft ||
    s.status == SubmissionStatus.revisionRequested;

/// One assignment: for a singer the piece to work on now, what the conductor
/// said and the next step; for a conductor who sent what.
class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key, required this.assignmentId});
  final String assignmentId;
  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  String? _chosen;
  var _sending = false;
  var _showInfo = false;

  Future<void> _send(BuildContext button, Submission draft) async {
    final scope = ChoirScope.read(context);
    setState(() => _sending = true);
    final origin = shareOrigin(button);
    try {
      if (scope.store.isOnline(draft.choirId)) {
        // Online choir: the take goes to the choir's Drive, no share sheet.
        await scope.store.markSent(draft);
        if (mounted) toast(context, CT.of(context).takeUploaded);
        return;
      }
      final sent = draft.submit(scope.store.now.toUtc());
      final path = await scope.bundles.exportSubmission(sent);
      if (await scope.files.share(path, origin: origin)) {
        await scope.store.markSent(draft);
      }
    } on ChoirBackendException catch (e) {
      if (mounted) toast(context, CT.of(context).backendProblem(e.problem));
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
    final a = store.assignments
        .where((x) => x.id == widget.assignmentId)
        .firstOrNull;
    if (a == null) return const ChoirPage(title: '', children: []);
    final choirRow = store.choir(a.choirId)!;
    if (store.isConductor(choirRow)) return _conductor(store, text, a);

    final next = a.pieces
        .where((p) => pieceOpen(store.mySubmission(a.id, p.id)))
        .firstOrNull;
    final focusedId = _chosen ?? next?.id ?? a.pieces.first.id;
    final piece = a.piece(focusedId) ?? a.pieces.first;
    final s = store.mySubmission(a.id, piece.id);
    final me = store.meIn(a.choirId);
    final status = s?.status;
    final hasDraft = status == SubmissionStatus.draft && s!.recordingId != null;
    final feedback = s?.latestFeedback;
    final hasMidi = piece.midiReferenceId != null;
    final others = a.pieces.where((p) => p.id != piece.id);

    void record() => _push(TakeScreen(assignment: a, piece: piece));
    void practise() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (route) => PracticeScreen(
          piece: piece,
          part: me?.part,
          crumb: text.crumbPractice(choirRow.name),
          onReady: pieceOpen(s)
              ? () => Navigator.of(route).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => TakeScreen(assignment: a, piece: piece),
                  ),
                )
              : null,
        ),
      ),
    );

    return ChoirPage(
      title: a.title,
      crumb: text.crumbWork(choirRow.name),
      bottom: _singerActions(
        text,
        a: a,
        piece: piece,
        s: s,
        hasDraft: hasDraft,
        hasMidi: hasMidi,
        practise: practise,
        record: record,
      ),
      children: [
        _WorkHeader(assignment: a),
        const SizedBox(height: 20),
        HeroCard(
          key: Key('piece_${piece.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.caps(text.workingOnPiece),
                      style: const TextStyle(
                        color: TC.heroMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TiltTag(
                        feedback != null
                            ? text.feedbackTagLabel
                            : text.statusName(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                piece.title,
                style: TT.display.copyWith(color: Colors.white, fontSize: 37),
              ),
              const SizedBox(height: 12),
              Text(
                '${piece.voicing} · ${text.modeName(piece.mode)} · '
                '${text.sectionText(piece)} · '
                '${piece.withAccompaniment ? text.accompanied : text.unaccompanied}',
                style: const TextStyle(
                  color: TC.heroMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text.modeHint(piece.mode),
                style: const TextStyle(
                  color: TC.heroMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (s != null && s.sentLate(a))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    text.lateTag,
                    style: const TextStyle(color: TC.heroMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (feedback != null) ...[
          const SizedBox(height: 20),
          FeedbackView(feedback: feedback),
        ],
        if (pieceOpen(s)) ...[
          const SizedBox(height: 20),
          Text(text.workHint, style: TT.small.copyWith(height: 1.5)),
        ],
        if (others.isNotEmpty) ...[
          Caption(text.caps(text.otherPieces)),
          for (final p in others)
            ChoirRow(
              key: Key('piece_${p.id}'),
              icon: Ic.music2,
              title: p.title,
              subtitle:
                  '${text.modeName(p.mode)} · ${text.sectionText(p)} · '
                  '${p.withAccompaniment ? text.accompanied : text.unaccompanied}'
                  ' · ${text.statusName(store.mySubmission(a.id, p.id)?.status)}',
              onTap: () => setState(() => _chosen = p.id),
            ),
        ],
        if (store.partTakes(a.id, piece.id) case final peers
            when peers.isNotEmpty) ...[
          Caption(text.caps(text.partTakesTitle)),
          Text(text.partTakesHint, style: TT.small),
          const SizedBox(height: 8),
          for (final t in peers)
            ChoirRow(
              key: Key('peer_take_${t.id}'),
              icon: Ic.headphones,
              title:
                  store
                      .singersOf(a.choirId)
                      .where((m) => m.userId == t.memberId)
                      .firstOrNull
                      ?.displayName ??
                  text.partName(t.part),
              subtitle: text.statusName(t.status),
              onTap: store.leadsReview(t)
                  ? () => _push(ReviewScreen(submissionId: t.id))
                  : null,
              trailing: store.leadsReview(t)
                  ? null
                  : FilePlayButton(mediaId: t.recordingId!, label: text.listen),
            ),
        ],
      ],
    );
  }

  Widget _singerActions(
    CT text, {
    required Assignment a,
    required AssignmentPiece piece,
    required Submission? s,
    required bool hasDraft,
    required bool hasMidi,
    required VoidCallback practise,
    required VoidCallback record,
  }) {
    final store = ChoirScope.read(context).store;
    if (hasDraft) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilePlayButton(mediaId: s!.recordingId!, label: text.listen),
          const SizedBox(height: 8),
          Builder(
            builder: (button) => BigButton(
              key: Key('piece_send_${piece.id}'),
              label: text.sendToConductor,
              icon: Ic.send,
              busy: _sending,
              onPressed: () => _send(button, s),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextLink(text.recordAgain, onTap: record),
              TextLink(text.deleteTake, onTap: () => store.discardTake(s)),
            ],
          ),
        ],
      );
    }
    if (hasMidi) {
      return BigButton(
        key: Key('piece_practise_${piece.id}'),
        label: text.practiseWith(piece.title),
        icon: Ic.play,
        onPressed: practise,
      );
    }
    if (pieceOpen(s)) {
      return BigButton(
        key: Key('piece_record_${piece.id}'),
        label: text.startTake,
        icon: Ic.mic,
        color: TC.sun,
        onPressed: record,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _conductor(ChoirStore store, CT text, Assignment a) {
    final choirRow = store.choir(a.choirId)!;
    final queue = store
        .reviewQueue(a.choirId)
        .where((s) => s.assignmentId == a.id);
    return ChoirPage(
      title: a.title,
      crumb: text.crumbConductorOf(choirRow.name),
      bottom: BigButton(
        key: const Key('assignment_queue'),
        label: text.openQueue,
        icon: Ic.headphones,
        onPressed: queue.isEmpty
            ? null
            : () => _push(ReviewScreen(submissionId: queue.first.id)),
      ),
      children: [
        _WorkHeader(assignment: a),
        const SizedBox(height: 20),
        Row(
          children: [
            _ViewTab(
              key: const Key('tab_submissions'),
              label: text.submissions,
              selected: !_showInfo,
              onTap: () => setState(() => _showInfo = false),
            ),
            const SizedBox(width: 8),
            _ViewTab(
              key: const Key('tab_info'),
              label: text.workInfo,
              selected: _showInfo,
              onTap: () => setState(() => _showInfo = true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final piece in a.pieces)
          _showInfo
              ? _PieceInfo(piece: piece)
              : _ConductorPiece(assignment: a, piece: piece),
      ],
    );
  }
}

/// Which side of a conductor's assignment is showing.
class _ViewTab extends StatelessWidget {
  const _ViewTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    excludeSemantics: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TiltTag(label, color: selected ? TC.sun : Colors.white),
    ),
  );
}

/// Due line and note beside the lime tile.
class _WorkHeader extends StatelessWidget {
  const _WorkHeader({required this.assignment});
  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final materials = MaterialLocalizations.of(context);
    final due = assignment.dueAt?.toLocal();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (due != null)
                Text(
                  '${text.dueDate}: ${materials.formatMediumDate(due)} · '
                  '${materials.formatTimeOfDay(TimeOfDay.fromDateTime(due))}',
                  style: TT.small,
                ),
              if (assignment.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(assignment.note, style: TT.body.copyWith(color: TC.ink)),
              ],
            ],
          ),
        ),
        if (assignment.dueAt != null) ...[
          const SizedBox(width: 16),
          DueShape(now: store.now, due: assignment.dueAt!),
        ],
      ],
    );
  }
}

class _PieceInfo extends StatelessWidget {
  const _PieceInfo({required this.piece});
  final AssignmentPiece piece;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(piece.title, style: TT.display.copyWith(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              '${piece.voicing} · ${text.modeName(piece.mode)} · '
              '${text.sectionText(piece)} · '
              '${piece.withAccompaniment ? text.accompanied : text.unaccompanied}',
              style: TT.small,
            ),
          ],
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      piece.title,
                      style: TT.display.copyWith(fontSize: 32),
                    ),
                  ),
                  const Icon(Ic.music2, color: TC.primary, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${piece.voicing} · ${text.modeName(piece.mode)} · '
                '${text.sectionText(piece)}',
                style: TT.small,
              ),
              const SizedBox(height: 12),
              Text(text.caps(text.submissionSummary), style: TT.caps),
              const SizedBox(height: 10),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          text.partName(row.part),
                          style: TT.body.copyWith(color: TC.ink),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          text.partShort(row),
                          style: TT.small.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(text.rosterLimit, style: TT.small),
            ],
          ),
        ),
        Caption(text.caps(text.takes)),
        for (final s in takes)
          ChoirRow(
            icon: Ic.userRound,
            title: _name(store, s),
            subtitle:
                '${piece.title} · ${text.statusName(s.status)}'
                '${s.sentLate(a) ? ' · ${text.lateTag}' : ''}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReviewScreen(submissionId: s.id),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(text.openForFeedback, style: TT.small),
        ),
      ],
    );
  }

  String _name(ChoirStore store, Submission s) {
    for (final m in store.singersOf(s.choirId)) {
      if (m.userId == s.memberId) return m.displayName;
    }
    return s.part.title;
  }
}

/// What the conductor said, with the way on to Personal practice for labels
/// that have one (the conductor's judgement, nothing the app detected).
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TC.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.caps(text.conductorReplied), style: TT.crumb),
          if (feedback.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(feedback.text, style: TT.title),
          ],
          if (feedback.marks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (final m in feedback.marks)
                  TiltTag(
                    '${clockText(Duration(milliseconds: m.atMs))} · '
                    '${text.tagName(m.tag)}'
                    '${m.text.isEmpty ? '' : ' · ${m.text}'}',
                    color: Colors.white,
                  ),
              ],
            ),
          ],
          if (feedback.voiceNoteId != null) ...[
            const SizedBox(height: 12),
            FilePlayButton(
              key: const Key('feedback_voice'),
              mediaId: feedback.voiceNoteId!,
              label: text.playVoiceNote,
            ),
          ],
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(text.practiseThis, style: TT.small),
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

class FilePlayButton extends StatefulWidget {
  const FilePlayButton({super.key, required this.mediaId, required this.label});
  final String mediaId;
  final String label;
  @override
  State<FilePlayButton> createState() => _FilePlayButtonState();
}

class _FilePlayButtonState extends State<FilePlayButton> {
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
      await player.open(await scope.store.ensureMedia(widget.mediaId));
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
    icon: Icon(_playing ? Ic.pause : Ic.play),
    label: Text(widget.label),
  );
}
