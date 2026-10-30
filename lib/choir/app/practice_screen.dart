import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../audio/take_engine.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
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
  var _ownGain = 1.0;
  var _othersGain = 0.45;
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
              icon: Icons.mic_none_rounded,
              onPressed: () {
                _player.pause();
                widget.onReady!();
              },
            ),
      children: [
        Text(text.caps(text.partLabel), style: TT.caps),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _PartChip(
                key: const Key('practice_full'),
                label: text.fullChoir,
                selected: own == null,
                onTap: () => _changed(() => _own = null),
              ),
              for (final p in ChoirPart.values)
                _PartChip(
                  key: Key('practice_part_${p.name}'),
                  label: text.partName(p),
                  selected: own == p,
                  onTap: () => _changed(() => _own = p),
                ),
            ],
          ),
        ),
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
                      style: const TextStyle(color: TC.heroMuted, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('practice_restart'),
                    tooltip: text.replayStart,
                    onPressed: ms == 0 ? null : _restart,
                    color: Colors.white,
                    disabledColor: TC.muted,
                    icon: const Icon(Icons.skip_previous_outlined),
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
                    selectedIcon: const Icon(
                      Icons.repeat_on_rounded,
                      color: TC.sun,
                    ),
                    icon: const Icon(Icons.repeat_rounded),
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

class _PartChip extends StatelessWidget {
  const _PartChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : TC.body,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      selected: selected,
      checkmarkColor: Colors.white,
      onSelected: (_) => onTap(),
    ),
  );
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
