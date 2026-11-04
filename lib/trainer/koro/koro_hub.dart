import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../features/chord_exercise/chord_placeholder_screen.dart';
import '../../features/melody/melody_session_screen.dart';
import '../../features/rhythm_imitation/rhythm_imitation_screen.dart';
import '../../features/single_tone_session/single_tone_session_screen.dart';
import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../learn/skill_screen.dart';
import '../prepare/breath_screen.dart';
import '../settings/settings_tab.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'aksak_patterns.dart';
import 'clap_rhythm.dart';
import 'range_test.dart';
import 'voice_count.dart';
import '../../domain/lang.dart';

/// Exercise library ("Egzersizler" tab, for every learner — ADR-035): ear
/// training paths plus single-voice and 2/3/4-voice work built on the
/// Resonia capture/pitch core, filtered by category. Status tags stay honest
/// about what is experimental, draft or still waiting for recordings.
class KoroHub extends StatefulWidget {
  const KoroHub({super.key, this.asTab = false});

  /// Shown as the home "Egzersizler" tab: no back button, no own scaffold
  /// colour.
  final bool asTab;

  @override
  State<KoroHub> createState() => _KoroHubState();
}

enum _Category { all, warmup, ear, voice, rhythm, parts }

extension on _Category {
  String get label => switch (this) {
    _Category.all => tr('Tümü', 'All'),
    _Category.warmup => tr('Isınma', 'Warm-up'),
    _Category.ear => tr('Kulak', 'Ear'),
    _Category.voice => tr('Ses', 'Voice'),
    _Category.rhythm => tr('Ritim', 'Rhythm'),
    _Category.parts => tr('Çok sesli', 'Parts'),
  };

  String get section => switch (this) {
    _Category.all => '',
    _Category.warmup => tr('ISINMA', 'WARM-UP'),
    _Category.ear => tr('KULAK EĞİTİMİ', 'EAR TRAINING'),
    _Category.voice => tr('TEK SESLİ', 'ONE VOICE'),
    _Category.rhythm => tr('RİTİM', 'RHYTHM'),
    _Category.parts => tr('ÇOK SESLİ (2 / 3 / 4)', 'PARTS (2 / 3 / 4)'),
  };
}

class _Exercise {
  const _Exercise({
    this.key,
    required this.category,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tag,
    this.progress,
    this.muted = false,
  });
  final Key? key;
  final _Category category;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Status label (DENEYSEL, TASLAK …); null for measured lesson paths.
  final String? tag;

  /// Lesson-path completion; only ear-training paths have one.
  final double? progress;
  final bool muted;
}

class _KoroHubState extends State<KoroHub> {
  var _category = _Category.all;

  void _push(Widget screen, {bool legacy = false}) {
    final scope = TrainerScope.of(context);
    if (!scope.liveAudio && legacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Bu çalışma yalnız cihazda açılır.',
              'This exercise opens on a device only.',
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            legacy ? Theme(data: ResoniaTheme.light(), child: screen) : screen,
      ),
    );
  }

  List<_Exercise> _exercises() {
    final scope = TrainerScope.of(context);
    final store = scope.store;
    final experimental = tr('DENEYSEL', 'EXPERIMENTAL');
    final draft = tr('TASLAK', 'DRAFT');
    return [
      _Exercise(
        key: const Key('lib_breath'),
        category: _Category.warmup,
        icon: Ic.wind,
        title: tr('Nefes', 'Breath'),
        subtitle: tr(
          '2 dk · yönlendirmeli, mikrofonsuz',
          '2 min · guided, no microphone',
        ),
        onTap: () => _push(const BreathScreen()),
      ),
      for (final kind in TrainerKind.values)
        _Exercise(
          key: Key('skill_${kind.id}'),
          category: _Category.ear,
          icon: trainerIcon(kind),
          title: kind.shortTitle,
          subtitle: tr(
            '${store.completedCount(kind)} / '
                '${trainerPaths[kind]!.lessonCount} ders',
            '${store.completedCount(kind)} / '
                '${trainerPaths[kind]!.lessonCount} lessons',
          ),
          progress: store.mastery(kind),
          onTap: () => openSkill(context, kind),
        ),
      _Exercise(
        category: _Category.voice,
        icon: Ic.speech,
        title: tr('Dinle ve söyle', 'Listen and sing'),
        subtitle: tr(
          'Tek notayı duy, aynı perdeyi söyle',
          'Hear a single note, sing the same pitch',
        ),
        tag: experimental,
        onTap: () => _push(const SingleToneSessionScreen(), legacy: true),
      ),
      _Exercise(
        category: _Category.voice,
        icon: Ic.music2,
        title: tr('Ezgi tekrarı', 'Melody echo'),
        subtitle: tr(
          'Kısa ezgiyi dinle, hafızandan söyle',
          'Hear a short melody, sing it from memory',
        ),
        tag: experimental,
        onTap: () => _push(const MelodySessionScreen(), legacy: true),
      ),
      _Exercise(
        category: _Category.rhythm,
        icon: Ic.pointer,
        title: tr('Ritim tekrarı', 'Rhythm echo'),
        subtitle: tr(
          'Duyduğun ritmi dokunarak tekrar et',
          'Tap back the rhythm you hear',
        ),
        tag: draft,
        onTap: () =>
            _push(RhythmImitationScreen(history: scope.history), legacy: true),
      ),
      _Exercise(
        key: const Key('koro_clap'),
        category: _Category.rhythm,
        icon: Ic.hand,
        title: tr('Alkışla ritim', 'Clap the rhythm'),
        subtitle: tr(
          'Batı ve Türk müziğinden rastgele ritim',
          'Random Western and Turkish rhythms',
        ),
        tag: draft,
        onTap: () => _push(const ClapRhythmScreen()),
      ),
      _Exercise(
        key: const Key('koro_aksak'),
        category: _Category.rhythm,
        icon: Ic.chartLine,
        title: tr('Aksak ritim', 'Odd-metre rhythm'),
        subtitle: tr(
          '5/8, 7/8, 9/8 ve 10/8 kalıpları',
          '5/8, 7/8, 9/8 and 10/8 patterns',
        ),
        tag: draft,
        onTap: () => _push(
          RhythmImitationScreen(
            history: scope.history,
            patterns: draftAksakPatterns,
          ),
          legacy: true,
        ),
      ),
      _Exercise(
        key: const Key('koro_voices'),
        category: _Category.parts,
        icon: Ic.layers,
        title: tr('Kaç ses duyuyorsun?', 'How many voices do you hear?'),
        subtitle: tr(
          '2, 3 ya da 4 sesli dokuyu ayırt et',
          'Tell 2, 3 or 4-part textures apart',
        ),
        tag: tr('DİNLEME', 'LISTENING'),
        onTap: () => _push(const VoiceCountScreen()),
      ),
      _Exercise(
        category: _Category.parts,
        icon: Ic.piano,
        title: tr('2 / 3 / 4 sesli tekrar', '2 / 3 / 4-part echo'),
        subtitle: tr(
          'Piyano kaydındaki sesleri tek tek söyle',
          'Sing each part of a piano recording in turn',
        ),
        tag: tr('YAKINDA', 'COMING SOON'),
        muted: true,
        onTap: () => _push(const ChordPlaceholderScreen(), legacy: true),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final range = store.koroRange?.split('-').map(int.tryParse).toList();
    final rangeText =
        range != null && range.length == 2 && range.every((m) => m != null)
        ? '${PitchClass.midiName(range[0]!, store.notation)} – ${PitchClass.midiName(range[1]!, store.notation)}'
        : null;
    final all = _exercises();
    final shown = _category == _Category.all
        ? [
            for (final c in _Category.values.skip(1))
              if (all.any((e) => e.category == c)) c,
          ]
        : [_category];
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        bottom: !widget.asTab,
        child: Column(
          children: [
            if (widget.asTab)
              tabHeader(
                tr('Keşfet', 'Explore'),
                tr('Egzersizler', 'Exercises'),
                store.part == null
                    ? tr(
                        'Kulak, ses aralığı, ritim, çok seslilik',
                        'Ear, range, rhythm, part singing',
                      )
                    : tr(
                        '${store.part!.title} aralığında çalışma',
                        'Practice in the ${store.part!.title.toLowerCase()} range',
                      ),
                trailing: const ProfileButton(),
              )
            else
              TopBar(title: tr('Egzersizler', 'Exercises')),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
              key: const Key('lib_categories'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in _Category.values) ...[
                    if (c != _Category.all) const SizedBox(width: 8),
                    _CategoryChip(
                      key: Key('cat_${c.name}'),
                      label: c.label,
                      selected: c == _category,
                      onTap: () => setState(() => _category = c),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  if (_category == _Category.all ||
                      _category == _Category.voice) ...[
                    const SizedBox(height: 8),
                    _RangeCard(
                      rangeText: rangeText,
                      onTap: () => _push(const RangeTestScreen()),
                    ),
                  ],
                  for (final c in shown) ...[
                    _Section(c.section),
                    _Grid([
                      for (final e in all)
                        if (e.category == c) e,
                    ]),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      'Mikrofon ölçümleri deneyseldir; cihaz ve insan sesi doğrulaması tamamlanmadı. '
                          'Sonuçlar puan ya da sınav notu değildir.',
                      'Microphone measurements are experimental; device and human voice validation is not complete. '
                          'Results are not scores or exam marks.',
                    ),
                    style: TT.small,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10, left: 4),
    child: Text(text, style: TT.caps),
  );
}

/// Filter pill; 48 dp tall hit area around a 38 dp pill.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: () {
        tapHaptic();
        onTap();
      },
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: ShapeDecoration(
              color: selected ? TC.ink : Colors.white,
              shape: StadiumBorder(
                side: selected
                    ? BorderSide.none
                    : const BorderSide(color: TC.line),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : TC.body,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Wide card on top: the (experimental) range test and its last result.
class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.rangeText, required this.onTap});
  final String? rangeText;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('koro_range'),
    color: TC.primarySoft,
    padding: const EdgeInsets.all(16),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: TC.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Ic.audioLines, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Ses aralığı testi', 'Vocal range test'),
                style: TT.title,
              ),
              const SizedBox(height: 2),
              Text(
                rangeText == null
                    ? tr(
                        'Piyanoyu dinle, tekrar et; aralığın çıksın',
                        'Hear the piano, repeat it; find your range',
                      )
                    : tr(
                        'Son ölçüm: $rangeText · taslak',
                        'Last measured: $rangeText · draft',
                      ),
                style: TT.small.copyWith(color: TC.body),
              ),
              const SizedBox(height: 6),
              Tag(tr('DENEYSEL', 'EXPERIMENTAL'), color: TC.koro),
            ],
          ),
        ),
        const Icon(Ic.chevronRight, color: TC.primary),
      ],
    ),
  );
}

/// Two columns; each row as tall as its taller card (text scale safe).
class _Grid extends StatelessWidget {
  const _Grid(this.items);
  final List<_Exercise> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ExerciseCard(items[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < items.length
                      ? _ExerciseCard(items[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(this.e);
  final _Exercise e;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: e.muted ? 0.7 : 1,
    child: AppCard(
      key: e.key,
      padding: const EdgeInsets.all(14),
      onTap: e.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: TC.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(e.icon, color: TC.primary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(e.title, style: TT.title),
          const SizedBox(height: 2),
          Text(e.subtitle, style: TT.small),
          const SizedBox(height: 10),
          const Spacer(),
          if (e.progress != null)
            ProgressBar(value: e.progress!, height: 4)
          else if (e.tag != null)
            Tag(e.tag!, color: e.muted ? TC.muted : TC.koro),
        ],
      ),
    ),
  );
}
