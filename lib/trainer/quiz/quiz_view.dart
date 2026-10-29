import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../ui/kit.dart';
import 'quiz.dart';

enum _Phase { answering, feedback, resetting }

/// Runs a list of questions with the trainer's listen → answer → feedback →
/// ear-reset rhythm. First attempts are scored; retries only teach.
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
    this.quickCheckLabel,
    this.onExit,
    this.forceHints = false,
    this.showSkip = false,
    this.onSkip,
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

  /// "KISA YOKLAMA" header for lesson checks.
  final String? quickCheckLabel;
  final VoidCallback? onExit;

  /// Lessons always explain a miss, regardless of the hints preference.
  final bool forceHints;
  final bool showSkip;
  final VoidCallback? onSkip;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _index = 0;
  _Phase _phase = _Phase.answering;
  bool? _frame;
  String _status = '';
  final _records = <AnswerRecord>[];
  bool _firstAttempt = true;
  final Set<String> _wrongPicks = {};
  final Set<int> _wrongSounds = {};
  String? _correctPick;
  int? _selectedSound;
  int? _activeSound;
  Timer? _countdown;
  int? _secondsLeft;
  int _hintSheets = 0;
  bool _disposed = false;

  QuizQuestion get _q => widget.questions[_index];
  Color get _color => widget.color ?? trainerColor(_q.trainer);
  TrainerScope get _scope => TrainerScope.of(context);

  @override
  void initState() {
    super.initState();
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
      _frame = null;
      _firstAttempt = true;
      _wrongPicks.clear();
      _wrongSounds.clear();
      _correctPick = null;
      _selectedSound = null;
      _activeSound = null;
      _status = _defaultPrompt;
    });
    if (_q.type != QuestionType.find) _scope.audio.play(_q.sound);
    _startTimer();
  }

  String get _defaultPrompt => switch (_q.type) {
    QuestionType.identify => _q.trainer.question,
    QuestionType.yesNo => 'Evet mi, hayır mı?',
    QuestionType.find => 'Dinlemek için her birine dokun',
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
      _frame = false;
      _status = 'Süre doldu';
      _correctPick = _q.answer;
      _phase = _Phase.feedback;
    });
    _advanceSoon();
  }

  void _record(bool correct, String? chosen) {
    if (!_firstAttempt) return;
    _firstAttempt = false;
    _records.add(AnswerRecord(_q, correct, chosen: chosen));
    if (widget.record) {
      final key = _q.type == QuestionType.yesNo ? _q.target : _q.answer;
      _scope.store.recordAnswer(_q.trainer, key, correct);
    }
  }

  bool get _hintsOn => widget.forceHints || _scope.store.hints;

  Future<void> _wrong(String? chosen) async {
    final wasFirst = _firstAttempt;
    _record(false, chosen);
    setState(() {
      _frame = false;
      if (chosen != null) _wrongPicks.add(chosen);
    });
    if (_hintsOn && wasFirst) {
      _countdown?.cancel();
      setState(() => _phase = _Phase.feedback);
      await _showHint(chosen);
      if (_disposed) return;
      _goReset();
      return;
    }
    if (widget.allowRetry && wasFirst && _q.type == QuestionType.identify) {
      setState(() => _status = 'Bir daha dinle');
      return;
    }
    setState(() {
      _status = 'Olmadı';
      _correctPick = _q.answer;
      _phase = _Phase.feedback;
    });
    _countdown?.cancel();
    _advanceSoon();
  }

  void _right(String? chosen) {
    _record(true, chosen);
    _countdown?.cancel();
    setState(() {
      _frame = true;
      _correctPick = chosen ?? _q.answer;
      _phase = _Phase.feedback;
      _status = switch (_q.type) {
        QuestionType.find => 'Doğru ses!',
        _ => _records.last.correct ? 'Tam isabet!' : 'Doğru!',
      };
    });
    _advanceSoon();
  }

  void _advanceSoon() {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!_disposed) _goReset();
    });
  }

  void _goReset() {
    if (_index == widget.questions.length - 1) {
      widget.onFinished(QuizSummary(List.of(_records)));
      return;
    }
    setState(() {
      _phase = _Phase.resetting;
      _frame = null;
      _status = 'Kulağını dinlendir...';
    });
    _scope.audio.play(SoundFactory(_rand).earReset());
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (_disposed) return;
      setState(() => _index++);
      _startQuestion();
    });
  }

  static final _rand = math.Random();

  void _pick(String item) {
    if (_phase != _Phase.answering || _wrongPicks.contains(item)) return;
    if (item == _q.answer) {
      _right(item);
    } else {
      _wrong(item);
    }
  }

  void _yesNo(bool yes) {
    if (_phase != _Phase.answering) return;
    if (yes == _q.isMatch) {
      _right(null);
    } else {
      _wrong(yes ? _q.target : null);
    }
  }

  void _playSound(int i) {
    setState(() {
      _activeSound = i;
      _selectedSound = _wrongSounds.contains(i) ? _selectedSound : i;
    });
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

  Future<void> _showHint(String? chosen) async {
    _hintSheets++;
    final store = _scope.store;
    final notation = store.notation;
    String label(String id) => itemLabel(
      _q.trainer,
      id,
      notation: notation,
      transposition: store.transposition,
      long: true,
    );
    final played = _q.type == QuestionType.yesNo ? _q.answer : _q.answer;
    final target = _q.type == QuestionType.yesNo ? _q.target : _q.answer;
    final yesNoMatch = _q.type == QuestionType.yesNo && _q.isMatch;
    final heard = _q.type == QuestionType.yesNo ? played : (chosen ?? played);
    await showTrainerSheet<void>(
      context,
      dismissible: false,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _q.type == QuestionType.yesNo ? 'Tam değil' : 'Az kaldı!',
            textAlign: TextAlign.center,
            style: TT.h3,
          ),
          const SizedBox(height: 6),
          Text(
            _q.type == QuestionType.yesNo
                ? (yesNoMatch
                      ? 'Hedefle aynıydı, yani cevap Evet olmalıydı. Tekrar dinlemek için dokun.'
                      : 'Farklı bir ${_q.trainer.unitWord}ydı, yani cevap Hayır olmalıydı. Karşılaştırmak için dokun.')
                : 'Farkı duymak için kartlara dokun. Bir dahakine olacak.',
            textAlign: TextAlign.center,
            style: TT.small,
          ),
          const SizedBox(height: 14),
          if (!yesNoMatch)
            _CompareCard(
              caption: _q.type == QuestionType.yesNo ? 'Duyduğun' : 'Seçtiğin',
              title: label(heard),
              body: itemFeel(_q.trainer, heard),
              good: false,
              onPlay: () => _scope.audio.play(
                SoundFactory(_rand).item(_q.trainer, heard),
              ),
            ),
          _CompareCard(
            caption: _q.type == QuestionType.yesNo ? 'Hedef' : 'Doğru cevap',
            title: label(target),
            body: itemFeel(_q.trainer, target),
            good: true,
            onPlay: () =>
                _scope.audio.play(SoundFactory(_rand).item(_q.trainer, target)),
          ),
          const SizedBox(height: 8),
          BigButton(
            label: _index == widget.questions.length - 1
                ? 'Devam'
                : 'Sonraki soru',
            color: TC.primary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
    if (!mounted ||
        widget.forceHints ||
        store.hintsPromptShown ||
        _hintSheets < 2) {
      return;
    }
    store.hintsPromptShown = true;
    store.save();
    final hide = await showTrainerSheet<bool>(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '💡',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 8),
          const Text(
            'İpuçları gizlensin mi?',
            textAlign: TextAlign.center,
            style: TT.h3,
          ),
          const SizedBox(height: 6),
          const Text(
            'Bu cevap kartlarını kapatmak ister misin? Ayarlar\'dan istediğin zaman yeniden açabilirsin.',
            textAlign: TextAlign.center,
            style: TT.small,
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'İpuçlarını gizle',
            color: TC.primary,
            onPressed: () => Navigator.pop(context, true),
          ),
          TextLink('Kalsın', onTap: () => Navigator.pop(context, false)),
        ],
      ),
    );
    if (hide == true) {
      store.hints = false;
      store.save();
    }
  }

  Future<void> _exit() async {
    // The question clock pauses while the learner decides.
    final paused = _countdown?.isActive ?? false;
    _countdown?.cancel();
    final ok = await confirmDialog(
      context,
      title: 'Pratik bitsin mi?',
      message:
          'Bu oturumu bitirmek istediğine emin misin? İlerlemen kaydedilmeyecek.',
      cancel: 'Devam et',
      confirm: 'Oturumu bitir',
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
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FeedbackFrame(
          state: _frame,
          child: SafeArea(
            child: Column(
              children: [
                TopBar(
                  title: widget.title,
                  onBack: _exit,
                  progress:
                      (_index + (_phase == _Phase.answering ? 0 : 1)) / total,
                  progressColor: _color,
                  counter: widget.showCounter ? '${_index + 1} / $total' : null,
                  shadow: true,
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_q.type) {
    QuestionType.identify => _identify(),
    QuestionType.yesNo => _yesNoBody(),
    QuestionType.find => _findBody(),
  };

  Widget _statusLine() {
    final text =
        _secondsLeft != null &&
            _phase == _Phase.answering &&
            _status == _defaultPrompt
        ? '${_secondsLeft}sn'
        : _status;
    final colored = _status == 'Tam isabet!';
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: const Key('quiz_status'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: colored ? _color : TC.ink,
        ),
      ),
    );
  }

  Widget _wave({double height = 200}) => WaveView(
    playing: _scope.audio.playing,
    color: _color,
    height: height,
    label: _q.trainer.replayLabel,
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
        const Spacer(),
        _wave(height: 220),
        const Spacer(),
        _statusLine(),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: usePiano
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
              : _AnswerGrid(
                  trainer: _q.trainer,
                  pool: _q.options,
                  correct: _correctPick,
                  wrong: _wrongPicks,
                  resetting: _phase == _Phase.resetting,
                  label: (id) => itemLabel(
                    _q.trainer,
                    id,
                    notation: store.notation,
                    transposition: store.transposition,
                  ),
                  onTap: _phase == _Phase.answering ? _pick : null,
                ),
        ),
      ],
    );
  }

  Widget _targetHeader(String caps, String? suffix) {
    final store = _scope.store;
    return Column(
      children: [
        if (widget.quickCheckLabel != null) ...[
          Text(widget.quickCheckLabel!, style: TT.caps),
          const SizedBox(height: 18),
        ],
        Text(caps, style: TT.caps),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: soft(_color),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Text(
            itemLabel(
              _q.trainer,
              _q.target,
              notation: store.notation,
              transposition: store.transposition,
              long: true,
            ),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(height: 10),
          Text(suffix, style: TT.caps),
        ],
      ],
    );
  }

  Widget _yesNoBody() => Column(
    children: [
      const SizedBox(height: 24),
      _targetHeader('BU', '...${_q.trainer.unitWord.toUpperCase()} MI?'),
      const Spacer(),
      _wave(height: 170),
      const Spacer(),
      _statusLine(),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: _YesNoButton(
                yes: true,
                enabled: _phase == _Phase.answering,
                onTap: () => _yesNo(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _YesNoButton(
                yes: false,
                enabled: _phase == _Phase.answering,
                onTap: () => _yesNo(false),
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
        const SizedBox(height: 24),
        const Spacer(),
        _targetHeader('BU ${_q.trainer.unitWord.toUpperCase()}YI BUL', null),
        const Spacer(),
        _statusLine(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < n; i++)
                LayoutBuilder(
                  builder: (context, c) => SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 44) / 2,
                    child: _SoundButton(
                      index: i,
                      color: _color,
                      selected: _selectedSound == i,
                      playing: _activeSound == i,
                      audioPlaying: _scope.audio.playing,
                      wrong: _wrongSounds.contains(i),
                      correct:
                          _correctPick != null &&
                          _phase != _Phase.resetting &&
                          i == _q.correctIndex &&
                          _frame == true,
                      resetting: _phase == _Phase.resetting,
                      onTap: _phase == _Phase.answering
                          ? () => _playSound(i)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: BigButton(
            label: 'Gönder',
            color: _color,
            onPressed: _selectedSound != null && _phase == _Phase.answering
                ? _submitFind
                : null,
          ),
        ),
      ],
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  const _AnswerGrid({
    required this.trainer,
    required this.pool,
    required this.correct,
    required this.wrong,
    required this.resetting,
    required this.label,
    required this.onTap,
  });
  final TrainerKind trainer;
  final List<String> pool;
  final String? correct;
  final Set<String> wrong;
  final bool resetting;
  final String Function(String) label;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final items = trainer.allItems;
    final columns = switch (trainer) {
      TrainerKind.pitch || TrainerKind.interval => 4,
      TrainerKind.scale => 2,
      _ => 3,
    };
    final tall = trainer == TrainerKind.progression;
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final id in items)
              SizedBox(
                width: w,
                height: tall ? 66 : (columns == 2 ? 44 : 52),
                child: _AnswerCell(
                  text: label(id),
                  active: pool.contains(id),
                  correct: correct == id,
                  wrong: wrong.contains(id),
                  resetting: resetting && pool.contains(id),
                  compact: columns == 2,
                  onTap: onTap == null || !pool.contains(id)
                      ? null
                      : () => onTap!(id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AnswerCell extends StatelessWidget {
  const _AnswerCell({
    required this.text,
    required this.active,
    required this.correct,
    required this.wrong,
    required this.resetting,
    required this.compact,
    required this.onTap,
  });
  final String text;
  final bool active;
  final bool correct;
  final bool wrong;
  final bool resetting;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = correct
        ? TC.green
        : wrong
        ? const Color(0xFFFDE5E1)
        : resetting
        ? const Color(0xFFF0EFF8)
        : Colors.white;
    final border = correct
        ? TC.green
        : wrong
        ? TC.red
        : active
        ? TC.line
        : Colors.transparent;
    final fg = correct
        ? Colors.white
        : wrong
        ? TC.red
        : active
        ? TC.ink
        : TC.faint;
    return Semantics(
      button: active,
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
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? bg : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 22 : 14),
            border: Border.all(color: border, width: 1.4),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YesNoButton extends StatelessWidget {
  const _YesNoButton({
    required this.yes,
    required this.enabled,
    required this.onTap,
  });
  final bool yes;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = yes ? TC.green : TC.red;
    return Semantics(
      button: true,
      enabled: enabled,
      label: yes ? 'Evet' : 'Hayır',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled
            ? () {
                tapHaptic();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 72,
          decoration: BoxDecoration(
            color: enabled ? soft(color) : const Color(0xFFF0EFF8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.35) : TC.line,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: enabled ? color : TC.faint,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  yes ? Icons.check_rounded : Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                yes ? 'Evet' : 'Hayır',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: enabled
                      ? (yes ? const Color(0xFF137A52) : TC.red)
                      : TC.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundButton extends StatelessWidget {
  const _SoundButton({
    required this.index,
    required this.color,
    required this.selected,
    required this.playing,
    required this.audioPlaying,
    required this.wrong,
    required this.correct,
    required this.resetting,
    required this.onTap,
  });
  final int index;
  final Color color;
  final bool selected;
  final bool playing;
  final ValueNotifier<bool> audioPlaying;
  final bool wrong;
  final bool correct;
  final bool resetting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = correct
        ? TC.green
        : selected
        ? color
        : wrong
        ? const Color(0xFFFDE5E1)
        : resetting
        ? const Color(0xFFF0EFF8)
        : Colors.white;
    final fg = correct || selected ? Colors.white : (wrong ? TC.red : TC.muted);
    return Semantics(
      button: true,
      label: 'Ses ${index + 1}',
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                tapHaptic();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 72,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: correct
                  ? TC.green
                  : selected
                  ? color
                  : wrong
                  ? TC.red
                  : TC.line,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 0,
                      spreadRadius: 5,
                    ),
                  ]
                : null,
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: audioPlaying,
            builder: (context, isPlaying, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  playing && isPlaying
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                  color: fg,
                ),
                const SizedBox(height: 4),
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.caption,
    required this.title,
    required this.body,
    required this.good,
    required this.onPlay,
  });
  final String caption;
  final String title;
  final String body;
  final bool good;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TC.line, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: good ? const Color(0xFFDDF6EC) : const Color(0xFFFDE5E1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              good ? Icons.check_rounded : Icons.close_rounded,
              color: good ? const Color(0xFF137A52) : TC.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: const TextStyle(fontSize: 11, color: TC.muted),
                ),
                Text(title, style: TT.title),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12.5, color: TC.body),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Dinle',
            onPressed: onPlay,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF0EFF8),
            ),
            icon: const Icon(
              Icons.volume_up_outlined,
              size: 20,
              color: TC.body,
            ),
          ),
        ],
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
