import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../ui/kit.dart';

class _Sample {
  const _Sample({
    required this.kind,
    required this.title,
    required this.tapLabel,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.sound,
    required this.success,
    required this.hintTitle,
    required this.hintBody,
  });
  final TrainerKind kind;
  final String title;
  final String tapLabel;
  final String prompt;
  final List<String> options;
  final String answer;
  final SoundSpec Function(SoundFactory) sound;
  final String success;
  final String hintTitle;
  final String hintBody;
}

List<_Sample> _samples(NoteNotation n) => [
  _Sample(
    kind: TrainerKind.pitch,
    title: 'Örnek: Nota',
    tapLabel: 'NOTAYI DİNLEMEK İÇİN DOKUN',
    prompt: 'Notayı dinle ve tanı',
    options: [
      PitchClass.name(0, n),
      PitchClass.name(2, n),
      PitchClass.name(4, n),
    ],
    answer: PitchClass.name(0, n),
    sound: (f) => SoundSpec([
      const ToneEvent(0, 0.5, [60, 64, 67]),
      const ToneEvent(0.6, 0.5, [59, 62, 67]),
      const ToneEvent(1.2, 0.8, [60, 64, 67]),
      const ToneEvent(2.3, 1.2, [72]),
    ]),
    success: 'Evde oturan o yerleşik nota ${PitchClass.name(0, n)}.',
    hintTitle: 'Bu ${PitchClass.name(0, n)}',
    hintBody:
        'Kadansın sonunda kulağın "eve döndüm" der. O ev notası ${PitchClass.name(0, n)}. Tekrar dinle.',
  ),
  _Sample(
    kind: TrainerKind.interval,
    title: 'Örnek: Aralık',
    tapLabel: 'ARALIĞI DİNLEMEK İÇİN DOKUN',
    prompt: 'Dinle ve aralığı tanı',
    options: const ['m3', 'M3', 'P5'],
    answer: 'M3',
    sound: (f) => f.interval('M3', rootMidi: 60),
    success: 'O parlak "Oh when" sıçraması bir büyük 3\'lü.',
    hintTitle: 'Bu bir büyük 3\'lü',
    hintBody:
        '"When the Saints" şarkısındaki "Oh when" sıçraması. Tekrar dinle.',
  ),
  _Sample(
    kind: TrainerKind.chord,
    title: 'Örnek: Akor',
    tapLabel: 'AKORU DİNLEMEK İÇİN DOKUN',
    prompt: 'Akoru dinle ve niteliğini tanı',
    options: const ['Maj', 'Min', 'Dim'],
    answer: 'Min',
    sound: (f) => f.chord('min', rootMidi: 57),
    success: 'Bu hüzünlü renk minör akor.',
    hintTitle: 'Bu bir minör akor',
    hintBody: 'Majörden daha karanlık ve hüzünlü. Orta ses yarım ses pesleşir.',
  ),
  _Sample(
    kind: TrainerKind.scale,
    title: 'Örnek: Dizi',
    tapLabel: 'DİZİYİ DİNLEMEK İÇİN DOKUN',
    prompt: 'Diziyi dinle ve tanı',
    options: const ['Majör', 'Doğal minör'],
    answer: 'Majör',
    sound: (f) => f.scale('major', root: 60),
    success: 'Parlak do-re-mi merdiveni: majör.',
    hintTitle: 'Bu majör dizi',
    hintBody: 'Parlak, mutlu, çözülmüş. "Do re mi" sesi.',
  ),
  _Sample(
    kind: TrainerKind.progression,
    title: 'Örnek: Yürüyüş',
    tapLabel: 'YÜRÜYÜŞÜ DİNLEMEK İÇİN DOKUN',
    prompt: 'Akor yürüyüşünü tanı',
    options: const ['I-IV-V-I', 'I-V-vi-IV'],
    answer: 'I-IV-V-I',
    sound: (f) => f.progression('I-IV-V-I', keyRoot: 48),
    success: 'Eve dönen klasik kadans: I-IV-V-I.',
    hintTitle: 'Bu I-IV-V-I',
    hintBody: 'Son akorda eve döndüğünü hissedersin. Tekrar dinle.',
  ),
];

/// "Try the training": five one-question samples. Results only steer the
/// starting focus; they are not stored as practice evidence.
class OnboardingSamples extends StatefulWidget {
  const OnboardingSamples({
    super.key,
    required this.onDone,
    required this.onBack,
  });
  final ValueChanged<Map<String, bool>> onDone;
  final VoidCallback onBack;
  @override
  State<OnboardingSamples> createState() => _OnboardingSamplesState();
}

class _OnboardingSamplesState extends State<OnboardingSamples> {
  late final List<_Sample> _list = _samples(
    TrainerScope.of(context).store.notation,
  );
  final _factory = SoundFactory(math.Random());
  final _results = <String, bool>{};
  int _i = 0;
  bool? _frame;
  String? _picked;
  String? _message;
  bool _first = true;
  bool _heard = false;

  _Sample get _s => _list[_i];

  void _play() {
    setState(() => _heard = true);
    TrainerScope.of(context).audio.play(_s.sound(_factory));
  }

  void _advance() {
    if (_i == _list.length - 1) {
      widget.onDone(_results);
      return;
    }
    setState(() {
      _i++;
      _frame = null;
      _picked = null;
      _message = null;
      _first = true;
      _heard = false;
    });
  }

  Future<void> _pick(String option) async {
    if (_frame == true) return;
    if (option == _s.answer) {
      _results.putIfAbsent(_s.kind.id, () => _first);
      setState(() {
        _frame = true;
        _picked = option;
        _message = _s.success;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) _advance();
      return;
    }
    _results.putIfAbsent(_s.kind.id, () => false);
    final firstMiss = _first;
    setState(() {
      _first = false;
      _frame = false;
      _picked = option;
      _message = 'Tam değil! Tekrar dene';
    });
    if (!firstMiss) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final retry = await showTrainerSheet<bool>(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '💡',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 6),
          Text(_s.hintTitle, textAlign: TextAlign.center, style: TT.h3),
          const SizedBox(height: 6),
          Text(_s.hintBody, textAlign: TextAlign.center, style: TT.small),
          const SizedBox(height: 16),
          BigButton(
            label: 'Tekrar dene',
            color: TC.blue,
            onPressed: () => Navigator.pop(context, true),
          ),
          TextLink('Bunu atla', onTap: () => Navigator.pop(context, false)),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == false) {
      _advance();
    } else {
      setState(() {
        _frame = null;
        _picked = null;
        _message = null;
      });
      _play();
    }
  }

  Future<void> _skip() async {
    final choice = await showTrainerSheet<String>(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🌱',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 6),
          const Text('Dert etme', textAlign: TextAlign.center, style: TT.h3),
          const SizedBox(height: 6),
          const Text(
            'Bunların her birini tam programda düzgünce çalışacaksın. Sadece bu soruyu ya da örneklerin geri kalanını atlayabilirsin.',
            textAlign: TextAlign.center,
            style: TT.small,
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'Kalanları atla',
            color: TC.blue,
            onPressed: () => Navigator.pop(context, 'rest'),
          ),
          TextLink(
            'Bu soruyu atla',
            onTap: () => Navigator.pop(context, 'one'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    _results.putIfAbsent(_s.kind.id, () => false);
    if (choice == 'rest') {
      for (final s in _list) {
        _results.putIfAbsent(s.kind.id, () => false);
      }
      widget.onDone(_results);
    } else {
      _advance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = trainerColor(_s.kind);
    final audio = TrainerScope.of(context).audio;
    return FeedbackFrame(
      state: _frame,
      child: Column(
        children: [
          TopBar(title: _s.title, onBack: widget.onBack),
          Text(_s.tapLabel, style: TT.caps),
          Expanded(
            child: Center(
              child: _frame == true
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TT.title,
                      ),
                    )
                  : WaveView(
                      key: Key('sample_wave_$_i'),
                      playing: audio.playing,
                      color: color,
                      height: 220,
                      label: _heard ? 'TEKRAR' : 'DİNLE',
                      onTap: _play,
                    ),
            ),
          ),
          Text(_message ?? _s.prompt, style: TT.title),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final o in _s.options)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
                        key: Key('sample_opt_$o'),
                        onTap: () => _pick(o),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _picked == o
                                ? (_frame == true ? TC.green : TC.red)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _picked == o
                                  ? Colors.transparent
                                  : TC.line,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            o,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _picked == o ? Colors.white : TC.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            key: const Key('sample_skip'),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFEFF2F7),
              foregroundColor: TC.body,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: _skip,
            child: const Text('Bilmiyor musun? Atla'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
