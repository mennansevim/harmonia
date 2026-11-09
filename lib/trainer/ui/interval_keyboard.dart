import 'package:flutter/material.dart';

import '../../domain/lang.dart';
import '../domain/music.dart';
import 'kit.dart';

/// Two octaves of keyboard showing an interval as a key count (QA-INT-01):
/// the example's two notes are filled, and every key from the first note
/// up carries its semitone number, so "a minor 2nd is one key" is seen,
/// not only read. Silent: it never plays, so it can sit on a quiz screen
/// without giving the answer away.
class IntervalKeyboard extends StatelessWidget {
  const IntervalKeyboard({
    super.key,
    required this.interval,
    this.color = TC.primary,
    this.height = 96,
  });

  final IntervalType interval;
  final Color color;
  final double height;

  static const _whites = [0, 2, 4, 5, 7, 9, 11];
  static const _blackAfterWhite = {1: 1, 3: 2, 6: 4, 8: 5, 10: 6};

  @override
  Widget build(BuildContext context) {
    final root = interval.exampleRoot;
    final top = root + interval.semitones;
    final from = PitchClass.name(root, NoteNames.current);
    final to = PitchClass.name(top, NoteNames.current);
    final n = interval.semitones;
    return Semantics(
      label: tr(
        'Klavyede $from → $to: $n yarım ses',
        'On the keyboard $from → $to: $n semitones',
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth / 14;
                Widget key(int k, bool black, double left) {
                  final step = k - root;
                  final end = k == root || k == top;
                  final inside = step > 0 && step < n;
                  final fill = end
                      ? color
                      : inside
                      ? soft(color)
                      : black
                      ? TC.ink
                      : Colors.white;
                  final ink = end
                      ? Colors.white
                      : black && !inside
                      ? Colors.white
                      : color;
                  final label = step > 0 && step <= n ? '$step' : null;
                  return Positioned(
                    left: left,
                    top: 0,
                    width: black ? w * 0.62 : w,
                    height: black ? height * 0.6 : height,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: black ? 0 : 0.6),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(5),
                        ),
                        border: Border.all(
                          color: black ? TC.ink : TC.line,
                          width: 0.8,
                        ),
                      ),
                      child: label == null
                          ? null
                          : FittedBox(
                              child: Text(
                                label,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    for (var o = 0; o < 2; o++)
                      for (var i = 0; i < 7; i++)
                        key(o * 12 + _whites[i], false, (o * 7 + i) * w),
                    for (var o = 0; o < 2; o++)
                      for (final e in _blackAfterWhite.entries)
                        key(
                          o * 12 + e.key,
                          true,
                          (o * 7 + e.value) * w - w * 0.31,
                        ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              '$from → $to · her tuş bir yarım ses · $n yarım ses',
              '$from → $to · each key is one semitone · $n semitones',
            ),
            textAlign: TextAlign.center,
            style: TT.small,
          ),
        ],
      ),
    );
  }
}

/// Two octaves of keyboard with a chord's or a scale's notes filled and
/// named on their keys (QA-INT-02). [tones] are semitones above [root].
/// Silent, like [IntervalKeyboard].
class NotesKeyboard extends StatelessWidget {
  const NotesKeyboard({
    super.key,
    required this.root,
    required this.tones,
    required this.caption,
    this.color = TC.primary,
    this.height = 96,
  });

  final int root;
  final List<int> tones;
  final String caption;
  final Color color;
  final double height;

  static const _whites = [0, 2, 4, 5, 7, 9, 11];
  static const _blackAfterWhite = {1: 1, 3: 2, 6: 4, 8: 5, 10: 6};

  /// A chord: its notes, and the gaps between them in semitones.
  factory NotesKeyboard.chord(ChordQuality chord, {Color color = TC.primary}) {
    final names = [
      for (final t in chord.tones)
        PitchClass.name(chord.exampleRoot + t, NoteNames.current),
    ];
    final gaps = [
      for (var i = 1; i < chord.tones.length; i++)
        chord.tones[i] - chord.tones[i - 1],
    ];
    return NotesKeyboard(
      key: const Key('notes_keyboard'),
      root: chord.exampleRoot,
      tones: chord.tones,
      color: color,
      caption: tr(
        '${names.join(' + ')} birlikte · aralar ${gaps.join(' + ')} yarım ses',
        '${names.join(' + ')} together · gaps of ${gaps.join(' + ')} semitones',
      ),
    );
  }

  /// A scale: its notes up to the octave and the step pattern
  /// (T/W = whole tone, 2 keys; Y/H = semitone, 1 key).
  factory NotesKeyboard.scale(ScaleType scale, {Color color = TC.primary}) {
    final steps = [...scale.steps, 12];
    final pattern = [
      for (var i = 1; i < steps.length; i++)
        switch (steps[i] - steps[i - 1]) {
          1 => tr('Y', 'H'),
          2 => tr('T', 'W'),
          final n => '$n',
        },
    ];
    return NotesKeyboard(
      key: const Key('notes_keyboard'),
      root: scale.exampleRoot,
      tones: steps,
      color: color,
      caption: tr(
        'Adımlar: ${pattern.join(' ')} · T = 2 tuş, Y = 1 tuş',
        'Steps: ${pattern.join(' ')} · W = 2 keys, H = 1 key',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = {for (final t in tones) root + t};
    final names = [
      for (final t in tones) PitchClass.name(root + t, NoteNames.current),
    ];
    return Semantics(
      label: '${names.join(', ')}. $caption',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth / 14;
                Widget key(int k, bool black, double left) {
                  final lit = on.contains(k);
                  return Positioned(
                    left: left,
                    top: 0,
                    width: black ? w * 0.62 : w,
                    height: black ? height * 0.6 : height,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: black ? 0 : 0.6),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.fromLTRB(1, 0, 1, 4),
                      decoration: BoxDecoration(
                        color: lit
                            ? color
                            : black
                            ? TC.ink
                            : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(5),
                        ),
                        border: Border.all(
                          color: black ? TC.ink : TC.line,
                          width: 0.8,
                        ),
                      ),
                      child: !lit
                          ? null
                          : FittedBox(
                              child: Text(
                                PitchClass.name(k, NoteNames.current),
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    for (var o = 0; o < 2; o++)
                      for (var i = 0; i < 7; i++)
                        key(o * 12 + _whites[i], false, (o * 7 + i) * w),
                    for (var o = 0; o < 2; o++)
                      for (final e in _blackAfterWhite.entries)
                        key(
                          o * 12 + e.key,
                          true,
                          (o * 7 + e.value) * w - w * 0.31,
                        ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(caption, textAlign: TextAlign.center, style: TT.small),
        ],
      ),
    );
  }
}
