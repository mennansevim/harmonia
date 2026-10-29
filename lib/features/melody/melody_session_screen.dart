import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/melody_session.dart';
import '../../application/melody_practice.dart';
import '../../application/microphone_permission_recovery.dart';
import '../../application/single_tone_session.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/synthetic_melody_backend.dart';
import '../common/ui/harmonia_ui.dart';
import '../common/ui/microphone_permission_recovery_card.dart';
import 'melody_practice_screen.dart';

/// Diagnostic only: no note matching, memory score, mastery or history entry.
class MelodySessionScreen extends StatefulWidget {
  const MelodySessionScreen({
    super.key,
    this.backend,
    this.worker,
    this.practicePlayerFactory,
    this.permissionRecovery,
  });
  final MelodyReferenceBackend? backend;
  final RecordingPitchWorker? worker;
  final DiagnosticMelodyPracticePlayer Function()? practicePlayerFactory;
  final MicrophonePermissionRecovery? permissionRecovery;
  @override
  State<MelodySessionScreen> createState() => _MelodySessionScreenState();
}

class _MelodySessionScreenState extends State<MelodySessionScreen>
    with WidgetsBindingObserver {
  late final MelodySessionController session;
  bool details = false;
  bool _openingPractice = false;
  String? _practiceError;

  Future<void> _openPractice({
    DiagnosticMelodyPractice? initialPractice,
  }) async {
    if (_openingPractice || !session.canStart) return;
    setState(() => _openingPractice = true);
    try {
      await session.close();
      if (!mounted) return;
      final player = widget.practicePlayerFactory?.call();
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => MelodyPracticeScreen(
            reference: session.reference,
            player: player,
            initialPractice: initialPractice,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _practiceError =
              'Ses oturumu güvenle devredilemedi. Uygulamayı kapatıp yeniden aç.',
        );
      }
    }
  }

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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => PopScope<void>(
      canPop: !_openingPractice,
      child: LessonScaffold(
        progress: null,
        counter: 'Puansız',
        closeLabel: 'Ezgi çalışmasını kapat',
        top: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill('Deneysel · Doğrulama bekliyor'),
          ),
          const SizedBox(height: HarmoniaSpacing.md),
          if (_openingPractice)
            Semantics(
              liveRegion: true,
              child: Text(
                _practiceError ??
                    'Kayıt oturumu kapatılıyor; bölüm dinlemeye geçilecek…',
                key: const Key('practice_handoff_status'),
              ),
            ),
          Text(
            'Kısa ezgi tekrarı',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${session.reference.frequenciesHz.length} ses: dinle ve söyle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Sentetik tonlar; piyano kaydı değildir. Nota, sıra ve hafıza puanı verilmez.',
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
          Text(
            session.calibration?.isUsable == true
                ? 'Ortam ölçüldü. Çıkış değişirse yeniden ölç.'
                : 'Önce 2 saniye sessiz kalıp ortamı ölç.',
          ),
          ExpansionTile(
            key: const Key('melody_help'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Nasıl çalışır?'),
            children: const [
              Text(
                'Tonları dinle; “Şimdi söyle” yazınca aynı sırayla tekrar et. Yanıt en fazla 8 saniye. Kayıt yerel analiz için okununca silinir; cihazdan gönderilmez. Ortam ölçümü eskirse veya çıkış değişirse yeniden ölç. Eğitimci ve cihaz doğrulaması bekliyor.',
              ),
            ],
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
            if (outcome.retryReason == SessionRetryReason.permissionDenied)
              MicrophonePermissionRecoveryCard(
                recovery: widget.permissionRecovery,
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
            if (outcome.alignment case final alignment?)
              if (DiagnosticMelodyPracticeSuggestion.fromAlignment(
                    reference: outcome.reference,
                    evidence: alignment,
                  )
                  case final suggestion?) ...[
                const SizedBox(height: HarmoniaSpacing.sm),
                Card(
                  key: const Key('melody_candidate_practice'),
                  child: Padding(
                    padding: const EdgeInsets.all(HarmoniaSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aday bölümü yeniden dinle',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${suggestion.referenceIndex + 1}. referans sesi çevresinde deneysel bir farklılık görüldü. Bu doğrulanmış hata veya puan değildir.',
                        ),
                        TextButton(
                          key: const Key('melody_open_candidate_practice'),
                          onPressed: _openingPractice
                              ? null
                              : () => _openPractice(
                                  initialPractice: suggestion.practice,
                                ),
                          child: const Text('Aday bölümü puansız dinle'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
          ],
        ],
        bottom: [
          if (session.canStart && !_openingPractice) ...[
            ChunkyButton(
              key: const Key('melody_calibrate'),
              onPressed: session.calibrate,
              tone: session.calibration?.isUsable == true
                  ? ChunkyTone.neutral
                  : ChunkyTone.primary,
              icon: Icons.mic_none_rounded,
              label: 'Ortamı ölç (2 sn sessizlik)',
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            ChunkyButton(
              key: const Key('melody_start'),
              onPressed: () {
                setState(() => details = false);
                unawaited(session.startAttempt());
              },
              icon: Icons.hearing,
              tone: session.calibration?.isUsable == true
                  ? ChunkyTone.primary
                  : ChunkyTone.neutral,
              label: 'Dinle ve söyle',
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            ChunkyButton(
              key: const Key('melody_open_practice'),
              onPressed: _openPractice,
              tone: ChunkyTone.neutral,
              label: 'Oturumu kapat ve bölüm dinle',
            ),
            const Text(
              'Bu oturum kapanır. Dinlemeden çıkınca önceki sayfaya dönersin; yeni kayıt için ezgi çalışmasını yeniden aç.',
            ),
          ],
          if (session.canFinishResponse) ...[
            ChunkyButton(
              key: const Key('melody_finish'),
              onPressed: session.finishResponse,
              icon: Icons.stop_rounded,
              tone: ChunkyTone.record,
              label: 'Bitirdim',
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
          ],
          if (!session.canStart && !_openingPractice)
            ChunkyButton(
              key: const Key('melody_cancel'),
              onPressed: session.cancel,
              tone: ChunkyTone.neutral,
              label: 'İptal et',
            ),
        ],
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
