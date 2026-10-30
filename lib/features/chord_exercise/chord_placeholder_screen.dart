import 'package:flutter/material.dart';

import '../../domain/audio/chord_recording_catalog.dart';
import '../../infrastructure/audio/asset_chord_recording_catalog.dart';
import '../../app/theme/resonia_theme.dart';
import '../common/content_status_panel.dart';
import '../common/ui/resonia_ui.dart';

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
    counter: 'Kapalı',
    closeLabel: 'Piyano örneklerini kapat',
    top: [
      const Align(
        alignment: AlignmentDirectional.centerStart,
        child: StatusPill('Kayıt bekleniyor'),
      ),
      const SizedBox(height: ResoniaSpacing.md),
      Text(
        '2 / 3 / 4 sesli piyano',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: ResoniaSpacing.sm),
      const Text(
        'Birlikte dinle, tek tek söyle. Kayıtlar doğrulanınca bu bölüm açılacak.',
      ),
      const SizedBox(height: 8),
      const Text('Şimdilik ses çalınmaz, mikrofon açılmaz ve puan üretilmez.'),
      ExpansionTile(
        key: const Key('chord_help'),
        tilePadding: EdgeInsets.zero,
        title: const Text('Nasıl çalışacak?'),
        children: const [
          Text(
            'Hazır piyano kaydındaki sesleri birlikte dinleyecek, referans bittikten sonra notaları birer birer söyleyeceksin. Kayıtlar geldiğinde nota, oktav, akort, ses kalitesi ve kullanım hakları birlikte kontrol edilecek. Canlı akor tanıma yapılmıyor.',
          ),
        ],
      ),
      const SizedBox(height: ResoniaSpacing.md),
      FutureBuilder<ChordRecordingCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ContentStatusPanel(
              key: Key('chord_loading'),
              kind: ContentStatusKind.loading,
              message: 'Örnek listesi yükleniyor…',
            );
          }
          if (snapshot.hasError) {
            return ContentStatusPanel(
              key: const Key('chord_error'),
              kind: ContentStatusKind.error,
              message: 'Örnek listesi yüklenemedi. Ses testi başlatılmadı.',
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
                          '${slot.voiceCount} sesli örnek',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('Piyano kaydı bekleniyor'),
                        const SizedBox(height: 12),
                        ChunkyButton(
                          key: Key('chord_listen_${slot.voiceCount}'),
                          onPressed: null,
                          icon: Icons.play_arrow,
                          tone: ChunkyTone.neutral,
                          label: 'Piyano örneğini dinle',
                        ),
                        const SizedBox(height: ResoniaSpacing.sm),
                        ChunkyButton(
                          key: Key('chord_repeat_${slot.voiceCount}'),
                          onPressed: null,
                          tone: ChunkyTone.neutral,
                          label: 'Sırayla tekrar et',
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
