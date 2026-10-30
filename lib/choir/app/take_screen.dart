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

const _reviewBars = ChoirWave.barCount;

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
  var _position = Duration.zero;
  List<double> _peaks = const [];
  Timer? _ticker;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;

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
    _positionSub = _player.positions.listen((p) {
      if (mounted) setState(() => _position = p);
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
    _positionSub?.cancel();
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
      final path = _take!.resultPath;
      _player.open(path);
      peaksOfFile(path, _reviewBars).then((peaks) {
        if (mounted) setState(() => _peaks = peaks);
      });
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
    return switch (phase) {
      TakePhase.review => _reviewPage(text, take!),
      TakePhase.preparing => _waiting(text.preparing),
      TakePhase.mixing => _waiting(text.mixing),
      _ => _setupPage(text, phase),
    };
  }

  Widget _waiting(String label) =>
      ChoirPage(title: widget.piece.title, children: [_status(label)]);

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

  /// The recording setup: what the route allows, and the one action.
  Widget _setupPage(CT text, TakePhase phase) {
    final advice = _route;
    final piece = widget.piece;
    final crumb = !_accompanied
        ? text.crumbSetup
        : switch (advice) {
            RouteAdvice.speaker => text.crumbNeedsHeadphones,
            RouteAdvice.bluetoothDelay => text.crumbBluetooth,
            _ => text.crumbSetup,
          };
    return ChoirPage(
      title: piece.title,
      crumb: crumb,
      subtitle:
          '${piece.voicing} · ${text.modeName(piece.mode)} · '
          '${text.sectionText(piece)}',
      bottom: BigButton(
        key: const Key('take_start'),
        label: text.startTake,
        icon: Icons.mic_none_rounded,
        color: TC.sun,
        onPressed: _canRecord ? _start : null,
      ),
      children: [
        if (phase == TakePhase.interrupted) _notice(text.interrupted),
        if (phase == TakePhase.failed) _notice(text.takeFailed),
        if (_denied) _notice(text.micDenied),
        if (_accompanied) ...[
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.caps(text.setupCaption),
                  style: const TextStyle(
                    color: TC.heroMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text.onePhoneHeadline,
                  style: TT.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text.onePhoneBody,
                  style: const TextStyle(
                    color: TC.heroMuted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (advice != null) _routeBanner(text, advice),
          if (advice == RouteAdvice.unknown && !_headphonesConfirmed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                key: const Key('take_confirm_headphones'),
                onPressed: () => setState(() => _headphonesConfirmed = true),
                child: Text(text.headphonesOn),
              ),
            ),
          if (advice == RouteAdvice.speaker)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                key: const Key('take_check_route'),
                onPressed: _checkRoute,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(text.checkAgain),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(text.readyFor(piece.title), style: TT.small),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(text.modeHint(piece.mode), style: TT.body),
          ),
        OutlinedButton.icon(
          key: const Key('take_import'),
          onPressed: _importTake,
          icon: const Icon(Icons.upload_outlined, size: 20),
          label: Text(text.addFromDevice),
        ),
      ],
    );
  }

  Widget _routeBanner(CT text, RouteAdvice advice) {
    final (icon, title, body, fill) = switch (advice) {
      RouteAdvice.ready => (
        Icons.headphones_outlined,
        text.wiredReady,
        text.readyToGo,
        TC.sun,
      ),
      RouteAdvice.bluetoothDelay => (
        Icons.bluetooth_rounded,
        text.btDelay,
        text.btHint,
        TC.warnSoft,
      ),
      RouteAdvice.speaker => (
        Icons.volume_up_outlined,
        text.speakerLeak,
        text.plugHeadphones,
        TC.warnSoft,
      ),
      RouteAdvice.unknown => (
        Icons.headphones_outlined,
        text.unknownRoute,
        text.unknownHint,
        TC.primarySoft,
      ),
    };
    return Padding(
      key: Key('take_route_${advice.name}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: fill == TC.warnSoft ? TC.warn : TC.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TT.title),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(color: TC.ink, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      border: TC.coral,
      child: Semantics(liveRegion: true, child: Text(message, style: TT.body)),
    ),
  );

  /// The one dark screen: nothing competes with singing. The wave is the
  /// real microphone level, not a decorative loop.
  Widget _recording(CT text, TakeController take) {
    final count = take.countIn;
    final inCount = _elapsed < count;
    final time = clockText(inCount ? Duration.zero : _elapsed - count);
    final stage = inCount ? text.countIn : text.recording;
    final part = ChoirScope.of(
      context,
    ).store.meIn(widget.assignment.choirId)?.part;
    final levels = take.recentLevels;
    return Scaffold(
      backgroundColor: TC.hero,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: TC.sun,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text.caps(text.recordingNow),
                    style: const TextStyle(
                      color: TC.sun,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.piece.title,
                style: TT.display.copyWith(color: Colors.white, fontSize: 43),
              ),
              const SizedBox(height: 4),
              Text(
                '${part == null ? '' : '${text.partName(part)} · '}'
                '${text.sectionText(widget.piece)}',
                style: const TextStyle(color: TC.heroMuted, fontSize: 14),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 242,
                  height: 242,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: inCount ? TC.navPill : TC.sun,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    label: '$stage $time',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mic_none_rounded,
                          color: TC.ink,
                          size: 26,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          time,
                          style: TT.h1.copyWith(
                            fontSize: 55,
                            letterSpacing: -3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          stage,
                          style: const TextStyle(
                            color: TC.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ChoirWave(
                peaks: [
                  ...List.filled(
                    TakeController.levelHistory - levels.length,
                    0.0,
                  ),
                  ...levels,
                ],
                progress: 1,
              ),
              const SizedBox(height: 14),
              Text(
                text.singAlong,
                textAlign: TextAlign.center,
                style: const TextStyle(color: TC.heroMuted, fontSize: 13.5),
              ),
              const Spacer(),
              BigButton(
                key: const Key('take_stop'),
                label: text.stopRecording,
                icon: Icons.crop_square_rounded,
                color: TC.sun,
                onPressed: take.finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewPage(CT text, TakeController take) {
    final total = take.resultDurationMs ?? 0;
    final progress = total == 0 ? 0.0 : _position.inMilliseconds / total;
    final part = ChoirScope.of(
      context,
    ).store.meIn(widget.assignment.choirId)?.part;
    return ChoirPage(
      title: text.listenBack,
      crumb: '${widget.piece.title} / ${text.crumbTakeCheck}',
      subtitle:
          '${widget.piece.title}'
          '${part == null ? '' : ' · ${text.partName(part)}'}',
      trailing: TiltTag(text.takeReady),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            key: const Key('take_keep'),
            label: text.keepTake,
            icon: Icons.check_rounded,
            busy: _keeping,
            onPressed: _keep,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('take_again'),
            onPressed: _start,
            icon: const Icon(Icons.replay_rounded, size: 20),
            label: Text(text.recordAgain),
          ),
        ],
      ),
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text.caps(text.yourTake),
                style: const TextStyle(
                  color: TC.heroMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              if (_peaks.isNotEmpty)
                ChoirWave(
                  peaks: _peaks,
                  progress: progress,
                  onSeek: (f) => _player.seek(
                    Duration(milliseconds: (total * f.clamp(0, 1)).round()),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      clockText(_position),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  LimePlay(
                    key: const Key('take_play'),
                    playing: _playing,
                    label: _playing ? text.pause : text.listen,
                    onTap: _playing ? _player.pause : _player.play,
                  ),
                  Expanded(
                    child: Text(
                      clockText(Duration(milliseconds: total)),
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: TC.heroMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (take.accompanied) ...[
          Caption(text.caps(text.alignHeading)),
          Text(text.alignExplain, style: TT.small),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.alignLabel,
                        style: TT.body.copyWith(color: TC.ink),
                      ),
                    ),
                    Text(
                      '${_sliderMs.round()} ms',
                      style: const TextStyle(
                        color: TC.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Slider(
                  key: const Key('take_align'),
                  value: _sliderMs,
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(text.earlier, style: TT.small),
                    Text(text.later, style: TT.small),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
