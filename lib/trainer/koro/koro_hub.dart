import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../features/chord_exercise/chord_placeholder_screen.dart';
import '../../features/melody/melody_session_screen.dart';
import '../../features/rhythm_imitation/rhythm_imitation_screen.dart';
import '../../features/single_tone_session/single_tone_session_screen.dart';
import '../app/scope.dart';
import '../domain/music.dart';
import '../ui/kit.dart';
import 'aksak_patterns.dart';
import 'range_test.dart';
import 'voice_count.dart';

/// Choir workshop: single-voice and 2/3/4-voice preparation built on the
/// Harmonia capture/pitch core. Status tags stay honest about what is
/// experimental, draft or still waiting for recordings.
class KoroHub extends StatelessWidget {
  const KoroHub({super.key});

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
            legacy ? Theme(data: HarmoniaTheme.light(), child: screen) : screen,
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
        child: Column(
          children: [
            const TopBar(
              title: 'Koro Atölyesi',
              titleIcon: TrainerBadge(
                color: TC.indigo,
                icon: Icons.groups_rounded,
                size: 32,
              ),
              shadow: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C6CF8), TC.indigo],
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KORO HAZIRLIĞI',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 11.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tek sesliden dört sesliye',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Sesini tanı, ritmi ve ezgiyi tekrar et, aksak ölçülere alış, çok sesli dokuyu duy.',
                          style: TextStyle(color: Colors.white, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const _Section('TEST'),
                  _Row(
                    key: const Key('koro_range'),
                    icon: Icons.graphic_eq_rounded,
                    title: 'Ses aralığı testi',
                    subtitle: rangeText == null
                        ? 'En pes ve en tiz rahat notanı ölç'
                        : 'Son ölçüm: $rangeText',
                    tag: 'DENEYSEL',
                    onTap: () => _push(context, const RangeTestScreen()),
                  ),
                  const _Section('TEK SESLİ'),
                  _Row(
                    icon: Icons.record_voice_over_outlined,
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
                    icon: Icons.music_note_outlined,
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
                    icon: Icons.touch_app_outlined,
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
                    icon: Icons.timeline_rounded,
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
                    icon: Icons.layers_outlined,
                    title: 'Kaç ses duyuyorsun?',
                    subtitle: '2, 3 ya da 4 sesli dokuyu ayırt et',
                    tag: 'DİNLEME',
                    onTap: () => _push(context, const VoiceCountScreen()),
                  ),
                  _Row(
                    icon: Icons.piano_outlined,
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
                color: const Color(0xFFEDEBFE),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: TC.indigo),
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
                  Tag(tag, color: muted ? TC.muted : TC.indigo),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: TC.faint),
          ],
        ),
      ),
    ),
  );
}
