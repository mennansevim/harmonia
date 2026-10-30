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

## 2e. 2026-10-30 — CHOIR-A0 Koro modülü (ADR-036)

`lib/choir/app|audio|data|midi|domain`. Sunucu yok, `ChoirStore` + `.harmonia` paketleri; sunucu gelince `ChoirPersistence` ve paket taşıması değişir, ekranlar değil. Eşlikli kayıt tek telefonda: `part_renderer` → `PluginTakeCapture` → `mixTake`. `Isolate.run` closure'ı store veya controller yakalamamalı; üst düzey fonksiyon kullan. Hoparlörde eşlikli kayıt kapalı kalsın. Kayıt puanlanmaz. Metinler `choir_text.dart` (TR/EN); uygulamanın geri kalanı Türkçe, İngilizce cihazda karışık görünür. Gerçek cihaz/kulaklık/Android/pilot kapıları açık; ayrıntı CURRENT_ROADMAP.

## 2d. 2026-10-30 — ADR-035 Personal / Choir

Plan: `PRODUCT_PLAN_PERSONAL_CHOIR.md`. Personal herkes içindir; eski “Koro” sekmesi **Ses** sekmesi (Ses Atölyesi, `KoroHub` sınıf adı korunuyor). Onboarding kişisel dille; aralık adımı atlanabilir; `focus` için `voice` id'si. Koro modülü (davet, ödev, kayıt gönderme, şef web paneli) yok ve sunucu/hesap/upload gerektirdiği için kullanıcı kararlarını (K1–K6) bekliyor. CHOIR-M1 (`lib/choir/domain/`) ve MIDI-01 (`lib/choir/midi/smf_reader.dart`) saf Dart + testli, hiçbir ekrana bağlı değil. Kararsız yapılabilecek kod bitti; sonraki adım K1–K6 kullanıcı kararları.

IA-01b ile kalan Personal metinleri rol bağımsızlaştırıldı: SATB seçimi yalnız
“çalışma aralığı”dır; uygulama bunu ses tipi veya koro partisi kararı diye
sunmaz. Personal ders metinlerinde koro/parti varsayımı domain testiyle
engellenir. Onboarding'deki “Bir koroda söylüyorum” ve “Koro şefi” seçenekleri
bilinçli olarak kalır; bunlar gerçek rol seçenekleridir. Full1041 + 1 skip,
analyze/format temiz; ses motoru veya cihaz kabulü değildir.

AUDIO-01 kod kapısı da kapandı: `reference_engine_contract_test.dart` manifest
ve loader'dan geçen sentetik PCM16 ile kısa buffer'ın Hz uydurmadığını ve
C4/C5 mutlak oktavının korunduğunu doğrular. Full1043 + 1 skip. Bu BENCH-01,
VAD-01 veya CAL-02'nin yerine geçmez; gerçek kayıt/cihaz skoru açma.

## 2c. 2026-10-29 — TRAINER-02 farklılaşma

Referans uygulamaya benzerlik bilinçli olarak azaltıldı (ADR-033): Harmonia paleti ve buton/kart dili, Bugün/Koro/İlerleme/Ayarlar sekmeleri, 8 adımlı koro onboarding'i, `VoicePart` ile partiye göre çalma, yerel koro seviyesi. Lig, istatistik kilidi, kullanıcı adı/topluluk ve 30 adımlı akış kaldırıldı. Yeni ekranlarda referans uygulamanın metnini/düzenini geri getirme. TRAINER-03 (ADR-034) ile ders/quiz/müfredat da yeniden yazıldı: `_ladder` müfredatı, Dinle → Söyle → Ayırt et, `ListenDisc` quiz, `SkillScreen`. Sıradaki doğal adım: Söyle adımını kalite kapılı mikrofonla isteğe bağlı ölçmek (ayrı kaynak etiketiyle).

## 2b. 2026-10-29 güncellemesi — yeni ana deneyim (TRAINER-01)

`lib/main.dart` → `TrainerApp` (`lib/trainer/`). Aşağıdaki §3 eski `HarmoniaApp`
kabuğunu anlatır; o kabuk testleriyle korunuyor ama açılışta kullanılmıyor.
Yeni yapı: `trainer/domain` (müzik sözlüğü, ses tarifleri, müfredat),
`trainer/audio` (additive sentez + clip player), `trainer/quiz` (soru üretimi
ve ortak quiz ekranı), `trainer/learn`, `trainer/practice`, `trainer/home`,
`trainer/stats`, `trainer/settings`, `trainer/onboarding`, `trainer/koro`
(ses aralığı testi çekirdek `RecordingPitchAnalyzer` kalite kapısıyla; eski
deneysel tekrar ekranları `HarmoniaTheme` ile itilir). Durum tek JSON:
`trainer/state/trainer_store.dart`. Testler `test/trainer/`; ekran turu:
`flutter test test/trainer/screenshot_tour_test.dart --dart-define=TOUR_DIR=/abs/dir`.
iOS: Homebrew Flutter 3.47.8 ile `flutter run -d <simülatör>` çalışıyor (3.44.4
lipo kontrolünde düşerdi; gerekirse `ios/` içinde `xcodebuild ... -sdk
iphonesimulator ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build`). Simülatör açılmazsa
önce disk boş alanına bak (CoreSimulator plist okuyamayıp çöküyordu). Xcode 27'de
Simulator.app yerine `DeviceHub.app` var. Onboarding'i geçmek için uygulama
konteynerindeki `Library/Application Support/ear_trainer.json` dosyasına
`onboardingDone/setupDone: true` yazılabilir.

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

**2026-10-13 22:10 TRT — Flutter güncellemesi (kullanıcı onayıyla):** Flutter
3.44.4 → **3.47.7** (Dart 3.13.5). `flutter build ios --simulator --debug`
Xcode 27.0 ile **başarılı** (Runner.app); lipo engeli kapandı. Upgrade iOS
minimum hedefini 13.0 → 15.0 yaptı, analysis_options build/android/ios'u
dışladı, pubspec.lock'ta yalnız SDK'ya bağlı test paketleri değişti. Quality
check yeni SDK'da exit 0: 596 test, analyze temiz, 174/0 format. Simulator'da
elle gezinti/gerçek cihaz/mikrofon testi yapılmadı. Android cmdline-tools/lisans
hâlâ eksik.

**2026-10-13 devam — SHELL-04b:** common/content_status_panel.dart + history/
chord consumer, history LocalOnlyNotice scoped veri politikası. Loading/empty/
error explicit retry, auto reset/score/network yok; 6 yeni widget test. Son
runner 609 test, analyze temiz, 181/0. Günlük plan/export/report/SDK güncellemesi
zaten devralınmıştı; tekrar yapılmadı. Yayın/channel/privacy/error-log dirty
işleri korunuyor. Kalan SHELL-04 session resume/tüm consumer matrix ve gerçek
cihaz/voice/eğitimci kapıları ayrı. Bu tur commit/push/yayın yapılmadı.

**2026-10-14 00:13 TRT — güncel:** SHELL-04c DailyPlanScreen shared state
consumer + manual retry, selected budget retained, pending no stale plan;
mounted guard. _loadForView observes immediate errors before frame subscription
but returns original FutureBuilder future, so failure stays visible. 3 widget
regressions, final runner IMPLEMENTATION_LOG. No planner/mastery/score changes,
no data clearing or auto audio resume. Dirty release/channel/privacy/error-log
work preserved. SHELL-04 all-consumer/session resume and external gates open.

**2026-10-14 05:35 TRT — güncel:** SHELL-04d skill-map shared loading/error
retry; history unavailable => nullable view state / Durum alınamadı, NOT domain
notMeasured. Report/focus hidden on failure, text lesson navigation allowed;
no completion/mastery/history write. Immediate error observer + mounted reload;
4 new recovery/pending/dispose widgets. Final runner IMPLEMENTATION_LOG.
Scorer/mastery/learning routes unchanged. Release/platform/user dirty work
preserved; SHELL-04 resume/all consumers and actual voice/device/EDU gates open.

**2026-10-14 10:36 TRT — güncel:** REL-06a TargetNoteTuning metadata guard
ExerciseProtocol constructor'a bağlandı, JSON reconstruction da geçer. Strict
scientific note/MIDI0–127, 12TET/A4 expected Hz; ≤0.005000001Hz sadece rounded
2-decimal metadata payı. Student tolerances/scorer/legacy Exercise unchanged.
10 new tests, final runner log'da. ADR-025. Gerçek recording/tuning/rights/voice
QA değil. Tuning tutarlılığı açık maddesi artık code guard testli; REL-06 tüm
session/hint/metadata cohort kapısı değil. Release/user dirty korunur, push yok.

**2026-10-14 15:39 TRT — güncel:** REL-06b ExerciseProtocol.fromJson now
strict root/tuning/event/target fields/types/enums/schema integer; both≤256
lists preflight. Safe shape errors FormatException, constructor semantic
ArgumentError/tuning/recall rules unchanged. 10 regressions; 636 full runner,
186/0, analyze clean. Valid schema1 round-trip same; no IO/text duplicate-key
canonicalization/approval or acoustic correctness claim. Session hint/tuning
cohort and true content/device/EDU gates remain open; no commit/push/deploy.

**2026-10-14 11:55 TRT — en güncel (kullanıcı oturumu):** REL-09 kanal bayrağı
(`HARMONIA_CHANNEL=beta` geliştirici araçlarını gizler), Android imzalama/ad,
iOS PrivacyInfo.xcprivacy; OPS-01a yerel hata günlüğü. RELEASE_READINESS.md
yayın açıklarını listeler. iOS simulator ve Android debug APK build başarılı.
626 test. Commit edilmedi. Otomatik ajanla aynı dosyalarda (home/settings/
harmonia_app) çalışırken mevcut dirty değişiklikleri koru.

**2026-10-14 — UI-01 A+C (design/a-c dalı):** Yeni tasarım sistemi ve alt
sekmeli kabuk; gerçek veriye bağlı ses görselleri (ADR-026). Bileşenler
`features/common/ui/`, sesler `features/common/sound/`, kabuk `features/home/`.
Yeni ekran yazarken ChunkyButton/AnswerOption/FeedbackPanel/StatTile kullan;
etiketleri toUpperCase ile büyütme (Türkçe i/İ). Sonsuz animasyon ekleme
(testlerde pumpAndSettle takılır, pil tüketir). İkonlar
`flutter test tool/brand/render_icons_test.dart` ile üretilir; iOS ikonları
sonra alfasız yapılmalı (sips). Ana dala birleştirme kullanıcı onayı bekliyor.

**2026-10-15 — UX-02 (design/a-c dalı):** Ders ekranları `LessonScaffold`
(top/bottom), seviye `LevelPicker`, ızgaralar `EqualHeightGrid` kullanır;
LayoutBuilder'ı ders gövdesine koyma (intrinsic ölçüm). Taslak uyarılarını
kartlara geri ekleme; tek yer "Beta" sayfası. Ana dal birleştirmesi onay bekliyor.

**2026-10-14 20:42 TRT — son heartbeat REL-06c:** Ortak
RhythmReferenceClock controller/evaluator'da overflow/ms collision/30 s
render-budget kontrolünü round öncesinde yapar; renderer aynı sabit. Negatif,
unsafe integer veya backwards timestamp/replay quota invalidInput puansız;
eşit tap extra ve first-tap anchor/rubrik değişmedi. Invalid reference renderer
öncesinde controller playbackFailed/idle; gerçek latency ölçümü değildir.
10 yeni test, hedefli32/full646; format188/0, analyze temiz. REL-06b dahil dirty
değişiklikler korundu, commit yok. Gerçek cihaz/voice/EDU ve release kapıları
hâlâ açık; güncel roadmap bağımlılıklarına göre bağımsız güvenli işe devam et.

**2026-10-15 02:06 TRT — son heartbeat REL-06d:** ResultCohort sekiz alanla
measured catalog + rhythm next-step karşılaştırmasını birleştirir. Farklı skill/
mode/difficulty/scoring sürümü artık mastery/today/daily plan'a sızmaz. Same
cohort invalid retry için kalır; JSON schema/puan/eşik değişmez, geçmiş yazılmaz.
Rhythm metadata bound Exercise'ten, perception explicit current learning/1/2
touch contract'tan gelir. Yeni12, learning76/full658; format190/0, analyze temiz.
Önceki dirty işler korunur, commit yok. Tuning/protocol fingerprint ve replay/
hint claim authenticity henüz çözülmedi; REL-06/dış voice/device/EDU/yayın
kapıları tamamlandı sayılmasın. Sıradaki güvenli paket güncel bağımlılığa göre;
2/3/4 kayıt gelmeden kapalı, gerçek ölçüm kabul edilmeden skor açılmaz.

**2026-10-15 08:44 TRT — SHELL-04e:** Home TodayCard artık shared
ContentStatusPanel loading/error + manual retry kullanır. Future eager error
observer orijinal future'ı UI'ya döndürür; next-frame hızlı hata kapanır,
boş geçmiş/fake öneri üretilmez. Exercise dönüşü mounted reload, goal/repository
değişiminde fresh Future; eski pending completion FutureBuilder ile dışlanır.
6 fake widget: retry/no-write, pending, dispose, repository switch, fast return
failure,320px/1.8×. Narrow test scroll/reflow sonrası header'a döner; offscreen
lazy child assertion yok, retry hitTestable doğrulanır. Skor/planner/dep değişmez.
Tam session resume/SHELL-04 ve dış voice/device/EDU/yayın kapıları hâlâ açık.

SHELL-04e son doğrulama: targeted6/full664, runner exit0, analyze temiz,
format191/0, diff check temiz. Commit/build/device yok; önceki dirty işler korundu.

**2026-10-15 13:47 TRT — CORE-04c1:** `application/melody_practice.dart`
DiagnosticMelodyPractice orijinal DiagnosticMelodyReference'e bağlı explicit
half-open range1..5notes/repeats1..3. Infrastructure
renderDiagnosticMelodyPractice yerel synthetic WAV hazırlar; note600ms/gap200ms,
repeatGap1000ms/final400ms, max13.8s. Tam referans renderer aynı samples üretir.
Bu paket player/UI/mic/permission/history/score başlatmaz, hata bölümü çıkarmaz.
Sonraki hazır **CORE-04c2** seçili bölüm dinleme UI + exclusive player coordinator:
cancel/close/background/pending-start testleri, session capture ile overlap yok;
manual synthetic practice ayrı, recall/hint/assessment gibi kaydetme. Yanlış
bölüm otomatik önerisi hâlâ gerçek güvenilir karar kapısına bağlı. Mevcut dirty
REL/SHELL işleri ve 2/3/4 placeholder yönü korundu. Kod QA sonucu log/roadmap'te.

CORE-04c1 final: hedefli16/full672 (+8), runner exit0, analyze temiz,
format193/0, diff check temiz. Gerçek cihaz/pilot veya yayın kabulü değil.

**2026-10-15 — birleştirme sonrası:** A+C arayüzü main'de (0875983); ayrı dal
ve worktree silindi. Sıradaki işlerin tek listesi CURRENT_ROADMAP › "Kalan
işler — 2026-10-15". İlk kod işi: eski düzendeki ekranları LessonScaffold/
ChunkyButton/kısa metin kurallarına taşımak; dış kapıları geçmiş sayma.

**2026-10-15 18:45 TRT — UX-02b:** Birleştirme sonrası yeni UI önceliği
izlendi; ezgi session ekranı A+C LessonScaffold/ChunkyButton/StatusPill ile
migrate edildi. Short visible synthetic/unscored/phase; privacy/süre/kalibrasyon
detayı Nasıl çalışır? içinde. Session/DSP/history/score değiştirilmedi.
LessonScaffold progress artık nullable: null diagnostic için bar/percent yok,
natural scroll column (büyük yazı/expanding result overflow önlenir); numeric
derslerin eski layout'u korunur. Yeni4 + önceki8 melody widgets. CORE-04c2
henüz uygulanmadı, migration önceliği CURRENT_ROADMAP tek listesinde sürer.
apple-design okunabilirlik/agency/reduced-motion ilkeleriyle mevcut bileşenler
yeniden kullanıldı; gerçek cihaz/tasarım kabulü iddiası yok. Commit/push yok.

**2026-10-15 23:45 TRT — UX-02c:** Mikroders okuyucu A+C ortak lesson shell'e
taşındı (progress:null, kompakt Taslak header, draft pill, neutral disabled
practice, alt Geri dön). Beş faz/özgün metinler değişmedi. Objective/dimension/
no-mastery görünür; sürüm/approval detayı Ders bilgisi içinde. Okuma completion
veya history/mastery yazmaz, ses/mic yok. Map dönüş testleri lesson_close kullanır.
apple-design readability/agency/dynamic-type kontrolü; yeni motion/dependency yok.
Önceki dirty UX-02b korundu, commit yok. Kalan UI migration CURRENT_ROADMAP tek
listede sürer; CORE-04c2 ve gerçek BENCH/device/EDU/yayın kapıları açık.

**2026-10-16 05:23 TRT — UX-02d:** ChordPlaceholderScreen A+C lesson shell
progress:null + Kapalı header/draft status/neutral disabled6actions. Short
noaudio/mic/score notice and Nasıl çalışacak? explain prerecorded→sequential
response; no paths/notes/rights invented. _loadForView eager observer returns
original Future; loading first hides stale error/cards during manual retry,
mounted guard, late-error/dispose tests. Katalog/schema değişmez, kayıt gelmeden
modül açılmaz. Önceki dirty UX-02b/c korunur; apple-design readability/dynamic
type/control-state ilkeleriyle ortak bileşenler kullanıldı. Commit/build yok.

UX-02d final: hedefli10/full698 (+5), runner exit0, analyze temiz9.6sn,
format202/0, diff check temiz. Kalan migration ve dış acceptance devam ediyor.

**2026-10-16 10:24 TRT — UX-02e:** DataTransferScreen A+C null-progress
shell/ChunkyButton + local/audio-free notice/live status. Busy guard starts
BEFORE import dialog and spans export load/clipboard; two actions/input locked,
cancel text preserved. Clipboard safe errors replace stale success. Leaving
before export load completes prevents clipboard write; confirmed repo import
may finish after leaving (no cancellation/rollback claim). Schema1 unchanged,
non-string exportedAt now safe date format exception. New6widgets+1codec,
targeted18. Önceki dirty UI migration korundu; no network/audio/API. apple-design
readability/agency ile mevcut bileşenler kullanıldı. Kalan UI migration ve
gerçek BENCH/device/EDU/yayın kapıları açık; commit/build yapılmadı.

UX-02e final: hedefli18/full705 (+7), runner exit0, analyze temiz4.4sn,
format202/0, diff check temiz. Gerçek pano/cihaz/pilot doğrulaması değildir.

**2026-10-16 16:07 TRT — UX-02f:** SingleToneSessionScreen A+C
LessonScaffold(progress:null)/StatusPill/ChunkyButton; visible synthetic/unscored
C4 + live phase/calibration. Long4sn/privacy detail under Nasıl çalışır?.
Contextual calibrate→listen/sing, responding finish, active cancel; InputLevelMeter
same capture-only rules. Fresh attempt resets details. Domain/controller/
route/quality/scorer same, no verdict/history/mastery/progress fabricated.
New4widgets, targeted13 including meter/a11y. Önceki dirty işler korundu;
apple-design readability/agency/dynamic-type ile mevcut bileşenler kullanıldı.
Kalan UI migration ve gerçek voice/device/EDU/yayın kapıları açık; commit/build yok.

UX-02f final: targeted13/full709 (+4), runner exit0, analyze temiz6.9sn,
format202/0, diff check temiz. Gerçek mikrofon/cihaz/öğretim kabulü değildir.

**2026-10-16 21:07 TRT — UX-02g:** DailyPlanScreen A+C null-progress lesson
shell/StatusPill/ChunkyButton. Budget5/12/15 seçici, preferences ve actual round/
free minutes değişmedi; draft notice visible, schedule detayları plan_help'te.
Done block neutral Bir tur daha; pending primary. Planner/cohort/mastery/
retention/Future/retry logic aynı; viewing/close history yazmaz, numeric
readiness/progress yaratılmaz. Shell back test lesson_close kullanır. Yeni4,
targeted14. Önceki dirty UI işleri korundu, commit yok; apple-design readability/
agency/dynamic-type ile mevcut bileşenler kullanıldı. Kalan UI migration ve
gerçek BENCH/device/EDU/yayın kapıları açık.

UX-02g final: targeted14/full713 (+4), runner exit0, analyze temiz5.3sn,
format202/0, diff check temiz. Gerçek cihaz/öğretim kabulü değildir.

**2026-10-17 02:18 TRT — UX-02h:** Çalışma geçmişi A+C kartları,
StatusPill/DataLabel/ChunkyButton ve history_help. Uzun liste için lazy
ListView/AppBar korunur (LessonScaffold'a zorlama). Skill içeren record cohort,
createdAt son3, eksik/bozuk sayaçta unknown ve unsupported skill no numeric
trend; sıfır varsayımı kaldırıldı. Kart detayı da null/bozuk sayacı göstermez.
Fast error observer ve clear mounted guard; skor/rubrik/depo şeması aynı.
Yeni6 ile targeted16 geçti; dark/reduced-motion320px1.8× dahil. apple-design
readability/agency ilkeleri mevcut bileşenlere yön verdi. Önceki dirty işler
korundu, commit/build yok, gerçek veri silinmedi. Son runner exit0 full719
(+6), analyze temiz4.8sn, format202/0, diff check temiz. Sıradaki UI:
Ayarlar, Ses laboratuvarı, Tek ses sonuç örnekleri; ardından CORE-04c2. Dış
BENCH/device/EDU/yayın kapıları açık, otomatik takip bitmiş değildir.

**2026-10-17 13:10 TRT — UX-02i:** Ayarlar A+C kartları/StatusPill/neutral
ChunkyButton/semantic başlıklar; lazy list/AppBar korundu. Mikrofon/gizlilik
ayrıntıları expansion; cleanup warning dışarıda, abonelik/hesap yok bilgisi
aynı. Profil silme geçmişi silmez: rehber/onay bunu açıklar. Onay dahil delete
busy guard; hedef/deletion disabled during saving/deleting. Copy busy/live
status + stale success reset. Required MethodChannel platform.name + aynı
platform.codec ile Clipboard.setData: OptionalMethodChannel'ın eksik handler'ı
sessiz success sayması engellenir. Platform/MissingPlugin güvenli retry,
sanitized log formatı aynı; gerçek clipboard readback değildir. Started copy/
confirmed delete leaving sonrası tamamlanabilir, rollback iddiası yok; mounted
UI guard var. Yeni7, targeted24 geçti; dark/reduced-motion320px1.8× dahil.
apple-design readability/agency ilkeleri mevcut bileşenleri yönlendirdi.
Önceki dirty işler korundu; gerçek veri silinmedi, commit/build yok. Son runner
exit0 full726 (+7), analyze temiz4.5sn, format203/0, diff check temiz. Sıradaki UI Ses laboratuvarı,
Tek ses sonuç örnekleri; ardından CORE-04c2. Dış BENCH/device/EDU/yayın
kapıları açık; otomatik takip tamamlandı sayılmadı.

**2026-10-18 19:10 TRT — UX-02j:** 17 Ekim 18:41 TRT heartbeat işlendi;
clock çalışma gününü 18 Ekim doğruladı. Ses laboratuvarı null-progress A+C
LessonScaffold/StatusPill/ChunkyButton, görünür sentetik C4/deneysel/puansız
limit; kayıt/privacy yardımda. Phase+error live, kayıt metadata DataLabel,
quality ve diagnostic ayrı kartlar. Başlat/referans/kalibrasyon active fazlarda
gizli; bitir/iptal, InputLevelMeter capture-only aynı. Kalibrasyonun mevcut
kaydı sileceği açık. A11y coral kontrast3.95 bulundu: yalnız lab record/finish
primary tona alındı, guidelines geçti. Controller/DSP/quality/route/rubrik/
worker/lifecycle değişmedi, nota/puan/history/mastery yok. Yeni5 hedefli17,
dark/reduced-motion320px1.8× ve late permission/worker dahil. apple-design
readability/agency ilkeleriyle mevcut bileşenler kullanıldı. Son runner exit0
full731 (+5), analyze temiz7.8sn, format203/0, diff check temiz;
önceki dirty işler korundu, gerçek veri silinmedi, commit/build yok. Kalan UI
Tek ses sonuç örnekleri; ardından CORE-04c2. Gerçek BENCH/device/EDU/yayın
kapıları açık, otomatik takip bitmiş değildir.

**2026-10-18 19:13 TRT — UX-02k:** SingleToneExerciseScreen mock gallery
A+C null-progress LessonScaffold/StatusPill/ChunkyButton/DataLabel. Görünür
simülasyon/mikrofon kapalı/kişisel başarı değil; hedef/yönerge/puanlar örnek,
yardımda no playback/capture ve gerçek oturum ayrımı. Hardcoded green/amber
yerine tema correct/wrongOctave/nearMiss/notMeasured (invalid nötr). Skorer,
tolerans ve mocked payload aynı. _runScenario single-flight+stale reset,
mounted-before-score, safe error/retry/finally unlock; late error consumed.
History/mastery/API/audio yok. Yeni5 ile targeted24; tüm7 senaryo dark/reduced-
motion320px1.8× ve iki tema a11y. apple-design readability/agency ilkeleriyle
mevcut bileşenler kullanıldı. Son runner exit0 full736 (+5), analyze temiz4.3sn,
format203/0, diff check temiz; önceki dirty işler korundu,
commit/build yok. Adı listelenen migration ekranları tamam; sıradaki hazır iş
CORE-04c2 seçili ezgi bölümünü dinleme/player bağlantısı. Diğer UX backlog'u
ve gerçek BENCH/device/EDU/yayın kapıları açık; otomatik takip bitmedi.

**2026-10-19 10:12 TRT — CORE-04c2a:** Yeni melody_practice_playback.dart
MelodyPracticePlayback + practice.dart DiagnosticMelodyPracticePlayer only
play/stop/close. Native mutation queue, single-flight, identical bound reference,
epoch/wake noautoplay/late handle observer, idempotent close. Stop pendingload
sonrasına sıraya girer ama completion'ı beklemez; cleanup fail sticky locked.
SyntheticMelodyPracticePlayer existing c1 WAV'ını fresh ReferenceClipPlayer'a
verir; capture/session backend/player paylaşılmaz. UI henüz bağlı değil,
background test controller.stop çağrısı, gerçek lifecycle/focus kabulü değil.
Yeni10 controller +2 adapter, targeted38/full748; runner exit0, analyze temiz
11.3sn, format205/0 ve diff check temiz; önceki dirty işler
korundu, commit/build yok. **Sıradaki c2b**: explicit range/1–3 repeat, ayrı owned
player ekranı; parent capture idle/kapalı ve eşzamanlı session girişini
engelleyen navigation ownership; background/focus/close ve pendingstart exit,
dar ekran/manual synthetic etiketi widget testleri. Rehearsal completion'ı
attempt/referencePlays/recall/history/mastery'ye yazma. CORE-04c2 bütünü ve
gerçek BENCH/device/EDU/yayın kapıları açık; otomatik takip bitmiş değildir.

**2026-10-19 15:15 TRT — CORE-04c2b:** Yeni MelodyPracticeScreen explicit
start/end dahil range, 1–3 repeats, Hz, manual/synthetic/puansız, noauto/mic/
score/history. A+C LessonScaffold/ChunkyButton/Dropdown; busy/background/
monitoring gate. Parent MelodySessionScreen idle/canStart only + handoff
guard, await session.close before factory, pushReplacement: eski oturum geri
gelmez, back önceki sayfaya döner (visible copy). Native close bekleyen child
PopScope system/lesson back'i gate eder; failed close restart uyarısı, unsafe
route release yok. Lifecycle inactive/background + mobile AudioSession
interruption/noisy/device events stop, resume autoplay değil; monitor errors
play'i kapatır. Fake player/event injection mevcut. Yeni11 targeted28 geçti,
iki tema a11y/dark reduced-motion320px1.8×. Header Puansız ile overflow düzeldi.
apple-design readability/agency ilkeleri bileşenleri yönlendirdi. Son runner
exit0 full759 (+11), analyze temiz3.6sn, format207/0 ve diff check temiz.
Önceki dirty işler korundu, commit/build yok. c2 ekran bağlantısı
kod-test hazır, gerçek native focus/route/playback/EDU/device kabulü değil.
Sonraki hazır iş: onboarding mevcut 5/12/15 günlük süre tercihi. Gerçek
BENCH/device/EDU/yayın kapıları açık; otomatik takip bitmedi.

**2026-10-20 — ONB-01:** 19 Ekim20:56 TRT heartbeat. GuestOnboardingScreen
goal draft→5/12/15→home; explicit save-before-chooseGoal, skip preserves
prior/default12. Settings/returning profile same. Preferences schema1/profile/
planner/scorer/history/audio unchanged. Busy/back/dispose guard; budget await
sonrası disposed ise profile save başlamaz. Partial budget-success/profile-
failure disclosed; retry no resave. Started file write rollback iddiası yok.
Selected AnswerOption fill opaque alphaBlend(theme surface), iki tema
kontrastı testli; diğer states/layout aynı. apple-design readability/agency
ile A+C bileşenleri kullanıldı. Yeni9 + mevcut18 shell/a11y; full768 (+9),
runner exit0, analyze temiz3.7sn, format209/0, diff check temiz. Eski iki
onboarding test confirm/skip'e uyarlandı. Dirty işler korundu, commit/build
yok. Sonraki güvenli iş ana sayfa yükleme iskeleti. Gerçek voice/BENCH/
device/EDU/yayın kapıları açık; otomatik takip bitmiş sayılmadı.

**2026-10-20 — HOME-01:** 19 Ekim22:59 UTC heartbeat. Home static skeleton
replaces loading panel (today_loading key retained), single live-region label,
decorative semantics excluded; no shimmer/timer/fake scores/actions. Existing
tokens and apple-design readability/reduced-motion guidance used. FutureBuilder
may retain old data: only done/no-error data feeds streak/path/recommendation.
Pending/error hides stale content; retry safe, repository/planner/scorer same.
Yeni4 targeted15; full772 (+4), runner exit0, analyze temiz5.2sn, format209/0,
diff check temiz. Two themes320px1.8× reduced-motion, refresh/error/retry,
replacement repository, late disposal error tested with fakes only. Dirty işler
korundu; Agora mevcut dirty kaynaklarına dokunulmadı; build/commit/deploy yok.
Next safe backlog: algı turu sonuçlarında ne duydun/ne seçtin/doğrusu ve
karşılaştırmalı tekrar dinleme; önce mevcut perception/interval session ve
playback lifecycle sözleşmelerini oku. Real device/VoiceOver/BENCH/EDU/yayın
kapıları açık; otomatik takip tamamlandı sayılmadı.

**2026-10-20 — REVIEW-01a:** User requested continue. Added AnswerComparisonCard
and eight-card read-only review to interval/high-low summaries. Known synthetic
reference / selected touch answer / correct label, explicit correct/different/
unanswered status; no inference about internal hearing or singing. Optional
closed disclosure, new-round before review. No controller/domain/scoring/schema/
history/playback change. Existing theme tokens; apple-design readability/agency
and reduced-motion guidance; wide Wrap vs stacked large text. LayoutBuilder
inside intrinsic shell initially failed; removed. LessonScaffold bottom-empty
branch now uses natural scroll to handle expandable results without overflow;
bottom-action questions unaffected. Yeni5 + extended2 tests targeted7; full777,
runner exit0, analyze clean3.5s, format211/0, diff check clean. Dirty files kept;
Agora untouched. No build/real-device/API/upload/commit/push/deploy. UX item
remains open: **next REVIEW-01b comparative audio replay**. Inspect and strengthen
player pending-load/stop/close ordering and lifecycle before enabling; preserve
finished outcome, plays/retention counters and saved history during review.
Current detailed review is in-memory/session-only, not a history migration.
Real BENCH/device/VoiceOver/EDU/release gates remain open; automation not done.
REVIEW identifiers are separate from historical UX-03a input-level work.

**2026-10-20 — GROW-01a:** User requested three commercially successful app
benchmarks and feature adoption. COMMERCIAL_BENCHMARK_2026-10.md documents
Simply/Simply Piano, Yousician, Duolingo Music: source/date/financial-scope
caveats; not a top-grossing rank or feature-attributed revenue proof. Existing
F02/05/09/12/15/16/17/19/21 acceptance expanded; F27 habits and F28 family plan
added. Do not expand into a general piano app or licensed catalog for MVP.
Code: HomeData.recentPracticeOf returns immutable rolling7 local calendar days,
valid matching current catalog cohorts only, no future timestamps, unique days;
zero-correct valid result counts. RecentPracticeCard after loaded SkillPath,
theme/Wrap/status text, no animation, no activity-as-mastery claim. Old streak,
planner/scorer/storage unchanged. New4 data +2 theme widgets and pending test
extended. Full783 (+6), runner exit0, analysis clean12.8s, format213/0, diff clean.
apple-design readability/reduced-motion guidance informed UI. No build/physical
device/API/upload/payment/commit/push/deploy; dirty changes preserved, Agora
untouched. **Next audio job REVIEW-01b remains**, then GROW-01b optional weekly
target/reminder permission/plugin/device gates. F28 family/social requires
DATA/PAY/privacy pilot; not enabled or priced. Real device/BENCH/EDU/release
and retention/revenue experiment gates stay open; automation not complete.

**2026-10-20 — REVIEW-01b:** Added explicit optional result playback to
interval/high-low AnswerComparisonCards. No autoplay. New application
ReviewPlaybackCoordinator serializes stop/load/play, invalidates pending stale
requests, latest wins, supports Durdur, recoverable failure and close. Interval
plays reference or selected touch degree; pitch comparison replays reference.
Finished outcome identity, plays/retention and saved history remain unchanged;
background pause stops review without resetting result. Both screens use a
PopScope close gate; active audio closes before pop, player close failure blocks
unsafe release and explains restart. apple-design agency/readability guidance
informed explicit/interruption controls and no new motion. New4 coordinator +2
route tests; controller/screen tests extended. Targeted24; full791 (+8), runner
exit0, analyze clean3.2s, format216/0, diff clean. Fake/synthetic only—not
physical playback, native focus, screen-reader or EDU acceptance. Agora untouched;
dirty work preserved; no build/API/upload/payment/commit/push/deploy. REVIEW-01
code scope complete; next safe item GROW-01b voluntary local weekly goal. Keep
notification permission/plugin/device work separate. Real BENCH/device/EDU/
release gates remain open; do not claim live-ready.

**2026-10-20 — GROW-01b:** RecentPracticeCard now has optional local none or
2/3/4/5-day rolling7 goal. It reuses GROW-01a valid supported days; low scores
count, demo/invalid/future/unknown do not. Copy says not mastery/exam/streak,
no penalty; change/disable anytime. Save is single-flight; failure preserves
old goal. Practice preferences schema2 stores nullable budget+goal, exact v1
budget migrates, serialized read-modify-write prevents lost independent fields.
New2 storage +2 widget tests; targeted24, full795 (+4), analyze2.9s,
format217/0, diff clean. No notification permission/plugin/scheduler/network,
account, telemetry, reward or payment. Agora untouched; dirty work preserved;
no build/commit/push/deploy. Native reminder/device QA remains open. Next safe
product package: bind existing error evidence to short targeted retry actions;
do not claim live-ready while BENCH/device/EDU/release gates remain open.

**2026-10-20 — RETRY-01a:** Implemented user-started exact-mistake short rounds
for pitch high/low and movable-do interval summaries. Same item frequencies/
tonics, normal listen-answer-feedback; UI label “Tekrar”, no full-round threshold.
Fresh full round stays separate. Guided retry disables retention and never writes
history/mastery. Domain rounds carry guided=true and Outcome.toResult throws,
so accidental evidence conversion is fail-closed. New2 controller tests; both
320px1.8× screen flows extended, pitch guided loop completed end-to-end.
Targeted15; full797 (+2), analyze/format/diff clean. Synthetic/fake only; no
device or educator acceptance. Agora untouched, dirty work preserved; no build/
commit/push/deploy. Next safe work: rhythm/melody error-segment practice using
existing deterministic evidence; do not claim live-ready.

**2026-10-20 — RETRY-01b handoff:** Rhythm imitation results can now start a
short excerpt around the first timeline error. Source onsets are reused and
locally rebased; no generated rhythm or inferred learner intent. Guided outcome
is marked, excluded from history/next-step, and `toResult` throws. Full800,
analyze/format/diff clean; synthetic/fake only. Next safe F09 work is melody
error segmentation, but current melody practice is intentionally unscored and
has no trustworthy per-note learner alignment—do not fabricate a segment until
deterministic answer evidence exists. Real device/EDU/BENCH/release gates open.

**2026-10-20 — REM-01a handoff:** Added local reminder time schema3 with exact
v1/v2 migration plus `PracticeReminderPlatform` and fail-closed single-flight
coordinator. Saved state changes only after native schedule/cancel success;
storage failure triggers rollback attempt. Production adapter returns
unavailable, so no real notification/permission/alarm/UI is enabled. New8,
full808, analyze/format/diff clean. Next work needs a deliberate native plugin,
permission copy, settings UI and physical iOS/Android delivery tests; do not
present REM-01a as a working reminder. Melody auto-segment remains blocked by
unvalidated per-note learner alignment; existing manual excerpt stays puansız.

**2026-10-21 — REM-01b handoff:** Settings contains a tested reminder card for
time select/enable/change/disable and denied/pending/failure copy. HarmoniaApp
still injects `UnavailablePracticeReminderPlatform`; production therefore
shows “Kullanılamıyor”, offers no action and triggers no permission. New4,
full812, analyze/format/diff clean. Do not call reminders complete until a
chosen native adapter, reviewed permission copy and physical iOS/Android alarm
delivery tests exist. The later HAPTIC-01 package closes only the local
preference/code gate; physical-device vibration remains open.

**2026-10-21 — HAPTIC-01 handoff:** Settings now persists a default-on haptic
preference in schema4. `HarmoniaHapticsScope` gates all current direct Flutter
haptic calls; save-before-publish keeps runtime and disk consistent on failure.
Platform-channel and widget/storage tests pass; full815, analyze/format/diff
clean. Do not claim physical-device vibration validation. Native reminder
work is superseded by REM-01c at code/build level; physical iOS/Android delivery
is still open.

**2026-10-21 — REM-01c handoff:** Production now injects a tested native local
notification adapter instead of the unavailable fallback. Dependencies are
`flutter_local_notifications`22.3.2, `flutter_timezone`5.1.1 and
`timezone`0.11.2. Permission remains explicit, Android scheduling is inexact
idle-capable (no exact-alarm permission), device IANA time is used, reboot/iOS
native setup is present, and denial offers OS notification settings. Full820,
analyze/format/diff clean; Android debug and iOS simulator debug builds pass.
Do not call delivery verified until physical iOS/Android permission, scheduled
delivery, reboot/DST and OEM battery tests pass. No push service exists.

**2026-10-21 — SHELL-02 handoff:** After an actual microphone denial, single
tone, melody and audio lab now expose one explicit OS app-settings action via a
small application port and `permission_handler`12.0.3 adapter. No screen entry
prompts or opens settings; duplicate launches are locked and false/exception is
visible. Full824, analyze clean, format228/0; Android debug APK and iOS simulator
debug builds pass. Version13 was rejected because it requires compileSdk37 while
the current AGP9.0.1 recommends36. Do not claim real permission recovery until
physical iOS/Android denial, settings and resume/retry tests pass. Dirty user/
agent changes remain uncommitted; Agora untouched.

**2026-10-22 — SHELL-03a handoff:** Today now offers an optional three-round
starting check over 200-cent pitch direction, steady-quarter pulse and first
movable-do degree. It reloads local history, retries invalid evidence, continues
untried items and may suggest the first valid weak area. Unknown engine/content/
educator skills are counted explicitly; there is deliberately no level,
percentage, admissions or readiness score. New8; full832, analyze clean,
format233/0. SHELL-03b still needs educator level definitions and learner
acceptance. Do not promote this to conservatory placement. No build was needed
for this Dart/UI-only package; prior Android/iOS build evidence is unchanged.

**2026-10-22 — SHELL-04f handoff:** Today derives one safe return target from
the latest completed local result matching a supported current cohort. The CTA
always opens a fresh round; it never restores an in-flight question, player,
audio or microphone. Invalid current evidence can be retried; stale/future/
unknown evidence is ignored. New6; full838, analyze clean, format236/0. No
native/audio change, so prior build evidence is unchanged. Remaining work is
the broader offline/consumer matrix and physical device acceptance; do not
describe SHELL-04 as complete. Dirty worktree preserved; no commit/push/deploy.

**2026-10-22 — F06a handoff:** Wrong-answer pitch-direction and pulse results
now offer an optional link to their existing draft text micro-lesson. Opening
it adds no playback/capture and cannot change history, score, mastery or next
step; expanded widget flows verify player/history stability. Full838, analyze
clean, format236/0. Do not call F06 complete: educator-approved examples/audio
and a teaching pilot are still absent. No native change/build; dirty worktree
preserved, no commit/push/deploy.

**2026-10-22 — F06b handoff:** Added a third graph-bound draft micro-lesson for
movable-do tonic/degree and linked it from wrong interval results. Navigation
does not add playback or mutate the exact local result; catalog/codec and the
interval end-to-end flow pass. Full838, analyze clean, format236/0. This remains
draft text with empty example slots—not educator approval, licensed audio or
teaching evidence. No native build; dirty tree preserved; no commit/push/deploy.

**2026-10-22 — GROW-01c handoff:** The development screen now includes a
read-only weekly practice summary for the selected route: active days, valid
current-cohort rounds by exercise, incomplete measurements and valid-volume
comparison with the preceding seven local calendar days. Future/stale/unknown
evidence is ignored and empty history invents no progress. The UI explicitly
states this is not skill growth, readiness or exam success. New6; full844,
analyze clean, format238/0. No native/audio change, so prior build evidence is
unchanged. Learner-language acceptance and real teaching/device validation are
still open; dirty tree preserved, no commit/push/deploy.

**2026-10-23 — RETRY-01c handoff:** The unscored melody diagnostic now runs
its target-independent frequency candidates through the existing exact-order
symbolic aligner. A first reference-indexed difference may offer an explicit
two-note candidate review; the old capture owner closes before a fresh player
route opens, and playback never autostarts. Clean and extra-only comparisons
abstain. This creates no score/history/mastery/retention or memory result, and
the UI explicitly avoids calling it a verified error. New4; full848, analyze
clean, format238/0. BENCH/VAD, physical playback and educator acceptance remain
open; no native build, commit, push or deploy.

**2026-10-23 — DATA-03b handoff:** Local clipboard import now calls a shared
batch history operation. Memory/file adapters plan duplicate, conflict,
recorded and capacity outcomes with the existing attempt-id rules; the file
adapter writes all accepted additions in one temp+rename commit. A write failure
leaves no visible imported prefix, and the UI says the batch added nothing.
New4; full852, analyze clean, format238/0. This is not cloud sync or physical
cross-device clipboard proof: DATA-01/02 account/backend/outbox, consent and
device QA remain open. No native build, commit, push or deploy.

**2026-10-23 — SHELL-04g handoff:** Today now reloads local evidence once after
a real background→foreground transition. `inactive` and repeated `resumed`
events do not reload; the existing fail-closed loading shell hides stale
recommendations until the read completes. No media/session restore, autoplay,
history write or sync was introduced. New2; full854, analyze clean,
format238/0. Physical lifecycle/offline acceptance remains open; no native
build, commit, push or deploy.

**2026-10-23 — SHELL-04h handoff:** `ForegroundRefreshState` now owns the
one-shot local-view lifecycle rule for Today, daily plan, skill map and history.
Each consumer replaces stale local evidence with its fail-closed loading state
after a real background return; no write, navigation, playback, capture or
session restore is possible through the helper. New3; full857, analyze clean,
format239/0. Physical-device lifecycle/offline acceptance remains open; no
native build, commit, push or deploy.

**2026-10-24 — SHELL-04i handoff:** Daily plan, skill map and history now
invalidate their local projection when repository/goal/preference dependencies
are replaced. Existing evidence disappears behind the normal fail-closed
loading state until the new source resolves; a new preference store cannot
inherit the old in-memory budget. New3; full860, analyze clean, format239/0.
This is not account sync or device acceptance; no native build, commit, push or
deploy.

**2026-10-24 — DATA-03c handoff:** Local export v2 carries daily budget and
weekly goal through strict portable preferences; v1 remains readable. Reminder
time/permission and haptics never transfer. File preferences apply both portable
fields atomically while preserving device-only fields. History commits first;
preference failure is reported as partial rather than cross-file atomic. New3;
full863, analyze clean, format239/0. No audio/cloud/account proof, native build,
commit, push or deploy.

**2026-10-25 — DATA-03d handoff:** A successful portable-preference import now
increments an app-scoped revision. Today reloads daily budget and weekly goal
without replacing Home/Navigator, so the selected tab survives; generation
gating prevents an older async read from overwriting the imported values. The
import callback fires only after preference persistence succeeds. New1 widget
plus the strengthened import regression; full864, analyze clean, format239/0.
This is process-local freshness, not cloud/account sync or physical two-device
proof. No native build, commit, push or deploy.

**2026-10-25 — SHELL-04j handoff:** Today now treats preference repository
identity as projection state independently of the import revision. A new store
re-reads budget/weekly goal; a generation token rejects late reads from the old
store. One adversarial widget test replaces a pending 5-minute/two-day source
with 15-minute/four-day data and proves no rollback. Full865, analyze clean,
format239/0. No native/audio change, device/account/sync proof, commit, push or
deploy.

**2026-10-25 — SHELL-04k handoff:** Weekly-goal saves are bound to the store
identity and read generation present at start. Replacing the store clears old
pending/error presentation; a late old-store success or failure cannot mutate
the new goal UI. One adversarial widget test; full866, analyze clean,
format239/0. Generated Flutter build/cache output was cleaned after disk
exhaustion and locked dependencies restored; no source/user files, native
behavior, commit, push or deployment changed.

**2026-10-25 — SHELL-04l handoff:** Today now clears the previous preference
store's cached budget and weekly goal as soon as repository identity changes.
While replacement reads are pending it shows the safe 12-minute/no-goal local
projection; same-store revision refreshes remain visually stable. One
adversarial widget test covers old 5-minute/two-day → pending safe default → new
15-minute/four-day. Full867, analyze clean, format239/0. No native/audio change,
device/account/sync proof, commit, push or deployment.

**2026-10-26 — SHELL-04m handoff:** A new adversarial widget test proves
replacement preference reads fail independently: the new 15-minute budget may
publish while a failed weekly-goal read remains safely goal-free, with no old
two-day value or async UI exception. The current read failure shows a neutral
safe-default warning; stale generations cannot show it. Targeted7; full868,
analyze clean, format239/0. No audio/native behavior, device/account/sync proof,
commit, push or deployment changed.

**2026-10-26 — SHELL-04n handoff:** Current preference-read failures now show
an explicit “Tercihleri yeniden yükle” action. It starts a new generation only
for the currently bound store; successful recovery publishes the four-day goal
and removes warning/retry. Save failures do not receive the read retry.
Targeted10; full869, analyze clean, format239/0. No audio/native behavior,
device/account/sync proof, commit, push or deployment changed.

**2026-10-26 — SHELL-04o handoff:** Today now exposes a bounded preference
loading state and disables weekly-goal writes until budget and goal reads both
settle. The replacement-store regression proves controls stay closed while
pending and reopen after 15-minute/four-day data arrives. Targeted10; full869,
analyze clean, format239/0. No audio/native behavior, device/account/sync proof,
commit, push or deployment changed.

**2026-10-26 — REL-08a handoff:** The canonical local quality runner now adds
`--concurrency 4` to its full Flutter test step. CLI plan/default-argv tests
lock the setting. `dart tool/quality_check.dart` completed exit0 with
format239/0, clean analysis and full869. This fixes host-dependent test
resource pressure only; it is not device/audio/pilot/hosted-CI/release proof.
No dependency fetch, build, commit, push or deployment was performed.

**2026-10-26 — UI-01b handoff:** `tool/brand/render_icons_test.dart` now
generates modern iOS universal 1024 px default/dark/tinted assets from the
existing mark. Dark is transparent with the gold accent; tinted is transparent
grayscale. `Contents.json` has exactly the three Xcode 27 slots; obsolete
generated per-size iOS PNGs were removed. Four tests cover catalog/files,
dimensions, alpha and grayscale; actool is warning-free. Full873, analyze
clean, format240/0. Flutter simulator build still hits the pre-existing
`debug_unpack_ios` lipo false negative before asset compilation; do not claim
device/store acceptance. No commit, push or deployment.

**2026-10-27 — CONS-01a handoff:** Added
`lib/domain/audio/reviewed_chord_recording_manifest.dart` plus 10 tests. It is
a strict metadata boundary for future user-recorded 2/3/4-note PCM16 WAVs:
voice-count folder, ascending MIDI labels, hash, bounded header declarations,
rights reference and separate label-review reference. It performs no IO and
is intentionally not wired to the bundled placeholder. Next CONS-01b requires
the user's real recordings and a read-only byte/header/hash adapter; do not
mark files playable from metadata alone. No player, score, mic, UI, commit,
push or deployment. Targeted10/full883 pass; analysis clean, format242/0.

**2026-10-27 — CONS-01b handoff:** Added
`ReviewedChordRecordingLoader` and 12 tests. It safely reads future manifest
entries from an explicit local root, rejects symlinks/path escapes, checks
size/hash and parses PCM16 mono/stereo RIFF metadata for exact rate/channel/
frame agreement. It returns defensive bytes but never starts a player. Tests
use temporary synthetic zero PCM; full895/analyze/format244 clean. Next
CONS-01c needs the user's recordings, joint note/timbre/rights QA and a
fake-tested player/session. Do not wire placeholder availability from loader
success alone. No commit, push or deployment.

**2026-10-27 — CONS-01c handoff:** Added `ChordReferenceSession` plus 10 fake
player/clock tests. It binds one reviewed record and defensive WAV snapshot,
never autoplays, and exposes sequential-response readiness only after complete
playback, successful stop and bounded recall delay. Cancel/background/route
interruption invalidates the run without auto-resume; cleanup failure blocks
replay and close is serialized/idempotent. It does not open a microphone,
segment/score a voice, or write history/mastery. Keep the placeholder disabled.
Next: real piano note/timbre/rights QA, production loader→player/UI composition,
then CONS-02 monophonic sequential response alignment and device route tests.
Targeted10/full905 pass; analysis clean, format246/0. No commit, push or
deployment.

**2026-10-27 — CONS-02a handoff:** Added pure-domain
`ChordResponseMatcher` plus 10 controlled synthetic-frame tests. It converts
reviewed MIDI+A4 labels and existing monophonic diagnostic segments into an
exact low→high symbolic comparison. Missing, extra/duplicate, wrong pitch,
wrong octave and the same absolute targets in another order remain distinct.
Empty/invalid evidence abstains; provenance/analyzer and discarded-frame counts
survive. Do not persist `diagnosticCandidateMatch` as score, history, mastery or
exam evidence. Next safe work can prepare composition interfaces; actual enable
still requires real piano QA, BENCH/VAD, physical routes and UI/capture wiring.
Any-order/set matching remains open. Targeted10/full915 pass; analysis clean,
format248/0. No commit, push or deployment.

**2026-10-28 — CONS-02b handoff:** `ChordResponseMatcher.compare` now accepts
the protocol `ResponseOrder`. Exact keeps the existing sequence alignment;
any-order adds immutable counts for exact absolute targets, wrong octaves,
missing targets and extra/duplicate candidates. A bounded 2^N DP prevents one
candidate from satisfying two targets and leaves unrelated pitch as missing +
extra. Six added tests bring the matcher suite to 16. Do not convert either
mode's diagnostic candidate match into score/history/mastery. Real piano QA,
capture/UI composition, BENCH/VAD and physical routes remain open. No commit,
push or deployment. Matcher suite16/full921 pass; analysis clean, format248/0.

**2026-10-28 — CONS-01d handoff:** `ChordReferenceSession` now accepts only
learning or recall-exam mode, counts completed native playback callbacks and
enforces an explicit 1–10 learning quota. Recall exam is exactly one listen and
hides targets. Cancel/interruption/start failure consume no quota; replay
revokes response readiness until its own playback+recall completes.
`PianoChordReference` validates the same recall invariant. Three new session
tests bring that suite to 13; targeted session+reference20 pass. Treat the count
as operational callback evidence only, never audibility, score or mastery.
Production UI/events, real piano and device lifecycle remain open. No commit,
push or deployment. Full924 passes; analysis clean, format248/0.

**2026-10-28 — CONS-01e handoff:** Added the app-layer
`ChordReferenceSessionComposer`. It binds metadata and defensive bytes from one
`LoadedChordRecording` to a fresh owned player/session, validates replay/recall
policy before player allocation and never autoplays. Five tests cover binding,
recall policy, invalid preflight, factory failure and independent ownership.
Keep the placeholder disabled: no production player, real piano QA, UI/capture,
BENCH/VAD or physical route was exercised. Next safe code work may prepare
event/capture interfaces, but enabling requires the user's recordings and joint
QA. No commit, push or deployment. Targeted composer+session18/full929 pass;
analysis clean, format250/0.

**2026-10-28 — CONS-02c handoff:** Added `ChordResponseCaptureSession` and 10
fake-backed lifecycle tests. It requests permission before the first reference,
opens capture only after complete playback+recall, revokes readiness on replay,
and snapshots one bounded sequential response before deleting backend-owned
audio. Cancellation, focus/route interruption, pending native start and cleanup
failure are serialized/fail-closed; close owns both reference and capture
resources. The snapshot is not VAD, quality, pitch, score or learner evidence.
Next safe package is snapshot→quality/worker/segment/matcher composition; do not
enable UI before real piano joint QA and BENCH/VAD/device gates. No commit, push
or deployment. Full939 passes; analysis clean, format252/0.

**2026-10-28 — CONS-02d handoff:** Capture snapshots now retain the reviewed
recording plus capture-time route. Added `ChordResponseDiagnosticAnalyzer` and
7 tests: missing/wrong-route calibration and silence stop before DSP; usable
synthetic exact/any-order responses reach worker→segment→matcher; worker errors
and provenance promotion abstain. Metadata/source must remain identical. This
is candidate-only diagnostic evidence, never VAD, score/history/mastery or AI
input. Next safe work is chord calibration session/UX composition; actual UI
enable still needs real recordings, joint QA, BENCH/VAD and device routes. No
commit, push or deployment. Full946 passes; analysis clean, format254/0.

**2026-10-29 — CONS-02e handoff:** `ChordResponseCaptureSession` now owns an
explicit bounded room-calibration action on the same serialized backend queue.
It requests permission, snapshots route, records 1.5–5 seconds, verifies
metadata against PCM, discards native audio, then retains only an in-memory
noise-floor calibration. Noisy/activity/invalid/interrupted attempts are
neutral retries. Calibration survives reference playback but is cleared by
cancel, interruption and close; the analyzer still rechecks route/rate/age.
Six tests bring full suite to 984 passed plus one opt-in screenshot tour
skipped; analysis clean. Keep the 2/3/4 UI disabled until real recordings and
joint note/timbre/rights QA; BENCH/VAD and physical-device route checks remain.
No commit, push or deployment.

**2026-10-29 — CONS-02f handoff:** Added
`ChordResponseAttemptCoordinator`, the UI-facing owner for calibrate → reviewed
reference → sequential response → diagnostic analysis. It blocks product
listen/respond actions until calibration is usable, separates quality retry
from worker unavailable, and never persists candidate evidence. Capture
identity plus an analysis epoch suppresses pending results after cancel,
replay/interruption or close; close remains idempotent and owns the session.
Seven tests bring the full suite to 991 passed plus one opt-in screenshot tour
skipped; analysis/diff clean. Keep placeholder disabled until real recordings
and joint note/timbre/rights QA. Production player/UI, BENCH/VAD and physical
device routes remain open. No commit, push or deployment.

**2026-10-29 — TRAINER-04a handoff:** Added
`lib/trainer/sing/trainer_pitch_sing_session.dart` without touching the dirty
TRAINER-03 screen rewrite. It maps only a valid pitch lesson item/register and
optional choir part to immutable MIDI/Hz, renders the selected trainer timbre,
plays through a dedicated owned clip player and reuses SESSION-01 for calibrated
quality-gated capture. It exposes only unscored diagnostic evidence and cannot
write TrainerStore/history/mastery/completion/unlocks. Seven tests bring the
full suite to 1000 passed plus one opt-in screenshot tour skipped; analyze,
format and diff checks are clean. Next UI work may compose this into the pitch
lesson “Söyle” page, but must retain optional skip/retry, source labeling and
no-score language; real phone/human BENCH/VAD gates remain open. No commit,
push or deployment.

**2026-10-29 — TRAINER-04b handoff:** The pitch lesson “Söyle” page now owns
the optional TRAINER-04a diagnostic. Entry never requests permission or starts
audio; calibration and listen/respond are explicit, and “Ayırt etmeye geç”
always remains available. The screen shows phase, actual source and signed
cents with no-score copy. Pause/background cancels and resume never autoplays;
leaving closes+disposes the session. Factory failure is neutral/skippable,
non-pitch lessons and `liveAudio=false` stay self-guided. Four widget tests plus
the related session/app tests pass; full suite 1004 + one opt-in screenshot
skip, analyze/format/diff clean. Do not add a pass threshold or progress write
until real-phone human BENCH/VAD and educator acceptance exist. No commit, push
or deployment.
