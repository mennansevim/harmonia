import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/melody_practice.dart';
import '../../application/melody_practice_playback.dart';
import '../../application/melody_session.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../../infrastructure/audio/synthetic_melody_backend.dart';
import '../common/ui/harmonia_ui.dart';

/// Reference-only route. The caller must close its capture session FIRST.
/// Owns a fresh player and prevents back navigation until it is closed.
class MelodyPracticeScreen extends StatefulWidget {
  const MelodyPracticeScreen({
    super.key,
    required this.reference,
    this.player,
    this.interruptions,
    this.initialPractice,
  });
  final DiagnosticMelodyReference reference;
  final DiagnosticMelodyPracticePlayer? player;
  final DiagnosticMelodyPractice? initialPractice;

  /// Injected focus/route events for tests; mobile uses AudioSession signals.
  final Stream<void>? interruptions;
  @override
  State<MelodyPracticeScreen> createState() => _MelodyPracticeScreenState();
}

class _MelodyPracticeScreenState extends State<MelodyPracticeScreen>
    with WidgetsBindingObserver {
  late final MelodyPracticePlayback playback;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _start = 0, _end = 1, _repetitions = 1;
  bool _foreground = true, _focusReady = false, _focusFailed = false;
  bool _exiting = false, _canLeave = false;
  String? _exitError;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    playback = MelodyPracticePlayback(
      reference: widget.reference,
      player:
          widget.player ?? SyntheticMelodyPracticePlayer(JustAudioClipPlayer()),
    );
    final initial = widget.initialPractice;
    if (initial != null && identical(initial.reference, widget.reference)) {
      _start = initial.startIndex;
      _end = initial.endIndexExclusive;
      _repetitions = initial.repetitions;
    }
    WidgetsBinding.instance.addObserver(this);
    if (widget.interruptions case final events?) {
      _subscriptions.add(
        events.listen(
          (_) => _suspend(),
          onError: (Object _) => _monitoringFailed(),
        ),
      );
    }
    if (widget.player != null) {
      _focusReady = true;
    } else {
      unawaited(_watchFocus());
    }
  }

  Future<void> _watchFocus() async {
    try {
      final audio = await AudioSession.instance;
      if (!mounted || _exiting) return;
      _subscriptions.add(
        audio.interruptionEventStream.listen((event) {
          if (event.begin) _suspend();
        }, onError: (Object _) => _monitoringFailed()),
      );
      _subscriptions.add(
        audio.becomingNoisyEventStream.listen(
          (_) => _suspend(),
          onError: (Object _) => _monitoringFailed(),
        ),
      );
      _subscriptions.add(
        audio.devicesChangedEventStream.listen(
          (_) => _suspend(),
          onError: (Object _) => _monitoringFailed(),
        ),
      );
      setState(() => _focusReady = true);
    } catch (_) {
      if (mounted) setState(() => _focusFailed = true);
    }
  }

  void _suspend() {
    if (_exiting) return;
    if (playback.phase == MelodyPracticePhase.loading ||
        playback.phase == MelodyPracticePhase.playing) {
      unawaited(playback.stop());
    }
  }

  void _monitoringFailed() {
    if (!mounted || _exiting) return;
    setState(() {
      _focusReady = false;
      _focusFailed = true;
    });
    _suspend();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (!_foreground) _suspend();
  }

  Future<void> _exit() async {
    if (_exiting) return;
    setState(() => _exiting = true);
    try {
      await playback.close();
      if (!mounted) return;
      setState(() => _canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _exitError =
              'Ses kaynağının kapandığı doğrulanamadı. Uygulamayı kapatıp yeniden aç.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _canLeave,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_exit());
    },
    child: ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final enabled =
            playback.canPlay && !_exiting && _foreground && _focusReady;
        final count = widget.reference.frequenciesHz.length;
        return LessonScaffold(
          progress: null,
          counter: 'Puansız',
          closeLabel: 'Bölüm dinlemeyi kapat',
          top: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(
                widget.initialPractice == null
                    ? 'Sentetik · elle seçilen bölüm'
                    : 'Sentetik · deneysel aday bölüm',
              ),
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            Text(
              'Ezginin bir bölümünü dinle',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              widget.initialPractice == null
                  ? 'Mikrofon açılmaz. Bu seçim bir hata tespiti veya sınav değildir; dinleme geçmişe, puana ya da beceri ilerlemesine eklenmez.'
                  : 'Mikrofon açılmaz. Başlangıç seçimi yalnız deneysel frekans adaylarından türetilmiştir; doğrulanmış hata, puan veya hafıza sonucu değildir.',
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            Text(
              'Referans: ${widget.reference.id} • ${widget.reference.contentVersion}',
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: const Key('practice_start'),
              initialValue: _start,
              decoration: const InputDecoration(labelText: 'Başlangıç sesi'),
              items: [
                for (var i = 0; i < count; i++)
                  DropdownMenuItem(value: i, child: Text('${i + 1}. ses')),
              ],
              onChanged: enabled
                  ? (value) => setState(() {
                      _start = value!;
                      if (_end <= _start) _end = _start + 1;
                    })
                  : null,
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: ValueKey('practice_end_$_start'),
              initialValue: _end,
              decoration: const InputDecoration(
                labelText: 'Bitiş sesi (dahil)',
              ),
              items: [
                for (var i = _start + 1; i <= count; i++)
                  DropdownMenuItem(value: i, child: Text('$i. ses')),
              ],
              onChanged: enabled
                  ? (value) => setState(() => _end = value!)
                  : null,
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: const Key('practice_repetitions'),
              initialValue: _repetitions,
              decoration: const InputDecoration(labelText: 'Dinleme tekrarı'),
              items: [
                for (
                  var i = 1;
                  i <= DiagnosticMelodyPractice.maxRepetitions;
                  i++
                )
                  DropdownMenuItem(value: i, child: Text('$i tekrar')),
              ],
              onChanged: enabled
                  ? (value) => setState(() => _repetitions = value!)
                  : null,
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            DataLabel('Seçim: ${_start + 1}–$_end. ses • $_repetitions tekrar'),
            for (var i = _start; i < _end; i++)
              Text(
                '${i + 1}. ses: ${widget.reference.frequenciesHz[i].toStringAsFixed(2)} Hz',
              ),
            const SizedBox(height: HarmoniaSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                _exiting
                    ? (_exitError ?? 'Ses kaynağı kapatılıyor…')
                    : _focusFailed
                    ? 'Ses çıkışı izlemesi hazırlanamadı. Kapatıp yeniden deneyebilirsin.'
                    : !_focusReady
                    ? 'Ses çıkışı izlemesi hazırlanıyor…'
                    : _status(playback),
                key: const Key('practice_status'),
              ),
            ),
          ],
          bottom: [
            ChunkyButton(
              key: const Key('practice_play'),
              label: 'Seçili bölümü dinle',
              icon: Icons.hearing,
              onPressed: enabled
                  ? () => unawaited(
                      playback.play(
                        DiagnosticMelodyPractice(
                          reference: widget.reference,
                          startIndex: _start,
                          endIndexExclusive: _end,
                          repetitions: _repetitions,
                        ),
                      ),
                    )
                  : null,
            ),
            if (!_exiting &&
                (playback.phase == MelodyPracticePhase.loading ||
                    playback.phase == MelodyPracticePhase.playing ||
                    playback.phase == MelodyPracticePhase.stopping)) ...[
              const SizedBox(height: HarmoniaSpacing.sm),
              ChunkyButton(
                key: const Key('practice_stop'),
                label: 'Durdur',
                tone: ChunkyTone.neutral,
                onPressed: playback.phase == MelodyPracticePhase.stopping
                    ? null
                    : playback.stop,
              ),
            ],
            const SizedBox(height: HarmoniaSpacing.md),
            ExpansionTile(
              key: Key('practice_help'),
              tilePadding: EdgeInsets.zero,
              title: Text('Bu çalışma ne yapar?'),
              children: [
                Text(
                  widget.initialPractice == null
                      ? 'Ardışık sesleri kendin seçersin; uygulama hatalı bölümü belirlemez. Orijinal frekans, oktav ve sıra korunur. Sabit sentetik tempo, 1–3 tekrar; piyano kaydı değildir. Arka plana geçiş, ses odağı veya çıkış değişiminde durur; kendiliğinden devam etmez. Çıkışta oynatıcı kapanmadan önceki ekrana dönülmez.'
                      : 'Başlangıç aralığı deneysel aday karşılaştırmasındaki ilk farklı referans çevresidir; insan sesi doğrulaması olmadığı için hata sayılmaz. Seçimi değiştirebilirsin. Orijinal frekans, oktav ve sıra korunur; çalışma puansızdır.',
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

String _status(MelodyPracticePlayback playback) {
  if (playback.failure == MelodyPracticeFailure.cleanupFailed) {
    return 'Ses kaynağının durduğu doğrulanamadı. Kapatıp uygulamayı yeniden aç.';
  }
  if (playback.failure != null) {
    return 'Dinleme başlatılamadı veya kesildi. Yeniden deneyebilirsin.';
  }
  return switch (playback.phase) {
    MelodyPracticePhase.idle => 'Hazır. Mikrofon kapalı; otomatik oynatma yok.',
    MelodyPracticePhase.loading => 'Seçili bölüm hazırlanıyor…',
    MelodyPracticePhase.playing => 'Seçili bölüm çalıyor. Mikrofon kapalı.',
    MelodyPracticePhase.stopping => 'Oynatma durduruluyor…',
    MelodyPracticePhase.failed => 'Dinleme tamamlanamadı.',
    MelodyPracticePhase.closed => 'Oynatıcı kapalı.',
  };
}
