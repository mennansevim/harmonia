import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/trainers.dart';
import '../ui/kit.dart';

/// Builds a close-voiced choir-like chord of [voices] notes (2–4) inside
/// SATB-friendly registers; notes are distinct and at least a 3rd apart.
List<int> choirVoicing(int voices, math.Random random) {
  const steps = [3, 4, 5, 7];
  final bass = 48 + random.nextInt(8);
  final notes = [bass];
  while (notes.length < voices) {
    notes.add(notes.last + steps[random.nextInt(steps.length)]);
  }
  return notes;
}

/// "How many voices?" — perception drill for 2/3/4-part listening. Uses
/// synthesized tones; it is not the recorded-piano repeat exercise.
class VoiceCountScreen extends StatefulWidget {
  const VoiceCountScreen({super.key, this.random, this.length = 10});
  final math.Random? random;
  final int length;
  @override
  State<VoiceCountScreen> createState() => _VoiceCountScreenState();
}

class _VoiceCountScreenState extends State<VoiceCountScreen> {
  late final math.Random _random = widget.random ?? math.Random();
  int _index = 0;
  int _correct = 0;
  late int _answer;
  late List<int> _notes;
  bool? _frame;
  int? _picked;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _next(play: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _next({bool play = true}) {
    _answer = 2 + _random.nextInt(3);
    _notes = choirVoicing(_answer, _random);
    _frame = null;
    _picked = null;
    if (play) _play();
  }

  void _play() => TrainerScope.of(
    context,
  ).audio.play(SoundSpec([ToneEvent(0, 2.0, _notes)]));

  void _pick(int n) {
    if (_picked != null) return;
    final ok = n == _answer;
    setState(() {
      _picked = n;
      _frame = ok;
      if (ok) _correct++;
    });
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (_index == widget.length - 1) {
        TrainerScope.of(context).store.recordSession();
        setState(() => _done = true);
        return;
      }
      setState(() {
        _index++;
        _next();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎼', style: TextStyle(fontSize: 60)),
                      const SizedBox(height: 10),
                      Text('$_correct / ${widget.length}', style: TT.h1),
                      const SizedBox(height: 6),
                      const Text(
                        'Ses sayısını doğru duydun. Çok sesli koro kayıtları eklendiğinde her sesi tek tek tekrar etme çalışması açılacak.',
                        textAlign: TextAlign.center,
                        style: TT.body,
                      ),
                    ],
                  ),
                ),
                BigButton(
                  label: 'Bitti',
                  color: TC.koro,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: FeedbackFrame(
        state: _frame,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: 'Kaç ses duyuyorsun?',
                progress: (_index + (_picked == null ? 0 : 1)) / widget.length,
                progressColor: TC.koro,
                counter: '${_index + 1} / ${widget.length}',
                shadow: true,
              ),
              const Spacer(),
              WaveView(
                playing: TrainerScope.of(context).audio.playing,
                color: TC.koro,
                label: 'AKORU TEKRARLA',
                onTap: _picked == null ? _play : null,
                height: 200,
              ),
              const Spacer(),
              Text(
                _picked == null
                    ? 'Aynı anda kaç ses çalıyor?'
                    : _frame == true
                    ? 'Tam isabet!'
                    : 'Doğrusu $_answer ses',
                style: TT.title,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  children: [
                    for (final n in const [2, 3, 4])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: AppCard(
                            key: Key('voices_$n'),
                            border: _picked == null
                                ? TC.line
                                : n == _answer
                                ? TC.green
                                : (n == _picked ? TC.red : TC.line),
                            onTap: _picked == null ? () => _pick(n) : null,
                            child: Column(
                              children: [
                                Text('$n', style: TT.h1),
                                const Text('ses', style: TT.small),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
