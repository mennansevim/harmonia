import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../app/scope.dart';
import '../domain/music.dart';
import '../ui/kit.dart';

/// One sung take reduced to a single representative pitch, or a reason why
/// no pitch is reported. Never a score.
class RangeTake {
  const RangeTake.pitch(double this.hz) : failure = null;
  const RangeTake.failed(String this.failure) : hz = null;
  final double? hz;
  final String? failure;
}

abstract interface class RangeProbe {
  Future<bool> requestPermission();
  Stream<double> get levelDb;
  Future<RangeTake> record(Duration duration);
  Future<void> close();
}

/// Quality gate on the shared Resonia pitch core. Thresholds are draft
/// hypotheses (no human benchmark yet): a take must be mostly periodic and
/// steady, otherwise it is reported as unmeasured, never guessed.
RangeTake evaluateRangeEvidence(RecordingPitchEvidence evidence) {
  if (evidence.status == RecordingPitchStatus.invalidInput ||
      evidence.status == RecordingPitchStatus.insufficientData) {
    return const RangeTake.failed('Kayıt çok kısa ya da okunamadı.');
  }
  if (evidence.status != RecordingPitchStatus.periodicSignalObserved ||
      evidence.representativeFrequencyHz == null) {
    return const RangeTake.failed(
      'Net bir ses duyulamadı. Biraz daha yüksek sesle, sabit tut.',
    );
  }
  final ratio = evidence.periodicFrameRatio ?? 0;
  if (ratio < 0.35) {
    return const RangeTake.failed(
      'Sesin kaydın çoğunda duyulmadı. Üç saniye boyunca tut.',
    );
  }
  final spread = evidence.pitchDispersionCents;
  if (spread == null || spread > 80) {
    return const RangeTake.failed(
      'Ses fazla dalgalandı. Tek bir notada sabit kal.',
    );
  }
  return RangeTake.pitch(evidence.representativeFrequencyHz!);
}

class MicRangeProbe implements RangeProbe {
  final _backend = PluginAudioLabBackend();
  final _worker = IsolateRecordingPitchWorker();

  @override
  Stream<double> get levelDb => _backend.inputLevelDb;

  @override
  Future<bool> requestPermission() => _backend.requestMicrophonePermission();

  @override
  Future<RangeTake> record(Duration duration) async {
    await _backend.startCapture();
    await Future<void>.delayed(duration);
    await _backend.stopCapture();
    final CapturedAudioSamples samples = await _backend.readRecording();
    try {
      final evidence = await _worker.analyze(
        samples: samples.samples,
        sampleRateHz: samples.sampleRateHz,
        source: samples.source,
      );
      return evaluateRangeEvidence(evidence);
    } finally {
      await _backend.discardCapture();
    }
  }

  @override
  Future<void> close() => _backend.close();
}

VoicePart? suggestPart(int low, int high) {
  if (high - low < 5) return null;
  VoicePart? best;
  var bestScore = -1.0;
  for (final p in VoicePart.values) {
    final overlap =
        (high < p.high ? high : p.high) - (low > p.low ? low : p.low);
    final centre = ((low + high) / 2 - (p.low + p.high) / 2).abs();
    final score = overlap - centre * 0.1;
    if (overlap > 0 && score > bestScore) {
      bestScore = score;
      best = p;
    }
  }
  return best;
}

enum _Stage { intro, ready, recording, analyzing, take, result, denied }

class RangeTestScreen extends StatefulWidget {
  const RangeTestScreen({super.key, this.probe});
  final RangeProbe? probe;
  @override
  State<RangeTestScreen> createState() => _RangeTestScreenState();
}

class _RangeTestScreenState extends State<RangeTestScreen> {
  RangeProbe? _probe;
  _Stage _stage = _Stage.intro;
  bool _high = false;
  RangeTake? _lastTake;
  int? _lowMidi;
  int? _highMidi;
  double _level = -60;
  StreamSubscription<double>? _levels;
  int _secondsLeft = 3;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _levels?.cancel();
    _probe?.close();
    super.dispose();
  }

  RangeProbe _ensureProbe() => _probe ??= widget.probe ?? MicRangeProbe();

  Future<void> _start() async {
    final probe = _ensureProbe();
    bool granted;
    try {
      granted = await probe.requestPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    if (!granted) {
      setState(() => _stage = _Stage.denied);
      return;
    }
    _levels ??= probe.levelDb.listen((db) {
      if (mounted) setState(() => _level = db);
    });
    setState(() => _stage = _Stage.ready);
  }

  Future<void> _record() async {
    setState(() {
      _stage = _Stage.recording;
      _secondsLeft = 3;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 3));
    });
    RangeTake take;
    try {
      final recording = _ensureProbe().record(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _stage = _Stage.analyzing);
      take = await recording;
    } catch (_) {
      take = const RangeTake.failed(
        'Kayıt başlatılamadı. Mikrofonu başka bir uygulama kullanıyor olabilir.',
      );
    }
    _tick?.cancel();
    if (!mounted) return;
    setState(() {
      _lastTake = take;
      _stage = _Stage.take;
    });
  }

  void _accept() {
    final hz = _lastTake?.hz;
    if (hz == null) return;
    final midi = hzToMidi(hz).round();
    if (!_high) {
      setState(() {
        _lowMidi = midi;
        _high = true;
        _lastTake = null;
        _stage = _Stage.ready;
      });
      return;
    }
    setState(() {
      _highMidi = midi;
      _stage = _Stage.result;
    });
    final store = TrainerScope.of(context).store;
    if (_lowMidi! < midi) {
      store.koroRange = '$_lowMidi-$midi';
      store.save();
    }
  }

  void _restart() => setState(() {
    _high = false;
    _lowMidi = null;
    _highMidi = null;
    _lastTake = null;
    _stage = _Stage.ready;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          TopBar(
            title: 'Ses aralığı testi',
            progress: switch (_stage) {
              _Stage.intro || _Stage.denied => 0.05,
              _Stage.result => 1,
              _ => _high ? 0.66 : 0.33,
            },
            progressColor: TC.koro,
          ),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _body() {
    final store = TrainerScope.of(context).store;
    final notation = store.notation;
    switch (_stage) {
      case _Stage.intro:
        return _Page(
          emoji: '🎤',
          title: 'Ses aralığını bul',
          body:
              'Önce en pes, sonra en tiz rahat sesini "aa" ile 3 saniye tut. Resonia\'nın ses tespit çekirdeği her kaydın temsilî perdesini ölçer.\n\nKayıtlar cihazdan çıkmaz ve analizden sonra silinir. Sonuç deneyseldir; ses tipini bir eğitmen ya da koro şefi belirler.',
          button: 'Başla',
          onPressed: _start,
        );
      case _Stage.denied:
        return _Page(
          emoji: '🔒',
          title: 'Mikrofon izni gerekli',
          body:
              'Ses aralığını ölçmek için mikrofon izni ver. iOS Ayarlar > Resonia > Mikrofon\'dan açabilirsin.',
          button: 'Tekrar dene',
          onPressed: _start,
        );
      case _Stage.ready:
        return _Page(
          emoji: _high ? '⬆️' : '⬇️',
          title: _high ? 'En tiz rahat sesin' : 'En pes rahat sesin',
          body: _high
              ? 'Zorlamadan çıkabildiğin en tiz notayı "aa" ile 3 saniye tut.'
              : 'Hırıltıya kaçmadan çıkabildiğin en pes notayı "aa" ile 3 saniye tut.',
          button: 'Kaydı başlat',
          onPressed: _record,
          footer: _LevelBar(db: _level),
        );
      case _Stage.recording:
        return _Page(
          emoji: '🔴',
          title: 'Dinliyorum… $_secondsLeft',
          body: 'Sesini sabit tut.',
          footer: _LevelBar(db: _level),
        );
      case _Stage.analyzing:
        return const _Page(
          emoji: '⏳',
          title: 'Ölçülüyor…',
          body: 'Kayıt cihazda çözümleniyor.',
        );
      case _Stage.take:
        final take = _lastTake!;
        if (take.hz == null) {
          return _Page(
            emoji: '🤔',
            title: 'Ölçülemedi',
            body: '${take.failure}\nBu deneme sonuç sayılmadı.',
            button: 'Tekrar kaydet',
            onPressed: _record,
          );
        }
        final midi = hzToMidi(take.hz!).round();
        return _Page(
          emoji: '🎯',
          title: PitchClass.midiName(midi, notation),
          body:
              '${take.hz!.toStringAsFixed(1)} Hz civarı. Doğru duyuluyor mu? Değilse tekrar kaydet.',
          button: _high ? 'Sonucu gör' : 'Tize geç',
          onPressed: _accept,
          secondary: 'Tekrar kaydet',
          onSecondary: _record,
        );
      case _Stage.result:
        final low = _lowMidi!;
        final high = _highMidi!;
        if (high <= low) {
          return _Page(
            emoji: '↕️',
            title: 'Sonuç tutarsız',
            body:
                'Tiz kayıt pes kayıttan daha pes ölçüldü (oktav karışmış olabilir). Bu sonuç kaydedilmedi; testi tekrarla.',
            button: 'Baştan',
            onPressed: _restart,
          );
        }
        final part = suggestPart(low, high);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: Text('🎶', style: TextStyle(fontSize: 56))),
            const SizedBox(height: 8),
            Text(
              '${PitchClass.midiName(low, notation)} – ${PitchClass.midiName(high, notation)}',
              textAlign: TextAlign.center,
              style: TT.h1,
            ),
            const SizedBox(height: 4),
            Text(
              '${high - low} yarım ses · yaklaşık ${((high - low) / 12).toStringAsFixed(1)} oktav',
              textAlign: TextAlign.center,
              style: TT.body,
            ),
            const SizedBox(height: 20),
            _RangeChart(low: low, high: high, notation: notation),
            const SizedBox(height: 20),
            AppCard(
              color: const Color(0xFFEEEBFF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OLASI PARTİ · TASLAK', style: TT.caps),
                  const SizedBox(height: 4),
                  Text(part?.title ?? 'Belirsiz', style: TT.h3),
                  const SizedBox(height: 4),
                  const Text(
                    'Yalnız ölçülen iki uç notaya dayanır. Ses rengi, geçiş bölgeleri ve rahat tessitura ölçülmedi; ses tipi kararını eğitmen ya da koro şefi verir.',
                    style: TT.small,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (part != null && store.voicePart != part.name) ...[
              OutlinedButton.icon(
                key: const Key('range_save_part'),
                onPressed: () => setState(() {
                  store.voicePart = part.name;
                  store.save();
                }),
                icon: const Icon(Icons.how_to_reg_outlined),
                label: Text('${part.title} aralığında çalış'),
              ),
              const SizedBox(height: 12),
            ],
            BigButton(
              label: 'Bitti',
              color: TC.koro,
              onPressed: () => Navigator.pop(context),
            ),
            TextLink('Testi tekrarla', onTap: _restart),
          ],
        );
    }
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.emoji,
    required this.title,
    required this.body,
    this.button,
    this.onPressed,
    this.footer,
    this.secondary,
    this.onSecondary,
  });
  final String emoji;
  final String title;
  final String body;
  final String? button;
  final VoidCallback? onPressed;
  final Widget? footer;
  final String? secondary;
  final VoidCallback? onSecondary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Text(
                  title,
                  key: const Key('range_title'),
                  textAlign: TextAlign.center,
                  style: TT.h2,
                ),
              ),
              const SizedBox(height: 10),
              Text(body, textAlign: TextAlign.center, style: TT.body),
              if (footer != null) ...[const SizedBox(height: 26), footer!],
            ],
          ),
        ),
        if (button != null)
          BigButton(label: button!, color: TC.koro, onPressed: onPressed),
        if (secondary != null) TextLink(secondary!, onTap: onSecondary!),
      ],
    ),
  );
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.db});
  final double db;
  @override
  Widget build(BuildContext context) {
    final v = ((db + 60) / 60).clamp(0.0, 1.0);
    return Column(
      children: [
        const Text('GİRİŞ SEVİYESİ', style: TT.caps),
        const SizedBox(height: 8),
        ProgressBar(value: v, color: v > 0.92 ? TC.red : TC.koro, height: 10),
        const SizedBox(height: 6),
        const Text(
          'Yalnız gösterge; ses kalitesi ölçümü değildir.',
          style: TT.small,
        ),
      ],
    );
  }
}

class _RangeChart extends StatelessWidget {
  const _RangeChart({
    required this.low,
    required this.high,
    required this.notation,
  });
  final int low;
  final int high;
  final NoteNotation notation;
  @override
  Widget build(BuildContext context) {
    const min = 36;
    const max = 86;
    double x(int midi, double w) => w * (midi - min) / (max - min);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Column(
          children: [
            for (final p in VoicePart.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 64, child: Text(p.name, style: TT.small)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c2) => SizedBox(
                          height: 14,
                          child: Stack(
                            children: [
                              Positioned(
                                left: x(p.low, c2.maxWidth),
                                width:
                                    x(p.high, c2.maxWidth) -
                                    x(p.low, c2.maxWidth),
                                top: 3,
                                height: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4E3EF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                const SizedBox(width: 64, child: Text('Sen', style: TT.title)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c2) => SizedBox(
                      height: 18,
                      child: Stack(
                        children: [
                          Positioned(
                            left: x(low.clamp(min, max), c2.maxWidth),
                            width:
                                (x(high.clamp(min, max), c2.maxWidth) -
                                        x(low.clamp(min, max), c2.maxWidth))
                                    .clamp(4.0, w),
                            top: 2,
                            height: 14,
                            child: Container(
                              decoration: BoxDecoration(
                                color: TC.koro,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
