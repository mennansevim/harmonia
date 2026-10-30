import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../audio/take_engine.dart';
import '../domain/submission.dart';
import 'choir_scope.dart';
import 'choir_text.dart';

/// The conductor listens, marks moments (a breath leak here), speaks or sings
/// the correction, and decides. Everything here is the conductor's own
/// judgement; the app measures nothing in the take.
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
  final _tags = <FeedbackTag>{};
  final _marks = <FeedbackMark>[];
  final _subs = <StreamSubscription<Object?>>[];
  var _position = Duration.zero;
  Duration? _length;
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
      final length = await _player.open(await store.mediaPath(id));
      if (mounted) setState(() => _length = length);
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

  void _mark(FeedbackTag tag) {
    setState(() {
      _marks.add(FeedbackMark(atMs: _position.inMilliseconds, tag: tag));
    });
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

  Future<void> _decide(BuildContext button, ReviewOutcome outcome) async {
    final scope = ChoirScope.read(context);
    final text = CT.of(context);
    final s = _submission;
    if (s == null) return;
    final comment = _comment.text.trim();
    if (comment.isEmpty &&
        _tags.isEmpty &&
        _marks.isEmpty &&
        _voicePath == null) {
      toast(context, text.needFeedback);
      return;
    }
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
      text: comment,
      tags: _tags.toList(),
      marks: _marks,
      voiceNoteId: voice,
    );
    final path = await scope.bundles.exportFeedback(reviewed);
    await scope.files.share(path, origin: origin);
    nav.pop();
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
    return ChoirPage(
      title: singer?.displayName ?? text.reviewTake,
      children: [
        Text(
          '${text.partName(s.part)} · ${piece?.title ?? ''}',
          style: TT.title,
        ),
        if (piece != null)
          Text(
            '${text.modeName(piece.mode)} · ${text.sectionText(piece)} · '
            '${text.takeKindName(s.takeKind!)}',
            style: TT.small,
          ),
        if (assignment != null && s.sentLate(assignment))
          Text(text.lateTag, style: TT.small),
        const SizedBox(height: 10),
        if (_openFailed) Text(text.cannotOpen, style: TT.body),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.filled(
                    key: const Key('review_play'),
                    tooltip: _playing ? text.pause : text.listen,
                    onPressed: _toggle,
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      key: const Key('review_seek'),
                      value: total == 0
                          ? 0
                          : _position.inMilliseconds.clamp(0, total).toDouble(),
                      max: total == 0 ? 1 : total.toDouble(),
                      onChanged: total == 0
                          ? null
                          : (v) =>
                                _player.seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${clockText(_position)} / '
                    '${clockText(_length ?? Duration.zero)}',
                    style: TT.small,
                  ),
                  const Spacer(),
                  Text('${text.speed} ', style: TT.small),
                  SegmentedButton<double>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1×')),
                      ButtonSegment(value: 1.25, label: Text('1,25×')),
                    ],
                    selected: {_speed},
                    onSelectionChanged: (v) {
                      setState(() => _speed = v.first);
                      _player.setSpeed(v.first);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Caption(text.markHere.toUpperCase()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              key: const Key('mark_breathLeak'),
              avatar: const Icon(Icons.air_rounded, size: 18),
              label: Text(text.tagName(FeedbackTag.breathLeak)),
              onPressed: () => _mark(FeedbackTag.breathLeak),
            ),
            for (final t in const [
              FeedbackTag.pitch,
              FeedbackTag.rhythm,
              FeedbackTag.entry,
              FeedbackTag.diction,
            ])
              ActionChip(
                label: Text(text.tagName(t)),
                onPressed: () => _mark(t),
              ),
          ],
        ),
        for (final (i, m) in _marks.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${clockText(Duration(milliseconds: m.atMs))} · '
              '${text.tagName(m.tag)}',
            ),
            trailing: IconButton(
              tooltip: text.delete,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _marks.removeAt(i)),
            ),
          ),
        Caption(text.yourComment.toUpperCase()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in FeedbackTag.values)
              FilterChip(
                key: Key('tag_${t.name}'),
                label: Text(text.tagName(t)),
                selected: _tags.contains(t),
                onSelected: (_) => setState(() {
                  if (!_tags.remove(t)) _tags.add(t);
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('review_comment'),
          controller: _comment,
          maxLines: 3,
          decoration: choirField(text.yourComment),
        ),
        Caption(text.voiceNote.toUpperCase()),
        Text(text.voiceNoteHint, style: TT.small),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          key: const Key('review_voice'),
          onPressed: _toggleVoice,
          icon: Icon(_recordingVoice ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(_recordingVoice ? text.stopVoice : text.recordVoice),
        ),
        if (_voicePath != null && !_recordingVoice)
          TextLink(
            text.removeVoice,
            onTap: () => setState(() => _voicePath = null),
          ),
        const SizedBox(height: 18),
        if (s.awaitsConductor)
          Builder(
            builder: (button) => Row(
              children: [
                Expanded(
                  child: BigButton(
                    key: const Key('review_redo'),
                    label: text.askRedo,
                    color: TC.amber,
                    busy: _busy,
                    onPressed: () =>
                        _decide(button, ReviewOutcome.revisionRequested),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BigButton(
                    key: const Key('review_accept'),
                    label: text.accept,
                    color: TC.green,
                    busy: _busy,
                    onPressed: () => _decide(button, ReviewOutcome.accepted),
                  ),
                ),
              ],
            ),
          )
        else
          Builder(
            builder: (button) => BigButton(
              label: text.resendFeedback,
              onPressed: () async {
                final scope = ChoirScope.read(context);
                final origin = shareOrigin(button);
                final path = await scope.bundles.exportFeedback(s);
                await scope.files.share(path, origin: origin);
              },
            ),
          ),
      ],
    );
  }
}
