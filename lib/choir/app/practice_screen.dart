import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../audio/take_engine.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/part_ladder.dart';
import '../midi/part_renderer.dart';
import 'choir_scope.dart';
import 'choir_text.dart';
import 'piece_audio.dart';

const _bars = ChoirWave.barCount;

/// Own part forward, the rest behind, at any tempo: the MIDI work a singer
/// does before recording. Also serves as the player for a second device.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.piece,
    required this.part,
    this.crumb = '',
    this.onReady,
  });
  final AssignmentPiece piece;
  final ChoirPart? part;
  final String crumb;

  /// Moves on to recording; null once the piece is sent.
  final VoidCallback? onReady;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with WidgetsBindingObserver {
  late final ChoirPlayer _player;
  late ChoirPart? _own = widget.part;
  var _ownGain = PartStep.listen.ownGain;
  var _othersGain = PartStep.listen.othersGain;
  var _metronome = false;
  var _tempo = 100;
  var _loop = false;
  var _countIn = true;

  var _busy = false;
  var _playing = false;
  var _stale = true;
  Directory? _dir;
  String? _error;
  List<double> _peaks = const [];
  Duration _position = Duration.zero;
  Duration _length = Duration.zero;
  final _subs = <StreamSubscription<Object?>>[];
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = ChoirScope.read(context).newPlayer();
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) _player.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _player.close();
    _dir?.delete(recursive: true).catchError((Object _) => Directory(''));
    super.dispose();
  }

  void _changed(VoidCallback change) {
    if (_playing) _player.pause();
    setState(() {
      change();
      _stale = true;
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    if (!_stale) {
      await _player.play();
      return;
    }
    final scope = ChoirScope.read(context);
    final text = CT.of(context);
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final part = await renderPiece(
        store: scope.store,
        piece: widget.piece,
        mix: PartMix(
          ownPart: _own,
          ownGain: _ownGain,
          othersGain: _othersGain,
          metronomeGain: _metronome ? 0.8 : 0,
          tempoFactor: _tempo / 100,
          countInBars: _countIn ? 1 : 0,
        ),
      );
      final bytes = await encodeRendered(part);
      final peaks = await peaksOfPart(part, _bars);
      if (!mounted || generation != _generation) return;
      final dir = _dir ??= await (await scope.workDirectory()).createTemp(
        'choir-practice-',
      );
      final file = File('${dir.path}/mix-$generation.wav');
      await file.writeAsBytes(bytes, flush: true);
      final length = await _player.open(file.path, loop: _loop);
      if (!mounted || generation != _generation) return;
      setState(() {
        _length = length ?? part.duration;
        _peaks = peaks;
        _stale = false;
        _busy = false;
      });
      await _player.play();
    } on RenderTooLong {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = text.tooLong;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = text.renderFailed;
        });
      }
    }
  }

  void _restart() {
    _player.seek(Duration.zero);
  }

  PartStep? get _step =>
      _own == null ? null : PartStep.matching(_ownGain, _othersGain, _tempo);

  void _useStep(PartStep s) => _changed(() {
    _ownGain = s.ownGain;
    _othersGain = s.othersGain;
    _tempo = s.tempo;
  });

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final piece = widget.piece;
    final ms = _length.inMilliseconds;
    final progress = ms == 0 ? 0.0 : _position.inMilliseconds / ms;
    final own = _own;
    return ChoirPage(
      title: piece.title,
      crumb: widget.crumb,
      subtitle:
          '${piece.voicing} · ${text.modeName(piece.mode)} · '
          '${text.sectionText(piece)}',
      bottom: widget.onReady == null
          ? null
          : BigButton(
              key: const Key('practice_ready'),
              label: text.goToSetup,
              icon: Ic.mic,
              onPressed: () {
                _player.pause();
                widget.onReady!();
              },
            ),
      children: [
        Text(text.caps(text.partLabel), style: TT.caps),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            OptionChip(
              key: const Key('practice_full'),
              label: text.fullChoir,
              selected: own == null,
              onTap: () => _changed(() => _own = null),
            ),
            for (final p in ChoirPart.values)
              OptionChip(
                key: Key('practice_part_${p.name}'),
                label: text.partName(p),
                selected: own == p,
                onTap: () => _changed(() => _own = p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Steps(step: _step, enabled: own != null, onStep: _useStep),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Column(
            children: [
              if (own != null)
                _Level(
                  label: text.ownVolume,
                  value: _ownGain,
                  onChanged: (v) => _changed(() => _ownGain = v),
                ),
              _Level(
                label: text.othersVolume,
                value: _othersGain,
                onChanged: (v) => _changed(() => _othersGain = v),
              ),
              _Level(
                key: const Key('practice_tempo'),
                label: text.tempoCaption,
                value: (_tempo - 50) / 70,
                shown: '%$_tempo',
                divisions: 14,
                onChanged: (v) =>
                    _changed(() => _tempo = 50 + (v * 14).round() * 5),
              ),
              _Switch(
                label: text.metronome,
                value: _metronome,
                onChanged: (v) => _changed(() => _metronome = v),
              ),
              _Switch(
                label: text.countIn,
                value: _countIn,
                onChanged: (v) => _changed(() => _countIn = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoirWave(
                peaks: _peaks.isEmpty ? List.filled(_bars, 0.08) : _peaks,
                progress: progress,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      clockText(_position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('practice_restart'),
                    tooltip: text.replayStart,
                    onPressed: ms == 0 ? null : _restart,
                    color: Colors.white,
                    disabledColor: TC.muted,
                    icon: const Icon(Ic.skipBack),
                  ),
                  const SizedBox(width: 10),
                  LimePlay(
                    key: const Key('practice_play'),
                    playing: _playing,
                    busy: _busy,
                    label: _playing ? text.pause : text.play,
                    onTap: _toggle,
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    key: const Key('practice_loop'),
                    tooltip: text.loop,
                    isSelected: _loop,
                    onPressed: () => _changed(() => _loop = !_loop),
                    color: Colors.white,
                    selectedIcon: const Icon(Ic.repeat, color: TC.sun),
                    icon: const Icon(Ic.repeat),
                  ),
                  const Spacer(),
                  const SizedBox(width: 52),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TT.body),
          ),
        const SizedBox(height: 10),
        Text(text.synthNotice, style: TT.small),
      ],
    );
  }
}

/// The fading-support ladder ([PartStep]) over the mix controls. Moving a
/// slider by hand leaves the ladder ("your own mix") without losing it.
class _Steps extends StatelessWidget {
  const _Steps({
    required this.step,
    required this.enabled,
    required this.onStep,
  });
  final PartStep? step;
  final bool enabled;
  final ValueChanged<PartStep> onStep;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final s = step;
    return AppCard(
      key: const Key('practice_steps'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.caps(text.stepsTitle), style: TT.caps),
          const SizedBox(height: 6),
          Text(enabled ? text.stepsBody : text.chooseOwnPart, style: TT.small),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in PartStep.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: p == s,
                    label: '${text.stepCount(p)}: ${text.stepName(p)}',
                    child: GestureDetector(
                      key: Key('practice_step_${p.name}'),
                      onTap: enabled ? () => onStep(p) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 8,
                        decoration: BoxDecoration(
                          color: !enabled
                              ? TC.line
                              : s != null && p.index <= s.index
                              ? TC.primary
                              : TC.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Text(
              s == null
                  ? text.ownMix
                  : '${text.stepCount(s)} · ${text.stepName(s)}',
              style: TT.title,
            ),
            if (s != null) ...[
              const SizedBox(height: 4),
              Text(text.stepHow(s), style: TT.body),
            ],
            if (s?.next != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('practice_next_step'),
                  onPressed: () => onStep(s!.next!),
                  child: Text(text.nextStep),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Level extends StatelessWidget {
  const _Level({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.shown,
    this.divisions,
  });
  final String label;
  final double value;
  final String? shown;
  final int? divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(label, style: TT.body.copyWith(color: TC.ink)),
          ),
          Text(
            shown ?? '%${(value * 100).round()}',
            style: const TextStyle(
              color: TC.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
      Slider(
        value: value,
        divisions: divisions,
        padding: const EdgeInsets.symmetric(vertical: 8),
        onChanged: onChanged,
      ),
    ],
  );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: TT.body.copyWith(color: TC.ink)),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}
