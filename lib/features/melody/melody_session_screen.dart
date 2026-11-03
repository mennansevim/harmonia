import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/melody_session.dart';
import '../../application/melody_practice.dart';
import '../../application/microphone_permission_recovery.dart';
import '../../application/single_tone_session.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/synthetic_melody_backend.dart';
import '../common/ui/resonia_ui.dart';
import '../common/ui/microphone_permission_recovery_card.dart';
import 'melody_candidate_comparison_card.dart';
import 'melody_practice_screen.dart';
import '../../domain/lang.dart';

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
          () => _practiceError = tr(
            'Ses oturumu güvenle devredilemedi. Uygulamayı kapatıp yeniden aç.',
            'The audio session could not be handed over safely. Close and reopen the app.',
          ),
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
        counter: tr('Puansız', 'Unscored'),
        closeLabel: tr('Ezgi çalışmasını kapat', 'Close melody practice'),
        top: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(
              tr(
                'Deneysel · Doğrulama bekliyor',
                'Experimental · Awaiting validation',
              ),
            ),
          ),
          const SizedBox(height: ResoniaSpacing.md),
          if (_openingPractice)
            Semantics(
              liveRegion: true,
              child: Text(
                _practiceError ??
                    tr(
                      'Kayıt oturumu kapatılıyor; bölüm dinlemeye geçilecek…',
                      'Closing the recording session; moving to segment listening…',
                    ),
                key: const Key('practice_handoff_status'),
              ),
            ),
          Text(
            tr('Kısa ezgi tekrarı', 'Short melody echo'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            tr(
              '${session.reference.frequenciesHz.length} ses: dinle ve söyle',
              '${session.reference.frequenciesHz.length} notes: listen and sing',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            tr(
              'Sentetik tonlar; piyano kaydı değildir. Nota, sıra ve hafıza puanı verilmez.',
              'Synthetic tones, not a piano recording. No note, order or memory score is given.',
            ),
          ),
          const SizedBox(height: ResoniaSpacing.md),
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
                ? tr(
                    'Ortam ölçüldü. Çıkış değişirse yeniden ölç.',
                    'Room measured. Measure again if the output changes.',
                  )
                : tr(
                    'Önce 2 saniye sessiz kalıp ortamı ölç.',
                    'First stay quiet for 2 seconds to measure the room.',
                  ),
          ),
          ExpansionTile(
            key: const Key('melody_help'),
            tilePadding: EdgeInsets.zero,
            title: Text(tr('Nasıl çalışır?', 'How does it work?')),
            children: [
              Text(
                tr(
                  'Tonları dinle; “Şimdi söyle” yazınca aynı sırayla tekrar et. Yanıt en fazla 8 saniye. Kayıt yerel analiz için okununca silinir; cihazdan gönderilmez. Ortam ölçümü eskirse veya çıkış değişirse yeniden ölç. Eğitimci ve cihaz doğrulaması bekliyor.',
                  'Listen to the tones; when it says “Sing now”, repeat them in the same order. You have up to 8 seconds. The recording is deleted once read for local analysis; it never leaves the device. Measure the room again if it gets stale or the output changes. Educator and device validation is pending.',
                ),
              ),
            ],
          ),
          if (session.outcome case final outcome?) ...[
            const SizedBox(height: ResoniaSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(ResoniaSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outcome.needsRetry
                          ? tr(
                              'Ölçüm alınamadı — puanlanmadı',
                              'No measurement — not scored',
                            )
                          : tr(
                              'Yerel analiz tamamlandı — puanlanmadı',
                              'Local analysis done — not scored',
                            ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      outcome.needsRetry
                          ? _retry(outcome.retryReason!)
                          : tr(
                              'Bulunan bölümler deneysel frekans adaylarıdır; insan sesi veya doğru nota kanıtı değildir. Yeniden çalışabilirsin.',
                              'The segments found are experimental frequency candidates, not proof of a human voice or a right note. You can practise again.',
                            ),
                    ),
                    Text(
                      tr(
                        'Tamamlanan referans: ${outcome.referencePlays} (bu deneme). Bu sayı duyma veya hafıza ölçümü değildir.',
                        'References played: ${outcome.referencePlays} (this attempt). This is not a measure of hearing or memory.',
                      ),
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
                child: Text(
                  details
                      ? tr('Ayrıntıyı gizle', 'Hide details')
                      : tr('Ölçüm ayrıntısı', 'Measurement details'),
                ),
              ),
            if (outcome.segments case final evidence? when details) ...[
              Text(
                tr(
                  'Kayıt kaynağı: ${evidence.provenance.source.name}',
                  'Recording source: ${evidence.provenance.source.name}',
                ),
              ),
              Text(
                tr(
                  'Aday bölüm sayısı: ${evidence.segments.length}',
                  'Candidate segments: ${evidence.segments.length}',
                ),
              ),
              if (evidence.segments.isEmpty)
                Text(
                  tr(
                    'Kararlı frekans adayı bulunamadı. Bu, öğrenciye sıfır puan değildir.',
                    'No steady frequency candidate was found. This is not a zero score for the student.',
                  ),
                ),
              for (var i = 0; i < evidence.segments.length; i++)
                Text(
                  tr(
                    'Aday ${i + 1}: ${evidence.segments[i].frequencyHz.toStringAsFixed(1)} Hz',
                    'Candidate ${i + 1}: ${evidence.segments[i].frequencyHz.toStringAsFixed(1)} Hz',
                  ),
                ),
              Text(
                tr(
                  'Kısa/kararsız bölüm frame sayısı: ${evidence.discardedFrameIndices.length}',
                  'Short or unsteady segment frames: ${evidence.discardedFrameIndices.length}',
                ),
              ),
              Text(
                tr(
                  'Bölüm sınırları analiz pencerelerinden tahmin edilir; gerçek nota başlangıcı ve süresi doğrulanmadı. Sonuç geçmişe veya beceri ilerlemesine kaydedilmez.',
                  'Segment edges are estimated from analysis windows; real note onsets and lengths are not validated. The result is not saved to history or skill progress.',
                ),
              ),
            ],
            if (outcome.alignment case final alignment?)
              MelodyCandidateComparisonCard(evidence: alignment),
            if (outcome.alignment case final alignment?)
              if (DiagnosticMelodyPracticeSuggestion.fromAlignment(
                    reference: outcome.reference,
                    evidence: alignment,
                  )
                  case final suggestion?) ...[
                const SizedBox(height: ResoniaSpacing.sm),
                Card(
                  key: const Key('melody_candidate_practice'),
                  child: Padding(
                    padding: const EdgeInsets.all(ResoniaSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            'Aday bölümü yeniden dinle',
                            'Hear the candidate segment again',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          tr(
                            '${suggestion.referenceIndex + 1}. referans sesi çevresinde deneysel bir farklılık görüldü. Bu doğrulanmış hata veya puan değildir.',
                            'An experimental difference was seen around reference note ${suggestion.referenceIndex + 1}. This is not a validated mistake or a score.',
                          ),
                        ),
                        TextButton(
                          key: const Key('melody_open_candidate_practice'),
                          onPressed: _openingPractice
                              ? null
                              : () => _openPractice(
                                  initialPractice: suggestion.practice,
                                ),
                          child: Text(
                            tr(
                              'Aday bölümü puansız dinle',
                              'Hear the candidate segment, unscored',
                            ),
                          ),
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
              label: tr(
                'Ortamı ölç (2 sn sessizlik)',
                'Measure the room (2 s of silence)',
              ),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
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
              label: tr('Dinle ve söyle', 'Listen and sing'),
            ),
            const SizedBox(height: ResoniaSpacing.md),
            ChunkyButton(
              key: const Key('melody_open_practice'),
              onPressed: _openPractice,
              tone: ChunkyTone.neutral,
              label: tr(
                'Oturumu kapat ve bölüm dinle',
                'Close the session and hear segments',
              ),
            ),
            Text(
              tr(
                'Bu oturum kapanır. Dinlemeden çıkınca önceki sayfaya dönersin; yeni kayıt için ezgi çalışmasını yeniden aç.',
                'This session closes. Leaving the listening page takes you back; reopen melody practice for a new take.',
              ),
            ),
          ],
          if (session.canFinishResponse) ...[
            ChunkyButton(
              key: const Key('melody_finish'),
              onPressed: session.finishResponse,
              icon: Icons.stop_rounded,
              tone: ChunkyTone.record,
              label: tr('Bitirdim', 'I am done'),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
          ],
          if (!session.canStart && !_openingPractice)
            ChunkyButton(
              key: const Key('melody_cancel'),
              onPressed: session.cancel,
              tone: ChunkyTone.neutral,
              label: tr('İptal et', 'Cancel'),
            ),
        ],
      ),
    ),
  );
}

String _phase(SingleToneSessionPhase phase) => switch (phase) {
  SingleToneSessionPhase.idle => tr(
    'Hazır. Mikrofon kapalı.',
    'Ready. Microphone off.',
  ),
  SingleToneSessionPhase.calibrating => tr(
    'Ortam ölçülüyor. Sessiz kal; mikrofon açık.',
    'Measuring the room. Stay quiet; microphone on.',
  ),
  SingleToneSessionPhase.preparing => tr('Hazırlanıyor…', 'Preparing…'),
  SingleToneSessionPhase.referencePlaying => tr(
    'Referansı dinle. Mikrofon kapalı.',
    'Listen to the reference. Microphone off.',
  ),
  SingleToneSessionPhase.waiting => tr(
    'Hazırlan… Mikrofon kapalı.',
    'Get ready… Microphone off.',
  ),
  SingleToneSessionPhase.responding => tr(
    'Şimdi söyle. Mikrofon açık.',
    'Sing now. Microphone on.',
  ),
  SingleToneSessionPhase.assessing => tr(
    'Kayıt kalitesi kontrol ediliyor…',
    'Checking the recording quality…',
  ),
  SingleToneSessionPhase.analyzing => tr(
    'Yerel analiz yapılıyor…',
    'Analysing locally…',
  ),
  SingleToneSessionPhase.finished => tr(
    'Deneme bitti. Mikrofon kapalı.',
    'Attempt finished. Microphone off.',
  ),
  SingleToneSessionPhase.closed => tr('Oturum kapandı.', 'Session closed.'),
};
String _retry(SessionRetryReason reason) => switch (reason) {
  SessionRetryReason.calibrationRequired => tr(
    'Önce ortamı ölç. Çıkış değiştiyse yeniden ölçmek gerekir.',
    'Measure the room first. If the output changed, measure again.',
  ),
  SessionRetryReason.permissionDenied => tr(
    'Mikrofon izni verilmedi. Telefon ayarlarından Vocalart mikrofon iznini açabilir veya geri dönebilirsin.',
    'Microphone permission was not given. You can allow it for Vocalart in your phone settings, or go back.',
  ),
  SessionRetryReason.routeUnsupported => tr(
    'Bu ses çıkışı desteklenmiyor. Kablolu kulaklıkla tekrar dene.',
    'This audio output is not supported. Try again with wired headphones.',
  ),
  SessionRetryReason.interrupted => tr(
    'Deneme kesildi. Hazır olduğunda yeniden başlat.',
    'The attempt was interrupted. Start again when you are ready.',
  ),
  SessionRetryReason.captureFailed => tr(
    'Kayıt alınamadı. Yeniden deneyebilirsin.',
    'Nothing was recorded. You can try again.',
  ),
  SessionRetryReason.analysisFailed => tr(
    'Analiz tamamlanamadı. Yeniden deneyebilirsin.',
    'The analysis could not finish. You can try again.',
  ),
  SessionRetryReason.quality => tr(
    'Kayıt kalitesi yeterli değil. Sessiz bir ortamda, mikrofon açıldıktan sonra tekrar dene. Bu bir öğrenci hatası değildir.',
    'The recording quality is not good enough. Try again somewhere quiet, after the microphone opens. This is not a student mistake.',
  ),
};
