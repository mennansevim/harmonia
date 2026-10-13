import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/melody_session.dart';
import '../../application/single_tone_session.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/synthetic_melody_backend.dart';

/// Diagnostic only: no note matching, memory score, mastery or history entry.
class MelodySessionScreen extends StatefulWidget {
  const MelodySessionScreen({super.key, this.backend, this.worker});
  final MelodyReferenceBackend? backend;
  final RecordingPitchWorker? worker;
  @override
  State<MelodySessionScreen> createState() => _MelodySessionScreenState();
}

class _MelodySessionScreenState extends State<MelodySessionScreen>
    with WidgetsBindingObserver {
  late final MelodySessionController session;
  bool details = false;
  @override
  void initState() {
    super.initState();
    session = MelodySessionController(
      backend:
          widget.backend ??
          SyntheticMelodyBackend.mobile(
            DiagnosticMelodyReference(
              id: 'diagnostic-three-tone',
              contentVersion: 'synthetic-1',
              frequenciesHz: [261.63, 329.63, 392.0],
            ),
          ),
      worker: widget.worker ?? IsolateRecordingPitchWorker(),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs may cause inactive; background really cancels.
    if (state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      unawaited(session.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kısa ezgi tekrarı')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(HarmoniaSpacing.lg),
          children: [
            Text(
              '${session.reference.frequenciesHz.length} ses: dinle ve söyle',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Deneysel • Referans sentetik tonlardan oluşur, piyano kaydı değildir. Nota doğruluğu, sıra ve hafıza puanı verilmez. Eğitimci ve cihaz doğrulaması bekliyor.',
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            Text(
              session.calibration?.isUsable == true
                  ? 'Ortam ölçüldü. Çıkış değişirse veya ölçüm eskirse yeniden ölç.'
                  : 'Önce 2 saniye sessiz kalıp ortamı ölç.',
            ),
            OutlinedButton(
              key: const Key('melody_calibrate'),
              onPressed: session.canStart ? session.calibrate : null,
              child: const Text('Ortamı ölç (2 sn sessizlik)'),
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            const Text(
              'Tonları sırayla dinle. Referans bitip “Şimdi söyle” yazısı gelince aynı sırayla tekrar et. Yanıt penceresi en fazla 8 saniye. Kayıt yerel analiz için okununca silinir; cihazdan gönderilmez.',
            ),
            FilledButton.icon(
              key: const Key('melody_start'),
              onPressed: session.canStart
                  ? () {
                      setState(() => details = false);
                      unawaited(session.startAttempt());
                    }
                  : null,
              icon: const Icon(Icons.hearing),
              label: const Text('Dinle ve söyle'),
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                _phase(session.phase),
                key: const Key('melody_status'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (session.canFinishResponse)
              FilledButton(
                key: const Key('melody_finish'),
                onPressed: session.finishResponse,
                child: const Text('Bitirdim'),
              ),
            if (!session.canStart)
              TextButton(
                key: const Key('melody_cancel'),
                onPressed: session.cancel,
                child: const Text('İptal et'),
              ),
            if (session.outcome case final outcome?) ...[
              const SizedBox(height: HarmoniaSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(HarmoniaSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outcome.needsRetry
                            ? 'Ölçüm alınamadı — puanlanmadı'
                            : 'Yerel analiz tamamlandı — puanlanmadı',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        outcome.needsRetry
                            ? _retry(outcome.retryReason!)
                            : 'Bulunan bölümler deneysel frekans adaylarıdır; insan sesi veya doğru nota kanıtı değildir. Yeniden çalışabilirsin.',
                      ),
                      Text(
                        'Tamamlanan referans: ${outcome.referencePlays} (bu deneme). Bu sayı duyma veya hafıza ölçümü değildir.',
                      ),
                    ],
                  ),
                ),
              ),
              if (outcome.segments != null)
                TextButton(
                  key: const Key('melody_details'),
                  onPressed: () => setState(() => details = !details),
                  child: Text(details ? 'Ayrıntıyı gizle' : 'Ölçüm ayrıntısı'),
                ),
              if (outcome.segments case final evidence? when details) ...[
                Text('Kayıt kaynağı: ${evidence.provenance.source.name}'),
                Text('Aday bölüm sayısı: ${evidence.segments.length}'),
                if (evidence.segments.isEmpty)
                  const Text(
                    'Kararlı frekans adayı bulunamadı. Bu, öğrenciye sıfır puan değildir.',
                  ),
                for (var i = 0; i < evidence.segments.length; i++)
                  Text(
                    'Aday ${i + 1}: ${evidence.segments[i].frequencyHz.toStringAsFixed(1)} Hz',
                  ),
                Text(
                  'Kısa/kararsız bölüm frame sayısı: ${evidence.discardedFrameIndices.length}',
                ),
                const Text(
                  'Bölüm sınırları analiz pencerelerinden tahmin edilir; gerçek nota başlangıcı ve süresi doğrulanmadı. Sonuç geçmişe veya beceri ilerlemesine kaydedilmez.',
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}

String _phase(SingleToneSessionPhase phase) => switch (phase) {
  SingleToneSessionPhase.idle => 'Hazır. Mikrofon kapalı.',
  SingleToneSessionPhase.calibrating =>
    'Ortam ölçülüyor. Sessiz kal; mikrofon açık.',
  SingleToneSessionPhase.preparing => 'Hazırlanıyor…',
  SingleToneSessionPhase.referencePlaying =>
    'Referansı dinle. Mikrofon kapalı.',
  SingleToneSessionPhase.waiting => 'Hazırlan… Mikrofon kapalı.',
  SingleToneSessionPhase.responding => 'Şimdi söyle. Mikrofon açık.',
  SingleToneSessionPhase.assessing => 'Kayıt kalitesi kontrol ediliyor…',
  SingleToneSessionPhase.analyzing => 'Yerel analiz yapılıyor…',
  SingleToneSessionPhase.finished => 'Deneme bitti. Mikrofon kapalı.',
  SingleToneSessionPhase.closed => 'Oturum kapandı.',
};
String _retry(SessionRetryReason reason) => switch (reason) {
  SessionRetryReason.calibrationRequired =>
    'Önce ortamı ölç. Çıkış değiştiyse yeniden ölçmek gerekir.',
  SessionRetryReason.permissionDenied =>
    'Mikrofon izni verilmedi. Telefon ayarlarından Harmonia mikrofon iznini açabilir veya geri dönebilirsin.',
  SessionRetryReason.routeUnsupported =>
    'Bu ses çıkışı desteklenmiyor. Kablolu kulaklıkla tekrar dene.',
  SessionRetryReason.interrupted =>
    'Deneme kesildi. Hazır olduğunda yeniden başlat.',
  SessionRetryReason.captureFailed =>
    'Kayıt alınamadı. Yeniden deneyebilirsin.',
  SessionRetryReason.analysisFailed =>
    'Analiz tamamlanamadı. Yeniden deneyebilirsin.',
  SessionRetryReason.quality =>
    'Kayıt kalitesi yeterli değil. Sessiz bir ortamda, mikrofon açıldıktan sonra tekrar dene. Bu bir öğrenci hatası değildir.',
};
