# Harmonia — Model devir ve genel işleyiş notu

**Güncelleme:** 2026-10-11 (Europe/Istanbul)  
**Repo:** `/Users/sevimm/Documents/Projects/harmonia`  
**Amaç:** Başka model konuşma geçmişi olmadan güvenle devam edebilsin.

## 1. Önce oku ve mevcut durumu kontrol et

1. `AGENTS.md` ve bu not.
2. `CURRENT_ROADMAP.md` (özellikle “Bir sonraki oturum”).
3. `IMPLEMENTATION_ROADMAP.md` ve son `IMPLEMENTATION_LOG.md` paketleri.
4. `AUDIO_TESTING.md`, `ARCHITECTURE.md`, `DECISIONS.md`.
5. Piyano işinde `PIANO_REFERENCES.md`; öğrenme/Plus işinde
   `LEARNING_MODEL.md`, `PRODUCT_AUDIT.md`, `HUMAN_REVIEW.md`.

`git status --short` / `git log -5 --oneline` ile devraldığın snapshot'ı kontrol
et. Bu teslim ilk yerel commit olarak hazırlanıyor; daha eski kod commit'leri
yoktu. Commit kimliğini `git log` üzerinden al; bu not kendi commit hash'ini
sabit yazmaz. Push/yayın bu teslimin kapsamı değil. Komşu Agora ayrı repodur;
çalışma dizini orası olarak açılmış olabilir, Harmonia workdir'ini explicit seç.

## 2. Ürün ve kullanıcı kararları

Flutter iOS/Android, Türkçe konservatuvar işitsel hazırlığı; koro ayrı rota.
Kulak/ritim/ezgi eğitimi, açıklanabilir sonuç ve sonraki çalışma hedefi.
**Aurora marka deneyimi + Konservatuvar açıklayıcı sonuçları** seçildi;
tasarım/öğretim pilotu geçmedi. Tam sınav/şan/çalgı eğitimi veya kabul garantisi
iddiası yok. Premium/Plus planlı; Plus'ta gerçek müzisyen/eğitimci kaydı dinler
ve kendi yazılı yorumunu teslim eder. AI onun yerine insan yorumu üretmez.

### Son piyano açıklaması — önceki varsayımları geçersiz kılar

Kullanıcı piyanoda örnekleri çalıp **hazır 2/3/4 sesli kayıtları sağlayacak**.
Tek ses dosyalarında olduğu gibi klasörden oynatılacak; öğrenci duyduğu
notaları tek tek tekrar edecek. Sesler gelene kadar yalnız placeholder.
“Canlı çalacağım” yanıtını canlı akor otomatik tanıma olarak yorumlama.
Tekil sample mix renderer önce yapıldı, alternatif altyapı olarak korunuyor;
ana içerik yolunu yeniden ona çevirmeme.

Agora tek sesler: `src/PitchTest/lib/audioPlayer.ts` →
`/sounds/piano/{noteName}.wav` fetch/decode/cache. 41 WAV var; örnek C4/A4
header mono PCM16/48 kHz, tüm etiket/hak zinciri doğrulanmadı. Repo MIT olsa da
sample hakları varsayılmadı; Harmonia'ya kopyalanmadı.

## 3. Uygulamayı açınca ne çalışıyor?

`lib/main.dart` → `HarmoniaApp` → `AppShellController` → yükleniyor → (profil yoksa) hedef seçimi → `HomeScreen`. Profil yalnız hedef + oluşturma zamanı; uygulamaya özel dizinde atomik JSON (`FileProfileRepository`). Widget testleri `HarmoniaApp(profiles: InMemoryProfileRepository(...), history: InMemoryResultHistory(), startupCleanup: ...)` kullanmalı; gerçek dosya IO'su FakeAsync içinde tamamlanmaz.

- Home birincil kart → **Ses laboratuvarı** (Deneysel): ortam sessizliği kalibrasyonu (2 sn, klip silinir), sentetik C4 referans, açık izinle kısa yerel WAV kaydı, replay/delete, kalite raporu (enerji/SNR/route; insan sesi tespiti değil) ve deneysel frekans diagnostics. iOS/Android adapter var; fiziksel mic/route QA yapılmadı. Upload/skor yok.
- **Tek ses: dinle ve söyle** (Deneysel, SESSION-01): kalibrasyon → referans → bekleme → cevap → kalite kapısı → puansız diagnostics; `SingleToneSessionOutcome.scoringEnabled == false`.
- **Ritim tekrarı** (Deneysel, CORE-02a): sentetik klik dinle → dokunarak tekrar; ilk dokunuş çapa (ölçülmez); vuruş zaman çizelgesi; 3 taslak desen.
- **Tek ses sonuç örnekleri** (Simülasyon): eski C4 mock senaryo ekranı; gerçek öğrenci DSP sonucu değil.
- **2 / 3 / 4 sesli piyano** (Kayıt bekleniyor): üç kart, dinle/tekrar disabled.
- Planlananlar (ritim, ezgi, aralık, günlük rota) disabled “Henüz yok”.
- **Bugünkü öneri** (home üstü, LEARN-03a): `RhythmNextStepPolicy` geçmişten tek adım önerir (tekrar/yeni desen/ertesi gün kalıcılık kontrolü); taslak ölçüt görünür.
- **Çalışma geçmişi** (home app bar / ayarlar): yerel `FileResultHistory`; ritim sonuçları `touch` kaynağıyla; cohort içinde ≥3 geçerli deneme yoksa “bilinmiyor”.
- Ayarlar: hedef değiştir, mikrofon yardımı, gizlilik ve veriler (geçmiş, yetim temizlik uyarısı), “satın alma yok”, misafir hesap, onaylı yerel profil silme.
- Açılışta `OrphanAudioCleaner` (SESSION-02) önceki oturumlardan kalan kendi temp ses dizinlerini temizler.

## 4. Kod haritası ve önemli sözleşmeler

- `lib/domain/audio/capture_quality.dart` (CAL-01, ADR-021): route politikası, kalibrasyon damgası (route/rate/30 dk), noise-floor, kalite kapısı, `LatencyCalibration.notMeasured()`. Eşikler benchmark öncesi hipotez; sonuca bakıp gevşetme. Sadece `usable` analiz edilir; diğer her durum nötr yeniden deneme.
- `lib/application/single_tone_session.dart` (SESSION-01): puansız ürün oturumu; `lib/domain/audio/rhythm_imitation.dart` + `lib/application/rhythm_imitation_controller.dart` (CORE-02a): ilk dokunuş çapası, taslak desenler `lib/domain/content/rhythm_patterns.dart`. Oynatıcılar her play öncesi `stop()` (just_audio tamamlanma notu).
- `lib/application/result_history.dart` + `lib/infrastructure/storage/file_result_history.dart` (CORE-05): attempt ID tekilleştirme/çakışma/kapasite; `lib/app/app_services.dart` geçmiş + temizlik raporu. `ExerciseResult.fromJson` katıdır.
- `lib/domain/learning/rhythm_next_step.dart` (LEARN-03a): taslak ustalık ölçütü (2 temiz deneme, ≤60 ms) ve öncelik sırası; testler ölçütü sabitler.
- `lib/domain/analytics/product_event.dart` (gönderim yok), `lib/domain/coach/coach_contract.dart` + `lib/application/coach_service.dart` (canlı API yok, UI'ya bağlı değil), `lib/features/common/input_level_meter.dart` (yalnız görüntü).
- `lib/app/theme/harmonia_theme.dart` (ADR-022): spacing/radius, `HarmoniaResultColors`. `lib/application/app_shell_controller.dart`, `profile_repository.dart`; `lib/infrastructure/storage/`.

- `lib/domain/models`: Exercise/Protocol/ConfiguredExercise, sonuç v2,
  ScoreMetric measured/notMeasured/notApplicable; invalid sayısal skor taşımaz.
  Evidence deep snapshot; progress difficulty/mode/content/scoring/source/
  analyzer cohort ve per-metric denominator kullanır. Persistence/dedup/tam
  mastery yok; tüm tuning/hint/session kanıtı tamamlanmadı.
- `lib/domain/scoring/pitch_exercise_scorer.dart`: mevcut rubrik; note 50 cents,
  stability 25 cents, minVoicedRatio 0.6. Wrong octave asla başarı değil.
- `event_rhythm_analyzer.dart`: bounded monoton event-list alignment,
  missed/extra/latency; gerçek tap UI veya mic onset capture değil.
  MockMelodyAnalyzer fail-closed, memory/order/timing başarı uydurmaz.
- `yin_pitch_frame_analyzer.dart`: target-independent deneysel YIN-style
  frame core; 8–48 kHz/8192 örnek; defaults 50–2000 Hz, −50 dB gate,
  CMNDF 0.15, clip oranı >%1. Full YIN veya Agora McLeod port'u değil.
  Status pitched/silence/insufficient/invalid/clipped/unreliable; finite RMS.
- `pitch_deviation.dart`: raw Hz sonrası signed absolute cents, pitch-class
  residual ve octave offset; hedefe frequency folding yok.
- `recording_pitch_analyzer.dart`: sabit config, 10 sn/512 frame bütçesi;
  tüm PCM preflight, regular half-hop + tek end-anchor. Immutable PCM-free
  frame trace/counts; source explicit, default unverified. PeriodicFrameRatio
  tüm full-frame denominator'ı; empty=null, analyzed silence=0. Observed lower
  median Hz, ≥2 accepted frame'de log-frequency dispersion; octave korunur.
  Human VAD/voicedRatio/öğrenci skoru değildir, PitchAnalyzer implementasyonu
  olarak otomatik takılmaz. Overlap'li frame'ler bağımsız deneme değildir.
- `isolate_recording_pitch_worker.dart`: native VM Isolate.run, bounded input
  snapshot ve tek active iş/instance. Native testli; web fallback/hard cancel
  yok. Lab/controller epoch stale result/error reddi bağlandı; worker cleanup kuyruğunu tutmaz.
- `pcm16_wav.dart` + fixture manifest/loader: narrow mono PCM16, actual header
  rate, bounded reads, hash/path/symlink/rate/count tutarlılığı. Private
  immutable dataset varsayımı; kernel sandbox veya label/consent QA değildir.
- `AudioLabController`: serialized native commands + cancel epoch;
  route/focus/background'ta cancel, auto resume yok. Optional `AudioRecordingReader`
  owned WAV'ı bounded `readLabWav` ile immutable PCM/source'a dönüştürür;
  açık analyze eylemi worker'a iletir. Plugin backend kendi temp
  reference/recording dosyalarını yönetir. Startup orphan cleanup ve shutdown
  error UI aktarımı açık. Lab timer overshoot ≤11 sn kabulü ile strict 10 sn
  analyzer bütçesi farklı; sessiz truncate veya öğrenci hatası yapma.
  Analysis error kayıt/replay'i korur. Load kaynak kuyruğunda, DSP dışında;
  cancel epoch hemen invalid, eski worker bitmeden yeni analiz kapalı.
  `_analysisInFlight` yeni kaydı engellemez; sadece analiz concurrency'sini sınırlar.
  Source microphone köken beyanıdır, cihaz/voice/accuracy onayı değildir.
- `piano_chord_reference.dart` / `piano_chord_renderer.dart`: bilinen MIDI
  hedef/protokol ve alternatif single-clock sample mix; origin/rate/tuning/
  key/headroom testli. Gerçek piyano bankası veya player bağlantısı yok.

AI/back-end/auth/sync/abonelik/insan hizmeti canlı değil. Model tercihi
`gpt-4o-mini`; skor deterministic, mobil API anahtarı yok.

## 5. Piyano dosyalarını bekleyen yer

`assets/audio/piano/chords/{2,3,4}-notes/` README-only klasörler.
`catalog.json` pubspec'te tek bundled chord asset; slot status
`awaiting_recording`, assetPath/targetMidiNotes/rightsReference null.
`ChordRecordingCatalog` placeholder-only schema: ready/path/label eklemek
feature'ı açmaz, validation error verir. Gerçek içerik reviewed şema/adapter,
asset registration/player ve session guard'larıyla ayrıca entegre edilecek.

Kullanıcıya önerilen **henüz kaydedilmemiş/onaylanmamış** ilk set:

| Dosya önerisi | Hedef notalar |
|---|---|
| 2-01.wav | C4 G4 |
| 2-02.wav | C4 E4 |
| 2-03.wav | D4 F4 |
| 3-01.wav | C4 E4 G4 |
| 3-02.wav | D4 F4 A4 |
| 3-03.wav | E4 G4 C5 |
| 4-01.wav | C4 E4 G4 C5 |
| 4-02.wav | D4 F4 A4 C5 |
| 4-03.wav | C4 E4 G4 B4 |

Bu tablo catalog target alanlarını doldurmak için onay değildir. Dosyalar
gelince birlikte nota/oktav/akort/format/seviye/süre/hak kontrolü yapılacak.
Öneri: birlikte basılmış, yaklaşık 2 sn, pedalsız/benzer şiddet, konuşmasız,
doğal sönüş ve kısa sessizlik; mümkünse WAV. Teacher/pilot doğrulaması değil.

## 6. Doğrulama ve ortam

Son suite: **422 test**, analyze temiz, format **122 Dart dosyası/0 değişiklik** (21:40 TRT heartbeat). Önceki 401-test paketinde iOS simulator build/elle gezinti başarılıydı; bu tur build/cihaz testi yok. Domain/mock/synthetic/widget + native isolate testleri; insan kayıt/gerçek telefon/öğretim pilotu değil. Android cmdline-tools/SDK lisans kapısı önceki kontrolde eksik/unknown; kurulmuş/kabul edilmiş varsayma. Yerelde Flutter 3.44.4/Dart 3.12.2.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
```

`flutter run` istenen simulator/cihaz seçilerek kullanılabilir. Donanım kaydı
ve ölçüm yapılmadan mic/latency/build başarısı iddia etme.

## 7. En yakın güvenli geliştirme dilimi

Modül envanteri ve kritik yol: `CURRENT_ROADMAP.md` başı; iş ID'leri `IMPLEMENTATION_ROADMAP.md` §11. Bu turda CAL-01 ve SHELL-01 kod-test oldu; `85f301b` sonrasındaki tüm değişiklikler commit edilmedi (commit yalnız kullanıcı isterse).

SESSION-01/02, CORE-02a/05, LEARN-03a, QA-01a, UX-03a, ANALYTICS-01 ve AI-02a kod-testli. CAL-03a `latency_estimator.dart` eklendi: immutable diagnostic, kaynak/method, 8–64 trial, ortak observed clock, route/rate ve chronology; raw median/MAD/P90–P10 + rejected indices. LatencyCalibration'a dönüşüm yok, correctionEnabled=false; count-in açılmaz. Tap motor bias ve loopback toplamını hardware/touch correction gibi kullanma. Sıradaki bağımsız paket LEARN-01 beceri grafiği; CAL-03b fiziksel clock/pipeline adapter ve protokol bekler. Android cmdline-tools/lisans, SHELL-02 plugin kararı, CAL-02 cihazları, BENCH-01 izinli kayıtlar, UXR-01 katılımcılar ve piyano kayıtları kullanıcı koordinasyonunda.

Kayıtlar gelmeden chord placeholder doldurulmaz. Gerçek VAD/benchmark olmadan simülasyon başarı ekranı gerçek motora bağlanmaz. PeriodicFrameRatio voicedRatio değildir; enerji etkinliği VAD değildir. Ücretli API/ödeme/upload/push/deployment/dış mesaj yetkisi yok. Başka model/session'da otomasyon çalışıyor varsayma.

**LEARN-01a (son paket):** `lib/domain/learning/skill_graph.dart` taslak grafik + `SkillStatusEvaluator`; `lib/features/skill_map/`. Gecikme (CAL-03a/b) başka bir ajanın işidir; bu iki işi aynı anda aynı dosyalarda yürütme.

**PERC-01:** `lib/domain/perception/pitch_comparison.dart`, `lib/application/pitch_comparison_controller.dart`, `lib/features/pitch_comparison/`; beceri değerlendirmesi `lib/domain/learning/measured_exercise.dart` üzerinden. iOS simulator build son denemede araç hatasıyla düştü; diğer ajan bitince `flutter clean` + yeniden derleme dene.

**LEARN-03b:** `lib/domain/learning/today_planner.dart`; home kartı buna bağlı. **iOS simulator build engeli:** Xcode 26.6 lipo + Flutter 3.44.4 `-verify_arch` uyumsuzluğu (ortam); kod değil.

**INT-01a (ADR-024 hareketli do):** `lib/domain/perception/interval_identification.dart`, `lib/application/interval_controller.dart`, `lib/features/interval/`. Hece ve aralık adı birlikte; mutlak nota adı yalnız mutlak yükseklik görevlerinde.

**2026-10-12 02:47 TRT heartbeat:** LEARN-01/PERC/INT paketlerini tekrar
uygulamadan bağımsız CORE-03a eklendi. `lib/domain/audio/pitch_sequence_alignment.dart`
known segmented Hz events→exact-order 1:1 alignment; missing/extra/wrongPitch/
wrongOctave. Null unmeasured response, immutable source; no score/timing/memory,
PCM segmentleme ve UI bağlantısı yok. 480 test/analyze temiz, format 143/0;
build veya cihaz testi yapılmadı. Sonraki CORE-03b frame→segment adapter'ı ve
sentetik regresyonlar, sonra CORE-04; VAD/insan benchmark kapısını geçilmiş sayma.
Dirty INT/grafik/günlük plan değişiklikleri korundu, commit/push yapılmadı.

**2026-10-12 07:51 TRT:** CORE-03b `pitch_segmenter.dart` eklendi; recording
evidence→target-independent periodic run candidates. 35 cent anchor/3 frame/
200 ms defaults deneysel; min span overlap count değil center-clock süre.
Raw octave korunur, gap/silence/unreliable/clip bridge yok; short run discarded
indices. Diagnostic boundaries gerçek onset/duration/VAD değildir. Ürün skoru
ve UI bağlantısı yok; gerçek kalite/etiket benchmark bekliyor. Sıradaki CORE-04
puansız response session/fake lifecycle; anyOrder veya memory skorunu ekleme.
Son doğrulama: 493 test (+13), analyze temiz, format 145/0; ayrıntı
IMPLEMENTATION_LOG'da. Build yapılmadı. Agora temiz; commit/push yapılmadı.

**2026-10-12 13:13 TRT — güncel sıradaki iş:** CORE-04a
`lib/application/melody_session.dart` + 10 fake/sentetik test eklendi; 503 suite,
147/0 format. Puansız session SESSION-01'i kompozisyonla kullanır, segment
adaylarını raporlar; tek ses deviation, sıra kararı veya score dışarı çıkmaz.
`MelodyReferenceBackend` reference declaration'ı gerçek review/rights QA değil.
Native queue pending start→cancel discard yarışını sıralar; error recovery var.
Eski native/read/worker settle olmadan restart yok; hard cancel/permission dialog
kapatma yok. CORE-04b bound synthetic reference adapter + puansız ekran/home
bağlantısını uygula; default C4 backend'i ezgi reference olarak takma. Bölüm
loop/memory başarı ve piano dosyalarını kendiliğinden açma. Gerçek benchmark/
cihaz/öğretim kapıları açık; son analyze sonucu IMPLEMENTATION_LOG'da.

**2026-10-12 18:20 TRT — en güncel devam:** CORE-04b1
`lib/infrastructure/audio/synthetic_melody_backend.dart` + infrastructure test.
3–5 note reference binding → immutable sine WAV (600/200/400 ms, 8–48 kHz),
capture backend'in default C4 reference'i kullanılmaz. Mobile factory mevcut
capture+clip plugin'lerini birleştirir; origin ayrı, route yoksa unverified.
Stop/close her iki owned resource'u dener; close idempotent/error korunur.
Son doğrulama IMPLEMENTATION_LOG'da. **Sonraki CORE-04b2** puansız ezgi
ekranı/home bağlantısı ve fake widget/lifecycle/narrow/a11y testleri; native
session'i concurrent başka caller'la kullanma. Bu adapter sentetik, gerçek
piyano veya eğitimci onaylı ders değildir. Skor/hafıza/history/AI bağlantısı ve
cihaz/human benchmark yok; chord placeholder değişmedi.

**2026-10-12 23:20 TRT — en güncel:** CORE-04b2
lib/features/melody/melody_session_screen.dart + 8 fake widget testi;
home open_melody_session Deneysel route. Üç sentetik ton, kalibrasyon,
play→wait→record→quality→puansız candidate detail. Piyano değil; source açık,
history/mastery/AI/scorer bağı yok. Background cancel, permission inactive
istisna, dispose queued close; girişte izin/kayıt yok. 320px/1.8× ve a11y
kılavuzları testli; physical reader/device/voice kanıtı değil. Son doğrulama
IMPLEMENTATION_LOG'da. CORE-04 bölüm loop/recall ve gerçek benchmark kapısı açık.
Sıradaki bağımsız iş REL-08 local QA runner/CI taslağı (dış CI etkinleştirme/
push/yayın yetkisi değil), ardından LEARN-02 mikroders şeması/onaysız taslak.

**2026-10-13 04:20 TRT — güncel:** REL-08 standalone
`dart tool/quality_check.dart` root-bound read-only format(lib/test/tool),
no-pub analyze + full test; ilk hatada exit korur. --plan dry run; --fetch
explicit locked pub get. `dart run` yerine doğrudan dart kullan, implicit pub/
build hook olmasın. CI docs/ci/README.md sağlayıcı-bağımsız ve etkin değil;
push/hosted activation/deploy yetkisi yok. AGENTS güncellendi. Son doğrulama
IMPLEMENTATION_LOG'da. Sıradaki LEARN-02 mikroders şeması: önce LEARNING_MODEL
ve mevcut skill graph/readiness'i oku; taslak eğitimci onayına dönüşmesin.
Gerçek VAD/benchmark/cihaz/eğitimci/piyano kapıları açık.

**2026-10-13 09:15 TRT — en güncel:** LEARN-02a mikroders schema:
lib/domain/learning/micro_lesson.dart + content/draft_micro_lessons.dart.
Tam beş faz, immutable/bounded, graph skill/route/dimension binding ve held-out
ID separation. İki developer text draft (tiz/pes algı, puls üretim); boş örnek
slotları pending. EducatorApproved/assessmentEnabled false; onay/JSON/asset/
UI/exercise/result/mastery bridge yok. ID disjointliği acoustic novelty kanıtı
değil; gerçek reviewed content/hak/hash QA daha sonra gerekir. Son doğrulama
IMPLEMENTATION_LOG'da. Sonraki LEARN-02b draft lesson okuma ekranı/skill-map
erişimi; görünür taslak/örnek bekleme, okuma skill mastery yaratmasın. EDU-01
gerçek eğitimci/içerik ve pedagojik pilot kapılarını açık tut.

**2026-10-13 14:17 TRT — en güncel:** LEARN-02b
features/learning/micro_lesson_screen.dart, skill-map lesson buttons + 6 widget
test. Salt metin draft reader: onay/örnek bekleme, beş faz/algı-üretim/version,
disabled practice. No audio/mic/completion/history/mastery dependency. Custom
graph default lessons boş; injectable catalog route/dimension matching.
320px/1.8× ve a11y guideline code-test, gerçek cihaz/reader/pedagoji değil.
Son doğrulama IMPLEMENTATION_LOG'da. Sıradaki LEARN-02c strict versioned JSON
draft catalog round-trip/import guard; educator approval/rights/sample review
ve öğrenci completion→mastery dönüşümü ekleme. EDU-01/benchmark/cihaz açık.

**2026-10-13 19:17 TRT — en güncel:** LEARN-02c
domain/learning/micro_lesson_codec.dart + 11 tests; schema1/draft kind/review,
strict keys/types/enums/budgets, constructor+graph+held-out guards. Immutable
restore/no prefix, 1MiB UTF8, sanitized parser errors. Standard JSON duplicate
keys, not canonical/signed/hak/etiket/waveform verifier. No auto file/asset
replacement/import UI/approval. Son doğrulama IMPLEMENTATION_LOG'da. Sonraki
LEARN-03 süreli günlük 5/12/15dk plan (taslak süreleri açık), mastery threshold
değiştirme; gerçek voice/cihaz/eğitimci/piyano/pedagoji kapıları açık.

**2026-10-13 20:45 TRT — en güncel:** LEARN-03c
domain/learning/daily_plan.dart + features/daily_plan/daily_plan_screen.dart,
ortak features/learning/exercise_launcher.dart; MeasuredExercise.draftMinutes.
Home "Günlük çalışma rotası" artık Deneysel. Plan gece yarısından önceki
sonuçlarla sabit; kontrol (1/3/7/14) → zayıf → yeni, günde ≤1/2 yeni, boş süre
açık. 19 test, 574 suite. Bütçe kalıcı değil. Eşikler/aralıklar taslak;
EDU-01/pilot açık. Bu paket ve önceki 10 paket kullanıcı isteğiyle tek yerel
commit'te toplandı (push yok).

**2026-10-13 21:40 TRT — en güncel:** DATA-03a (`application/data_export.dart`,
Ayarlar → "Verilerini taşı": ses-siz JSON pano, strict import), LEARN-04a
(`domain/learning/skill_report.dart`, beceri haritası rapor kartı, yüzde yok),
SHELL-04a (`application/practice_preferences.dart` + file adapter; günlük bütçe
hatırlanır; AppServices.preferences). 596 test, analyze/format temiz. Bu üç paket
commit edilmedi. iOS simulator build Xcode 27.0'da da Flutter 3.44.4 lipo
kontrolüyle düşüyor; Flutter güncellemesi kullanıcı onayı ister. Android
cmdline-tools/lisans eksik. Kalan işler dış kapı veya kullanıcı kararı:
SHELL-02 plugin, DATA-01 backend, AI-01 ücretli API, PAY mağaza, OPS-01 servis,
CAL-02/03b cihaz, BENCH-01/VAD-01 kayıt, EDU-01 eğitimci, UXR-01, piyano kayıtları.
