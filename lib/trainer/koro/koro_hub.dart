import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../features/chord_exercise/chord_placeholder_screen.dart';
import '../../features/melody/melody_session_screen.dart';
import '../../features/rhythm_imitation/rhythm_imitation_screen.dart';
import '../../features/single_tone_session/single_tone_session_screen.dart';
import '../app/scope.dart';
import '../domain/music.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'aksak_patterns.dart';
import 'clap_rhythm.dart';
import 'range_test.dart';
import 'voice_count.dart';
import '../../domain/lang.dart';

/// Voice workshop ("Ses" tab, for every learner — ADR-035): single-voice and
/// 2/3/4-voice work built on the Resonia capture/pitch core. Status tags stay honest about what is
/// experimental, draft or still waiting for recordings.
class KoroHub extends StatelessWidget {
  const KoroHub({super.key, this.asTab = false});

  /// Shown as the home "Ses" tab: no back button, no own scaffold colour.
  final bool asTab;

  void _push(BuildContext context, Widget screen, {bool legacy = false}) {
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

  @override
  Widget build(BuildContext context) {
    final scope = TrainerScope.of(context);
    final store = scope.store;
    final range = store.koroRange?.split('-').map(int.tryParse).toList();
    final rangeText =
        range != null && range.length == 2 && range.every((m) => m != null)
        ? '${PitchClass.midiName(range[0]!, store.notation)} – ${PitchClass.midiName(range[1]!, store.notation)}'
        : null;
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        bottom: !asTab,
        child: Column(
          children: [
            if (asTab)
              tabHeader(
                tr('Sesini tanı', 'Know your voice'),
                tr('Ses Atölyesi', 'Voice Lab'),
                store.part == null
                    ? tr(
                        'Ses aralığı, ritim, ezgi, çok seslilik',
                        'Range, rhythm, melody, part singing',
                      )
                    : tr(
                        '${store.part!.title} aralığında çalışma',
                        'Practice in the ${store.part!.title.toLowerCase()} range',
                      ),
              )
            else
              TopBar(title: tr('Ses Atölyesi', 'Voice Lab')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  HeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('SES ÇALIŞMASI', 'VOICE WORK'),
                          style: TT.heroCaps,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr(
                            'Tek sesliden dört sesliye',
                            'From one voice to four',
                          ),
                          style: TT.display.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr(
                            'Sesini tanı, ritmi ve ezgiyi tekrar et, aksak ölçülere alış, çok sesli dokuyu duy.',
                            'Know your voice, repeat rhythms and melodies, get used to odd metres, hear part textures.',
                          ),
                          style: TextStyle(
                            color: TC.heroMuted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Section(tr('SES TESPİTİ', 'VOICE DETECTION')),
                  _Row(
                    key: const Key('koro_range'),
                    icon: Ic.audioLines,
                    title: tr('Ses aralığı testi', 'Vocal range test'),
                    subtitle: rangeText == null
                        ? tr(
                            'Piyanoyu dinle, tekrar et; aralığın çıksın',
                            'Hear the piano, repeat it; find your range',
                          )
                        : tr(
                            'Son ölçüm: $rangeText',
                            'Last measured: $rangeText',
                          ),
                    tag: tr('DENEYSEL', 'EXPERIMENTAL'),
                    onTap: () => _push(context, const RangeTestScreen()),
                  ),
                  _Section(tr('TEK SESLİ', 'ONE VOICE')),
                  _Row(
                    icon: Ic.speech,
                    title: tr('Dinle ve söyle', 'Listen and sing'),
                    subtitle: tr(
                      'Tek notayı duy, aynı perdeyi söyle',
                      'Hear a single note, sing the same pitch',
                    ),
                    tag: tr('DENEYSEL', 'EXPERIMENTAL'),
                    onTap: () => _push(
                      context,
                      const SingleToneSessionScreen(),
                      legacy: true,
                    ),
                  ),
                  _Row(
                    icon: Ic.music2,
                    title: tr('Ezgi tekrarı', 'Melody echo'),
                    subtitle: tr(
                      'Kısa ezgiyi dinle, hafızandan söyle',
                      'Hear a short melody, sing it from memory',
                    ),
                    tag: tr('DENEYSEL', 'EXPERIMENTAL'),
                    onTap: () => _push(
                      context,
                      const MelodySessionScreen(),
                      legacy: true,
                    ),
                  ),
                  _Row(
                    icon: Ic.pointer,
                    title: tr('Ritim tekrarı', 'Rhythm echo'),
                    subtitle: tr(
                      'Duyduğun ritmi dokunarak tekrar et',
                      'Tap back the rhythm you hear',
                    ),
                    tag: tr('TASLAK', 'DRAFT'),
                    onTap: () => _push(
                      context,
                      RhythmImitationScreen(history: scope.history),
                      legacy: true,
                    ),
                  ),
                  _Row(
                    key: const Key('koro_clap'),
                    icon: Ic.hand,
                    title: tr('Alkışla ritim', 'Clap the rhythm'),
                    subtitle: tr(
                      'Batı ve Türk müziğinden rastgele ritim, ellerle senkron',
                      'Random Western and Turkish rhythms, in time with the hands',
                    ),
                    tag: tr('TASLAK', 'DRAFT'),
                    onTap: () => _push(context, const ClapRhythmScreen()),
                  ),
                  _Row(
                    key: const Key('koro_aksak'),
                    icon: Ic.chartLine,
                    title: tr('Aksak ritim', 'Odd-metre rhythm'),
                    subtitle: tr(
                      '5/8, 7/8, 9/8 ve 10/8 kalıpları',
                      '5/8, 7/8, 9/8 and 10/8 patterns',
                    ),
                    tag: tr('TASLAK', 'DRAFT'),
                    onTap: () => _push(
                      context,
                      RhythmImitationScreen(
                        history: scope.history,
                        patterns: draftAksakPatterns,
                      ),
                      legacy: true,
                    ),
                  ),
                  _Section(tr('ÇOK SESLİ (2 / 3 / 4)', 'PARTS (2 / 3 / 4)')),
                  _Row(
                    key: const Key('koro_voices'),
                    icon: Ic.layers,
                    title: tr(
                      'Kaç ses duyuyorsun?',
                      'How many voices do you hear?',
                    ),
                    subtitle: tr(
                      '2, 3 ya da 4 sesli dokuyu ayırt et',
                      'Tell 2, 3 or 4-part textures apart',
                    ),
                    tag: tr('DİNLEME', 'LISTENING'),
                    onTap: () => _push(context, const VoiceCountScreen()),
                  ),
                  _Row(
                    icon: Ic.piano,
                    title: tr('2 / 3 / 4 sesli tekrar', '2 / 3 / 4-part echo'),
                    subtitle: tr(
                      'Piyano kaydındaki sesleri tek tek söyle',
                      'Sing each part of a piano recording in turn',
                    ),
                    tag: tr('YAKINDA', 'COMING SOON'),
                    muted: true,
                    onTap: () => _push(
                      context,
                      const ChordPlaceholderScreen(),
                      legacy: true,
                    ),
                  ),
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

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
    this.muted = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;
  final bool muted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Opacity(
      opacity: muted ? 0.7 : 1,
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEBFF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: TC.koro),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TT.title),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TT.small),
                  const SizedBox(height: 6),
                  Tag(tag, color: muted ? TC.muted : TC.koro),
                ],
              ),
            ),
            const Icon(Ic.chevronRight, color: TC.faint),
          ],
        ),
      ),
    ),
  );
}
