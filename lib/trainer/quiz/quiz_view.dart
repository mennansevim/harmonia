import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../ui/kit.dart';
import 'quiz.dart';
import '../../domain/lang.dart';

enum _Phase { answering, review, done }

/// Resonia question runner: one listening disc, only the question's own
/// options, a per-question evidence strip and an inline comparison panel
/// after a miss. First attempts are scored; retries only teach.
class QuizView extends StatefulWidget {
  const QuizView({
    super.key,
    required this.title,
    required this.questions,
    required this.onFinished,
    this.color,
    this.record = true,
    this.timeLimitSeconds,
    this.allowRetry = true,
    this.showCounter = true,
    this.onExit,
    this.forceHints = false,
  });

  final String title;
  final List<QuizQuestion> questions;
  final ValueChanged<QuizSummary> onFinished;
  final Color? color;

  /// Writes answers into the local practice evidence.
  final bool record;
  final int? timeLimitSeconds;
  final bool allowRetry;
  final bool showCounter;
  final VoidCallback? onExit;

  /// Lessons always explain a miss, regardless of the hints preference.
  final bool forceHints;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _index = 0;
  _Phase _phase = _Phase.answering;
  String _status = '';
  final _records = <AnswerRecord>[];
  final List<bool?> _strip = [];
  bool _firstAttempt = true;
  final Set<String> _wrongPicks = {};
  final Set<int> _wrongSounds = {};
  String? _correctPick;
  String? _reviewChoice;
  int? _selectedSound;
  Timer? _countdown;
  int? _secondsLeft;
  bool _disposed = false;

  QuizQuestion get _q => widget.questions[_index];
  Color get _color => widget.color ?? trainerColor(_q.trainer);
  TrainerScope get _scope => TrainerScope.of(context);
  bool get _last => _index == widget.questions.length - 1;

  @override
  void initState() {
    super.initState();
    _strip.addAll(List<bool?>.filled(widget.questions.length, null));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startQuestion());
  }

  @override
  void dispose() {
    _disposed = true;
    _countdown?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    if (_disposed) return;
    setState(() {
      _phase = _Phase.answering;
      _firstAttempt = true;
      _wrongPicks.clear();
      _wrongSounds.clear();
      _correctPick = null;
      _reviewChoice = null;
      _selectedSound = null;
      _status = _defaultPrompt;
    });
    if (_q.type != QuestionType.find) _scope.audio.play(_q.sound);
    _startTimer();
  }

  String get _defaultPrompt => switch (_q.type) {
    QuestionType.identify => _q.trainer.question,
    QuestionType.yesNo => tr('Duyduğun bu mu?', 'Is this what you heard?'),
    QuestionType.find => tr('Seslerden hangisi?', 'Which of the sounds?'),
  };

  void _startTimer() {
    _countdown?.cancel();
    final limit = widget.timeLimitSeconds;
    if (limit == null) {
      _secondsLeft = null;
      return;
    }
    _secondsLeft = limit;
    _tick();
  }

  /// Counts down from the current [_secondsLeft]; also resumes after a pause.
  void _tick() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed || _phase != _Phase.answering) return;
      setState(() => _secondsLeft = _secondsLeft! - 1);
      if (_secondsLeft! <= 0) {
        t.cancel();
        _timeout();
      }
    });
  }

  void _timeout() {
    _record(false, null);
    setState(() {
      _status = tr('Süre doldu', 'Time is up');
      _correctPick = _q.answer;
      _phase = _Phase.done;
    });
    _advanceSoon();
  }

  void _record(bool correct, String? chosen) {
    if (!_firstAttempt) return;
    _firstAttempt = false;
    _records.add(AnswerRecord(_q, correct, chosen: chosen));
    _strip[_index] = correct;
    if (widget.record) {
      final key = _q.type == QuestionType.yesNo ? _q.target : _q.answer;
      _scope.store.recordAnswer(_q.trainer, key, correct);
    }
  }

  bool get _hintsOn => widget.forceHints || _scope.store.hints;

  void _wrong(String? chosen) {
    final wasFirst = _firstAttempt;
    _record(false, chosen);
    if (chosen != null) _wrongPicks.add(chosen);
    if (_hintsOn && wasFirst) {
      _countdown?.cancel();
      setState(() {
        _phase = _Phase.review;
        _reviewChoice = chosen;
        _correctPick = _q.type == QuestionType.find ? _q.answer : null;
        _status = tr('Karşılaştır', 'Compare');
      });
      return;
    }
    if (widget.allowRetry && wasFirst && _q.type == QuestionType.identify) {
      setState(() => _status = tr('Bir daha dinle', 'Listen once more'));
      return;
    }
    _countdown?.cancel();
    setState(() {
      _status = tr('Olmadı', 'Not quite');
      _correctPick = _q.answer;
      _phase = _Phase.done;
    });
    _advanceSoon();
  }

  void _right(String? chosen) {
    _record(true, chosen);
    _countdown?.cancel();
    setState(() {
      _correctPick = chosen ?? _q.answer;
      _phase = _Phase.done;
      _status = _records.last.correct
          ? tr('Tam isabet!', 'Spot on!')
          : tr('Doğru!', 'Right!');
    });
    _advanceSoon();
  }

  void _advanceSoon() {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!_disposed) _next();
    });
  }

  void _next() {
    if (_last) {
      widget.onFinished(QuizSummary(List.of(_records)));
      return;
    }
    setState(() => _index++);
    _startQuestion();
  }

  static final _rand = math.Random();

  void _pick(String item) {
    if (_phase != _Phase.answering || _wrongPicks.contains(item)) return;
    item == _q.answer ? _right(item) : _wrong(item);
  }

  void _yesNo(bool yes) {
    if (_phase != _Phase.answering) return;
    yes == _q.isMatch ? _right(null) : _wrong(yes ? _q.target : null);
  }

  void _playSound(int i) {
    setState(() => _selectedSound = _wrongSounds.contains(i) ? null : i);
    _scope.audio.play(_q.sounds[i]);
  }

  void _submitFind() {
    final i = _selectedSound;
    if (i == null || _phase != _Phase.answering) return;
    if (i == _q.correctIndex) {
      _right(_q.options[i]);
    } else {
      _wrongSounds.add(i);
      _selectedSound = null;
      _wrong(_q.options[i]);
    }
  }

  String _label(String id, {bool long = false}) {
    final store = _scope.store;
    return itemLabel(
      _q.trainer,
      id,
      notation: store.notation,
      transposition: store.transposition,
      long: long,
    );
  }

  Future<void> _exit() async {
    // The question clock pauses while the learner decides.
    final paused = _countdown?.isActive ?? false;
    _countdown?.cancel();
    final ok = await confirmDialog(
      context,
      title: tr('Pratik bitsin mi?', 'End practice?'),
      message: tr(
        'Bu turdaki cevaplar sonuç olarak sayılmaz.',
        'Answers from this round will not count as results.',
      ),
      cancel: tr('Devam et', 'Keep going'),
      confirm: tr('Oturumu bitir', 'End session'),
    );
    if (!mounted) return;
    if (!ok) {
      if (paused && _phase == _Phase.answering && _secondsLeft != null) _tick();
      return;
    }
    await _scope.audio.stop();
    if (widget.onExit != null) {
      widget.onExit!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: switch (_q.type) {
                    QuestionType.identify => _identify(),
                    QuestionType.yesNo => _yesNoBody(),
                    QuestionType.find => _findBody(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
    child: Row(
      children: [
        BackSquare(icon: Ic.x, onTap: _exit),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trCaps(widget.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TT.crumb,
              ),
              const SizedBox(height: 6),
              _EvidenceStrip(results: _strip, current: _index, color: _color),
            ],
          ),
        ),
        if (widget.showCounter) ...[
          const SizedBox(width: 12),
          Text(
            '${_index + 1} / ${widget.questions.length}',
            style: TT.small.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    ),
  );

  Widget _statusText() {
    final good = _phase == _Phase.done && _strip[_index] == true;
    return Semantics(
      liveRegion: true,
      child: Text(
        _status,
        key: const Key('quiz_status'),
        textAlign: TextAlign.center,
        style: TT.h3.copyWith(color: good ? TC.green : TC.ink),
      ),
    );
  }

  Widget _disc() => ListenDisc(
    color: _color,
    playing: _scope.audio.playing,
    timeFraction: _secondsLeft == null || widget.timeLimitSeconds == null
        ? null
        : _secondsLeft! / widget.timeLimitSeconds!,
    secondsLeft: _phase == _Phase.answering ? _secondsLeft : null,
    onTap: _phase == _Phase.answering
        ? () => _scope.audio.play(_q.sound)
        : null,
  );

  Widget _identify() {
    final store = _scope.store;
    final usePiano =
        _q.trainer == TrainerKind.pitch &&
        store.keyboard &&
        store.transposition == 0;
    return Column(
      children: [
        const SizedBox(height: 18),
        _statusText(),
        const Spacer(),
        _disc(),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _phase == _Phase.review
              ? _review(target: _q.answer, heard: _reviewChoice)
              : usePiano
              ? PianoAnswer(
                  enabled: {for (final o in _q.options) int.parse(o)},
                  correct: _correctPick == null
                      ? null
                      : int.parse(_correctPick!),
                  wrong: {for (final w in _wrongPicks) int.parse(w)},
                  notation: store.notation,
                  onTap: _phase == _Phase.answering
                      ? (pc) => _pick('$pc')
                      : null,
                )
              : _Options(
                  options: _q.options,
                  correct: _correctPick,
                  wrong: _wrongPicks,
                  color: _color,
                  label: _label,
                  onTap: _phase == _Phase.answering ? _pick : null,
                ),
        ),
      ],
    );
  }

  Widget _targetChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      color: soft(_color),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      _label(_q.target, long: true),
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: _color,
      ),
    ),
  );

  Widget _yesNoBody() => Column(
    children: [
      const SizedBox(height: 18),
      _statusText(),
      const SizedBox(height: 12),
      _targetChip(),
      const Spacer(),
      _disc(),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: _phase == _Phase.review
            ? _review(target: _q.target, heard: _q.answer)
            : Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: tr('Evet', 'Yes'),
                      button: true,
                      excludeSemantics: true,
                      child: BigButton(
                        label: tr('Evet, bu', 'Yes, this one'),
                        color: TC.green,
                        onPressed: _phase == _Phase.answering
                            ? () => _yesNo(true)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      label: tr('Hayır', 'No'),
                      button: true,
                      excludeSemantics: true,
                      child: BigButton(
                        label: tr('Hayır, değil', 'No, it isn\'t'),
                        color: TC.coral,
                        onPressed: _phase == _Phase.answering
                            ? () => _yesNo(false)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ],
  );

  Widget _findBody() {
    final n = _q.sounds.length;
    return Column(
      children: [
        const SizedBox(height: 18),
        _statusText(),
        const SizedBox(height: 12),
        _targetChip(),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < n; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SoundRow(
                    letter: String.fromCharCode(65 + i),
                    color: _color,
                    selected: _selectedSound == i,
                    wrong: _wrongSounds.contains(i),
                    correct:
                        _correctPick != null &&
                        i == _q.correctIndex &&
                        _phase != _Phase.answering,
                    onTap: _phase == _Phase.answering
                        ? () => _playSound(i)
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _phase == _Phase.review
              ? _review(target: _q.answer, heard: _reviewChoice)
              : BigButton(
                  label: tr('Bu ses', 'This sound'),
                  color: _color,
                  onPressed:
                      _selectedSound != null && _phase == _Phase.answering
                      ? _submitFind
                      : null,
                ),
        ),
      ],
    );
  }

  /// Inline comparison after a first miss: play both, then move on.
  Widget _review({required String target, String? heard}) {
    final showHeard = heard != null && heard != target;
    void play(String id) =>
        _scope.audio.play(SoundFactory(_rand).item(_q.trainer, id));
    return Container(
      key: const Key('quiz_review'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TC.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showHeard) ...[
                Expanded(
                  child: _PlayPill(
                    caption: tr('SENİN CEVABIN', 'YOUR ANSWER'),
                    text: _label(heard, long: true),
                    color: TC.coral,
                    onTap: () => play(heard),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _PlayPill(
                  caption: tr('DOĞRUSU', 'CORRECT'),
                  text: _label(target, long: true),
                  color: TC.green,
                  onTap: () => play(target),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(itemFeel(_q.trainer, target), style: TT.small),
          const SizedBox(height: 12),
          BigButton(
            label: _last
                ? tr('Devam', 'Continue')
                : tr('Sonraki soru', 'Next question'),
            onPressed: _next,
          ),
        ],
      ),
    );
  }
}

/// One dot per question: grey = to come, outlined = now, green/coral = result.
class _EvidenceStrip extends StatelessWidget {
  const _EvidenceStrip({
    required this.results,
    required this.current,
    required this.color,
  });
  final List<bool?> results;
  final int current;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < results.length; i++)
        Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: switch (results[i]) {
                true => TC.green,
                false => TC.coral,
                null => i == current ? color.withValues(alpha: 0.35) : TC.line,
              },
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
    ],
  );
}

/// Large round listen button; an optional ring shows the time left.
class ListenDisc extends StatelessWidget {
  const ListenDisc({
    super.key,
    required this.color,
    required this.playing,
    required this.onTap,
    this.timeFraction,
    this.secondsLeft,
  });
  final Color color;
  final ValueNotifier<bool> playing;
  final VoidCallback? onTap;
  final double? timeFraction;
  final int? secondsLeft;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr('Tekrar dinle', 'Listen again'),
    child: GestureDetector(
      onTap: onTap,
      child: ValueListenableBuilder<bool>(
        valueListenable: playing,
        builder: (context, isPlaying, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 172,
              height: 172,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: timeFraction ?? 1,
                      strokeWidth: 6,
                      color: timeFraction == null ? TC.line : color,
                      backgroundColor: TC.line,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: isPlaying ? 140 : 128,
                    height: isPlaying ? 140 : 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPlaying ? color : soft(color),
                    ),
                    child: Icon(
                      isPlaying ? Ic.audioLines : Ic.rotateCcw,
                      size: 48,
                      color: isPlaying ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              secondsLeft != null
                  ? tr('$secondsLeft sn', '$secondsLeft s')
                  : tr('Tekrar dinle', 'Listen again'),
              style: TT.small.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Only the question's options, as chunky two-column buttons.
class _Options extends StatelessWidget {
  const _Options({
    required this.options,
    required this.correct,
    required this.wrong,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final List<String> options;
  final String? correct;
  final Set<String> wrong;
  final Color color;
  final String Function(String) label;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = options.length > 6 ? 3 : 2;
      const gap = 10.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final id in options)
            SizedBox(
              width: w,
              child: _OptionButton(
                text: label(id),
                color: color,
                state: correct == id
                    ? true
                    : wrong.contains(id)
                    ? false
                    : null,
                onTap: onTap == null || wrong.contains(id)
                    ? null
                    : () => onTap!(id),
              ),
            ),
        ],
      );
    },
  );
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.text,
    required this.color,
    required this.state,
    required this.onTap,
  });
  final String text;
  final Color color;
  final bool? state;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final fill = switch (state) {
      true => TC.green,
      false => const Color(0xFFFDE5E1),
      null => Colors.white,
    };
    final edge = switch (state) {
      true => const Color(0xFF137A52),
      false => TC.coral,
      null => TC.line,
    };
    final fg = switch (state) {
      true => Colors.white,
      false => TC.coral,
      null => TC.ink,
    };
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                tapHaptic();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: edge),
              top: BorderSide(color: edge),
              right: BorderSide(color: edge),
              bottom: BorderSide(color: edge, width: 4),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.letter,
    required this.color,
    required this.selected,
    required this.wrong,
    required this.correct,
    required this.onTap,
  });
  final String letter;
  final Color color;
  final bool selected;
  final bool wrong;
  final bool correct;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final accent = correct
        ? TC.green
        : wrong
        ? TC.coral
        : selected
        ? color
        : TC.line;
    return Semantics(
      button: true,
      label: tr('Ses $letter', 'Sound $letter'),
      selected: selected,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        border: accent == TC.line ? null : accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent == TC.line ? soft(color) : accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: accent == TC.line ? color : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected
                    ? tr(
                        'Seçili · tekrar dinlemek için dokun',
                        'Selected · tap to hear it again',
                      )
                    : tr('Dinle', 'Listen'),
                style: TT.title,
              ),
            ),
            Icon(Ic.circlePlay, color: color),
          ],
        ),
      ),
    );
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({
    required this.caption,
    required this.text,
    required this.color,
    required this.onTap,
  });
  final String caption;
  final String text;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: soft(color),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Ic.play, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One line: at large text "DOĞRUSU" broke mid-word.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      caption,
                      maxLines: 1,
                      softWrap: false,
                      style: TT.caps.copyWith(color: color, fontSize: 10),
                    ),
                  ),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TT.title,
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

/// One-octave piano for answering single notes (Keyboard preference).
class PianoAnswer extends StatelessWidget {
  const PianoAnswer({
    super.key,
    required this.enabled,
    required this.correct,
    required this.wrong,
    required this.notation,
    required this.onTap,
  });
  final Set<int> enabled;
  final int? correct;
  final Set<int> wrong;
  final NoteNotation notation;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final whiteW = c.maxWidth / 7;
      Color fill(int pc, bool black) => correct == pc
          ? TC.green
          : wrong.contains(pc)
          ? TC.red
          : black
          ? (enabled.contains(pc) ? TC.ink : const Color(0xFF9AA3B2))
          : (enabled.contains(pc) ? Colors.white : const Color(0xFFF0EFF8));
      Widget key(
        int pc,
        bool black,
        double left,
        double width,
        double height,
      ) => Positioned(
        left: left,
        top: 0,
        width: width,
        height: height,
        child: Semantics(
          button: true,
          label: PitchClass.name(pc, notation),
          child: GestureDetector(
            onTap: onTap != null && enabled.contains(pc)
                ? () => onTap!(pc)
                : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: fill(pc, black),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
                border: Border.all(color: TC.line),
              ),
              child: black
                  ? null
                  : Text(
                      PitchClass.name(pc, notation),
                      style: const TextStyle(fontSize: 11, color: TC.muted),
                    ),
            ),
          ),
        ),
      );
      const blacks = {1: 1, 3: 2, 6: 4, 8: 5, 10: 6};
      return SizedBox(
        height: 170,
        child: Stack(
          children: [
            for (var i = 0; i < 7; i++)
              key(PitchClass.whiteKeys[i], false, i * whiteW, whiteW, 170),
            for (final e in blacks.entries)
              key(
                e.key,
                true,
                e.value * whiteW - whiteW * 0.3,
                whiteW * 0.6,
                105,
              ),
          ],
        ),
      );
    },
  );
}
