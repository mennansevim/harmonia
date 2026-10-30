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

/// Own part forward, the rest behind, at any tempo: the MIDI work a singer
/// does before recording. Also serves as the player for a second device.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.piece, required this.part});
  final AssignmentPiece piece;
  final ChoirPart? part;
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

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final piece = widget.piece;
    final ms = _length.inMilliseconds;
    return ChoirPage(
      title: piece.title,
      bottom: BigButton(
        key: const Key('practice_play'),
        label: _playing ? text.pause : text.play,
        icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        busy: _busy,
        onPressed: _toggle,
      ),
      children: [
        Text(
          '${text.modeName(piece.mode)} · ${text.sectionText(piece)}',
          style: TT.title,
        ),
        const SizedBox(height: 10),
        ProgressBar(
          value: ms == 0 ? 0 : _position.inMilliseconds / ms,
          color: TC.koro,
          height: 6,
        ),
        const SizedBox(height: 4),
        Text(
          '${clockText(_position)} / ${clockText(_length)}',
          style: TT.small,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TT.body),
        ],
        Caption(text.myPart.toUpperCase()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('practice_full'),
              label: Text(text.fullChoir),
              selected: _own == null,
              onSelected: (_) => _changed(() => _own = null),
            ),
            for (final p in ChoirPart.values)
              ChoiceChip(
                key: Key('practice_part_${p.name}'),
                label: Text(text.partName(p)),
                selected: _own == p,
                onSelected: (_) => _changed(() => _own = p),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_own != null)
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
        Text(text.tempoLabel(_tempo), style: TT.title),
        Slider(
          key: const Key('practice_tempo'),
          value: _tempo.toDouble(),
          min: 50,
          max: 120,
          divisions: 14,
          label: '$_tempo',
          onChanged: (v) => _changed(() => _tempo = v.round()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _metronome,
          onChanged: (v) => _changed(() => _metronome = v),
          title: Text(text.metronome, style: TT.title),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _countIn,
          onChanged: (v) => _changed(() => _countIn = v),
          title: Text(text.countIn, style: TT.title),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _loop,
          onChanged: (v) => _changed(() => _loop = v),
          title: Text(text.loop, style: TT.title),
        ),
        const SizedBox(height: 4),
        Text(text.synthNotice, style: TT.small),
      ],
    );
  }
}

class _Level extends StatelessWidget {
  const _Level({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 108, child: Text(label, style: TT.body)),
      Expanded(
        child: Slider(value: value, onChanged: onChanged),
      ),
    ],
  );
}
