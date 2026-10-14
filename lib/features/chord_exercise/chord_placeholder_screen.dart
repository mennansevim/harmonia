import 'package:flutter/material.dart';

import '../../domain/audio/chord_recording_catalog.dart';
import '../../infrastructure/audio/asset_chord_recording_catalog.dart';
import '../common/content_status_panel.dart';

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
    _catalog = _repository.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('2 / 3 / 4 Ses')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Piyanoyu dinle, sesleri tekrar et',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Birlikte çalınmış piyano kaydını dinleyecek, duyduğun notaları '
              'birer birer söyleyeceksin. Kayıtlar eklendiğinde bu bölüm açılacak.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Şimdilik ses çalınmaz, mikrofon açılmaz ve puan üretilmez.',
            ),
            const SizedBox(height: 24),
            FutureBuilder<ChordRecordingCatalog>(
              future: _catalog,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ContentStatusPanel(
                    kind: ContentStatusKind.error,
                    message:
                        'Örnek listesi yüklenemedi. Ses testi başlatılmadı.',
                    onRetry: () {
                      final pending = _repository.load();
                      setState(() {
                        _catalog = pending;
                      });
                    },
                  );
                }
                if (!snapshot.hasData) {
                  return const ContentStatusPanel(
                    kind: ContentStatusKind.loading,
                    message: 'Örnek listesi yükleniyor…',
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
                              FilledButton.icon(
                                key: Key('chord_listen_${slot.voiceCount}'),
                                onPressed: null,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Piyano örneğini dinle'),
                              ),
                              OutlinedButton(
                                key: Key('chord_repeat_${slot.voiceCount}'),
                                onPressed: null,
                                child: const Text('Sırayla tekrar et'),
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
        ),
      ),
    ),
  );
}
