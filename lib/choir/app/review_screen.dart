import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../audio/take_engine.dart';
import '../domain/submission.dart';
import 'choir_scope.dart';
import 'choir_text.dart';
import 'piece_audio.dart';

const _waveBars = ChoirWave.barCount;

/// The conductor listens, notes moments (a breath leak here), sings the
/// correction, and decides. Everything here is the conductor's own judgement;
/// the app measures nothing in the take. The wave shows loudness only.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.submissionId});
  final String submissionId;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ChoirPlayer _player;
  late final TakeCapture _capture;
  final _comment = TextEditingController();
  final _marks = <FeedbackMark>[];
  final _subs = <StreamSubscription<Object?>>[];
  var _position = Duration.zero;
  Duration? _length;
  List<double> _peaks = const [];
  var _playing = false;
  var _speed = 1.0;
  var _openFailed = false;
  var _recordingVoice = false;
  var _heard = false;
  var _busy = false;
  String? _voicePath;
  Directory? _dir;

  @override
  void initState() {
    super.initState();
    final scope = ChoirScope.read(context);
    _player = scope.newPlayer();
    _capture = scope.newCapture();
    _subs
      ..add(
        _player.positions.listen((p) {
          if (mounted) setState(() => _position = p);
        }),
      )
      ..add(
        _player.playingChanges.listen((p) {
          if (mounted) setState(() => _playing = p);
        }),
      );
    _load();
  }

  Submission? get _submission => ChoirScope.read(
    context,
  ).store.submissions.where((s) => s.id == widget.submissionId).firstOrNull;

  Future<void> _load() async {
    final store = ChoirScope.read(context).store;
    final id = _submission?.recordingId;
    if (id == null) return;
    try {
      final path = await store.mediaPath(id);
      final length = await _player.open(path);
      if (mounted) setState(() => _length = length);
      final peaks = await peaksOfFile(path, _waveBars);
      if (mounted) setState(() => _peaks = peaks);
    } catch (_) {
      if (mounted) setState(() => _openFailed = true);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _comment.dispose();
    _player.close();
    _capture.close().catchError((Object _) {});
    _dir?.delete(recursive: true).catchError((Object _) => Directory(''));
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    await _player.play();
    if (!_heard) {
      _heard = true;
      final s = _submission;
      if (s != null && mounted) {
        await ChoirScope.read(context).store.markListened(s);
      }
    }
  }

  void _addMark(CT text) {
    final at = _position;
    final note = TextEditingController();
    showTrainerSheet<void>(
      context,
      (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text.addMomentNote, style: TT.h3),
            Text(clockText(at), style: TT.small),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mark_note'),
              controller: note,
              decoration: choirField(text.momentNoteHint),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in FeedbackTag.values)
                  ActionChip(
                    key: Key('mark_${t.name}'),
                    label: Text(text.tagName(t)),
                    onPressed: () {
                      setState(() {
                        _marks.add(
                          FeedbackMark(
                            atMs: at.inMilliseconds,
                            tag: t,
                            text: note.text.trim(),
                          ),
                        );
                      });
                      Navigator.pop(sheet);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(note.dispose);
  }

  Future<void> _toggleVoice() async {
    final scope = ChoirScope.read(context);
    final text = CT.of(context);
    if (_recordingVoice) {
      await _capture.stop();
      setState(() => _recordingVoice = false);
      return;
    }
    if (!await _capture.requestPermission()) {
      if (mounted) toast(context, text.micDenied);
      return;
    }
    await _player.pause();
    final dir = _dir ??= await (await scope.workDirectory()).createTemp(
      'choir-voice-',
    );
    final path = '${dir.path}/voice.wav';
    await _capture.start(vocalPath: path);
    if (mounted) {
      setState(() {
        _voicePath = path;
        _recordingVoice = true;
      });
    }
  }

  /// One send button, then the decision the singer needs to see.
  Future<void> _send(BuildContext button) async {
    final text = CT.of(context);
    if (_comment.text.trim().isEmpty && _marks.isEmpty && _voicePath == null) {
      toast(context, text.needFeedback);
      return;
    }
    final outcome = await showTrainerSheet<ReviewOutcome>(
      context,
      (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.howDidItGo, style: TT.h3),
          const SizedBox(height: 14),
          BigButton(
            key: const Key('review_accept'),
            label: text.accept,
            color: TC.sun,
            onPressed: () => Navigator.pop(sheet, ReviewOutcome.accepted),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('review_redo'),
            onPressed: () =>
                Navigator.pop(sheet, ReviewOutcome.revisionRequested),
            child: Text(text.askRedo),
          ),
        ],
      ),
    );
    if (outcome != null && button.mounted) await _decide(button, outcome);
  }

  Future<void> _decide(BuildContext button, ReviewOutcome outcome) async {
    final scope = ChoirScope.read(context);
    final s = _submission;
    if (s == null) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final origin = shareOrigin(button);
    if (_recordingVoice) await _toggleVoice();
    final voice = _voicePath == null
        ? null
        : await scope.store.addMedia(_voicePath!, 'voice.wav');
    final reviewed = await scope.store.review(
      submission: s,
      outcome: outcome,
      text: _comment.text.trim(),
      marks: _marks,
      voiceNoteId: voice,
    );
    final path = await scope.bundles.exportFeedback(reviewed);
    await scope.files.share(path, origin: origin);
    nav.pop();
  }

  void _seekFraction(double f) {
    final total = _length?.inMilliseconds ?? 0;
    if (total > 0) {
      _player.seek(Duration(milliseconds: (total * f.clamp(0, 1)).round()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final s = _submission;
    if (s == null) return const ChoirPage(title: '', children: []);
    final singer = store
        .singersOf(s.choirId)
        .where((m) => m.userId == s.memberId)
        .firstOrNull;
    final assignment = store.assignments
        .where((a) => a.id == s.assignmentId)
        .firstOrNull;
    final piece = assignment?.piece(s.pieceId);
    final total = _length?.inMilliseconds ?? 0;
    final name = singer?.displayName ?? text.partName(s.part);
    final progress = total == 0 ? 0.0 : _position.inMilliseconds / total;
    return ChoirPage(
      title: name,
      crumb: text.crumbReview,
      bottom: Builder(
        builder: (button) => s.awaitsConductor
            ? BigButton(
                key: const Key('review_send'),
                label: text.sendFeedback,
                icon: Ic.send,
                busy: _busy,
                onPressed: () => _send(button),
              )
            : BigButton(
                label: text.resendFeedback,
                onPressed: () async {
                  final scope = ChoirScope.read(context);
                  final origin = shareOrigin(button);
                  final path = await scope.bundles.exportFeedback(s);
                  await scope.files.share(path, origin: origin);
                },
              ),
      ),
      children: [
        Row(
          children: [
            if (piece != null)
              Flexible(child: TiltTag(piece.title, color: TC.primarySoft)),
            const SizedBox(width: 8),
            if (assignment != null)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TiltTag(assignment.title, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${text.partName(s.part)}'
          '${piece == null ? '' : ' · ${text.sectionText(piece)}'}'
          '${s.takeKind == null ? '' : ' · ${text.takeKindName(s.takeKind!)}'}'
          '${assignment != null && s.sentLate(assignment) ? ' · ${text.lateTag}' : ''}',
          style: TT.small,
        ),
        const SizedBox(height: 20),
        if (_openFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text.cannotOpen, style: TT.body),
          ),
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.caps('$name · ${text.sentRecording}'),
                      style: const TextStyle(
                        color: TC.heroMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Icon(Ic.headphones, color: TC.sun, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              if (_peaks.isEmpty)
                Slider(
                  key: const Key('review_seek'),
                  value: progress.clamp(0, 1),
                  onChanged: total == 0 ? null : _seekFraction,
                )
              else
                ChoirWave(
                  peaks: _peaks,
                  progress: progress,
                  onSeek: _seekFraction,
                  marks: [
                    if (total > 0)
                      for (final m in _marks) m.atMs / total,
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      clockText(_position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  LimePlay(
                    key: const Key('review_play'),
                    playing: _playing,
                    label: _playing ? text.pause : text.listen,
                    onTap: _toggle,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          key: const Key('review_speed'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final next = _speed == 1 ? 1.25 : 1.0;
                            setState(() => _speed = next);
                            _player.setSpeed(next);
                          },
                          child: Text(_speed == 1 ? '1×' : '1,25×'),
                        ),
                        IconButton(
                          key: const Key('review_restart'),
                          tooltip: text.replayStart,
                          onPressed: total == 0
                              ? null
                              : () => _player.seek(Duration.zero),
                          color: Colors.white,
                          disabledColor: TC.heroMuted,
                          icon: const Icon(Ic.rotateCcw, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const Key('review_add_mark'),
          onPressed: () => _addMark(text),
          icon: const Icon(Ic.plus, size: 18),
          label: Text(text.addMomentNote),
        ),
        Caption(text.caps(text.feedbackHeading)),
        TextField(
          key: const Key('review_comment'),
          controller: _comment,
          maxLines: 4,
          decoration: choirField(text.feedbackFor(name)),
        ),
        for (final (i, m) in _marks.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              decoration: BoxDecoration(
                color: TC.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  TiltTag(
                    clockText(Duration(milliseconds: m.atMs)),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${text.tagName(m.tag)}'
                      '${m.text.isEmpty ? '' : ' · ${m.text}'}',
                      style: TT.body.copyWith(color: TC.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: text.delete,
                    onPressed: () => setState(() => _marks.removeAt(i)),
                    icon: const Icon(Ic.x, size: 20),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const Key('review_voice'),
          onPressed: _toggleVoice,
          icon: Icon(_recordingVoice ? Ic.square : Ic.mic, size: 18),
          label: Text(_recordingVoice ? text.stopVoice : text.voiceFeedback),
        ),
        if (_voicePath != null && !_recordingVoice)
          TextLink(
            text.removeVoice,
            onTap: () => setState(() => _voicePath = null),
          ),
      ],
    );
  }
}
