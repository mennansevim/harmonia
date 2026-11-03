import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/melody_practice.dart';
import '../../application/melody_practice_playback.dart';
import '../../application/melody_session.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../../infrastructure/audio/synthetic_melody_backend.dart';
import '../common/ui/resonia_ui.dart';
import '../../domain/lang.dart';

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
          () => _exitError = tr(
            'Ses kaynağının kapandığı doğrulanamadı. Uygulamayı kapatıp yeniden aç.',
            'Could not confirm the audio source closed. Close and reopen the app.',
          ),
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
          counter: tr('Puansız', 'Unscored'),
          closeLabel: tr('Bölüm dinlemeyi kapat', 'Close segment listening'),
          top: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(
                widget.initialPractice == null
                    ? tr(
                        'Sentetik · elle seçilen bölüm',
                        'Synthetic · hand-picked segment',
                      )
                    : tr(
                        'Sentetik · deneysel aday bölüm',
                        'Synthetic · experimental candidate segment',
                      ),
              ),
            ),
            const SizedBox(height: ResoniaSpacing.md),
            Text(
              tr('Ezginin bir bölümünü dinle', 'Hear part of the melody'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              widget.initialPractice == null
                  ? tr(
                      'Mikrofon açılmaz. Bu seçim bir hata tespiti veya sınav değildir; dinleme geçmişe, puana ya da beceri ilerlemesine eklenmez.',
                      'The microphone stays off. This choice is not mistake detection or an exam; listening is not added to history, scores or skill progress.',
                    )
                  : tr(
                      'Mikrofon açılmaz. Başlangıç seçimi yalnız deneysel frekans adaylarından türetilmiştir; doğrulanmış hata, puan veya hafıza sonucu değildir.',
                      'The microphone stays off. The starting choice comes only from experimental frequency candidates; it is not a validated mistake, score or memory result.',
                    ),
            ),
            const SizedBox(height: ResoniaSpacing.md),
            Text(
              tr(
                'Referans: ${widget.reference.id} • ${widget.reference.contentVersion}',
                'Reference: ${widget.reference.id} • ${widget.reference.contentVersion}',
              ),
            ),
            const SizedBox(height: ResoniaSpacing.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: const Key('practice_start'),
              initialValue: _start,
              decoration: InputDecoration(
                labelText: tr('Başlangıç sesi', 'First note'),
              ),
              items: [
                for (var i = 0; i < count; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(tr('${i + 1}. ses', 'Note ${i + 1}')),
                  ),
              ],
              onChanged: enabled
                  ? (value) => setState(() {
                      _start = value!;
                      if (_end <= _start) _end = _start + 1;
                    })
                  : null,
            ),
            const SizedBox(height: ResoniaSpacing.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: ValueKey('practice_end_$_start'),
              initialValue: _end,
              decoration: InputDecoration(
                labelText: tr('Bitiş sesi (dahil)', 'Last note (included)'),
              ),
              items: [
                for (var i = _start + 1; i <= count; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(tr('$i. ses', 'Note $i')),
                  ),
              ],
              onChanged: enabled
                  ? (value) => setState(() => _end = value!)
                  : null,
            ),
            const SizedBox(height: ResoniaSpacing.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: const Key('practice_repetitions'),
              initialValue: _repetitions,
              decoration: InputDecoration(
                labelText: tr('Dinleme tekrarı', 'Repeats'),
              ),
              items: [
                for (
                  var i = 1;
                  i <= DiagnosticMelodyPractice.maxRepetitions;
                  i++
                )
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      tr('$i tekrar', i == 1 ? '1 time' : '$i times'),
                    ),
                  ),
              ],
              onChanged: enabled
                  ? (value) => setState(() => _repetitions = value!)
                  : null,
            ),
            const SizedBox(height: ResoniaSpacing.md),
            DataLabel(
              tr(
                'Seçim: ${_start + 1}–$_end. ses • $_repetitions tekrar',
                'Selection: notes ${_start + 1}–$_end • $_repetitions times',
              ),
            ),
            for (var i = _start; i < _end; i++)
              Text(
                tr(
                  '${i + 1}. ses: ${widget.reference.frequenciesHz[i].toStringAsFixed(2)} Hz',
                  'Note ${i + 1}: ${widget.reference.frequenciesHz[i].toStringAsFixed(2)} Hz',
                ),
              ),
            const SizedBox(height: ResoniaSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                _exiting
                    ? (_exitError ??
                          tr(
                            'Ses kaynağı kapatılıyor…',
                            'Closing the audio source…',
                          ))
                    : _focusFailed
                    ? tr(
                        'Ses çıkışı izlemesi hazırlanamadı. Kapatıp yeniden deneyebilirsin.',
                        'Audio output monitoring could not be prepared. Close and try again.',
                      )
                    : !_focusReady
                    ? tr(
                        'Ses çıkışı izlemesi hazırlanıyor…',
                        'Preparing audio output monitoring…',
                      )
                    : _status(playback),
                key: const Key('practice_status'),
              ),
            ),
          ],
          bottom: [
            ChunkyButton(
              key: const Key('practice_play'),
              label: tr('Seçili bölümü dinle', 'Hear the selected segment'),
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
              const SizedBox(height: ResoniaSpacing.sm),
              ChunkyButton(
                key: const Key('practice_stop'),
                label: tr('Durdur', 'Stop'),
                tone: ChunkyTone.neutral,
                onPressed: playback.phase == MelodyPracticePhase.stopping
                    ? null
                    : playback.stop,
              ),
            ],
            const SizedBox(height: ResoniaSpacing.md),
            ExpansionTile(
              key: Key('practice_help'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                tr('Bu çalışma ne yapar?', 'What does this exercise do?'),
              ),
              children: [
                Text(
                  widget.initialPractice == null
                      ? tr(
                          'Ardışık sesleri kendin seçersin; uygulama hatalı bölümü belirlemez. Orijinal frekans, oktav ve sıra korunur. Sabit sentetik tempo, 1–3 tekrar; piyano kaydı değildir. Arka plana geçiş, ses odağı veya çıkış değişiminde durur; kendiliğinden devam etmez. Çıkışta oynatıcı kapanmadan önceki ekrana dönülmez.',
                          'You pick consecutive notes yourself; the app does not find the wrong part. The original frequencies, octave and order are kept. Fixed synthetic tempo, 1–3 repeats; not a piano recording. It stops on backgrounding, audio focus or output changes and does not resume by itself. On exit you return to the previous screen only after the player closes.',
                        )
                      : tr(
                          'Başlangıç aralığı deneysel aday karşılaştırmasındaki ilk farklı referans çevresidir; insan sesi doğrulaması olmadığı için hata sayılmaz. Seçimi değiştirebilirsin. Orijinal frekans, oktav ve sıra korunur; çalışma puansızdır.',
                          'The starting range is around the first differing reference in the experimental candidate comparison; with no human voice validation it is not counted as a mistake. You can change the selection. The original frequencies, octave and order are kept; the exercise is unscored.',
                        ),
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
    return tr(
      'Ses kaynağının durduğu doğrulanamadı. Kapatıp uygulamayı yeniden aç.',
      'Could not confirm the audio source stopped. Close and reopen the app.',
    );
  }
  if (playback.failure != null) {
    return tr(
      'Dinleme başlatılamadı veya kesildi. Yeniden deneyebilirsin.',
      'Listening could not start or was interrupted. You can try again.',
    );
  }
  return switch (playback.phase) {
    MelodyPracticePhase.idle => tr(
      'Hazır. Mikrofon kapalı; otomatik oynatma yok.',
      'Ready. Microphone off; no autoplay.',
    ),
    MelodyPracticePhase.loading => tr(
      'Seçili bölüm hazırlanıyor…',
      'Preparing the selected segment…',
    ),
    MelodyPracticePhase.playing => tr(
      'Seçili bölüm çalıyor. Mikrofon kapalı.',
      'Playing the selected segment. Microphone off.',
    ),
    MelodyPracticePhase.stopping => tr(
      'Oynatma durduruluyor…',
      'Stopping playback…',
    ),
    MelodyPracticePhase.failed => tr(
      'Dinleme tamamlanamadı.',
      'Listening could not finish.',
    ),
    MelodyPracticePhase.closed => tr('Oynatıcı kapalı.', 'Player closed.'),
  };
}
