import 'dart:math' as math;

/// Play-and-listen vocal range ladder, ported from the author's Agora range
/// test (`agoravoiceweb/src/PitchTest/lib/rangeMachine.ts` and
/// `pitchDetector.ts#matchToTarget`). The app plays one piano note, the
/// singer repeats it, and the ladder climbs (then descends) one natural note
/// at a time until two attempts in a row miss.
///
/// Differences from the web version, required by Vocalart's rules:
/// * a take sung in another octave is reported as [RangeMatch.octaveOff] and
///   never reaches the note (the web version accepted it with a penalty);
/// * a take the quality gate rejects is [RangeMatch.unmeasured], kept apart
///   from a measured miss;
/// * there is no gender question: the start note comes from a comfortable
///   take ([startFromComfort]) or the shared middle note [neutralStartMidi].

/// White-key notes E1–C7, the web test's note table.
final List<int> rangeLadderNotes = [
  for (var m = 28; m <= 96; m++)
    if (const {0, 2, 4, 5, 7, 9, 11}.contains(m % 12)) m,
];

/// A3: inside every adult SATB range, so nobody starts out of reach.
const neutralStartMidi = 57;

/// Attempts per note before the direction ends (web: MAX_ATTEMPTS).
const rangeAttemptsPerNote = 2;

/// Web tolerance window and pass mark: closeness = 100·(1 − |cents|/100),
/// reached at 60 or more, i.e. within 40 cents of the played note.
const rangeToleranceCents = 100.0;
const rangePassMark = 60.0;

enum RangeDirection { up, down }

enum RangeMatch {
  /// Same octave, within [rangePassMark].
  matched,

  /// Same octave but too far from the note.
  missed,

  /// Close to the note only one or two octaves away: not reached.
  octaveOff,

  /// The quality gate found no steady voice: no pitch, no closeness.
  unmeasured,
}

double centsBetween(double hz, double refHz) =>
    1200 * math.log(hz / refHz) / math.ln2;

double _midiHz(int midi) => 440.0 * math.pow(2, (midi - 69) / 12).toDouble();

class RangeJudgement {
  const RangeJudgement(
    this.match, {
    this.cents,
    this.closeness,
    this.octave = 0,
  });
  final RangeMatch match;

  /// Signed cents from the played note (same octave as matched), null when
  /// unmeasured.
  final double? cents;

  /// 0–100 within the tolerance window, null when unmeasured.
  final double? closeness;

  /// Octaves between the take and the played note when [RangeMatch.octaveOff].
  final int octave;
}

/// [hz] is the take's representative pitch or null when the quality gate
/// rejected it.
RangeJudgement judgeRangeTake(double? hz, int targetMidi) {
  if (hz == null || hz <= 0 || !hz.isFinite) {
    return const RangeJudgement(RangeMatch.unmeasured);
  }
  final target = _midiHz(targetMidi);
  final cents = centsBetween(hz, target);
  final closeness = math.max(
    0.0,
    (1 - cents.abs() / rangeToleranceCents) * 100,
  );
  if (closeness >= rangePassMark) {
    return RangeJudgement(
      RangeMatch.matched,
      cents: cents,
      closeness: closeness,
    );
  }
  for (final octave in const [-1, 1, -2, 2]) {
    final shifted = centsBetween(hz, target * math.pow(2, octave));
    if ((1 - shifted.abs() / rangeToleranceCents) * 100 >= rangePassMark) {
      return RangeJudgement(
        RangeMatch.octaveOff,
        cents: cents,
        closeness: closeness,
        octave: octave,
      );
    }
  }
  return RangeJudgement(RangeMatch.missed, cents: cents, closeness: closeness);
}

/// Nearest ladder note to a comfortable take, or [neutralStartMidi].
int startFromComfort(double? hz) {
  if (hz == null || hz <= 0 || !hz.isFinite) return neutralStartMidi;
  final midi = 69 + 12 * math.log(hz / 440) / math.ln2;
  return rangeLadderNotes.reduce(
    (a, b) => (a - midi).abs() <= (b - midi).abs() ? a : b,
  );
}

class RangeAttempt {
  const RangeAttempt({
    required this.targetMidi,
    required this.direction,
    required this.attempt,
    required this.judgement,
    this.hz,
  });
  final int targetMidi;
  final RangeDirection direction;
  final int attempt;
  final RangeJudgement judgement;
  final double? hz;
}

/// Immutable state of one ladder run.
class RangeLadder {
  const RangeLadder._({
    required this.startIndex,
    required this.index,
    required this.direction,
    required this.attempt,
    required this.reached,
    required this.log,
    required this.done,
  });

  factory RangeLadder.start(int startMidi) {
    final i = rangeLadderNotes.indexOf(startMidi);
    final start = i < 0 ? rangeLadderNotes.indexOf(neutralStartMidi) : i;
    return RangeLadder._(
      startIndex: start,
      index: start,
      direction: RangeDirection.up,
      attempt: 1,
      reached: const {},
      log: const [],
      done: false,
    );
  }

  final int startIndex;
  final int index;
  final RangeDirection direction;

  /// 1-based attempt on the current note.
  final int attempt;
  final Set<int> reached;
  final List<RangeAttempt> log;
  final bool done;

  int get currentMidi => rangeLadderNotes[index];
  int get startMidi => rangeLadderNotes[startIndex];

  RangeLadder _copy({
    int? index,
    RangeDirection? direction,
    int? attempt,
    Set<int>? reached,
    List<RangeAttempt>? log,
    bool? done,
  }) => RangeLadder._(
    startIndex: startIndex,
    index: index ?? this.index,
    direction: direction ?? this.direction,
    attempt: attempt ?? this.attempt,
    reached: reached ?? this.reached,
    log: log ?? this.log,
    done: done ?? this.done,
  );

  /// Records one take on [currentMidi] and moves the ladder on.
  RangeLadder record(double? hz) {
    if (done) return this;
    final judgement = judgeRangeTake(hz, currentMidi);
    final log = [
      ...this.log,
      RangeAttempt(
        targetMidi: currentMidi,
        direction: direction,
        attempt: attempt,
        judgement: judgement,
        hz: judgement.match == RangeMatch.unmeasured ? null : hz,
      ),
    ];
    if (judgement.match == RangeMatch.matched) {
      final next = _copy(log: log, reached: {...reached, currentMidi});
      final step = direction == RangeDirection.up ? 1 : -1;
      final i = index + step;
      if (i < 0 || i >= rangeLadderNotes.length) return next._switchOrFinish();
      return next._copy(index: i, attempt: 1);
    }
    if (attempt < rangeAttemptsPerNote) {
      return _copy(log: log, attempt: attempt + 1);
    }
    return _copy(log: log)._switchOrFinish();
  }

  /// "That is my limit": ends the current direction without a take.
  RangeLadder skipDirection() => done ? this : _switchOrFinish();

  RangeLadder _switchOrFinish() {
    if (direction == RangeDirection.up && startIndex > 0) {
      return _copy(
        direction: RangeDirection.down,
        index: startIndex - 1,
        attempt: 1,
      );
    }
    return _copy(done: true);
  }

  RangeBounds? get bounds {
    if (reached.length < 2) return null;
    final low = reached.reduce(math.min);
    final high = reached.reduce(math.max);
    return RangeBounds(low, high);
  }
}

class RangeBounds {
  const RangeBounds(this.lowMidi, this.highMidi);
  final int lowMidi;
  final int highMidi;
  int get semitones => highMidi - lowMidi;

  /// log2 of the frequency ratio, as the web result reports it.
  double get octaves => semitones / 12;
}
