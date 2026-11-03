import 'package:flutter/material.dart';

import '../../domain/audio/chord_recording_catalog.dart';
import '../../infrastructure/audio/asset_chord_recording_catalog.dart';
import '../../app/theme/resonia_theme.dart';
import '../common/content_status_panel.dart';
import '../common/ui/resonia_ui.dart';
import '../../domain/lang.dart';

/// Prerecorded chord placeholders only: no permission, player or scorer.
class ChordPlaceholderScreen extends StatefulWidget {
  const ChordPlaceholderScreen({super.key, this.repository});
  final ChordRecordingCatalogRepository? repository;

  @override
  State<ChordPlaceholderScreen> createState() => _ChordPlaceholderScreenState();
}

class _ChordPlaceholderScreenState extends State<ChordPlaceholderScreen> {
  late final ChordRecordingCatalogRepository _repository;
  late Future<ChordRecordingCatalog> _catalog;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AssetChordRecordingCatalog();
    _catalog = _loadForView();
  }

  Future<ChordRecordingCatalog> _loadForView() {
    final future = _repository.load();
    // Observe immediate failures before the next FutureBuilder frame while
    // returning the original future so the user still sees the load error.
    future.ignore();
    return future;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _catalog = _loadForView();
    });
  }

  @override
  Widget build(BuildContext context) => LessonScaffold(
    progress: null,
    counter: tr('Kapalı', 'Closed'),
    closeLabel: tr('Piyano örneklerini kapat', 'Close piano examples'),
    top: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: StatusPill(tr('Kayıt bekleniyor', 'Awaiting recordings')),
      ),
      const SizedBox(height: ResoniaSpacing.md),
      Text(
        tr('2 / 3 / 4 sesli piyano', '2 / 3 / 4-part piano'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: ResoniaSpacing.sm),
      Text(
        tr(
          'Birlikte dinle, tek tek söyle. Kayıtlar doğrulanınca bu bölüm açılacak.',
          'Hear them together, sing them one by one. This section opens once the recordings are verified.',
        ),
      ),
      const SizedBox(height: 8),
      Text(
        tr(
          'Şimdilik ses çalınmaz, mikrofon açılmaz ve puan üretilmez.',
          'For now nothing plays, the microphone stays off and no score is made.',
        ),
      ),
      ExpansionTile(
        key: const Key('chord_help'),
        tilePadding: EdgeInsets.zero,
        title: Text(tr('Nasıl çalışacak?', 'How will it work?')),
        children: [
          Text(
            tr(
              'Hazır piyano kaydındaki sesleri birlikte dinleyecek, referans bittikten sonra notaları birer birer söyleyeceksin. Kayıtlar geldiğinde nota, oktav, akort, ses kalitesi ve kullanım hakları birlikte kontrol edilecek. Canlı akor tanıma yapılmıyor.',
              'You will hear the notes of a ready-made piano recording together, then sing them one by one after the reference. When the recordings arrive, notes, octaves, tuning, sound quality and usage rights will be checked together. There is no live chord recognition.',
            ),
          ),
        ],
      ),
      const SizedBox(height: ResoniaSpacing.md),
      FutureBuilder<ChordRecordingCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ContentStatusPanel(
              key: Key('chord_loading'),
              kind: ContentStatusKind.loading,
              message: tr(
                'Örnek listesi yükleniyor…',
                'Loading the example list…',
              ),
            );
          }
          if (snapshot.hasError) {
            return ContentStatusPanel(
              key: const Key('chord_error'),
              kind: ContentStatusKind.error,
              message: tr(
                'Örnek listesi yüklenemedi. Ses testi başlatılmadı.',
                'The example list could not load. No audio test was started.',
              ),
              onRetry: _reload,
            );
          }
          return Column(
            children: [
              for (final slot in snapshot.data!.slots)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(
                            '${slot.voiceCount} sesli örnek',
                            '${slot.voiceCount}-part example',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            'Piyano kaydı bekleniyor',
                            'Awaiting the piano recording',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ChunkyButton(
                          key: Key('chord_listen_${slot.voiceCount}'),
                          onPressed: null,
                          icon: Icons.play_arrow,
                          tone: ChunkyTone.neutral,
                          label: tr(
                            'Piyano örneğini dinle',
                            'Hear the piano example',
                          ),
                        ),
                        const SizedBox(height: ResoniaSpacing.sm),
                        ChunkyButton(
                          key: Key('chord_repeat_${slot.voiceCount}'),
                          onPressed: null,
                          tone: ChunkyTone.neutral,
                          label: tr('Sırayla tekrar et', 'Repeat in turn'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
