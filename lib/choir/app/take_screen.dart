import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../audio/take_controller.dart';
import '../audio/take_engine.dart';
import '../domain/assignment.dart';
import '../domain/submission.dart';
import '../midi/part_renderer.dart';
import 'choir_scope.dart';
import 'choir_text.dart';
import 'piece_audio.dart';

/// Records one piece. With a MIDI on headphones this replaces the second
/// phone: playback and capture run here, then join into one file.
class TakeScreen extends StatefulWidget {
  const TakeScreen({super.key, required this.assignment, required this.piece});
  final Assignment assignment;
  final AssignmentPiece piece;
  @override
  State<TakeScreen> createState() => _TakeScreenState();
}

class _TakeScreenState extends State<TakeScreen> with WidgetsBindingObserver {
  late final TakeCapture _capture;
  late final ChoirPlayer _player;
  TakeController? _take;
  Directory? _dir;
  RouteAdvice? _route;
  var _headphonesConfirmed = false;
  var _denied = false;
  var _keeping = false;
  var _playing = false;
  var _sliderMs = 0.0;
  var _elapsed = Duration.zero;
  Timer? _ticker;
  StreamSubscription<bool>? _playingSub;

  bool get _accompanied => widget.piece.withAccompaniment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final scope = ChoirScope.read(context);
    _capture = scope.newCapture();
    _player = scope.newPlayer();
    _playingSub = _player.playingChanges.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    _checkRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askConsent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app ends the take; it is never resumed behind the singer.
    if (state == AppLifecycleState.paused) {
      final take = _take;
      if (take?.phase == TakePhase.recording) {
        take!.finish();
      } else if (_playing) {
        _player.pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _playingSub?.cancel();
    _take?.dispose();
    _player.close();
    _capture.close().catchError((Object _) {});
    _dir?.delete(recursive: true).catchError((Object _) => Directory(''));
    super.dispose();
  }

  Future<void> _askConsent() async {
    final store = ChoirScope.read(context).store;
    if (store.recordingConsent || !mounted) return;
    final text = CT.of(context);
    final ok = await showTrainerSheet<bool>(
      context,
      (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.consentTitle, style: TT.h3),
          const SizedBox(height: 8),
          Text(text.consentBody, style: TT.body),
          const SizedBox(height: 16),
          BigButton(
            key: const Key('consent_agree'),
            label: text.agree,
            onPressed: () => Navigator.pop(sheet, true),
          ),
          TextLink(text.cancel, onTap: () => Navigator.pop(sheet, false)),
        ],
      ),
      dismissible: false,
    );
    if (ok == true) {
      await store.setConsent();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _checkRoute() async {
    try {
      final route = await _capture.route();
      if (mounted) setState(() => _route = adviseRoute(route));
    } catch (_) {
      if (mounted) setState(() => _route = RouteAdvice.unknown);
    }
  }

  bool get _canRecord {
    if (!_accompanied) return true;
    return switch (_route) {
      RouteAdvice.ready || RouteAdvice.bluetoothDelay => true,
      RouteAdvice.unknown => _headphonesConfirmed,
      RouteAdvice.speaker || null => false,
    };
  }

  Future<void> _start() async {
    final scope = ChoirScope.read(context);
    if (!await _capture.requestPermission()) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    if (!mounted) return;
    _dir ??= await (await scope.workDirectory()).createTemp('choir-take-');
    final piece = widget.piece;
    final take = _take ??= TakeController(
      capture: _capture,
      workDirectory: _dir!,
      maxSeconds: widget.assignment.maxRecordingSeconds,
      render: _accompanied
          ? () => renderPiece(
              store: scope.store,
              piece: piece,
              mix: PartMix(
                ownPart: scope.store.meIn(widget.assignment.choirId)?.part,
                countInBars: 1,
              ),
            )
          : null,
    );
    take.removeListener(_onTake);
    take.addListener(_onTake);
    setState(() {
      _denied = false;
      _sliderMs = 0;
      _elapsed = Duration.zero;
    });
    _ticker?.cancel();
    await _player.pause();
    await take.begin();
    if (take.phase == TakePhase.recording) {
      final clock = Stopwatch()..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() => _elapsed = clock.elapsed);
      });
    }
  }

  void _onTake() {
    if (!mounted) return;
    final phase = _take?.phase;
    if (phase != TakePhase.recording) _ticker?.cancel();
    if (phase == TakePhase.review) {
      _player.open(_take!.resultPath);
    }
    setState(() {});
  }

  Future<void> _keep() async {
    final take = _take!;
    final store = ChoirScope.read(context).store;
    final nav = Navigator.of(context);
    setState(() => _keeping = true);
    await _player.pause();
    await store.keepTake(
      assignment: widget.assignment,
      piece: widget.piece,
      sourcePath: take.resultPath,
      fileName: 'take.wav',
      durationMs: take.resultDurationMs!,
      kind: take.kind,
    );
    nav.pop();
  }

  /// A take made elsewhere: the old two-device way still works.
  Future<void> _importTake() async {
    final scope = ChoirScope.read(context);
    final text = CT.of(context);
    final nav = Navigator.of(context);
    final picked = await scope.files.pick();
    if (picked == null || !mounted) return;
    Duration? length;
    try {
      length = await _player.open(picked.path);
    } catch (_) {
      length = null;
    }
    if (!mounted) return;
    final max = widget.assignment.maxRecordingSeconds;
    if (length == null || length <= Duration.zero) {
      toast(context, text.fileBad);
      return;
    }
    if (length.inSeconds > max) {
      toast(context, text.tooLongTake(max ~/ 60));
      return;
    }
    await scope.store.keepTake(
      assignment: widget.assignment,
      piece: widget.piece,
      sourcePath: picked.path,
      fileName: picked.name,
      durationMs: length.inMilliseconds,
      kind: TakeKind.imported,
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final take = _take;
    final phase = take?.phase ?? TakePhase.idle;
    if (phase == TakePhase.recording) return _recording(text, take!);
    return ChoirPage(
      title: widget.piece.title,
      children: switch (phase) {
        TakePhase.preparing => [_status(text.preparing)],
        TakePhase.mixing => [_status(text.mixing)],
        TakePhase.review => _review(text, take!),
        _ => _setup(text, phase),
      },
    );
  }

  Widget _status(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text(label, style: TT.body, textAlign: TextAlign.center),
      ],
    ),
  );

  List<Widget> _setup(CT text, TakePhase phase) {
    final advice = _route;
    return [
      Text(
        '${text.modeName(widget.piece.mode)} · '
        '${text.sectionText(widget.piece)}',
        style: TT.title,
      ),
      const SizedBox(height: 4),
      Text(text.modeHint(widget.piece.mode), style: TT.small),
      const SizedBox(height: 12),
      if (phase == TakePhase.interrupted) _notice(text.interrupted),
      if (phase == TakePhase.failed) _notice(text.takeFailed),
      if (_denied) _notice(text.micDenied),
      if (_accompanied) ...[
        AppCard(
          color: TC.primarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.headphonesTitle, style: TT.title),
              const SizedBox(height: 6),
              Text(text.headphonesBody, style: TT.body),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (advice != null)
          ChoirRow(
            key: Key('take_route_${advice.name}'),
            icon: advice == RouteAdvice.speaker
                ? Icons.headset_off_rounded
                : Icons.headphones_rounded,
            title: text.routeText(advice.index),
          ),
        if (advice == RouteAdvice.unknown && !_headphonesConfirmed)
          OutlinedButton(
            key: const Key('take_confirm_headphones'),
            onPressed: () => setState(() => _headphonesConfirmed = true),
            child: Text(text.headphonesOn),
          ),
        if (advice == RouteAdvice.speaker)
          OutlinedButton(
            key: const Key('take_check_route'),
            onPressed: _checkRoute,
            child: Text(text.checkAgain),
          ),
        const SizedBox(height: 10),
        Text(text.singHint, style: TT.small),
      ],
      const SizedBox(height: 14),
      BigButton(
        key: const Key('take_start'),
        label: text.startRecording,
        icon: Icons.fiber_manual_record_rounded,
        color: TC.sun,
        onPressed: _canRecord ? _start : null,
      ),
      TextLink(text.addFromDevice, onTap: _importTake),
    ];
  }

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      border: TC.coral,
      child: Semantics(liveRegion: true, child: Text(message, style: TT.body)),
    ),
  );

  /// The one dark screen: nothing competes with singing. The shape breathes
  /// with the real microphone level, not a decorative loop.
  Widget _recording(CT text, TakeController take) {
    final level = ((take.levelDb + 60) / 60).clamp(0.0, 1.0);
    final count = take.countIn;
    final inCount = _elapsed < count;
    final still = MediaQuery.disableAnimationsOf(context);
    final time = clockText(inCount ? Duration.zero : _elapsed - count);
    final stage = inCount ? text.countIn : text.recording;
    return Scaffold(
      backgroundColor: TC.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.piece.title,
                style: TT.h2.copyWith(color: Colors.white),
              ),
              Text(
                text.sectionText(widget.piece),
                style: const TextStyle(color: TC.navPill, fontSize: 15),
              ),
              Expanded(
                child: Center(
                  child: AnimatedScale(
                    scale: still ? 1 : 0.92 + level * 0.14,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      width: 262,
                      height: 262,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: inCount ? TC.navPill : TC.sun,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.elliptical(115, 136),
                          topRight: Radius.elliptical(147, 105),
                          bottomLeft: Radius.elliptical(105, 157),
                          bottomRight: Radius.elliptical(157, 126),
                        ),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        label: '$stage $time',
                        excludeSemantics: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(time, style: TT.h1.copyWith(fontSize: 58)),
                            Text(
                              stage,
                              style: const TextStyle(
                                color: TC.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              BigButton(
                key: const Key('take_stop'),
                label: text.stopRecording,
                icon: Icons.stop_rounded,
                color: TC.peach,
                onPressed: take.finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _review(CT text, TakeController take) => [
    AppCard(
      child: Row(
        children: [
          IconButton.filled(
            key: const Key('take_play'),
            tooltip: _playing ? text.pause : text.listen,
            onPressed: _playing ? _player.pause : _player.play,
            icon: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            clockText(Duration(milliseconds: take.resultDurationMs ?? 0)),
            style: TT.title,
          ),
        ],
      ),
    ),
    if (take.accompanied) ...[
      Caption(text.caps(text.alignTitle)),
      Text(text.alignBody, style: TT.small),
      Slider(
        key: const Key('take_align'),
        value: _sliderMs,
        min: -TakeController.alignmentRangeMs.toDouble(),
        max: TakeController.alignmentRangeMs.toDouble(),
        divisions: 40,
        label: text.alignValue(_sliderMs.round()),
        onChanged: (v) => setState(() => _sliderMs = v),
        onChangeEnd: (v) async {
          await _player.pause();
          await take.setAlignment(v.round());
        },
      ),
      Text(
        text.alignValue(_sliderMs.round()),
        textAlign: TextAlign.center,
        style: TT.small,
      ),
    ],
    const SizedBox(height: 18),
    BigButton(
      key: const Key('take_keep'),
      label: text.keepTake,
      busy: _keeping,
      onPressed: _keep,
    ),
    TextLink(text.recordAgain, onTap: _start),
  ];
}
