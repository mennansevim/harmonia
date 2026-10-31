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
import 'range_test.dart';
import 'voice_count.dart';

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
        const SnackBar(content: Text('Bu çalışma yalnız cihazda açılır.')),
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
                'Sesini tanı',
                'Ses Atölyesi',
                store.part == null
                    ? 'Ses aralığı, ritim, ezgi, çok seslilik'
                    : '${store.part!.title} aralığında çalışma',
              )
            else
              const TopBar(title: 'Ses Atölyesi'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  HeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SES ÇALIŞMASI', style: TT.heroCaps),
                        const SizedBox(height: 12),
                        Text(
                          'Tek sesliden dört sesliye',
                          style: TT.display.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sesini tanı, ritmi ve ezgiyi tekrar et, aksak ölçülere alış, çok sesli dokuyu duy.',
                          style: TextStyle(
                            color: TC.heroMuted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _Section('TEST'),
                  _Row(
                    key: const Key('koro_range'),
                    icon: Ic.audioLines,
                    title: 'Ses aralığı testi',
                    subtitle: rangeText == null
                        ? 'En pes ve en tiz rahat notanı ölç'
                        : 'Son ölçüm: $rangeText',
                    tag: 'DENEYSEL',
                    onTap: () => _push(context, const RangeTestScreen()),
                  ),
                  const _Section('TEK SESLİ'),
                  _Row(
                    icon: Ic.speech,
                    title: 'Dinle ve söyle',
                    subtitle: 'Tek notayı duy, aynı perdeyi söyle',
                    tag: 'DENEYSEL',
                    onTap: () => _push(
                      context,
                      const SingleToneSessionScreen(),
                      legacy: true,
                    ),
                  ),
                  _Row(
                    icon: Ic.music2,
                    title: 'Ezgi tekrarı',
                    subtitle: 'Kısa ezgiyi dinle, hafızandan söyle',
                    tag: 'DENEYSEL',
                    onTap: () => _push(
                      context,
                      const MelodySessionScreen(),
                      legacy: true,
                    ),
                  ),
                  _Row(
                    icon: Ic.pointer,
                    title: 'Ritim tekrarı',
                    subtitle: 'Duyduğun ritmi dokunarak tekrar et',
                    tag: 'TASLAK',
                    onTap: () => _push(
                      context,
                      RhythmImitationScreen(history: scope.history),
                      legacy: true,
                    ),
                  ),
                  _Row(
                    key: const Key('koro_aksak'),
                    icon: Ic.chartLine,
                    title: 'Aksak ritim',
                    subtitle: '5/8, 7/8, 9/8 ve 10/8 kalıpları',
                    tag: 'TASLAK',
                    onTap: () => _push(
                      context,
                      RhythmImitationScreen(
                        history: scope.history,
                        patterns: draftAksakPatterns,
                      ),
                      legacy: true,
                    ),
                  ),
                  const _Section('ÇOK SESLİ (2 / 3 / 4)'),
                  _Row(
                    key: const Key('koro_voices'),
                    icon: Ic.layers,
                    title: 'Kaç ses duyuyorsun?',
                    subtitle: '2, 3 ya da 4 sesli dokuyu ayırt et',
                    tag: 'DİNLEME',
                    onTap: () => _push(context, const VoiceCountScreen()),
                  ),
                  _Row(
                    icon: Ic.piano,
                    title: '2 / 3 / 4 sesli tekrar',
                    subtitle: 'Piyano kaydındaki sesleri tek tek söyle',
                    tag: 'KAYIT BEKLENİYOR',
                    muted: true,
                    onTap: () => _push(
                      context,
                      const ChordPlaceholderScreen(),
                      legacy: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mikrofon ölçümleri deneyseldir; cihaz ve insan sesi doğrulaması tamamlanmadı. '
                    'Sonuçlar puan ya da sınav notu değildir.',
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
