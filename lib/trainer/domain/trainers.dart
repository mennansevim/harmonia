import 'dart:math' as math;

import 'music.dart';
import '../../domain/lang.dart';

/// The five listening trainers. The choir module is separate (koro/).
enum TrainerKind { pitch, interval, chord, scale, progression }

enum IntervalDirection { ascending, descending, mixed }

extension TrainerKindInfo on TrainerKind {
  String get id => name;
  String get title => switch (this) {
    TrainerKind.pitch => tr('Nota Eğitimi', 'Note Training'),
    TrainerKind.interval => tr('Aralık Eğitimi', 'Interval Training'),
    TrainerKind.chord => tr('Akor Tanıma', 'Chord Recognition'),
    TrainerKind.scale => tr('Dizi Tanıma', 'Scale Recognition'),
    TrainerKind.progression => tr('Akor Yürüyüşleri', 'Chord Progressions'),
  };
  String get shortTitle => switch (this) {
    TrainerKind.pitch => tr('Nota', 'Notes'),
    TrainerKind.interval => tr('Aralıklar', 'Intervals'),
    TrainerKind.chord => tr('Akorlar', 'Chords'),
    TrainerKind.scale => tr('Diziler', 'Scales'),
    TrainerKind.progression => tr('Yürüyüşler', 'Progressions'),
  };
  String get tagline => switch (this) {
    TrainerKind.pitch => tr('Notayı adlandır', 'Name the note'),
    TrainerKind.interval => tr(
      'Notalar arası mesafe',
      'The distance between notes',
    ),
    TrainerKind.chord => tr('Akor rengini tanı', 'Know a chord by its colour'),
    TrainerKind.scale => tr('Diziyi bul', 'Find the scale'),
    TrainerKind.progression => tr(
      'Şarkı kalıplarını duy',
      'Hear the patterns in songs',
    ),
  };
  String get pitchLine => switch (this) {
    TrainerKind.pitch => tr('Tek bir notayı tanı', 'Recognise a single note'),
    TrainerKind.interval => tr(
      'İki nota arasındaki mesafe',
      'The distance between two notes',
    ),
    TrainerKind.chord => tr(
      'Akor niteliğini tanı',
      'Recognise the chord quality',
    ),
    TrainerKind.scale => tr(
      'Dizi türünü kulaktan bul',
      'Find the scale type by ear',
    ),
    TrainerKind.progression => tr(
      'Yürüyüş kalıplarını yakala',
      'Catch the progression patterns',
    ),
  };
  String get unitWord => switch (this) {
    TrainerKind.pitch => tr('nota', 'notes'),
    TrainerKind.interval => tr('aralık', 'intervals'),
    TrainerKind.chord => tr('akor', 'chords'),
    TrainerKind.scale => tr('dizi', 'scales'),
    TrainerKind.progression => tr('yürüyüş', 'progressions'),
  };
  String get question => switch (this) {
    TrainerKind.pitch => tr('Bu hangi nota?', 'Which note is this?'),
    TrainerKind.interval => tr('Bu hangi aralık?', 'Which interval is this?'),
    TrainerKind.chord => tr('Bu hangi akor?', 'Which chord is this?'),
    TrainerKind.scale => tr('Bu hangi dizi?', 'Which scale is this?'),
    TrainerKind.progression => tr(
      'Bu hangi yürüyüş?',
      'Which progression is this?',
    ),
  };
  String get replayLabel => switch (this) {
    TrainerKind.pitch => tr('TEKRAR DİNLE', 'LISTEN AGAIN'),
    TrainerKind.interval => tr('ARALIĞI TEKRARLA', 'REPLAY INTERVAL'),
    TrainerKind.chord => tr('AKORU TEKRARLA', 'REPLAY CHORD'),
    TrainerKind.scale => tr('DİZİYİ TEKRARLA', 'REPLAY SCALE'),
    TrainerKind.progression => tr('YÜRÜYÜŞÜ TEKRARLA', 'REPLAY PROGRESSION'),
  };

  /// Every answer id the trainer can ask about.
  List<String> get allItems => switch (this) {
    TrainerKind.pitch => [for (var i = 0; i < 12; i++) '$i'],
    TrainerKind.interval => [for (final i in Intervals.all) i.id],
    TrainerKind.chord => [for (final c in Chords.all) c.id],
    TrainerKind.scale => [for (final s in Scales.all) s.id],
    TrainerKind.progression => [for (final p in Progressions.all) p.id],
  };
}

/// A thing to play: notes starting at offsets. Rendering lives in the synth.
class ToneEvent {
  const ToneEvent(this.startSeconds, this.durationSeconds, this.midiNotes);
  final double startSeconds;
  final double durationSeconds;
  final List<int> midiNotes;
}

class SoundSpec {
  const SoundSpec(this.events);
  final List<ToneEvent> events;
  double get durationSeconds => events.fold(
    0,
    (end, e) => math.max(end, e.startSeconds + e.durationSeconds),
  );

  SoundSpec followedBy(SoundSpec other, {double gap = 0.4}) {
    final offset = durationSeconds + gap;
    return SoundSpec([
      ...events,
      for (final e in other.events)
        ToneEvent(e.startSeconds + offset, e.durationSeconds, e.midiNotes),
    ]);
  }
}

/// Builds the audio for one item. Random root/octave unless pinned.
class SoundFactory {
  SoundFactory(this.random);
  final math.Random random;

  SoundSpec note(int midi, {double seconds = 1.3}) => SoundSpec([
    ToneEvent(0, seconds, [midi]),
  ]);

  SoundSpec pitch(int pitchClass, Register register, {bool reference = false}) {
    final target = SoundSpec([
      ToneEvent(0, 1.3, [register.rootC + pitchClass]),
    ]);
    if (!reference) return target;
    return note(register.rootC, seconds: 0.9).followedBy(target, gap: 0.6);
  }

  int _root(Register register, int span) {
    final base = register.rootC - 5;
    final room = math.max(1, 12 - math.max(0, span - 12)).toInt();
    return base + random.nextInt(room);
  }

  /// [learn]: low, high, then both together (the lesson convention).
  SoundSpec interval(
    String id, {
    Register register = Register.medium,
    IntervalDirection direction = IntervalDirection.ascending,
    int? rootMidi,
    bool learn = false,
  }) {
    final semis = Intervals.byId(id).semitones;
    final root = rootMidi ?? _root(register, semis);
    final top = root + semis;
    final down =
        direction == IntervalDirection.descending ||
        (direction == IntervalDirection.mixed && random.nextBool());
    final first = down ? top : root;
    final second = down ? root : top;
    return SoundSpec([
      ToneEvent(0, 0.9, [first]),
      ToneEvent(1.0, 0.9, [second]),
      if (learn) ToneEvent(2.2, 1.4, [root, top]),
    ]);
  }

  List<int> chordNotes(String id, int root) => [
    for (final t in Chords.byId(id).tones) root + t,
  ];

  SoundSpec chord(
    String id, {
    Register register = Register.medium,
    int? rootMidi,
    bool arpeggiate = false,
  }) {
    final root = rootMidi ?? _root(register, 12) - 3;
    final notes = chordNotes(id, root);
    if (!arpeggiate) return SoundSpec([ToneEvent(0, 1.8, notes)]);
    return SoundSpec([
      for (var i = 0; i < notes.length; i++)
        ToneEvent(i * 0.35, 0.5, [notes[i]]),
      ToneEvent(notes.length * 0.35 + 0.2, 1.6, notes),
    ]);
  }

  SoundSpec scale(String id, {Register register = Register.medium, int? root}) {
    final r = root ?? register.rootC + random.nextInt(7) - 2;
    final steps = [...Scales.byId(id).steps, 12];
    return SoundSpec([
      for (var i = 0; i < steps.length; i++)
        ToneEvent(i * 0.34, 0.42, [r + steps[i]]),
    ]);
  }

  /// Root-position triads (bass follows the progression) or voice-led
  /// inversions that keep the upper notes close together.
  SoundSpec progression(
    String id, {
    Register register = Register.medium,
    bool inversions = false,
    int? keyRoot,
  }) {
    final p = Progressions.byId(id);
    final key = keyRoot ?? register.rootC - 7 + random.nextInt(8);
    final events = <ToneEvent>[];
    List<int>? previous;
    for (var i = 0; i < p.chords.length; i++) {
      final (offset, quality) = p.chords[i];
      var notes = chordNotes(quality, key + offset);
      if (inversions && previous != null) {
        notes = _voiceLead(previous, notes);
      }
      previous = notes;
      events.add(ToneEvent(i * 0.95, 0.9, [notes.first - 12, ...notes]));
    }
    return SoundSpec(events);
  }

  List<int> _voiceLead(List<int> previous, List<int> target) {
    final center = previous.reduce((a, b) => a + b) / previous.length;
    final moved = [
      for (final n in target)
        [
          n - 12,
          n,
          n + 12,
        ].reduce((a, b) => (a - center).abs() <= (b - center).abs() ? a : b),
    ]..sort();
    return moved;
  }

  SoundSpec item(
    TrainerKind kind,
    String itemId, {
    Register register = Register.medium,
    IntervalDirection direction = IntervalDirection.ascending,
    bool reference = false,
    bool inversions = false,
  }) => switch (kind) {
    TrainerKind.pitch => pitch(
      int.parse(itemId),
      register,
      reference: reference,
    ),
    TrainerKind.interval => interval(
      itemId,
      register: register,
      direction: direction,
    ),
    TrainerKind.chord => chord(itemId, register: register),
    TrainerKind.scale => scale(itemId, register: register),
    TrainerKind.progression => progression(
      itemId,
      register: register,
      inversions: inversions,
    ),
  };
}

/// Human label for an answer id.
String itemLabel(
  TrainerKind kind,
  String id, {
  NoteNotation notation = NoteNotation.solfege,
  int transposition = 0,
  bool long = false,
}) => switch (kind) {
  TrainerKind.pitch => PitchClass.name(
    int.parse(id) - transposition + 12,
    notation,
  ),
  TrainerKind.interval => long ? Intervals.byId(id).name : id,
  TrainerKind.chord => long ? Chords.byId(id).name : Chords.byId(id).label,
  TrainerKind.scale => Scales.byId(id).name,
  TrainerKind.progression => Progressions.byId(id).label,
};

String itemFeel(TrainerKind kind, String id) => switch (kind) {
  TrainerKind.pitch => tr(
    'Do\'ya göre yerini düşün, sonra adını söyle.',
    'Place it against the tonic, then name it.',
  ),
  TrainerKind.interval =>
    '${Intervals.byId(id).feel} ${tr('Örnek', 'Example')}: ${Intervals.byId(id).anchor}.',
  TrainerKind.chord => Chords.byId(id).feel,
  TrainerKind.scale => Scales.byId(id).feel,
  TrainerKind.progression => Progressions.byId(id).feel,
};
