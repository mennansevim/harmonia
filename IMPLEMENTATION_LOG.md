# Resonia — Uygulama kaydı

## 2026-10-11 — İlk güvenilirlik paketi, REL-01–05

**Kullanıcı isteği:** Ayrıntılı roadmap ve uygulamaya başlama. Çalışma Resonia klasöründe yapıldı; Agora kaynakları değiştirilmedi. Git commit/push/PR, dış yayın, ödeme veya canlı API bağlantısı yapılmadı.

### Uygulananlar

- `lib/domain/models/score_metric.dart`: measured/not_measured/not_applicable; yalnız measured sonlu 0–100 değer taşır. Null, öğrenci başarısızlığı veya 100 değildir.
- `exercise_result.dart`: sonuç v2 JSON, valid/invalid, mode/difficulty/content/scoring sürümü; geçersiz sonuç sayısal skor taşıyamaz. Boş hata listesi, ölçüm yokken başarı sayılmaz.
- `exercise.dart`: learning/recall_exam/sight_reading/choir_practice ve içerik sürümü. Tam nota/onset/tuning/hint sözleşmesi henüz yok.
- `pitch_exercise_scorer.dart`: tek seste timing/memory uygulanamaz; gürültü/sessizlik/non-finite veri puanlanmaz. Nota/oktav/kararlılık kuralları ve toleransları korunur. Geçersiz hedef runtime'da reddedilir.
- `skill_progress.dart`: her metriğin kendi örnek sayısı; veri yoksa ortalama null. Invalid ve ölçümsüz sonuçlar dışlanır; farklı skill/difficulty/mode/content/scoring cohort'ları reddedilir.
- `event_rhythm_analyzer.dart`: monoton birebir event alignment, eksik/fazla vuruş cezası, bağımsız latency düzeltmesi, signed bias + mutlak sapma, deadband ve sınırlı event bütçesi. Demo ritim adapter'ı bu motoru kullanır.
- `mock_melody_analyzer.dart`: eşit nota sayısından sıra/timing/memory başarısı çıkarımı kaldırıldı. Gerçek analyzer olmadığı için skorlar ve sıra ölçülmedi, nedeni açık. **Gerçek ezgi algılama uygulanmadı.**
- Tek ses sonuç ekranı: invalid durumda nötr “Ölçüm Alınamadı”; puan/gelişim cezası yok. Uzun başlık dar ekran/büyük yazıda sarılır. Ana tasarım hâlâ mevcut demo; Aurora görseli henüz bağlı değil.
- Ayrıntılı iş, bağımlılık, kabul kapısı ve sprint planı: [IMPLEMENTATION_ROADMAP.md](./IMPLEMENTATION_ROADMAP.md).

### Doğrulama

- `flutter test --no-pub`: **58 test geçti** (önceki 26 testten sonra +32 yeni test).
- `flutter analyze --no-pub`: **sorun bulunmadı**; son kod değişiklikleriyle tekrar çalıştırıldı.
- `dart format --output=none --set-exit-if-changed lib test`: **25 dosya, değişiklik yok**.
- 16 kök Markdown dosyasında yerel bağlantı/fence/son satır kontrolleri: sorun yok.
- Yeni kontroller: measured zero/null/status JSON; invalid numerical evidence; NaN güvenli export; cohort ve denominator; ekstra/mükerrer ritim, greedy tuzak, karşıt sapmalar, latency/zero tolerance/empty input; placeholder'ın ölçmediğini iddia etmemesi; 320 px ve 1.8× yazıda invalid sonuçta overflow olmaması.

Widget/domain testleri gerçek telefon, gerçek mikrofon veya pedagojik etkililik testi değildir. Ritim formülü bir öğretmen sınav rubriği gibi pazarlanmaz; kalibrasyon ve pilot gerekir.

### Kalanlar ve sonraki paket

1. REL-06/07: sequence/tuning/hint/gecikme/response-order sözleşmesi, provenance ve immutable veri/fixture kontrolleri.
2. AUD-DEV-01: kayıt/fixture formatı ve lisans envanteri; sentetik ile gerçek holdout ayrımı.
3. AUD-DEV-02: capture/playback adaptör araştırması, gerçek sample rate, izin/iptal/route prototipi.
4. AUD-DEV-03/04/05: gerçek frame motoru ve session koordinasyonu; cihaz benchmark.
5. CORE-03: gerçek nota segmenti ve ezgi sıra/süre alignment. Placeholder geçici olarak güvenle ölçümsüz kalır.

Persistence/fromJson/migration adapter, kullanıcı sonuç dedup, hint/tuning cohort, tam mastery, AI ve insan hizmeti bu pakette yok. Sonuç JSON'u v2 olarak değişti; gelecekte v1 veri varsa açık migration gerekir. Gerçek ses başarı hedefleri henüz karşılanmış sayılmaz.

## 2026-10-11 — Devam: protokol, kaynak kanıtı ve ses dosyası temeli

**Uygulanan:** `ExerciseProtocol` / `NoteEvent` / `ConfiguredExercise`; öğrenme/recall/deşifre/koro politikaları, birlikte/sıralı referans, exact/anyOrder cevap, beat/tempo/ölçü, A4 bağlamı ve JSON round-trip. Sonuç evidence nested defensive snapshot. Pitch sonuçlarında unverified/mock/synthetic/microphone provenance; mock'ın yedi senaryosunda kaynak/version korunur. Gelişimde kaynak/analyzer cohort ayrımı. `Pcm16Wav` codec, bounded deterministic sentetik tone, `AudioFixture` metadata ve duplicate/subject partition kapısı.

**Doğrulama:** 82 test geçti (**+24**); static analysis temiz; format **34 dosya, değişiklik yok**. Yeni testler: protocol round-trip ve mod/skill çelişkileri, immutable nested evidence/non-JSON rejection, mock provenance ve gerçek cohort'tan dışlama; farklı sample rate, signed PCM, bozuk/truncated WAV, deterministik fade'li tone; consent/holdout leakage/duplicate metadata. Bunlar telefon/mikrofon veya eğitim başarı testleri değildir.

**Araştırma:** Agora'da 41 piyano WAV; C4/A4 örnek header'ları mono PCM16 48 kHz. Repo MIT; sample'ların özgün kaynak/hak zinciri ayrıca doğrulanmalı. Dosyalar kopyalanmadı, Agora kaynakları değişmedi. Resmî record/just_audio sayfaları kontrol edildi; adaylar henüz bağımlılık olarak eklenmedi. API, hesap, ödeme, upload, commit/push ve yayın yok.

**Tamamlanmış sayılmayan:** REL-06/07 ve AUD-DEV-01 kısmi. Yeni protokol demo ekranına/session'a bağlanmadı; tuning isim/frekans tutarlılığı ve gerçek hint kullanım kanıtı, katalog/sonuç persistence, fixture dosya/hash/header loader, diğer analyzer provenance, dedup, gerçek kayıt seti bekliyor. AUD-DEV-02 yalnız araştırma, kayıt/çalma prototipi yok. Canlı DSP, Aurora ses görseli ve cihaz benchmark henüz yok.

**Doğrudan sonraki iş:** [AUDIO_TESTING.md](./AUDIO_TESTING.md) içindeki AUD-DEV-02 dilimi: ayrı yerel kayıt laboratuvarı, capture/playback arayüz ve fake-testli coordinator, sentetik referans → açık izinle kısa WAV kayıt → header doğrulama → dinle/sil; cancel/background/route yarışları. Sonra gerçek frame analyzer. İnsan benchmark toplama/etiketleme kullanıcı koordinasyonuyla yapılır.

## 2026-10-11 — “Şimdi başlat”: AUD-DEV-02 dar laboratuvar

Saatlik takip kurulduktan sonra kullanıcı geliştirmeyi şimdi başlatmayı istedi. Bu oturumda kod uygulandı; takip bir sonraki pakete güncel roadmap üzerinden devam edebilir. Otomasyon ayarı tekrar oluşturulmadı.

### Eklenenler

- Domain `AudioCapture`, `ReferencePlayback`, `AudioLabBackend`, `PlaybackHandle`, `CapturedAudio` metadata sözleşmeleri. Domain layer codec/plugin/Flutter UI implementasyonuna bağımlı değil.
- `AudioLabController`: serialized native kaynak komutları, cancel epoch, geciken permission/start/stop/playback callback koruması; referans ve kayıt birbirini bloke eder; playback completion komut kuyruğunu bloke etmez. 10 sn stop timer, invalid dosyada nötr hata ve cleanup; kaynak/focus değişiminde iptal, otomatik resume yok.
- `PluginAudioLabBackend`: record **7.1.2**, just_audio **0.10.6**, path_provider **2.1.6**, audio_session **0.2.4** lockfile ile çözüldü. İzin explicit start'ta; mono WAV config istenir, çıktı format/Hz header'dan doğrulanır. Dosya/read bütçesi; recorder'ın farklı path'i okunmaz. Kendi benzersiz temp klasörünün sadece ürettiği reference/recording dosyaları temizlenir, recursive silme yok. Close işlemi bir hata olsa da diğer temizleme adımlarını dener.
- Ayrı “Ses laboratuvarı” ekranı; ana mock ekranın app bar mikrofon düğmesinden ulaşılır. Sentetik C4 dinle, kaydı başlat/bitir, gerçek dosya metadata, kaydını dinle/sil. Ekrana girişte mikrofon veya izin yok; puan, gerçek pitch, AI, paylaşım ve upload yok.
- iOS NSMicrophoneUsageDescription; Android RECORD_AUDIO. OS izin diyaloğundaki geçici inactive, isteği iptal etmez; paused/background iptal eder. Fiziksel route davranışı henüz doğrulanmadı.

### Son doğrulama

- `flutter test --no-pub --reporter expanded`: **100 test geçti (+18)**.
- `flutter analyze --no-pub`: **sorun yok**.
- Format: **41 dosya, değişiklik yok**.
- `flutter build ios --simulator --debug --no-pub`: **başarılı**, `build/ios/iphonesimulator/Runner.app`. Simülatörde mikrofon kaydı yapılmadı; fiziksel telefona kurulum/yayın yapılmadı.
- Fake kontroller: otomatik izin/kayıt olmaması, izin reddi, double start/stop, permission/start/stop/load sırasında iptal, gecikmiş playback hata/bitişi, route/focus ve arka plan iptali, boş/bozuk/uzun kayıt, cleanup error, shutdown idempotency, süre sınırı. Widget: giriş/kayıt/metadata/dispose, 320px 1.8× yazıda ret, izin diyaloğu inactive ve arka plan.

İlk test çalıştırmasındaki disposal/lifecycle fake-clock kontrolleri düzeltildi; son tam suite geçti. Statik lint mekanik düzeltmeleri yapıldı. Son kaynak durumuyla test/analyze/build tekrarlandı. Mock/codec testleri fiziksel ses başarısı değildir.

### Devam / dış kapılar

AUD-DEV-02 **kod alt paketi** var; fiziksel iOS/Android permission/kalıcı ret/kayıt/kulaklık/Bluetooth/çağrı ve tam session QA kabul kapısı geçmedi. Kesintide pause-resume yerine güvenli cancel var. Android doctor: cmdline-tools eksik, lisans unknown; Android build denenmedi, lisans kabulü veya SDK kurulumu yapılmadı. Xcode/simulator build kapısı geçti.

Startup orphan temp temizliği, kapatma hatasının UI'ya aktarılması ve isolate/performance kontrolü bekliyor. Dosyayı OS crash/kill durumunda mutlaka silme garantisi verilmez. `CapturedAudio` yalnız metadata; frame analyzer için PCM yükleme/stream adapter henüz yok. Sıradaki otomatik paket: fixture loader hash/header/varlık eşleşmesi → AUD-DEV-03 deterministik gerçek frame motorunun sentetik short-buffer/oktav/noise testleri → capture-analysis bağlantısı. Gerçek etiketli veri ve cihaz benchmark kullanıcı koordinasyonuyla ayrıca doğrulanır. Agora, canlı API/AI/ödeme, commit/push ve dış yayın değişmedi.

## 2026-10-11 — İlk heartbeat: AUD-DEV-01 fixture loader kod kapısı

**Uygulama:** `AudioFixture.toJson/fromJson`; `AudioFixtureEntry` ve `AudioFixtureManifest` v1/mono_pcm16_wav, strict sürüm/alan/kaynak ve 1–1024 entry; immutable snapshot, duplicate path (case-insensitive), id/hash/group checks. Read-only `AudioFixtureLoader`: explicit root, göreli path, dosya/symlink türü, byte bütçesi, aynı handle üzerinden byte okuma, SHA-256 ve codec/header Hz/sample-count eşleşmesi. Eksik/bozuk dosya typed failure verir; sequential stream fail-fast. `LoadedAudioFixture` metadata/PCM'i birlikte taşır; nota etiketinin doğru olduğunu veya izin/lisansın gerçek olduğunu çıkarmaz.

**Bağımlılıklar:** mevcut transitive crypto **3.0.7** ve path **1.9.1** direct yapıldı/lockfile çözüldü; native plugin eklenmedi. Loader varsayılan 4.224.044-byte dosya bütçesi, en çok 46.080.044 explicit override. Büyük dataset importer/web/asset/remote adapter ve total-memory/performance raporu yok. Symlink/path koruması hostile yerel süreçlere karşı kernel sandbox/TOCTOU garantisi değildir; private immutable dataset varsayılır.

**Doğrulama:** **123 test geçti (+23)**; analyze temiz; format **45 dosya, değişiklik yok**. Sekiz manifest testi: round-trip, schema/codec/type/source/consent/holdout, path traversal/URL/alias, duplicate ve kapasite. On beş loader testi: hash/header/rate/count eşleşmesi, eksik/yanlış root, bozuk/truncated/stereo, bütçe, symlink file/parent/internal alias, yanlış dosya türü, nested file, manifest fail-fast ve private path'i hata mesajına koymama. Gerçek disk fixture'ları testte benzersiz temp klasörde sentetik üretilip yalnız kendi test klasörü temizlendi. Domain/widget eski regresyonları korundu.

**Sınırlar ve devam:** Gerçek insan/piyano dosyası kopyalanmadı veya benchmark'a eklenmedi. Fiziksel cihaz/mikrofon/iOS build/Android build bu tur çalıştırılmadı; önceki iOS simulator build tarihsel doğrulama. API/AI/ödeme/upload/yayın/git push yok; Agora değiştirilmedi. AUD-DEV-01'in loader kod kapısı geçti, bütün gerçek veri/lisans/label benchmark işi bitmedi. Sonraki heartbeat **AUD-DEV-03 frame analyzer**, kısa buffer/sessizlik/noise/oktav/confidence testleri; sonra güvenli capture-analysis ve isolate/device/performance. Başarı toleransları değiştirilmedi; bütün ürün tamamlanmadı, takip açık kalır.

## 2026-10-11 — 08:41 UTC heartbeat: AUD-DEV-03 frame çekirdeği

**Uygulanan:** target-independent pure Dart `YinPitchFrameAnalyzer`, bounded sample-rate/pencere/config/input; DC/RMS, CMNDF ilk eşik altı minimum ve lag interpolation; sessizlik/clip/kısa/invalid/unreliable abstention. Hz/RMS/periodicity diagnostic, score/voice probability değil. Ayrı `PitchDeviation` signed absolute/pitch-class cents/octave offset, hedefe folding yok. Scorer/mocks/lab, başarı toleransları ve kullanıcı dosyaları korunuyor. Yeni paket/native bağımlılık yok.

**Doğrulama:** **184 test geçti (+61)**; `flutter analyze --no-pub` temiz; `dart format --output=none --set-exit-if-changed lib test`: **50 dosya, 0 değişiklik**. 24 sample-rate×nota senaryosu, determinism, zayıf fundamental/kuvvetli harmonikler, phase/gain/DC/oktav; short-buffer/NaN/Inf/clip/noise, config/bounds, extreme comparison; dört rate'te sentetik WAV decode→frame ve yanlış-clock sınırı. İlk koşuda silence dB tabanı exactness farkı düzeltildi; son tam suite geçti. Sentetik/ünite regresyonları gerçek öğrenci/cihaz/öğretim doğruluğu değil. Mobil build tekrar yapılmadı.

**Karar/sınırlar:** deneysel YIN-style çekirdek; Agora McLeod port'u değil, tam YIN/best-local-estimate/temporal tracking yok. Özgün yayın referansı araştırıldı; PDF fetch başarısız, yayımlanmış doğruluk değerleri aktarılmadı. ADR-019 ve teknik dokümanlar güncellendi. 8–48 kHz/8192 örnek; senkron bounded core, isolate yok. Periodic source/konuşma/eşlik ayırıcı gerçek VAD değil. Skor ekranı mock; kayıt aggregation/coverage/stability, capture/session/provenance ve Aurora görseli bekliyor. Frame kod kapısını AUD-DEV-03/R1 veya benchmark tamamlanması sayma.

**Sonraki paket:** bounded overlapping kayıt analiz adapter'ı; periodic evidence ile gerçek voice iddiasını ayıran sözleşme, source/version, kararlılık/oktav kanıtı → lab-owned PCM/worker/isolate/cancel. İnsan holdout/eğitimci/consent/etiket ve fiziksel iOS/Android/düşük cihaz performansı dış kapıları açık. Agora kaynakları, API/AI/ödeme/upload, git push ve dış yayın değiştirilmedi. Tamamlanma kapıları geçmediği için otomasyon kapatılmadı.

## 2026-10-11 — Kullanıcı devam isteği: kayıt evidence + native isolate

**Uygulanan:** `RecordingPitchAnalyzer`/`RecordingPitchEvidence`/`RecordingPitchFrame`; strict rate/duration/full-input preflight; regular half-hop + end-anchor, immutable frame trace/status counts. Tüm denominator'ları koruyan periodicFrameRatio (empty=null), observed lower median Hz, raw oktavı koruyan log-frequency population dispersion (tek frame=null). Explicit source/default unverified, version config dahil; PCM/result score yok. `RecordingPitchWorker` async boundary ve native `IsolateRecordingPitchWorker`: bounded immutable input snapshot/tek active request/finally reset/separate closure scope, off-isolate DSP. Yeni paket/plugin eklenmedi.

**Doğrulama:** `flutter test --no-pub --reporter expanded`: **205 test (+21)**; `flutter analyze --no-pub` temiz; format **54 dosya/0 değişiklik**. Yeni 17 diagnostic + 4 native worker testi: dört rate/raw frequency, determinism, provenance, complete-tail/grid, silence/noise/clipping denominator, octaves/dispersion/observed median, short/invalid/oversized/max-duration, immutable JSON; gerçek native isolate'ta sync parity/pending mutation/busy reset/invalid input. Sonuçlar sentetik/VM kod testidir; fiziksel cihaz/öğrenci/pedagoji veya performans kanıtı değil. Mobil build tekrarlanmadı.

**Karar/sınırlar:** ADR-020 diagnostic evidence voice/scoring'den ayrıldı. Dart resmi Isolate.run sözleşmesi incelendi. Worker hard cancel/owner epoch, lab-owned PCM adapter/UI ve VAD henüz yok; web fallback yok. Strict 10 sn analyzer bütçesi ile timer-overshoot lab kabul sınırı bağlantıda açıkça ele alınmalı, sessiz truncate yapılmamalı. Mock skor ekranı/toleranslar aynen korundu. AI/ödeme/upload/push/yayın ve Agora kaynakları değiştirilmedi.

**Bir sonraki iş:** güvenli lab PCM read + worker üzerinden ayrı diagnostic UI; load/analyze cancel/delete/background/route/close ve stale-result regresyonları. Voice probability/başarı skoru üretme; gerçek VAD/benchmark/cihaz/öğretmen kapıları hâlâ açık. Geliştirme tamamlandı denmedi, takip kapatılmadı.

## 2026-10-11 — 2/3/4 referans için piyano altyapısı

**Kullanıcı yönü:** 2/3/4 sesli örnekler piyanodan gelecek. Tekil nota/hazır akor/canlı fiziksel piyano biçimi soruldu, henüz yanıt yok. Bilinen hedefleri ortak tanımlamak ve tekil sample mix kolunu güvenle hazırlamak uygulandı; bilinmeyen canlı akor transkripsiyonu eklenmedi.

**Kod:** `PianoChordReference` runtime 2/3/4 distinct MIDI key, sorted immutable response targets, A4→isim/frekans tek kaynağı, learning/recall/exact/anyOrder ve existing simultaneous `ConfiguredExercise`. `PianoNoteSample` declared key/tuning/origin/rights reference + bounded mono PCM; `PianoChordRenderer` same actual rate/tuning/origin, exact sample-per-key, sample-zero single WAV, 0.8/n headroom, 2/12 ms fades ve settle silence. Missing/short/silent/key/rate/tuning/Nyquist mismatch fail-closed; resampling/pitch shift/sine fallback yok. Dosya/piyano bankası kopyalanmadı, native paket eklenmedi.

**Doğrulama:** **221 test (+16)**; analyze temiz; format **58 dosya/0 değişiklik**. Yedi domain (2/3/4 binding/round-trip, tuning, recall/set policy, immutable keys, limits) ve dokuz renderer (2/3/4 simultaneity/worst-case peaks, sample order/contribution, clock/tuning/origin/key/missing/short/silent/Nyquist/metadata) regresyonu. Test sesleri sentetik/constant peak; gerçek piyano tınısı, etiket/lisans, fiziksel mikrofon/player veya pedagojik doğrulama değil. Mobil build yapılmadı.

**Devam:** [PIANO_REFERENCES.md](./PIANO_REFERENCES.md) sample hazırlama/format/ürün sınırlarıyla eklendi; roadmap/mimari/motor/testing güncellendi. Bank/import adapter, prepared-reference/player, fake-testli playback→settle/recall→response coordinator; öğrenci segment/alignment, VAD/device/öğretmen kapıları açık. Renderer sadece preparation, worker/capture/UI bağlanmadı. Existing single-tone lab/mock/toleranslar ve Agora korunuyor; AI/ödeme/upload/push/deploy yok. Bilinen piyano chord referansı mevcut monofonik motorun multipitch motoruna dönüştüğü anlamına gelmez.

## 2026-10-11 — Hazır akor klasörleri ve placeholder

**Netleşen kullanıcı isteği:** Tek ses dosyaları gibi klasörden 2/3/4 sesli hazır piyano kayıtları çalınacak, öğrenci tekrar edecek. Sesler gelince birlikte incelenecek; şimdi yalnız placeholder. Önceki live/mix varsayımı ana akıştan çıkarıldı; mix kodu alternatif olarak korundu.

**İnceleme:** Agora `src/PitchTest/lib/audioPlayer.ts` `/sounds/piano/{noteName}.wav` fetch/decode/cache yapıyor. Preload hatayı yutuyor, play missing file'da throw; Resonia placeholder'da eksik kaynak başarıya dönüşmüyor. Agora kaynakları/41 WAV değiştirilmedi/kopyalanmadı. Resonia tek ses ekranı mock, lab C4 sentetik olarak ayrı kaldı.

**Uygulama:** assets/audio/piano/chords/{2,3,4}-notes README klasörleri; bundled catalog.json üç null-file/null-target/null-rights awaiting_recording slot'u. Strict immutable domain catalog, asset repository, loading/error/retry/disposal-safe `ChordPlaceholderScreen`; home app bar entry, dinle/tekrar disabled. Permission/player/capture/scorer yok; boş/sentetik WAV yaratılmadı. Pubspec yalnız JSON asset içerir. Ready/path/etiket ekleyerek bu placeholder schema sessiz açılmaz; reviewed içerik şeması sonraki iş.

**Doğrulama:** **230 test (+9)**; analyze temiz; format **63 dosya/0 değişiklik**. Catalog schema/null/path/cardinality/duplicates ve immutable kontrol; gerçek bundled manifest load/home route, disabled actions, 320px 1.8× text, error/retry ve late completion. İlk koşuda fixture null-list type ve fake-clock asset wait düzeltildi; UI retry setState closure'ın Future dönüşü düzeltildi; tam suite geçti. Gerçek piyano/player/telefon/pedagoji veya mobil build değil.

**Devam:** Kayıtlar gelince birlikte hak/nota/oktav/akort/format/süre QA + reviewed asset/player/session. Placeholder'ı uydurma ses/hedef/skorla doldurma; live multipitch başlatma. Bağımsız lab diagnostics/cancel ve roadmap işleri sürebilir. AI/ödeme/upload/push/deploy yok; takip tamamlandı denmedi.

## 2026-10-11 — Yerel commit ve başka modele devir

Kullanıcı çalışmanın commit edilmesini ve genel işleyiş notu istedi.
Repo main henüz commitsizdi; Flutter/platform kaynakları, ürün/teknik
dokümanlar, ses/sözleşme/fixture/worker/lab ve hazır chord placeholder
geliştirmeleri ilk yerel snapshot'a hazırlanıyor. Build/cache/native üretilmiş
artefact'lar ignore dışında commit kapsamına alınmadı; WAV/öğrenci kaydı yok.

`MODEL_HANDOFF.md` ürün yönü, son prerecorded piyano açıklaması, kod/ekran
haritası, DSP vs scorer vs VAD ayrımı, 10 sn/overshoot/cancel sınırları,
önerilmiş fakat kaydedilmemiş 9 piyano örneği, test/cihaz kapıları ve en yakın
lab PCM→diagnostic worker işini anlatır. `AGENTS.md` sonraki modellerin repo
kurallarını ve okuma sırasını verir; README/CURRENT_ROADMAP bağlantıları eklendi.

Teslim öncesi yeniden **230 test geçti**, analyze temiz, format **63 dosya,
0 değişiklik**. Bu oturum doküman/devir paketi; yeni ses özelliği, fiziksel
test veya mobile build yok. Basit kaynak secret-pattern taramasında eşleşme
bulunmadı; kapsamlı security audit iddiası değil. Agora git durumu temiz kaldı.
Commit kullanıcı talebiyle yerel yapılacak; git push/ödeme/API/upload/deployment
yetkisi verilmedi ve uygulanmadı. Commit kimliği `git log`/teslim yanıtından
alınır; bu dosya kendi commit hash'ini gömmez.

## 2026-10-11 13:44 UTC — Yerel kayıt → deneysel analiz

AGENTS/devir/roadmap ve ilgili ses sözleşmeleri okundu; başlangıç git temiz.
Optional AudioRecordingReader + immutable source/PCM DTO; Plugin backend fixed
owned WAV'ını bounded same-handle regular-file/header reader ile yükler.
Controller açık analyze eylemini native worker'a bağlar. File load serialized,
DSP queue dışında; epoch cancel/route/background/close eski sonucu reddeder.
Eski worker bitmeden yeni analiz yok, yeni kayıt/replay mümkün. Analiz hatası
kayıt dosyasını korur; metadata mismatch/48 kHz üstü/10 sn aşımı explicit hata.
UI frekans/periodic pencere/dispersion diagnostic gösterir; ses kimliği veya
öğrenci başarı kararı vermez. Mock scorer ve 2/3/4 piyano placeholder değişmedi.

248 test (+18), analyze temiz, format 67 dosya/0 değişiklik. Native worker
sentetik 440 Hz WAV ile controller üzerinden çalıştırıldı; gerçek mikrofon
veya fiziksel cihaz doğrulaması değil. Mobil build/pilot yok. Decode/snapshot
UI isolate maliyeti, hard cancel, VAD/noise-floor/latency, orphan cleanup ve
shutdown error görünürlüğü açık. Dosya silme worker belleğini anında silmez.
Roadmap/testing/mimari/devir/README güncellendi. Önceki yerel commit 85f301b
korundu; yeni commit/push/deployment/API/upload yapılmadı. Agora değiştirilmedi.

## 2026-10-11 — Modül envanteri, CAL-01 kalibrasyon ve SHELL-01 misafir kabuğu

**Kullanıcı isteği:** Projeyi incele, A–Q eksik modül envanteri ve yayın roadmap'i çıkar, onay gerektirmeyen en öncelikli paketleri uygula. Başlangıçta 248 test/analyze/format (67/0) yeniden doğrulandı; önceki commit'lenmemiş lab→worker değişiklikleri korundu. Agora değiştirilmedi.

**Roadmap:** CURRENT_ROADMAP'e A–Q modül/kanıt tablosu, üç teslim kapsamı, mermaid kritik yol ve 30/60/90 planı; IMPLEMENTATION_ROADMAP §11'e yeni ID'ler (SHELL-01–04, UXR-01, CAL-01–03, SESSION-01/02, VAD-01, BENCH-01, CORE-05/HIST-01, RANGE-01, INT-01, ANALYTICS-01, ECON-01) ve mevcut ID eşlemesi. COMPETITOR_RESEARCH 2026-10-10 tarihli resmî kaynak incelemesi bir gün önce yapıldığı için bu turda yenilenmedi; uygulamalı rakip testi hâlâ yok.

**CAL-01 (AUD-DEV-05 kod alt paketi):** `capture_quality.dart` — route politikası (hoparlörde tek ses sıralı, ritim her zaman ölçülmüş gecikme, hoparlörde rehberli koro yok, inferred/unknown route doğrulanmamış), kalibrasyonun route/rate/yaş bağlaması, noise-floor (medyan/burst), kayıt kalite kapısı ve `LatencyCalibration.notMeasured()` varsayılanı. `AudioRouteProbe` + audio_session eşlemesi (iOS reported, Android inferred; deneysel API). Lab: “Ortam sessizliğini ölç (2 sn)”, kalibrasyon klibi silinir; cevap analizinde kalite raporu + route açıklaması. Eşikler ADR-021'de benchmark öncesi hipotez olarak kayıtlı.

**SHELL-01:** Aurora tema token'ları ve `ResoniaResultColors` (yanlış oktav ≠ başarı rengi, geçersiz = nötr; kontrast testli), light/dark. `AppShellController` + `ProfileRepository` + atomik `JsonFileStore`/`FileProfileRepository`. Hedef seçimi (hesap yok), home (Deneysel/Simülasyon/Kayıt bekleniyor/Henüz yok etiketleri), ayarlar: hedef değiştir, mikrofon yardımı, gizlilik, “satın alma yok” abonelik metni, misafir hesap ve onaylı yerel profil silme; bozuk profil için yeniden dene/açık yeniden başla. Simülasyon tek ses ekranındaki kısayollar home'a taşındı; ekranın kendisi değişmedi.

**Doğrulama:** `flutter test --no-pub`: **299 test geçti (+51: CAL-01 31, SHELL-01 20)**. `flutter analyze --no-pub` temiz. Format **85 dosya/0 değişiklik**. `flutter build ios --simulator --debug --no-pub` başarılı. Eski app testleri yeni kabuğa göre güncellendi (tek ses demo ekranı doğrudan; piyano placeholder home'dan). Testler sentetik/fake/widget; fiziksel mikrofon/route, Android build, ekran okuyucu ve kullanıcı testi yapılmadı.

**Sınırlar:** Enerji etkinliği VAD değildir; kalite `usable` doğru nota demek değildir. Android route çıkarımı aktif route değildir. Profil deposu tek cihaz/yerel; hesap, sync, export yok. Kalıcı izin reddinde OS ayarına derin bağlantı yok (SHELL-02). Mock başarı ekranı gerçek motora bağlanmadı; toleranslar değişmedi. Commit/push/deployment/ödeme/API/upload yapılmadı.

**Sonraki:** SESSION-01 tek ses ürün oturum koordinatörü (puansız), CORE-05 yerel geçmiş, CORE-02 tap ritim; dış kapılar CAL-02 cihaz protokolü, BENCH-01, UXR-01.

## 2026-10-11 — SESSION-01 tek ses oturumu ve CORE-02a ritim taklidi

**SESSION-01:** `SingleToneSessionController` — kalibrasyon (2 sn sessizlik, klip silinir), route/yaş kontrolü, izin referanstan önce, referans → bekleme → cevap penceresi (en çok 4 sn, “Bitirdim”) → stop/read → **ham cevap analizden önce silinir** → kalite kapısı (`requireCalibration: true`) → worker → `PitchDeviation` (oktav korunur). `scoringEnabled = false`: VAD-01/BENCH-01 olmadan doğru/yanlış/puan yok. Kesinti/iptal epoch ile eski sonucu reddeder; worker bitene kadar yeni deneme kapalı. Ekran: adım kartları, nötr yeniden deneme metinleri, isteğe bağlı ölçüm ayrıntısı (etiketli). Home'a “Deneysel” kart.

**Hata düzeltmesi:** just_audio `play()` tamamlanmış oynatmadan sonra `playing=true` kaldığı için sonraki çağrıda hemen dönebiliyordu (resmî API notu). Lab backend ve yeni clip player her oynatmadan önce `stop()` çağırıyor; aksi halde oturum ikinci denemede mikrofonu referans çalarken açabilirdi. Cihazda ayrıca doğrulanmalı.

**CORE-02a:** `EventRhythmAnalyzer` artık kronolojik vuruş hizalaması (`RhythmEventMatch`) döndürür; rubrik/toleranslar değişmedi. `RhythmImitationEvaluator`: dinle→tekrar modunda ortak saat olmadığı için ilk dokunuş ilk referans vuruşuna **tanım gereği** eşlenir; bu çapa gösterilir ama zamanlanmaz/puanlanmaz, gecikme uygulanmaz/çıkarılmaz. Kalan vuruşlar referans tempoda eşleşir; eksik/fazla/erken/geç zaman çizelgesi, span oranıyla tempo ipucu (%15 hipotez). `RhythmImitationController`: pointer `event.timeStamp` (monoton engine zamanı), referans çalarken dokunuşlar yalnız sayılır, dinleme kotası (taslakta 3), ilk dokunuştan sonra tekrar dinleme yok, 2,5 sn hareketsizlikte bitiş. Sentetik 1 kHz klik referansı (`click_track.dart`), `ReferenceClipPlayer`/`JustAudioClipPlayer`. Üç **taslak** desen (eğitimci onayı bekliyor; sınav modunda kullanılamaz). `toResult` geçerli ölçümde yalnız timing/overall ölçülü, memory ölçülmedi, accuracy uygulanamaz; çapa `anchorTimingMeasured: false`.

**Doğrulama:** **338 test (+39: SESSION-01 17, CORE-02a 22)**; analyze temiz; format 100 dosya/0. iOS simulator build geçti; iPhone 17 Pro simülatöründe onboarding (gerçek dosya profili yeniden açılışta korundu), home, kalibrasyonsuz oturumun izin istemeden yönlendirmesi ve ritimde gerçek just_audio oynatma tamamlanması → dokunma alanı → açıklamalı sonuç elle denendi. Simülatör mikrofonu kullanılmadı; fiziksel dokunma örnekleme gecikmesi, cihaz ses çıkışı ve kullanıcı testi yapılmadı.

**Sınırlar:** Ekran okuyucuda dokunma zamanlaması değişebilir (ipucu metni var, alternatif giriş yok). Count-in ritim (CORE-02b) CAL-03 gerektirir. Tek ses oturumu doğru/yanlış göstermez. Sonuçlar henüz kalıcı değil (CORE-05 sıradaki iş). Commit/push/ödeme/API/upload yok.

## 2026-10-11 — CORE-05 yerel geçmiş ve SESSION-02 yetim ses temizliği

**CORE-05:** `ExerciseResult`/`ExerciseScores`/`ExerciseError`/`ScoreMetric`/`MeasurementProvenance` için katı `fromJson` (bilinmeyen enum/kaynak, eksik alan, ölçülmüş metrikte değer yokluğu, ölçülmemişte değer, invalid+skor ve sözleşme ihlalleri `FormatException`). `MeasurementSource.touch` eklendi (ritim dokunuşları; ses değil). `ResultHistoryRepository` + `classifyRecord` kuralı: aynı attempt ID ve aynı içerik → duplicate (çift sayım yok), farklı içerik → conflict (üzerine yazılmaz), kapasite → storageFull (sessiz budama yok). `FileResultHistory`: tek atomik JSON (`JsonFileStore`), işlemler seri, bozuk dosya raporlanır ve yeniden yazılmaz (yalnız açık “tümünü sil” ile). Ritim controller her denemeye tek ID verir (tekrar dinleme aynı deneme), bitişte bir kez kaydeder; kayıt hatası sonucu kaybettirmez. `AppServices` (InheritedWidget) navigator üstünde. Geçmiş ekranı: boş/hata/bozuk durumları, en yeni üstte, kaynak etiketi, cohort (egzersiz/zorluk/mod/içerik/puanlama/kaynak/analyzer sürümü) içinde ≥3 geçerli deneme yoksa “gelişim bilinmiyor”, varsa son üç denemede eksik+fazla vuruş dizisi; tek ve onaylı toplu silme. Home app bar ve ayarlardan erişim.

**Hata düzeltmesi:** geçmiş ekranında `setState(() => _entries = …)` Future döndürüyordu; widget testi yakaladı, blok gövdeye çevrildi.

**SESSION-02:** `OrphanAudioCleaner` açılışta, ses ekranları oluşmadan çalışır; temp kökünde yalnız `resonia-audio-lab-*`/`resonia-clip-*` dizinleri, içlerinde yalnız `recording.wav`/`reference.wav`/`clip.wav` silinir, dizin boşsa kaldırılır; symlink izlenmez, beklenmeyen içerik korunup raporlanır. Başarısızlık ayarlarda anlaşılır uyarı olarak görünür.

**Doğrulama:** **363 test (+25: CORE-05 19, SESSION-02 6)**; analyze temiz; format 109/0. Gerçek cihazda kill sonrası temizlik ve büyük geçmiş dosyası performansı ölçülmedi. Export ve hesap/sync yok. Commit/push/ödeme/API/upload yok.

## 2026-10-11 — LEARN-03a sonuçtan tek somut sonraki adım

`RhythmNextStepPolicy` (deterministik, AI yok): yalnız karşılaştırılabilir sonuçlar (touch kaynağı, güncel analyzer ve içerik sürümü). Öncelik: vadesi gelen kalıcılık kontrolü (taslak ölçüte ulaşılan günden sonraki bir takvim günü, tek dinleme, sonuçta `retentionCheck: true`) → az önce çalışılan desen ustalaşılmadıysa onun tekrarı (son denemenin baskın hatası: eksik > fazla > geç > erken) veya ölçülemeyen denemenin yeniden denenmesi → ilk ustalaşılmamış desen → bitti. Taslak ölçüt: art arda iki geçerli deneme eksik/fazla vuruşsuz ve ortalama mutlak sapma ≤ 60 ms; ekranda “eğitimci onayı bekliyor” notuyla görünür. Tek temiz deneme, seri, süre veya aynı soruyu tekrarlamak tek başına ustalık sayılmaz. Home'da “Bugünkü öneri” kartı (geçmişten hesaplanır, dönüşte yenilenir, hata durumunda açıklama), ritim sonucunda “Sonraki adım” kartı ve tek dokunuşla uygulama.

**Doğrulama:** **377 test (+14)**; analyze temiz; format 112/0. Uygulama testlerine bellek içi geçmiş/temizlik enjekte edildi (FakeAsync içinde gerçek dosya IO'su tamamlanmadığı için). Öğrenme etkisi, eşiklerin pedagojik uygunluğu ve kullanıcı anlayışı test edilmedi.

## 2026-10-11 — QA-01a erişilebilirlik kılavuzları ve UX-03a canlı giriş seviyesi

**QA-01a:** `meetsGuideline` ile Android/iOS dokunma hedefi, etiketli dokunma hedefi ve metin kontrastı; onboarding ve home açık/koyu tema, ayrıca tek ses oturumu, ritim, laboratuvar ve geçmiş ekranları. İlk çalıştırmada değişiklik gerekmedi. Otomatik kılavuzlar VoiceOver/TalkBack ile manuel testin yerini tutmaz; ritimde ekran okuyucu dokunma zamanlamasını değiştirir (ipucu metni var, alternatif giriş yok).

**UX-03a:** `InputLevelSource` (opsiyonel yetkinlik); `PluginAudioLabBackend` kayıt sırasında `record` eklentisinin `onAmplitudeChanged(100 ms)` akışını dBFS olarak yayınlar, stop/discard/close'da abonelik kapanır. `InputLevelMeter`: bekleniyor/uygun/çok düşük (< −50)/çok yüksek (≥ −3) etiketleri, yalnız çizimde 3 dB tepe-tutma azalması, “notanın doğru olduğunu göstermez” notu; oturumda kalibrasyon/cevap, laboratuvarda kayıt/kalibrasyon sırasında görünür. Ölçüm, kalite kapısı veya skor bu akışı kullanmaz. Eklenti genliğinin cihazlar arası dBFS doğruluğu doğrulanmadı.

**Doğrulama:** **384 test (+7)**; analyze temiz; format 115/0; iOS simulator build geçti.

## 2026-10-11 — ANALYTICS-01 sözleşmesi, ECON-01 modeli, UXR-01 protokolü, UX akış/durumları

**ANALYTICS-01 (kod):** `product_event.dart` — 11 izinli olay, olay başına izinli anahtarlar ve değer doğrulayıcıları (enum/bool/0–1000 tamsayı/içerik kimliği/token); bilinmeyen anahtar, serbest metin, ses dizisi, kişisel/kalıcı kimlik reddedilir; oturum kimliği rastgele hex; zaman dakika hassasiyeti; sınırlı bellek içi kayıt. Ağ gönderimi ve UI bağlantısı yok (sağlayıcı/rıza kararı gerekir). Metrik eşlemesi PRODUCT_SPEC'te.

**ECON-01 (doküman):** formül ve düşük/orta/yüksek × %15/%30 komisyon tablosu PRODUCT_SPEC'te; tüm girdiler doğrulanacak varsayım. Örnek varsayımlarda Premium katkısını en çok edinim ve komisyon belirliyor; Plus örnek fiyatı eğitimci kullanımı %70'te zarar ediyor → fiyat/kota pilot sonrası.

**UXR-01 / UX:** DESIGN_QA'ya üretim Flutter akış diyagramı, ekran × durum matrisi ve önceden kayıtlı eşikli kullanıcı testi protokolü eklendi (yürütülmedi; katılımcı daveti kullanıcıda).

**Doğrulama:** **389 test (+5)**; analyze temiz.

## 2026-10-11 — AI-02a koç sözleşmesi ve yerel eval (canlı API yok)

`CoachInput` (izinli, yuvarlanmış, metinsiz yük; mock/sentetik/doğrulanmamış kaynak reddi), `CoachReplyValidator` (skor alanı, olmayan egzersiz, yüzde/hazırlık/garanti, eğitimci taklidi, sağlık teşhisi, geçersiz ölçümde övgü, uzunluk, bozuk/enjekte metin reddi), `CoachService` (zaman aşımı, etiketli yedek). 12 eval testi. UI'ya bağlanmadı; sunucu gateway ve ücretli çağrı onay bekliyor. Model durumu web aramasıyla kontrol edildi (AI_COACH.md).

**Oturum sonu doğrulaması:** **401 test**, `flutter analyze` temiz, format 120 dosya/0 değişiklik, `flutter build ios --simulator --debug` başarılı. Android: SDK 36 var, cmdline-tools eksik, lisanslar kabul edilmemiş — build denenmedi (lisans kabulü kullanıcı kararı). Fiziksel iPhone'lar ağda görünüyor, bağlı/Developer Mode değil. Hiçbir commit/push/ödeme/API/upload/deployment yapılmadı; Agora değiştirilmedi.

## 2026-10-11 21:40 TRT — CAL-03a gecikme diagnostic tahmincisi

Devralınan 401-test paketinin kalibrasyon, kabuk, oturum, ritim, geçmiş,
öğrenme ve AI değişiklikleri korundu; dirty tree reset/commit yapılmadı.
Güncel handoff hazır sıradaki iş olarak CAL-03a'yı gösterdiği için uygulandı.

Domain `latency_estimator.dart`: bounded 8–64 paired trial, ortak observed
clock/chronology ve route/rate binding; medyan/MAD/ham P90–P10, rejected indeksleri,
minimum retained ve hipotez spread sınırları. Bozuk tail/mixed clock/scheduled
playback/inferred route fail-closed. Immutable source/method/evidence; invalid
istatistik null, unstable retained estimate null. Diagnostic ayrı tip,
LatencyCalibration bridge/scoring/count-in açma yok; correctionEnabled=false.
Tap bias veya loopback toplamı hardware/touch correction olarak sunulmadı.

**Doğrulama:** 422 test (+21), format 122/0, son analyze temiz. İlk koşudaki
iki brace uyarısı düzeltildi. Sentetik trial
testleri fiziksel gecikme/cihaz/öğretim kanıtı değil. Mobil build, mic, upload,
API, ödeme, commit/push/deployment yok; Agora temiz ve değiştirilmedi.
ADR-023, roadmap, testing ve handoff güncellendi. Sonraki bağımsız paket
LEARN-01 beceri grafiği; CAL-03b fiziksel clock/pipeline protokolü ve cihaz
girdisi ister. CORE-02b, VAD/BENCH, eğitimci ve piyano kapıları açık.

Git whitespace kontrolünde devralınan ADR-021/022 satırlarındaki iki Markdown
hard-break trailing-space uyarısı sürüyor; kullanıcıya ait satırlar değiştirilmedi.

## 2026-10-11 — LEARN-01a taslak beceri grafiği ve beceri haritası

Kullanıcı gecikme işini diğer ajana bıraktı (CAL-03a dosyaları o ajana ait; bu oturum dokunmadı ve `f4dfe51` commit'ine almadı). Bu paket: `skill_graph.dart` — LEARNING_MODEL basamaklarından 15 düğümlük **taslak** grafik (temel + konservatuvar + koro, aktarım düğümleri eğitimci gözlemli). Doğrulama: tekil kimlik, bilinen önkoşul, rota-arası önkoşul yasağı (rota düğümü yalnız temel veya kendi rotasına dayanır), döngü reddi, `measuredInApp` ⇔ bağlı egzersiz. `SkillStatusEvaluator`: yalnız ölçülen düğümler (puls → dört dörtlük; ritim tekrarı → sekizlik + senkop) kanıtla ilerler; son iki geçerli deneme taslak ölçütü karşılamazsa “çalışılıyor”, karşılarsa tekrar dinlemeyle “destekle”, tek dinlemeyle “bağımsız”, daha sonraki bir günde temiz kalıcılık kontrolüyle “korundu”; denenmemiş bağlı egzersiz düğümü “çalışılıyor”da tutar; farklı analyzer/içerik sürümü sayılmaz. Ses motoru/içerik/eğitimci gerektiren düğümler geçmiş ne olursa olsun “henüz ölçülmedi”. `RhythmNextStepPolicy` ölçüt yardımcıları paylaşıma açıldı (davranış değişmedi). Beceri haritası ekranı: hedefe göre rota, önerilen sıra, kilit yok, algı/üretim etiketi, ölçüm desteği açıklaması, geçmiş hatasında durum gösterilmez. Home app bar'dan erişim.

**Doğrulama:** 436 test (bu paketin 14'ü + diğer ajanın CAL-03a 21 testi dahil); analyze temiz; format 126/0. Mikroders içeriği, günlük süre planı ve eğitimci onayı yok.

## 2026-10-11 — PERC-01 tiz/pes algı çalışması

`lib/domain/perception/pitch_comparison.dart`: 80–1200 Hz ton çiftleri, 3 taslak seviye (200/100/50 cent), tur başına 8 öğe, tam yarısında ikinci ses tiz (sabit cevap %50 alır), tohumlu rastgele. `PitchComparisonOutcome.toResult`: `Skill.pitch`, `dimension: perception`, doğru sayısı, `referencePlays` (çiftlerin en çok dinlenme sayısı), accuracy/overall ölçülü, diğerleri uygulanamaz; eksik tur geçersiz ve puansız. Üretim (söyleme) bu sonuçtan çıkarılmaz. `MeasuredExercise` arayüzü + ritim/algı uyarlayıcıları; `SkillStatusEvaluator` bunu kullanır, “Tiz / pes ayırt etme” düğümü 200+100 cent seviyelerine bağlandı (taslak ölçüt ≥7/8, art arda iki tur; P(≥7/8 | tahmin) ≈ %3,5). `PitchComparisonController`: çift bir kez çalınmadan cevap yok, tekrar dinleme sayılır, anında öğrenme geri bildirimi, tur bitince bir kez geçmişe kayıt, iptal/eksik tur kaydedilmez. **Test yakaladı:** tur ortasında seviye değişimi cevapları sessizce siliyordu; artık yalnız ilk cevaptan önce veya tur sonunda. Ekran + home kartı + geçmiş metni; erişilebilirlik kılavuz testine eklendi.

**Doğrulama:** 448 test (bu paket 12; diğer ajanın CAL-03a testleri dahil); analyze temiz; format temiz. iOS simulator build `debug_unpack_ios` adımında araç hatası verdi (Flutter.framework x86_64+arm64 içeriyor; motor önbelleği derleme sırasında yeniden yazılmış; başka ajanın `flutter_tester` süreci açık). `flutter clean` diğer ajanın sürecini bozabileceği için yapılmadı; simülatörde elle deneme bu paket için yapılamadı.

## 2026-10-11 — LEARN-03b rota genelinde günlük öneri; iOS build araç engeli teşhisi

`TodayPlanner`: hedefin rotasındaki ölçülen düğümlerin egzersizleri üzerinde vadesi gelen kalıcılık kontrolü → ilk tamamlanmamış (başla/yeniden dene/tekrar/sıradaki) → tamam; ölçülemeyen önkoşullar engellemez. `MeasuredExercise.title`, `SkillStatusEvaluator.exerciseState` açıldı. Algı controller'ında `retentionCheck` (çift başına tek dinleme, sonuçta işaret). Home kartı egzersiz türüne göre algı veya ritim ekranını önerilen seviye/desenle açar; metinler son kanıtı alıntılar (son turda X/8; son denemede N eksik vuruş). PERC-01 commit'i `44d8d82`.

**Doğrulama:** 454 test (+6), analyze/format temiz. **iOS simulator build:** Xcode 26.6 `lipo` çoklu mimari `-verify_arch` çağrısını reddediyor; Flutter 3.44.4 `debug_unpack_ios` bu çağrıyı yapıyor. Tek mimarili doğrulama geçiyor. Temiz `build/ios` ile de tekrarlandı. Sahipsiz kalmış bir `flutter_tester` süreci (üst süreç launchd, 22:33) görüldü; dokunulmadı.

## 2026-10-11 — INT-01a hareketli do derece duyma (ADR-024)

Kullanıcı hareketli do'yu seçti (ADR-024). `interval_identification.dart`: `SolfegeDegree` (re…do', majör dizide yarım ton, hece, Türkçe aralık adı), 3 taslak seviye (re·mi·sol; re→la; re→do'), 8 soruluk tur — seçenekler eşit dağıtılır ve karıştırılır, tonik her soruda A3–G4 arasından seçilir. Ses: do–mi–sol bağlamı, duraklama, do → hedef (sentetik ton dizisi, `renderToneSequence`). `IntervalOutcome`: doğru sayısı, şans yüzdesi, “duyulan→seçilen” karışma sayıları, `Skill.interval`, `solfege: movable_do`, algı boyutu, eksik tur geçersiz. `IntervalController` PERC-01 kurallarıyla (dinlemeden/seçenek dışı cevap yok, tur ortası seviye kilidi, iptal kaydetmez, kalıcılık kontrolünde tek dinleme). `PerceptionCriterion.minCorrect = 7` paylaşıldı; “Tonik ve dereceler” düğümü ilk iki seviyeye bağlandı; günlük öneri ve home kartı aralık ekranını açabiliyor; geçmiş algı metnini kullanıyor.

**Doğrulama:** 466 test (+12), analyze/format temiz. Simülatörde deneme yok (Xcode lipo engeli). Aralık söyleme (üretim) ses motoru kapısına bağlı; inen/harmonik aralıklar ve minör bağlam sonraki içerik.

## 2026-10-12 02:47 TRT — CORE-03a symbolic pitch sequence alignment

Dirty tree'deki INT-01a, beceri grafiği/günlük plan ve diğer kullanıcı/ajan
değişiklikleri korundu. LEARN-01 zaten uygulanmış olduğundan tekrar yapılmadı;
CAL-03b fiziksel kapısına atlamadan bağımsız CORE-03a uygulandı.

Yeni `pitch_sequence_alignment.dart`: segmented monophonic event DTO ve
immutable source/evidence; 64 event/60 sn, finite positive Hz/non-overlap/süre
doğrulaması. Exact-order 1:1 DP: edit cost→correct count→absolute cents tie.
Yanlış pitch/oktav/eksik/fazla ayrımı; ham octave fold yok. Boş/invalid cevap
wholeSequenceCorrect=null; invalid tail clean prefix'i güvenilir yapmaz.
Timing, memory, VAD, PCM segmentation ve ExerciseResult/scorer bridge yok.

**Doğrulama:** 480 test (+14), analyze temiz, format 143 dosya/0 değişiklik.
İlk targeted koşudaki iki num→double test type ve bir braces uyarısı düzeltildi;
targeted 14 ve full suite geçti. Testler sentetik Hz/event listeleridir; gerçek
ezgi kaydı/öğrenci/cihaz/pedagoji kanıtı değil. Bu tur build yapılmadı; önceki
Xcode lipo engeli çözülmüş sayılmadı. Agora değiştirilmedi; commit/push/ödeme/
API/upload/deployment yok. CURRENT/roadmap/testing/mimari/handoff güncellendi.

## 2026-10-12 07:51 TRT — CORE-03b diagnostic pitch segmentation

Mevcut dirty INT-01a/grafik/günlük öneri ve diğer kullanıcı/ajan değişiklikleri
korundu. `pitch_segmenter.dart` ve 13 regresyon testi eklendi. RecordingPitchEvidence
frame'lerinden hedef bağımsız periodic pitch adayları; bounded/strict input,
ham oktav, ilk frekansa bağlı 35 cent run, en az 3 frame ve 200 ms center-clock
span. Sessizlik/unreliable/clip/kapsanmayan boşluk hard boundary; kısa run ve
spike indeksleri discarded evidence'da. Immutable provenance ve frame indeksleri
korunur. Bozuk tail tüm girdiyi reddeder; overlap sayısı süreyi şişirmez.

Sınırlar window-center tahminidir: gerçek onset/duration, VAD veya insan nota
kimliği değildir. Hızlı notalar elenebilir, artefaktlar run'ı bölebilir; defaults
detector hipotezi, öğrenci başarı rubriği değil. Ürün analyzer/scorer/ExerciseResult
ve UI bağlantısı eklenmedi. Sentetik iki ton PCM→gerçek DSP→segment→symbolic
alignment yalnız testte açıkça bağlandı; insan ezgi başarısı olarak sunulmadı.

**Doğrulama:** full suite 493 test geçti (+13); son `flutter analyze --no-pub`
temiz (4.3 sn), format 145 dosya/0 değişiklik. İlk e2e koşusundaki 2 Hz test
varsayımı başarısızdı (660 Hz aday ≈662.25 Hz); assertion mevcut frame regression
15 cent sınırına alındı. Üretim eşikleri ve scorer toleransı değiştirilmedi.
İlk brace lint'leri düzeltildi. Son whitespace kontrolü paket dosyalarında temiz.

CURRENT/IMPLEMENTATION_ROADMAP/ARCHITECTURE/AUDIO_TESTING/MODEL_HANDOFF
güncellendi. Agora git durumu temiz; değiştirilmedi. Mobil build, fiziksel mic,
API, upload, ödeme, commit/push veya deployment yok. Xcode lipo ortam engeli,
insan VAD/ezgi benchmark, cihaz/eğitimci ve piyano kayıt kapıları açık.
Sıradaki bağımsız paket CORE-04 puansız response session + fake lifecycle;
gerçek doğrulama olmadan memory/timing/başarı kararı bağlama.

## 2026-10-12 13:13 TRT — CORE-04a puansız ezgi koordinatörü

Önce güncel roadmap/log/testing/mimari/kararlar ve dirty kod okundu; kullanıcı/
diğer ajan INT/grafik/home değişiklikleri korunarak iki yeni dosya eklendi:
`lib/application/melody_session.dart`, `test/application/melody_session_test.dart`.

Immutable 3–5 nota reference declaration + typed backend binding; SESSION-01
kalibrasyon/kalite/capture/epoch akışının private kompozisyonu. Tek ses deviation
sonuca verilmez; yalnız diagnostic segment/quality/retry ve completed reference
callback sayısı. Skor/sequence başarı/hafıza/timing/ExerciseResult/history bağlantısı
yok. Player declaration gerçek content/hak veya duyma doğrulaması değildir;
production reference adapter/ekran CORE-04b'de hâlâ bekliyor.

Private native queue mutation/read/route çağrılarını sıralar; delayed capture
start→cancel→discard sırası ve failed-command recovery testli. Callback/worker
kuyruğu bloklamaz, facade eski işlem settle olmadan restart vermez. İzin/native
callback cleanup'ı geciktirebilir; hard cancel yok. Close eski DSP sonucunu ve
notification'ı reddeder. Placeholder ve mevcut scorer toleransları değişmedi.

**Doğrulama:** 10 targeted ve full suite **503 test** geçti (+10);
format **147 dosya/0 değişiklik**; son analyze **temiz** (2.4 sn).
İlk targeted koşuda tam sıfır sinyalin status assertion'ı `silent` olarak
düzeltildi (üretim kalite davranışı değişmedi). Serialization sonrası pending
permission testinin yanlış await sırası timeout oldu; callback çözülüp cleanup
beklenecek biçimde düzeltilerek suite tekrar geçti. Son analyze'daki bir
unnecessary-underscores info'su düzeltildi; final analyze temiz.

CURRENT/IMPLEMENTATION_ROADMAP/AUDIO_TESTING/ARCHITECTURE/MODEL_HANDOFF
güncellendi. Agora read-only git kontrolü temiz; kaynaklarına dokunulmadı.
Bu tur mobil build, gerçek mic/insan/cihaz/pilot, dış sistem, API, ödeme, upload,
commit/push/deployment yok. Gerçek VAD/benchmark/cihaz/öğretim kapıları ve
önceki iOS lipo araç engeli açık. Sıradaki bağımsız iş CORE-04b reference'e bağlı
yerel sentetik player adapter ve puansız ezgi ekranı/home bağlantısı.

## 2026-10-12 18:20 TRT — CORE-04b1 bağlı sentetik ezgi oynatıcısı

Güncel git/roadmap/log/testing/devir/mimari/kararlar ve mevcut session/player/
capture kodu incelendi. Dirty INT/grafik/home ve diğer kullanıcı/ajan değişiklikleri
korundu; bu paket yalnız yeni infrastructure renderer+backend ve test dosyasını
ekler, mevcut home/UI kodunu değiştirmez.

`SyntheticMelodyBackend`: immutable typed reference → mono PCM16 sine WAV,
3–5 sıralı ton, 600 ms tone/200 ms gap/400 ms final silence, bounded 8–48 kHz.
Tek doğru frequency kaynağı reference; encoded bytes immutable. Ayrı clip
player bu WAV'ı çalar, capture default C4 reference'e fallback yapmaz. Capture
PCM/source/route/interruption/replay forwarded; unknown route unverified kalır.
Mobile factory mevcut PluginAudioLabBackend/JustAudioClipPlayer'ı lazy bağlar.
Stop/close hata halinde diğer kaynağı yine kapatır; close future idempotent ve
ilk hata korunur. Closed backend yeni play/capture reddeder. Session native
serialization/epoch sahibi; adapter dışarıda concurrent kullanılmamalı.

**Doğrulama:** 8 yeni fake/sentetik test dahil **511 full test geçti**;
format **149 dosya/0 değişiklik**, son analyze **temiz** (7.1 sn).
3/4/5 × 8/48 kHz render/codec/raw Hz (<15 cent existing synthetic bound)/gap/
amplitude/determinism; exact WAV/binding/completion, forwarding/unknown route,
failure/no fallback/close-idempotence; session+adapter capture only after clip
completion/cancel-cleanup. İlk test compile'da List<int>→List<double> literal
tipi ve unused import düzeltildi; initializing-formal lint düzeltildi. Üretim
rubriği veya kalite eşikleri değiştirilmedi. Nihai full suite sonrası analyze
temiz; önceki 510-test koşusu entegrasyon testi eklenmeden tarihsel kontrol.

Bu kod-test alt paketi: ekran/home, gerçek duyulma/latency, fiziksel native
focus/route/mikrofon QA ve eğitimci içerik onayı yok. Sine WAV piyano kaydı
değil. Skor/başarı/hafıza/history/AI/abonelik bağlantısı açılmadı. Piano placeholder
değişmedi; lisansı belirsiz ses eklenmedi. Agora git durumu temiz, kaynakları
değiştirilmedi. Build/cihaz/insan/pilot/API/upload/ödeme/commit/push/deployment
yok; iOS lipo ortam engeli hâlâ açık. Roadmap/testing/mimari/handoff güncellendi.
Sıradaki hazır iş CORE-04b2 puansız ezgi ekranı + home + fake widget/lifecycle QA.

## 2026-10-12 23:20 TRT — CORE-04b2 puansız ezgi ekranı/home

Güncel git, roadmap/log/testing/devir/mimari/kararlar ve session/adapter/widget
kodları okundu. Kullanıcı/ajan INT/grafik/learning değişiklikleri korundu;
home'a yalnız yeni Deneysel ezgi route eklendi, eski disabled ezgi satırı kaldırıldı.
Yeni MelodySessionScreen, üç sentetik C4/E4/G4 reference (synthetic-1) ve native
worker: açık kalibrasyon/başlat/bitir/iptal, phase live region, nötr quality/
permission/error retry, isteğe bağlı candidate Hz/source ve reference callback
sayısı. Piyano/başarı/VAD/hafıza iddiası yok; history/mastery/AI/scorer bağlanmadı.
Girişte izin/capture yok, background cancel, permission inactive istisnası,
dispose owned resource close. Mevcut theme token'ları; fake success animation yok.

**Doğrulama:** 8 targeted widget ve full suite **519 test geçti** (+8),
format **151 dosya/0 değişiklik**, son analyze **temiz** (3.0 sn).
Giriş/kalibrasyon eksikliği, izin reddi, 320px/1.8× tam flow+mock source,
sessizlik, stuck playback cancel/background/no autoresume, pending permission
dispose, home default synthetic route ve tap/label/contrast guideline testleri.
İlk Dart pattern guard syntax ve void lifecycle await düzeltildi. İlk dispose
assertion (targeted + erken full suite) native permission/stream cleanup'ı fake
frame pump ile bekliyordu; mevcut audio-lab testleri gibi runAsync completion/
event-loop tick ile düzeltildi, targeted ve full suite tekrar geçti. Üretim
quality/scorer eşikleri değiştirilmedi. Native cleanup anlık/bellek erase garantisi
değil; fiziksel test yapılmadı. Widget screenshot/native görsel QA yok.

Roadmap/testing/mimari/handoff güncellendi. Agora git durumu temiz; değiştirilmedi.
Mobil build, gerçek mic/insan/cihaz/eğitimci pilotu, API/upload/ödeme/commit/push/
deployment yok; piano placeholder aynı. Xcode lipo engeli çözülmüş sayılmadı.
CORE-04 tamamı değil: gerçek segment/voice/benchmark, recall protokolü ve
güvenilir hata bölüm loop hâlâ açık. Sıradaki bağımsız hazır iş REL-08 local QA
runner/CI taslağı (dış CI etkinleştirme değil); ardından LEARN-02 mikroders şeması.

## 2026-10-13 04:20 TRT — REL-08 yerel ortak kalite runner

Git/roadmap/log/testing/devir/mimari/kararlar ve pubspec/analysis ayarları
okundu; mevcut kullanıcı/ajan dirty değişiklikleri korundu. Yeni standalone
tool/quality_check.dart + 10 test + docs/ci/README.md; AGENTS ortak komutu aldı.
Runner script root Resonia guard ile cwd'den bağımsız; immutable argv/process
spawn (shell string yok), read-only lib/test/tool format → no-pub analyze →
full test. İlk tool exit aynen korunur; ProcessException 127, otomatik SDK kurma
yok. --plan hiçbir step çalıştırmaz; --fetch explicit pub get --enforce-lockfile.
Flag yerel help ile kontrol edildi, fetch uygulanmadı. Doğrudan dart giriş
implicit pub/build hooks başlamasını önler; dart run tavsiye edilmez.

**Doğrulama:** Son gerçek `dart tool/quality_check.dart` pipeline exit 0:
**529 test geçti (+10)**, analyze temiz (2.8 sn), **153 dosya/0 format değişikliği**.
CLI plan alternatif temp cwd'de ve read-only Agora cwd'de Resonia'ya bağlı;
unknown option, plan/no-fetch/locked-fetch, immutable snapshots, sequential
success, her stepte fail-fast exit, missing executable, unexpected failure
ve yanlış repo adı testli. İlk koşuda CLI testi Platform.resolvedExecutable'ı
Dart sandı; Flutter test host'unda flutter_tester döndüğü için iki alt süreç
bekledi. Yalnız bu testin gözlenen child PID'leri sonlandırıldı, eski/başka
ajan süreçlerine dokunulmadı; CLI testleri açık `dart` ile düzeltildi ve tüm
pipeline tekrar geçti. Üretim ses/scorer eşikleri veya SDK değiştirilmedi.

CI sağlayıcı-bağımsız taslağı etkinleştirilmedi; secrets/private audio/fixture
upload yok. Hard subprocess timeout yok; hosted job timeout ayrı ayarlanmalı.
Hosted CI/diğer OS/mobil build/gerçek mic/cihaz/insan/pedagoji doğrulaması değil.
Piano placeholder/scorer kapıları aynı; iOS lipo araç engeli açık. Agora kaynakları
değiştirilmedi. API/ödeme/upload/commit/push/deploy yok. Roadmap/testing/mimari/
devir/AGENTS güncellendi. Sıradaki LEARN-02 mikroders şeması: taslak ile gerçek
eğitimci onayını ayrı tut; BENCH/VAD/cihaz kapılarını sentetik testle kapatma.

## 2026-10-13 09:15 TRT — LEARN-02a draft mikroders sözleşmesi

Git/roadmap/log/testing/devir/mimari/kararlar, LEARNING_MODEL ve skill graph/
measured catalog okundu. Kullanıcı/ajan dirty değişiklikleri korunarak üç yeni
dosya: domain/learning/micro_lesson.dart, content/draft_micro_lessons.dart,
test/domain/learning/micro_lesson_test.dart.

Immutable/bounded draft LessonStep/MicroLesson/Catalog, tam sıralı beş faz;
graph known skillId/route/dimension doğrulaması; training/guided vs independent
vs delayed ID partition sızıntı reddi. Kimlik ayrımı waveform novelty/consent/
telif/etiket/çalıştırılabilir exercise kabulü değildir. Boş örnek slotu pending;
educatorApproved/assessmentEnabled false. İki text draft tiz/pes algı ve puls
üretim; no audio, UI, JSON importer/onay flow, ExerciseResult/mastery bridge.
Okuma completion beceri kanıtı sayılmaz. 12/120 içerik hedefi tamamlanmadı.

**Doğrulama:** Ortak `dart tool/quality_check.dart` exit 0; **538 full test
geçti (+9)**, analyze temiz (2.6 sn), **156 dosya/0 format değişikliği**.
Draft gate/binding, immutable snapshot, missing/duplicate/shuffled phases,
train-independent-delayed/guided leak, malformed/budget reference/text,
unknown skill/route/dimension, duplicate/128 catalog budget, pending vs bound
ids ama approval/assessment kapalı regresyonları. Üretim scorer eşikleri,
skill mastery ve mevcut UI değiştirilmedi. Gerçek ses/cihaz/pedagoji onayı yok.

Roadmap/testing/mimari/devir/LEARNING_MODEL güncellendi. Agora read-only git
kontrolü temiz; değiştirilmedi. Build/mic/insan/eğitimci pilotu/API/upload/ödeme/
commit/push/deployment yok; piano placeholder aynı, iOS lipo engeli açık.
Sıradaki LEARN-02b draft okuma ekranı + skill-map erişimi, görünür içerik/onay
bekleme ve completion'dan mastery üretmeme widget testleri. EDU-01 gerçek
eğitimci, izinli örnek bankası ve yeni/gecikmeli öğrenme pilotu kapıları açık.

## 2026-10-13 14:17 TRT — LEARN-02b salt metin mikroders ekranı

Git/roadmap/log/testing/devir/mimari/kararlar ve mevcut skill-map/mikroders
kodları okundu; dirty kullanıcı/ajan değişiklikleri korundu. Yeni stateless
MicroLessonScreen ve 6 widget test; skill_map_screen'e ders katalog injection/
button navigation eklendi. Default graph iki text draft alır, custom graph
implicit unrelated ders almaz; skillId/route/dimension filtrelenir.

Reader: görünür metin taslağı/eğitimci onayı bekliyor; algı/üretim, content
version/goal, beş faz/semantic headings. Bekleyen örnekler ve disabled practice,
bound ID varsa bile play/assessment yok. Audio/mic/repository/completion marker
dependency yok; okuma history/SkillStatusEvaluator'a dönüşmez. Back dönünce
mevcut history ve mastery state korunur. Mevcut theme/scrollable layout kullanıldı.

**Doğrulama:** İlk ortak runner koşusu exit 0: **544 full test geçti (+6)**,
analyze temiz (8.3 sn), **158 dosya/0 format değişikliği**. Draft/disabled phase,
skill-map→reader→back history boş + state unchanged, puls üretim route, custom
graph, 320px/1.8× tüm fazlar ve Android/iOS target/label/contrast guideline.
Widget testleri gerçek device/reader/visual/performance/pedagogy kabulü değil.
Yeni failure veya eşik değişimi yok; gerçek reviewed ses bankası/onay eklenmedi.

Roadmap/testing/mimari/devir güncellendi. Agora read-only git temiz; kaynakları
değiştirilmedi. Build/mic/cihaz/insan/eğitimci pilot/API/upload/ödeme/commit/push/
deploy yok. Piano placeholder ve scorer kapıları aynı; Xcode lipo engeli açık.
Sıradaki LEARN-02c strict versioned JSON draft catalog round-trip/import guard;
EDU-01 kayıt/hak/etiket/onay ve öğretim pilotu ayrı kapı. Okuma completion'dan
mastery veya exam eligibility çıkarma.

## 2026-10-13 19:17 TRT — LEARN-02c draft katalog JSON codec

Git/roadmap/log/testing/devir/mimari/kararlar ve mikroders kodu okundu; mevcut
kullanıcı/ajan dirty değişiklikleri korundu. Yeni MicroLessonCodec + 11 test:
schema1/draft kind/review only; exact root/lesson/step keys/types/enums,
1MiB UTF8 ve lesson/step/ID/text bütçeleri, constructor + graph + held-out
partition guard. Geç bozuk lesson whole-catalog reject, restore immutable,
fresh export maps; malformed parser errors source temizlenir. IO/file/asset
ve mobile import UI eklenmedi. Approval/assessment/mastery/scorer açılmadı.
Standard jsonDecode duplicate keys çözümler; signed/canonical belge veya
hak/hash/etiket/acoustic novelty doğrulaması değildir.

**Doğrulama:** 11 targeted test geçti; son ortak runner exit 0 **555 full
test geçti (+11)**, analyze temiz (3.1 sn), **160 dosya/0 format değişikliği**.
Round-trip/draft gate, strict version/kind/key/type/enum, graph/duplicate,
invalid tail, phase/control leak, UTF8/text/list budget, immutable input/export
ve sanitized error testli. İlk analyze'da 3 braces info + 3 unnecessary cast
düzeltildi. İlk tam suite'de mevcut `melody_session_test.dart: late worker
after route interruption cannot publish candidates` başarısız oldu; bu test/
üretim session kodu değiştirilmedi. Tekrar full suite tamamen geçti. Bu tur
tekil failure'ın kök nedeni teşhis edilmedi; async test timing riski gizlenmedi,
yeniden tekrarlanırsa state-based wait teşhisi gerekir. Codec rubriği gevşetilmedi.

Roadmap/testing/mimari/devir güncellendi; Agora git read-only kontrolü temiz,
kaynakları değiştirilmedi.
Build/gerçek mic/voice/cihaz/eğitimci pilotu/API/upload/ödeme/commit/push/deploy
yok. Piano placeholder, real success kapıları ve iOS lipo araç engeli aynı.
Sıradaki LEARN-03 süreli günlük 5/12/15dk plan; taslak süreleri, gerçek içerik/
eğitimci onayı ve öğrenme etkisi pilotunu ayrı tut.

## 2026-10-13 20:45 TRT — LEARN-03c süreli günlük plan (5/12/15 dk)

Kullanıcı isteğiyle LEARN-03 uygulandı. Yeni `lib/domain/learning/daily_plan.dart`
(DailyBudget/PlanBlock/DailyPlan/DailyPlanner), `lib/features/daily_plan/
daily_plan_screen.dart`, ortak `lib/features/learning/exercise_launcher.dart`;
`MeasuredExercise.draftMinutes` eklendi; `lastResultReason` next_step_text'ten
ayrıldı. Home'daki "Günlük çalışma rotası" planlanan karttan Deneysel karta
dönüştü (geçmiş servisi varsa); "Planlanan çalışmalar" bölümü boşaldığı için kalktı.

Kurallar: plan gece yarısından önceki sonuçlardan kurulur ve gün boyu sabit
kalır; bugünkü geçerli turlar ilerleme işaretler. Öncelik: en gecikmiş kontrol
→ ilk zayıf → yeni(ler) → diğer kontroller → diğer zayıflar; açgözlü bütçe,
sonra tekrar/yeni bloklara ikinci tur (ölçüt art arda iki temiz tur). Kontrol
tek tur, retentionCheck bayrağıyla açılır. Kuyruk 1/3/7/14 gün; günde ≤1 (5 dk)
/≤2 yeni. Boş süre "planlanmadı" diye yazılır, sahte blokla doldurulmaz.
Mastery eşikleri, skor kuralları ve beceri durum merdiveni değiştirilmedi.

**Doğrulama:** `dart tool/quality_check.dart` exit 0: **574 test geçti (+19)**,
analyze temiz, **165 dosya/0 format değişikliği**. Önceki tekil ezgi testi
kararsızlığı bu koşuda görülmedi. Build/cihaz/insan testi yapılmadı.

**Sınırlar:** Süreler (2/2/3 dk), 1/3/7/14 aralıkları ve yeni sınırları
geliştirici hipotezi; eğitimci onayı ve öğrenme pilotu (EDU-01, LAUNCH öncesi)
bekliyor. Bütçe seçimi kalıcı değil. Mikroders okuma, ezgi/tek ses (puansız)
modülleri plana girmez; yalnız ölçülen dokunma egzersizleri planlanır.

## 2026-10-13 21:30 TRT — DATA-03a, LEARN-04a, SHELL-04a (kod-yalnız eksikler)

Kullanıcı "tüm eksikleri tamamla" dedi; dış kapı gerektirmeyen işler yapıldı.
- **DATA-03a yerel taşıma:** `LocalDataExport` + Ayarlar → "Verilerini taşı".
  Ses içermeyen sürümlü JSON panoya; yapıştırılan belge önce tamamen doğrulanır,
  sonra mevcut geçmiş kurallarıyla eklenir (aynı deneme tekrar sayılmaz, çakışan
  korunur, kapasite aşılmaz). Upload/consent/signed URL kısmı backend'e bağlı, açık.
- **LEARN-04a beceri raporu:** `SkillReport` + beceri haritası rapor kartı:
  ölçülebilen/ölçülemeyen sayıları, durum dağılımı, tek hedef ve eylem. Yüzde yok;
  ölçülemeyen beceri "bilinmiyor", zayıf değil.
- **SHELL-04a tercih:** günlük plan bütçesi cihazda hatırlanır (bozuk → varsayılan).
  Ortak durum bileşenleri ve offline göstergesi (uygulama zaten tamamen offline) ayrı.

**Doğrulama:** `dart tool/quality_check.dart` exit 0: **596 test geçti (+22)**,
analyze temiz, **174 dosya/0 format değişikliği**. `flutter doctor`: Xcode artık
27.0; Android cmdline-tools eksik ve lisans durumu bilinmiyor (değişmedi).
Gerçek cihaz/pano/insan testi yapılmadı.

**iOS simulator build (21:40 TRT):** `flutter build ios --simulator --debug`
Xcode 27.0 ile de düştü: `debug_unpack_ios` "Flutter.framework does not contain
architectures arm64 x86_64" diyor, oysa `lipo -info` x86_64+arm64 gösteriyor.
Aynı Flutter 3.44.4 lipo uyumsuzluğu; kod kaynaklı değil. Çözüm Flutter
güncellemesi (kullanıcının global SDK'sını değiştirir → kullanıcı onayı gerekir).

**2026-10-13 22:10 TRT — Flutter güncellemesi (kullanıcı onayıyla):** Flutter
3.44.4 → **3.47.7** (Dart 3.13.5). `flutter build ios --simulator --debug`
Xcode 27.0 ile **başarılı** (Runner.app); lipo engeli kapandı. Upgrade iOS
minimum hedefini 13.0 → 15.0 yaptı, analysis_options build/android/ios'u
dışladı, pubspec.lock'ta yalnız SDK'ya bağlı test paketleri değişti. Quality
check yeni SDK'da exit 0: 596 test, analyze temiz, 174/0 format. Simulator'da
elle gezinti/gerçek cihaz/mikrofon testi yapılmadı. Android cmdline-tools/lisans
hâlâ eksik.

## 2026-10-13 devam — SHELL-04b ortak içerik durumları

Güncel git/docs/kod okundu: günlük plan/export/rapor zaten diğer oturumda
uygulanmıştı; tekrar edilmedi. Devralınan dirty release/channel/privacy/error-
log/manifest/SDK işleri korunarak bağımsız common state işi seçildi.
Yeni ContentStatusPanel loading/empty/error, explicit retry/no auto reset;
History/chord consumer ve history LocalOnlyNotice (connectivity/sync değil).
Corrupt dosya açıklaması ve store davranışı aynı, skor/data mutation yok.

**Doğrulama:** Son ortak runner exit 0 **609 test geçti**, analyze temiz
(3.1 sn), **181 dosya/0 format değişikliği**. Bizim paket 6 yeni widget test,
toplam ayrıca devralınan app-channel/error-log testlerini içeriyor. Loading/
empty/manual retry/corrupt-recovery/pending/narrow-a11y matrix. İlk analyze
test brace lint düzeltildi. İlk full+targeted aralık ve algı history UI testleri
yeni local notice nedeniyle sonuç kartı viewport altına kaydığı için başarısızdı;
iki testi scrollUntilVisible ile gerçek akışa uydurduk, sonuç assertions korunur.
Son full suite geçti. Bu testlerde skor/ölçüm veya tolerans değiştirilmedi.

Roadmap/mimari/testing/handoff güncellendi. Bu tur build/gerçek mic/cihaz/insan/
eğitimci pilotu/API/ödeme/upload/commit/push/deploy yok. Önceki başarılı simulator
build ve kullanıcı onaylı SDK update kaydı korunur; bu tur tekrar yapılmadı.
SHELL-04 tam resume/tüm ekran migration değil; dış BENCH/VAD/CAL/EDU/mağaza/
backend kapıları açık. Agora read-only kontrolü temiz, kaynakları değiştirilmedi.

## 2026-10-14 00:13 TRT — SHELL-04c günlük plan hata kurtarma

Git/roadmap/log/testing/devir/mimari/kararlar ve DailyPlanScreen/tests okundu.
Dirty yayın/channel/privacy/error-log/platform işleri korundu. Günlük plan
loading/error/no-content/nothing-due ortak ContentStatusPanel'a taşındı;
explicit retry, bütçe korunur, pending stale plan görünmez, mounted reload guard.
Planner selection/mastery/retention/scorer davranışı değiştirilmedi.

3 yeni widget test: unavailable history→budget5→manual retry, pending/no
duplicate action/stale plan, dispose→late response. İlk full+targeted testte
budget switch esnasında immediate failed Future, yeni FutureBuilder frame'i
subscribe olmadan hata verdi. _loadForView immediate error observer (ignore)
ile aralık kapandı; original Future UI'ya verilerek gerçek hata görünür kaldı.
Empty/fake successful plan ile hata gizlenmedi, data reset veya tolerance
gevşetme yok. Observer teknik amaçlıdır, UI hata açıklaması korunur.

**Doğrulama:** Son ortak runner exit 0: **612 test geçti (+3)**, analyze
temiz (3.1 sn), **182 dosya/0 format değişikliği**. Eski günlük budget/retention/
persistence/narrow/a11y testleri de geçti. İlk failed test logu korunur; sorun
üretim UI async ownership düzeltmesiyle kapandı. Widget tests gerçek reader/
device/network/audio/pedagoji kabulü değildir.

Roadmap/testing/mimari/devir güncellendi. Agora read-only git kontrolü temiz,
kaynakları değiştirilmedi. Build/mic/insan/cihaz/eğitimci pilotu/API/upload/ödeme/
commit/push/deploy yok; önceki simulator/SDK onay kaydı korunur. SHELL-04 tam
session resume/tüm consumer kabulü değil; BENCH/VAD/CAL/EDU/mağaza/backend
gibi dış kapılar ve piano kayıtları açık. Otomatik takip tamamlandı sayılmadı.

## 2026-10-14 05:35 TRT — SHELL-04d beceri haritası hata kurtarma

Git/docs/kararlar ve mevcut skill-map/report/tests okundu. Dirty kullanıcı/
ajan release/channel/privacy/error-log/platform değişiklikleri korundu.
Skill-map shared loading/error panel + manual retry; history unavailable
null view state/Durum alınamadı, NOT domain MasteryState.notMeasured. Report/
focus hata sırasında gösterilmez; metin dersleri açık, history/mastery write
yok. Immediate Future error observer, original future UI failure korur;
mounted reload ve exercise dönüşünde güvenli refresh. Score/rubric aynı.

4 yeni widget: unavailable vs unattempted, explicit retry→report/empty,
draft/back no invented progress, pending/dispose no stale/late UI. İlk full/
targeted iki yeni testte assignment arrow closure setState'a Future döndürdü;
synchronous block closure ile düzeltildi, assertion/eşik gevşetilmedi.
**Son ortak runner exit 0: 616 full test geçti (+4), analyze temiz (5.2 sn),
183 dosya/0 format değişikliği.** Eski skill map/report/microlesson/narrow/a11y
testleri de geçti. Widget tests gerçek reader/device/voice/eğitim kabulü değil.

Roadmap/testing/mimari/devir güncellendi. Agora read-only git temiz, kaynakları
değiştirilmedi. Build/gerçek mic/cihaz/insan/eğitimci pilot/API/upload/ödeme/
commit/push/deploy yok; önceki simulator SDK kaydı korundu. SHELL-04 tüm
consumer/session resume değil; gerçek BENCH/VAD/CAL/EDU/piyano ve hesap/mağaza
kapıları açık. Otomatik takip tamamlandı sayılmadı.

## 2026-10-14 10:36 TRT — REL-06a hedef tuning metadatası

Git/docs/kararlar ve HUMAN_REVIEW/REL-06 açıkları ile mevcut protocol/piano
kodları okundu. Dış kapı gerektirmeyen daha öncelikli metadata tutarlılığı
seçildi; dirty kullanıcı/ajan yayın/platform/channel/privacy/error-log işi
korundu. Pure TargetNoteTuning scientific note→MIDI0–127/frequencyFor(A4)
ve validate, ExerciseProtocol constructor'da her note için uygulanır; JSON
reconstruction aynı invariant'e tabi. Wrong label/octave/A4 fail-closed;
enharmonic octave carry ve finite positive numeric checks. 0.005000001Hz
yalnız 2-decimal metadata rounding; öğrenci50cent/stability25cent/voice gate
değişmedi. Const legacy TargetNote/Exercise/scorer ve waveform pipeline aynı.
Schema1 alanları aynı, stricter validation ADR-025'e yazıldı.

**Doğrulama:** Son ortak runner exit 0: **626 full test geçti (+10)**,
analyze temiz (3.1 sn), **185 dosya/0 format değişikliği**. Canonical MIDI
range formula/aliases/octave carry/rounding, mismatch+retuned target, malformed
label/range/whitespace/nonfinite/overflow, JSON reconstruction, invalid tail,
400–480Hz piano target generator ve rhythm-only compatibility testli. İlk
analyze'daki iki braces info düzeltildi; strict match-end guard trailing newline
reddini explicit yaptı. Eşikler test sonuçlarıyla gevşetilmedi.

Bu target metadata QA, gerçek recording/audio/etiket/hak/clock/voice/device
kanıtı değil. REL-06 session/hint/tuning cohort ve gerçek ses benchmark kapıları
tamamlanmadı. Roadmap/testing/mimari/ADR/devir güncellendi. Build/mic/cihaz/
insan/eğitimci pilot/API/upload/ödeme/commit/push/deploy yok. Agora read-only
kontrolü temiz, kaynakları değiştirilmedi. Piano placeholders/success gate aynı;
önceki simulator/SDK kaydı korunur. Otomatik takip tamamlandı sayılmadı.

## 2026-10-14 11:55 TRT — REL-09 yayın hijyeni + OPS-01a yerel hata günlüğü

Kullanıcı "canlıya çıkış için geliştirme açıkları" sordu; dış kapısız işler
uygulandı ve RELEASE_READINESS.md yazıldı (iç beta / Core / ücretli yayın
açıkları, tür: kod/karar/dış). Bu oturum yeniden başlarken otomatik ajanın
SHELL-04b/c/d ve REL-06a işleri ağaçta bulundu, korundu.
- **REL-09:** `lib/app/app_channel.dart` (`--dart-define=RESONIA_CHANNEL=dev|beta`,
  bilinmeyen değer hata); beta'da ses laboratuvarı, simülasyon ve piyano
  placeholder gizli; Ayarlar → Hakkında kanal. Android label/iOS CFBundleName
  "Resonia"; release imzalama `android/key.properties` (yoksa uyarı + debug,
  mağazaya yüklenemez); keystore dosyaları gitignore. iOS
  `PrivacyInfo.xcprivacy` (tracking yok, toplanan veri yok, FileTimestamp
  C617.1) Xcode projesine eklendi ve paket içinde doğrulandı. pubspec açıklaması.
- **OPS-01a:** `LocalErrorLog` (bellekte ≤50, mesaj metni tutulmaz; tür + ilk
  `package:resonia` konumu, dakika hassasiyeti) + `installGlobalErrorHandlers`
  (FlutterError/PlatformDispatcher; release'te sakin placeholder). Ayarlar →
  "Uygulama hataları" yalnız hata varsa; rapor panoya kopyalanır, gönderim yok.

**Doğrulama:** ortak runner exit 0: **626 test**, analyze temiz, 185/0 format
(otomatik ajanın paketleri dahil; bu paket 7 test ekledi: kanal 3, hata 4).
`flutter build ios --simulator --debug --dart-define=RESONIA_CHANNEL=beta`
başarılı, PrivacyInfo paket içinde, CFBundleName Resonia. `flutter build apk
--debug` başarılı (Gradle CMake 3.22.1 kurdu). Gerçek cihaz/emülatör çalıştırma,
release imzalı build, mağaza yüklemesi yapılmadı. Commit yok.

## 2026-10-14 — UI-01 A+C tasarımının uygulanması

Kullanıcı A+C yönünü seçti ve gerçekçi ses animasyonları istedi. Çalışma
`design/a-c` dalında ayrı worktree'de yapıldı (otomatik ajanla çakışmamak için).
- Tema ve bileşenler (ADR-026), alt sekmeli kabuk: Bugün (öneri kartı, günlük
  plan kartı, beceri yolu, seri rozeti), Pratik (modül kartları; geliştirici
  araçları yalnız dev kanalında), Gelişim (beceri haritası + C tarzı rapor),
  Profil (geçmiş, beceri haritası, ayarlar).
- Tiz/pes, derece ve ritim ekranları: ilerleme çubuğu, büyük cevap kartları,
  alttan açıklama paneli, C tarzı özet kutuları; seviye çipleri dinleme
  sırasında pasif kalır (sayfa zıplamaz).
- Ses görselleri gerçek veriye bağlı: dinlemede çalınan WAV'ın zarfı, çalma
  başı ve osiloskobu; kayıtta mikrofon seviyesine bağlı ses şeridi. Ritim
  dokunma alanında dokunuş halkası ve dokunsal geri bildirim (zaman ölçümü
  pointer-down zaman damgasından, değişmedi).
- Hedef seçimi yenilendi; Türkçe büyük harf hatasını önlemek için etiketler
  programla büyütülmüyor. iOS/Android ikon seti ve açılış ekranı renkleri.
- Simulator'da bulunan ve düzeltilen hatalar: kart gölgesinin içi gri
  doldurması, yol bağlantı noktalarının metnin üstünden geçmesi, BAŞLA
  balonunun bölüm başlığına binmesi, setState'e Future döndürülmesi.

**Doğrulama:** `dart tool/quality_check.dart` exit 0 (worktree): 639+ test,
analyze temiz, format 0 değişiklik. iOS simulator build ve elle gezinti
(açık/koyu). Gerçek cihaz, Android çalıştırma, ekran okuyucu ve kullanıcı
testi yapılmadı. Ölçüt/skor/tolerans değişmedi.

## 2026-10-15 — UX-02 sadeleştirme (rakip sistem incelemesi sonrası)

Kullanıcı ekranları karmaşık buldu. Duolingo Music, Simply Piano/Sing,
Yousician, EarMaster, ToneGym, Perfect Ear, Complete/Functional Ear Trainer,
Tenuto, MyEarTraining, Singing Carrots ve Apple HIG / Material 3 / NN/g
rehberleri üç araştırma ajanıyla incelendi (kaynaklar ikincil ağırlıklı;
uygulamalar elle denenmedi). Uygulanan ilkeler: ekran başına tek birincil
eylem, tek satırlık yönerge, ayarlar bir kademe derinde, uyarılar tek yerde.
- Bugün: üç başlatma noktası teke indi (Sıradaki kartı + dakika halkası +
  yol). Günlük plan kartı kaldırıldı; halka planı açar. Tüm taslak/ölçüm
  notları başlıktaki "Beta" sayfasında. Yol balonu kartın fiiliyle aynı.
- Ders modu (`LessonScaffold`): başlık çubuğu yok; kapat + ilerleme + sayaç.
  Seviye çipleri `LevelPicker` sayfasına taşındı; cevaplar ve geri bildirim
  ekranın altında (başparmak bölgesi), kısa ekranda kaydırılır.
- Pratik: iki sütunlu eşit yükseklikte kutucuklar, kısa başlıklar; kart başı
  rozetler kaldırıldı, "Söyle" grubunda tek "Puan yok" rozeti.
- Gelişim: kısa giriş, kart başına başlık+durum, meta tek satır.
- Ana sayfa yüklemesi tercih dosyasını beklemez (yavaş IO'da takılma
  giderildi); dakika halkası büyük yazıda taşmaz.
Doğrulama: 639 test, analyze/format temiz; simulator'da elle gezinti.
Gerçek kullanıcı testi yapılmadı; kanıt yok sayılmalı, UXR-01 açık.

## 2026-10-14 15:39 TRT — REL-06b protokol JSON preflight

Git/docs/kararlar ve protocol kodu okundu; girişte ağaç temizdi (önceki kullanıcı/
ajan paketleri commit edilmişti). ExerciseProtocol.fromJson strict exact root/
tuning/event/target fields; integer schema1, enum-safe mode/presentation/order,
finite numeric, integer policy/bool flags. Both event counts≤256 before note
traversal; malformed shape FormatException safe fixed text, no value/source
echo. Existing constructor semantic ArgumentError/tuning/recall constraints
unchanged; valid JSON output same. No partial catalog/protocol delivered.

**Doğrulama:** İlk ortak runner exit 0, **636 full test geçti (+10)**;
analyze temiz (3.8 sn), **186 dosya/0 format değişikliği**. Round-trip/aids,
schema coercion, keys all depths, flags/int, enums/mode, numeric/type, budgets/
malformed prefix, late invalid+semantic rules, snapshot/no text echo tests.
Üretim öğrenci/rubrik eşikleri değişmedi; fixture/scorer compatibility geçti.

Roadmap/testing/mimari/devir güncellendi. JSON decoded-map boundary only:
raw text size/duplicate-key canonicalization, authenticity/rights/waveform
etiket veya actual voice/device/teaching doğrulaması değildir. REL-06 session
hint/metadata cohort ve dış acceptance kapıları açık. Build/mic/cihaz/insan/
pilot/API/upload/ödeme/commit/push/deploy yok. Agora git read-only temiz,
kaynakları değiştirilmedi. Önceki kullanıcı build kayıtları korunur; otomatik
takip tamamlandı sayılmadı.

## 2026-10-14 20:42 TRT — REL-06c ritim referans saatini güvenli bağla

RhythmImitationEvaluator daha önce finite pozitif ama çok küçük tempo veya
büyük beat değerinde round() hatası, çok büyük tempoda ms çakışması sonrası
analyzer hatası üretebiliyordu. Negatif ilk tap hizalamayla gizlenebiliyordu.
RhythmReferenceClock artık controller/evaluator ortak preflight; renderClickTrack
aynı 30000 ms sabitini kullanır. Referans taşması/çakışması puansız invalidInput;
controller renderer/player öncesinde playbackFailed ile idle'a döner.
Timestamps 0..9007199254740991 microseconds, kronolojik; replay kota kontrolü.
Eşit tap extra, ilk tap anchor, toleranslar/skor formülü değişmedi. Yeni cevap
süresi sınırı veya latency düzeltmesi yok. Mevcut dirty REL-06b işleri korundu.

Doğrulama: hedefli 32 test geçti; ortak runner exit 0, 646 full test (+10),
188 dosya/0 format değişikliği, analyze temiz. Fake/numeric tests only; build,
cihaz/mic, insan sesi, eğitimci/pilot, API, upload, ödeme, commit/push/deploy yok.
Agora read-only git status temiz; kaynakları değiştirilmedi. Dış kabul kapıları
açık; otomatik takip tamamlandı sayılmadı.

## 2026-10-15 02:06 TRT — REL-06d öğrenmede karşılaştırılabilir kanıt

Measured catalog ve RhythmNextStepPolicy filtreleri önceden yalnız ID/content/
source/analyzer eşliyordu; farklı mode/difficulty/scoring/skill sonuçları aynı
ilerleme zincirine girebiliyordu. Yeni immutable ResultCohort sekiz alanı eşler.
Üç measured adapter beklenen cohort'u bildirir; skill-map/report/today/daily
plan ortak filtre üzerinden korunur. Invalid aynı-cohort deneme retry içindir,
mastery sayılmaz; eski/farklı koşuldaki geçmiş dosyadan silinmez/yazılmaz.
Senkop policy test fixture'ı bound difficulty2/mode'u kullanacak şekilde düzeldi;
üretim tanımını veya skor rubriğini gevşetmedim. Önceki dirty paketler korundu.

12 yeni regresyon: üç gerçek outcome-codec yolu (sentetik referans + touch,
gerçek öğrenci kaydı değil), sekiz alanın tek tek izolasyonu, invalid/retry,
chronological mixed history ve exam→today/daily learning leakage. Hedefli
öğrenme katmanı 76 test geçti; ortak runner exit0, full658 (+12), analyze temiz,
format190/0. git diff --check temiz. Bu paket protocol fingerprint/tuning/hint
doğrulaması değildir; tam REL-06 session context ve dış acceptance kapıları açık.
Build/mic/cihaz/pilot/API/upload/ödeme/commit/push/deploy yapılmadı. Agora
kaynakları değiştirilmedi; otomatik takip tamamlandı sayılmadı.

## 2026-10-15 08:44 TRT — SHELL-04e ana ekran önerisi recovery

Home TodayCard geçmiş hatasında yalnız başka ekrana yönlendiriyordu; shared
ContentStatusPanel loading/error + manual retry eklendi. _loadForView eager
error observer orijinal Future'ı FutureBuilder'a verir: setState→next-frame
hata aralığı kapanır, UI hata durumunu göstermeye devam eder. _reload mounted;
exercise dönüşü aynı yol; goal/history değişiminde fresh Future. Pending yükte
eski öneri/aksiyon gizli. Boş geçmişe çevirme, auto retry, veri yazma/silme yok.

6 yeni fake-repository widget: retry/no writes/private error text, pending,
disposal late failure, repository swap, immediate failure on exercise return,
320px/1.8×. İlk full koşuda yeni narrow test offscreen retry nedeniyle düştü;
scroll layout pump/hitTestable eklendi. İkinci full test eski sürümü yürütürken
sonuç kartı lazy list viewport dışında kaldı; test header'a geri kaydırarak
sonucu assert eder. Assertion/eşik gevşetilmedi. Son hedefli6 geçti; son ortak
runner exit0: full664 (+6), analyze temiz (2.9sn), format191/0; diff check temiz.
Önceki dirty REL-06b/c/d korundu. Build/cihaz/mic/voice/pilot/API/upload/ödeme/
commit/push/deploy yok. Agora read-only status temiz, kaynakları değişmedi.
SHELL-04 tüm consumer/session resume ve dış acceptance kapıları açık;
otomatik takip tamamlandı sayılmadı.

## 2026-10-15 13:47 TRT — CORE-04c1 seçili ezgi tekrarı ses hazırlama

Yeni DiagnosticMelodyPractice orijinal immutable reference'e bağlı 1–5 ardışık
nota seçimi ve1–3 tekrar taşır; invalid range clamp/reorder edilmez. Renderer
600ms ton,200ms iç gap,1000ms tekrar sessizliği,400ms final tail ile yerel
mono PCM/WAV üretir; max5×3=13.8s/662400 samples48kHz. Raw Hz/oktav/sıra
aynı, tempo/transpozisyon/mix yok. renderDiagnosticMelody full-range single
repeat üzerinden aynı eski samples üretir. Hazırlama yalnız bellekte, player/
file/izin/mic/history/scorer bağlantısı yok; kullanıcı otomatik hata bölümü veya
başarı görmez. Sonraki c2 ayrı owned playback/stop/close/background ve UI işi.

İlk hedefli koşuda yeni testte inferred List<int>→List<double> compile hatası
vardı; typed literal düzeltildi. Hedefli16 geçti (8yeni+8backend). İlk runner
yalnız son test düzenlemesinin formatını işaretledi; format sonrası son runner
exit0: full672 (+8), analyze temiz3.0sn, format193/0. Generated tone/pitch/
rest/PCM codec testleri fiziksel ses, insan holdout veya öğretim pilotu değil.
Piyano dosyası/lisans taşınmadı; 2/3/4 placeholder aynı. Önceki dirty işler
korundu, Agora read-only status/diff temiz; kaynakları değişmedi. Build/device/
API/upload/ödeme/commit/push/deploy yok. CORE-04 ve dış acceptance bitmedi;
otomatik takip tamamlandı sayılmadı.

## 2026-10-15 — Birleştirme ve kalan işler listesi

Otomatik ajanın commit'siz paketleri 83cf533, A+C/UX-02 9bbf15b olarak
commit'lendi; 0875983 ile birleştirildi (home_screen'de SHELL-04e hata
kurtarma yeni Bugün sekmesine taşındı, sekmeler ilk ziyarette kuruluyor).
685 test, analyze/format temiz. Kalan işler CURRENT_ROADMAP'e tek liste
olarak eklendi. Push/deploy yok.

## 2026-10-15 18:45 TRT — UX-02b A+C ezgi ekranı migration

Devralırken git clean, 447c268/0875983 birleşimi ve yeni tek kalan-iş listesi
görüldü. Önceden planlanan CORE-04c2 yerine yeni UI önceliği izlendi; home/
tasarım dalı/diğer ekranlar yeniden yazılmadı. MelodySessionScreen ortak
LessonScaffold/ChunkyButton/StatusPill kullanır. Sentetik/puan yok ve mikrofon
durumu görünür; uzun privacy/8sn/yeniden kalibrasyon bilgisi açık yardımda.
Primary eylem ortam ölçümünden dinle-söyle'ye geçer; finish/cancel yalnız ilgili
phase'te. Controller/DSP/quality/provenance/history değişmedi.

LessonScaffold null progress diagnostic'lerde bar/percent üretmez; natural
scroll column büyük yazıda expanding help/result'ı taşır. Mevcut numeric
lessons aynı pinned/intrinsic layout'ta. apple-design readability/agency/
reduced-motion kontrolüyle mevcut bileşenler yeniden kullanıldı; animasyon
veya bağımlılık eklenmedi. İlk narrow test intrinsic-height taşmasını buldu,
diagnostic doğal scroll ile çözüldü. Yeni testte dark() çağrısı düzeltildi;
close testi asynchronous native/stream cleanup için gerçek-zone microtask'i
bekler, cleanup assertion korunur.

Hedefli12 (8mevcut+4yeni) ve son ortak runner exit0: full689 (+4), analyze
temiz6.7sn, format202/0; diff check temiz. Testler fake/sentetik, fiziksel
voice/device/UXR kabulü değil. CORE-04c2 hâlâ açık, kalan UI migration listesi
güncellendi. Agora read-only status temiz; kaynakları değişmedi. Commit/build/
API/upload/ödeme/push/deploy yok. Tüm dış kabul kapıları geçilmedi; otomatik
takip tamamlandı sayılmadı.

## 2026-10-15 23:45 TRT — UX-02c A+C mikroders okuyucu migration

Mevcut dirty UX-02b korunarak yeni kalan-UI listesi izlendi. MicroLessonScreen
null-progress LessonScaffold/StatusPill/ChunkyButton kullanır; objective,
algı/üretim ve no-mastery görünür; sürüm ve onay sınırı açılır Ders bilgisi'nde.
Beş faz/özgün instruction metinleri aynı; dört practice disabled, alt Geri dön
yalnız route'u kapatır. Player/mic/score/history/completion eklenmedi. apple-design
okunabilirlik/agency/dynamic-type ilkeleri mevcut bileşenlerle uygulandı.

İlk targeted koşularda uzun header320px/1.8× yatay taşma yaptı; kısa Taslak
etiketiyle düzeltildi. AppBar back yerine lesson_close kullanan test navigasyonu
güncellendi (reader+map recovery), disabled/no-write assertions korunur.
Hedefli10 (6mevcut+4yeni) geçti; son ortak runner exit0 full693 (+4), analyze
temiz5.5sn, format202/0; diff check temiz. Yeni testler metin/faz koruma,
metadata/no-unlock, alt dönüş/no mastery ve dark/reduced-motion büyük yazı.
Önceki ezgi migration testleri de full suite'te geçti. Gerçek VoiceOver/TalkBack,
cihaz, eğitimci içerik onayı ve öğretim etkisi doğrulanmadı. Agora read-only
status temiz; kaynakları değişmedi. Build/API/upload/ödeme/commit/push/deploy
yok. Kalan migration/CORE-04c2 ve dış kapılar açık; otomatik takip bitmedi.

## 2026-10-16 05:23 TRT — UX-02d A+C piyano placeholder migration

Mevcut dirty UX-02b/c korunarak kalan migration listesinden ChordPlaceholder
taşındı: null-progress LessonScaffold, Kapalı header, StatusPill, kısa no-audio/
mic/score notice, açılır prerecorded→birer birer response akışı. 2/3/4 kartlarda
altı neutral ChunkyButton onPressed:null; path/nota/rights uydurulmadı.
Katalog _loadForView eager observer aynı Future'ı UI'ya döndürür; loading
error/data'dan önce kontrol edilir, pending retry'da eski hata/düğme yok.
Mounted reload, disposal late failure gözlemi. Katalog schema/import ve
ürün kapıları değişmedi, player/capture/scorer yok.

apple-design readability/control-state/dynamic-type kontrolüyle mevcut
bileşenler kullanıldı; yeni motion/dependency yok. İlk targeted compile
ChunkyButton icon'a eski Icon widget'ını geçirmeyi yakaladı, IconData düzeldi.
Son hedefli10 (5mevcut+5yeni), full698 (+5), runner exit0; analyze temiz9.6sn,
format202/0, diff check temiz. Yeni testler closed shell/help/all disabled,
fast retry/noauto, pending/disposal failure, dark/reduced-motion320px1.8× ve
tap/label guideline, close/no reload. Fake/asset-metadata testleri gerçek
piyano/insan sesi/cihaz veya eğitimci kabulü değildir. Agora read-only status
temiz; kaynakları değişmedi. Build/API/upload/ödeme/commit/push/deploy yok.
Kalan UI, chord içerik/engine/device/EDU/yayın kapıları açık; takip bitmedi.

## 2026-10-16 10:24 TRT — UX-02e A+C yerel veri taşıma

DataTransferScreen null-progress LessonScaffold/StatusPill/ChunkyButton ve
live status'a taşındı. Busy guard export load+clipboard ve import confirmation+
write süresini kapsar; input/iki eylem kilitli. Yeni deneme eski ilgili status'u
temizler; confirmation cancel input/history'yi korur. Platform/MissingPlugin
pano hataları safe mesajdır, false success/private text yok. Export load
bittiğinde disposed ise clipboard yazılmaz. Önceden onaylanmış import leaving
sonrası repository'de bitebilir; cancellation/rollback garantisi verilmez.
LocalDataExport non-string exportedAt önce safe date error verir, cast crash
yok. Schema1, full validation, consent, profile/dedup/conflict/capacity değişmez.

apple-design agency/readability ile ortak UI kullanıldı. İlk targeted compile
Semantics const ve test import sırasını yakaladı; düzeltildi. Hedefli18 geçti
(6yeniwidget+1codec dahil); ilk runner yeni mock testin if braces lint'inde
durdu; düzeltme sonrası runner exit0 full705 (+7), analyze temiz4.4sn,
format202/0, diff check temiz. Pending/double action, pano failure/retry,
late dispose/no clipboard, consent cancel/no write, dark/reduced-motion320px
ve date types regressions. Mock clipboard/storage yalnız kod QA; gerçek
cihazlar arası veri/pano, voice/device/EDU/pilot/yayın kabulü değil. Önceki dirty
işler korundu; Agora read-only status temiz, kaynakları değiştirilmedi.
Build/API/upload/ödeme/commit/push/deploy yok; otomatik takip bitmedi.

## 2026-10-16 16:07 TRT — UX-02f A+C tek ses diagnostic oturumu

Önceki dirty UX-02b/c/d/e korunarak kalan migration listesi izlendi.
SingleToneSessionScreen null-progress LessonScaffold/StatusPill/ChunkyButton;
kısa sentetik/puansız C4 ve canlı phase/kalibrasyon görünür; uzun4sn/privacy
yönergesi açılır yardımda. Calibrate→listen/sing primary yönlendirme; aktif
fazda yeni attempt gizli, responding finish ve aktif cancel korunur. InputLevelMeter
yalnız calibrating/responding + InputLevelSource koşulunda. Yeni attempt
detail expansion'ı temizler. _Step eski görsel kartı kaldırıldı; controller,
quality/route/DSP/diagnostic/scorer toleransı değişmedi. Yeni verdict/puan/
history/mastery/progress yok.

apple-design agency/readability/dynamic-type ilkeleriyle mevcut kontroller
yeniden kullanıldı; yeni motion/dependency yok. İlk mevcut9 hedefli test geçti;
4 regression eklenince targeted13 geçti. Yeni testler noauto permission/help/
noprogress, contextual controls+capture meter+cancel, dark/reduced-motion320px
1.8× permission denial, lesson close pending permission late capture engeli.
Son ortak runner exit0 full709 (+4), analyze temiz6.9sn, format202/0,
diff check temiz. Testler fake/sentetik, fiziksel ses/route/cihaz/öğretim pilotu
kanıtı değildir. Agora read-only status temiz; kaynakları değişmedi. Build,
API/upload/ödeme/commit/push/deploy yok. Kalan UI/CORE-04c2 ve gerçek BENCH/
device/EDU/yayın kapıları açık; otomatik takip tamamlandı sayılmadı.

## 2026-10-16 21:07 TRT — UX-02g A+C günlük plan

Kalan UI migration listesine göre DailyPlanScreen null-progress LessonScaffold,
StatusPill/ChunkyButton'a taşındı. Kısa visible taslak uyarısı + plan_help;
5/12/15 budget selector, restore/save, gerçek valid round counts/free minutes
aynı. Done blok Bir tur daha neutral, pending primary; retention routing ve
exercise dönüşünde refresh/recovery korunur. DailyPlanner/cohort/mastery/
skor rubriği değiştirilmedi; view/close practice history yazmaz, readiness
percentage üretilmez. Shell navigation test AppBar back yerine lesson_close.

apple-design readability/agency/dynamic-type kontrolüyle mevcut bileşenler
yeniden kullanıldı, yeni motion/dependency yok. Mevcut10 plan/recovery testi
geçti; yeni4 ile targeted14 geçti. Yeni testler shell/help/no-mastery-write,
completed retention optional neutral action, dark/reduced-motion320px1.8×
budget15/help/action, close/budget5 preservation. Son runner exit0 full713
(+4), analyze temiz5.3sn, format202/0, diff check temiz. Fake touch/history
testleri gerçek cihaz/öğretim pilotu değildir. Önceki dirty işler korundu;
Agora read-only status temiz, kaynakları değişmedi. Build/API/upload/ödeme/
commit/push/deploy yok. Kalan UI/CORE-04c2 ve dış acceptance kapıları açık;
otomatik takip tamamlandı sayılmadı.

## 2026-10-17 02:18 TRT — UX-02h A+C çalışma geçmişi

Kalan UI listesine göre HistoryScreen kartları StatusPill/DataLabel ve neutral
ChunkyButton ile düzenlendi. Uzun kayıt listesi için lazy ListView/AppBar
korundu; LessonScaffold'a zorlanmadı. Karşılaştırma yardımı açılır, yerel veri
uyarısı ve açık silme onayı aynı. apple-design okunabilirlik/agency/büyük yazı
ilkeleriyle mevcut bileşenler kullanıldı; yeni hareket/dependency yok.

Sunumdaki iki güvenilirlik açığı kapatıldı: beceri artık çakışmasız record cohort
anahtarında; son3 sonuç createdAt sırasından seçilir, depo sırası yeniden
yazılmaz. Perception correct/total ve rhythm missed/extra tür/aralık kontrolü
olmadan trend üretilmez. Desteklenmeyen beceri eksik ritim alanlarından sahte
0→0→0 üretmez; kart detayı da null/bozuk sayaç göstermez. Fast retry Future
hatası erken gözlenir; dispose sonrası clear başlatılmaz. Skorer/rubrik ve
depo şeması aynı; yeni puan/mastery/readiness yok.

Yeni6 regresyon ile hedefli16 geçti: pitch≠rhythm, bozuk/eksik alanlar,
farklı beceri cohort'u, hızlı tekrar hata, dark/reduced-motion320px1.8× yardım/
cancel/geri dön ve kronolojik trend/depo sırası. İlk dar ekran testinde lazy
kartın scroll/layout beklemesi düzeltildi; son hedefli koşum temiz.
Testler yalnız fake depolarda; gerçek kullanıcı kaydı silinmedi. Son runner
exit0 full719 (+6), analyze temiz4.8sn, format202/0, diff check temiz.
Önceki dirty işler korundu; Agora read-only status temiz.
Build/API/upload/ödeme/commit/push/deploy yok. Kalan UI/CORE-04c2 ve dış
kabul kapıları açık; otomatik takip tamamlandı sayılmadı.

## 2026-10-17 13:10 TRT — UX-02i A+C ayarlar ve yerel işlem güvenliği

SettingsScreen aynı Scaffold/AppBar/lazy ListView üzerinde A+C kartları,
StatusPill ve neutral ChunkyButton kullanır. Başlıklar semantic header;
kısa görünür misafir/gizlilik/mikrofon bilgisi, açılır izin-kulaklık ve saklama
rehberleri. Startup cleanup uyarısı açılır alanın dışında görünür. Hedef seçme,
geçmiş/veri taşıma, misafir/abonelik yok ve kanal açıklamaları korundu. Profil
silme yalnız hedef profilini siler, geçmişi değil; hem rehberde hem onayda açık.
apple-design okunabilirlik/agency/büyük yazı ilkeleri mevcut bileşenlerin
kullanımına yön verdi; yeni animasyon/dependency/tema ayarı eklenmedi.

Stateful ekran onay dahil profil silmeyi tek işlemle sınırlar; pending sırada
hedef değiştirme/silme disabled, hata sonrası retry açık. Kopyalama da busy
guard kullanır, önce eski başarı temizlenir ve live status gösterilir. Flutter
OptionalMethodChannel Clipboard.setData eksik platformu sessiz kabul ettiği
için aynı kanal adı ve JSON codec ile required MethodChannel çağrısı yapıldı.
PlatformException/MissingPluginException sabit güvenli metin; rapor içeriği
önceki sanitized LocalErrorLog formatında. Platform yanıtı gerçek pano readback
veya fiziksel cihaz kabulü değildir. Kopya/silme başlamışsa ekranı terk etme
işlemi geri almaz; geç tamamlanmada mounted kontrolü UI erişimini engeller.

Yeni7 widget + mevcut17 shell/error-log testleri hedefli24 geçti. Rehberlerin
salt okunur olması, hata/success/retry, eksik platform, pending double-copy/
dispose, onay/pending delete/failure retry/cancel, route'lar ve dark/reduced-
motion320px1.8× doğrulandı. İlk derlemedeki Semantics const ve kanal testindeki
codec/optional davranışı düzeltildi; son hedefli koşum temiz. Testler fake
depo/platform; gerçek kullanıcı verisi silinmedi. Son runner exit0 full726
(+7), analyze temiz4.5sn, format203/0, diff check temiz. Önceki dirty işler korundu; Agora
read-only status temiz. Build/API/upload/ödeme/commit/push/deploy yok.
Sıradaki UI Ses laboratuvarı ve Tek ses sonuç örnekleri; CORE-04c2 ve gerçek
BENCH/device/EDU/yayın kapıları açık, otomatik takip bitmiş sayılmadı.

## 2026-10-18 19:10 TRT — UX-02j A+C ses laboratuvarı

17 Ekim 18:41 TRT heartbeat'i işlendi; çalışma zamanı clock ile 18 Ekim
olarak doğrulandı. AudioLabScreen null-progress LessonScaffold/StatusPill/
ChunkyButton'a taşındı. Görünür deneysel/puansız ve sentetik C4 açıklaması,
açılır kayıt/gizlilik rehberi; kayıt kalitesi ve deneysel frekans kanıtı ayrı
kartlarda. DataLabel gerçek kayıt metadata'sını gösterir. Active fazlarda
başlat/referans/kalibrasyon gizli; kayıt bitir ve iptal korunur. InputLevelMeter
yalnız recording/calibrating + InputLevelSource, nota/puan anlamı yüklenmez.
Kalibrasyonun mevcut geçici kaydı sildiği, yeni kaydın eskisini değiştirdiği
açık; mikrofon hem kayıt hem ortam ölçümüyle açılır bilgisi düzeltildi.

apple-design okunabilirlik/agency/büyük yazı ilkeleri mevcut bileşenleri
yönlendirdi, yeni animasyon/dependency yok. A11y kılavuzu mercan record tone
üzerinde 3.95 kontrast buldu; yalnız bu ekranın başlat/bitir düğmeleri primary
tona alındı, kontrast kontrolü geçti. Controller/backend/worker, noise/quality/
route/rubrik, iptal epoch ve kalibrasyon politikası aynı. Yeni puan/nota
kararı/history/mastery yok; gerçek cihaz/insan sesi doğrulaması yapılmadı.

Yeni5 + mevcut12 hedefli17 geçti: noauto/help/noprogress, phase/meter/discard,
close sırasında pending izin→late capture yok, dark/reduced-motion320px1.8×
izin reddi→mikrofonsuz referans ve explicit silme→geç worker hatası nötr.
Close testinde asenkron shutdown kuyruğu bir event-loop turu bekletildi.
Testler fake backend/sentetik kaynak, gerçek kullanıcı verisi silinmedi.
Son kalite runner exit0 full731 (+5), analyze temiz7.8sn, format203/0,
diff check temiz. Önceki dirty işler korundu; Agora read-only
status temiz. Build/API/upload/ödeme/commit/push/deploy yok. Kalan UI Tek ses
sonuç örnekleri; ardından CORE-04c2. BENCH/device/EDU/yayın kapıları açık;
otomatik takip tamamlandı sayılmadı.

## 2026-10-18 19:13 TRT — UX-02k A+C tek ses sonuç örnekleri

SingleToneExerciseScreen null-progress LessonScaffold/StatusPill/ChunkyButton
ve DataLabel kullanır. Örnek hedef/yönerge ve sonuçlar açıkça simülasyon;
mikrofon kapalı, kişisel başarı/geçmiş/gelişim değildir. Açılır rehber ses
çalınmadığını/kayıt alınmadığını ve gerçek oturumun ayrı olduğunu açıklar.
Doğru Söyle düğmesi Doğru ses örneği oldu; puanlar örnek etiketiyle kalır.
Invalid metni örnek puanlanmadı, nötr notMeasured; yanlış oktav wrongOctave,
başarı correct ve diğer uyarılar nearMiss tema token'ları. Sabit green/amber
ve renkli zemin kaldırıldı; iki temada kılavuz kontrastı doğrulandı.

_runScenario single-flight guard eski sonucu/hata durumunu temizler; await
sonrası mounted kontrolü, sabit nötr hata ve finally unlock sağlar. Geç hata
UI'ya erişmez; tekrar deneme mümkündür. Skorer/tolerans/senaryo verisi aynı,
gerçek oturum/capture/quality/worker/depo değişmez. apple-design okunabilirlik/
agency/büyük yazı ilkeleri mevcut A+C bileşenlerine yön verdi; yeni hareket
veya dependency yok. Mock test başarısı insan sesi benchmark'ı değildir.

Yeni5 + mevcut19 hedefli24 geçti: noauto/help/noprogress, duplicate pending/
eski success→error→retry, pending close/late error, tüm7 senaryo dark/reduced-
motion320px1.8×, iki temada success/octave/invalid için tap/label/contrast.
Eski noisy/silence testleri büyük düğmelere scroll eder; ilk Semantics const
ve test sonu handle temizliği düzeltildi. Son runner exit0 full736 (+5),
analyze temiz4.3sn, format203/0, diff check temiz. Agora read-only status
temiz, kaynakları değişmedi. Önceki
dirty işler korundu; build/cihaz/API/upload/ödeme/commit/push/deploy yok.
Adı listelenen ekran migration'ları tamamlandı; sırada CORE-04c2. Diğer UX
backlog'u, gerçek BENCH/device/EDU/yayın kapıları açık; otomatik takip bitmedi.

## 2026-10-19 10:12 TRT — CORE-04c2a seçili ezgi oynatma altyapısı

CORE-04c2 önce exclusive player alt paketine ayrıldı; UI c2b'ye kaldı.
DiagnosticMelodyPracticePlayer sadece play/stop/close sunar, capture/permission
API'si yok. MelodyPracticePlayback tek bound reference instance'ını kabul eder;
native mutation kuyruğu hatadan sonra da cleanup'ı çalıştırır. Idle/loading/
playing/stopping/failed/closed, single-flight, epoch ve completion wake ile
pending start/stop/close yarışları korunur. Stop completion callback'ini
beklemez; native start sürüyorsa onun ardından cleanup yapar. Queue başlamadan
iptal play'i atlar. Eski handle hataları gözlenir, geç callback sonuç yayınlamaz.
Cleanup hatası sticky fail-closed; yalnız close kaynağı bırakmayı deneyebilir.

SyntheticMelodyPracticePlayer c1 renderer WAV'ını immutable bytes olarak ayrı
ReferenceClipPlayer'a verir. Capture backend/player paylaşılmaz; existing
SyntheticMelodyBackend ve MelodySession davranışı değişmez. Completion
duyma/hafıza/başarı kanıtı veya attempt sayacı değildir. Skor/history/mastery,
API, kullanıcı kaydı veya yeni ses kaynağı yok. Sınırlı aralık/1–3 tekrar ve
orijinal frekans/sıra/tempo c1 sözleşmesinde. UI, background/focus handler ve
route ownership bağlantısı henüz yapılmadı; bu paket mikrofon oturumuyla
eşzamanlı kullanımın cihazda doğrulandığı iddiası değildir.

Yeni10 coordinator +2 adapter testi ve mevcut26 renderer/session/backend
regresyonu hedefli38 geçti. Noauto, foreign reference, duplicate, queued/pending
start stop, completion late error, playback failure/retry, cleanup fail-closed,
close idempotency ve exact excerpt WAV/immutable bytes testli. Testlerdeki
background senaryosu UI lifecycle olayı değil controller.stop çağrısıdır.
Son runner exit0 full748 (+12), analyze temiz11.3sn, format205/0, diff check
temiz. Önceki dirty işler korundu; Agora read-only status
temiz. Build/cihaz/API/upload/ödeme/commit/push/deploy yok. Sıradaki hazır iş
CORE-04c2b ekran/navigation/lifecycle ve büyük yazı testleri. Gerçek BENCH/
device/EDU/yayın kapıları açık; otomatik takip bitmiş sayılmadı.

## 2026-10-19 15:15 TRT — CORE-04c2b seçili ezgi ekranı ve güvenli devir

MelodyPracticeScreen null-progress A+C shell: başlangıç/bitiş dahil aralığı,
1–3 tekrar, orijinal sıra/Hz görünümü ve açık manual/sentetik/puansız metin.
Kayıt/izin/assessment/repository bağı yok, otomatik play yok. Playback sürerken
seçiciler kilitli; stop/retry ve yardım açık. apple-design okunabilirlik,
agency ve büyük yazı ilkeleri mevcut bileşenleri yönlendirdi. Header büyük
yazıda taşıdığı için kısa Puansız etiketi; dropdown'lar genişliğe uyarlanır.

MelodySessionScreen yalnız canStart ve yeni handoff guard ile geçiş açar.
Session.close tamamlanmadan factory/native child player oluşturulmaz; parent
route pushReplacement ile kaldırılır. Bu kasıtlıdır: dinlemeden dönüş home/
önceki sayfayadır, eski kayıt oturumu devam etmez; metin bunu açıklar. Close
hatası veya pending devirde eski başlat/back devre dışı; stale dispose hiçbir
yeni player/route oluşturmaz. Child route PopScope hem close hem sistem geri
için playback.close'u bekler. Pending native load sonrası close tamamlanana
kadar route bırakılmaz; cleanup hatasında yeniden başlat uyarısı/fail-closed.

WidgetsBinding lifecycle inactive/background durdurur, resume autoplay yapmaz.
Mobilde AudioSession interruption-begin, becomingNoisy ve devicesChanged
dinlenir; monitoring hazır olmadan play kapalıdır. Stream hatası monitoring'i
fail-closed kapatır. Test injection ayrı fake olay stream/player kullanır;
gerçek plugin/route/focus/cihaz doğrulaması değildir. C1/c2a renderer/queue,
mevcut ölçüm rubriği, referencePlays, skor/history/mastery değişmedi. Başarı/
hatalı bölge çıkarımı veya duyma/hafıza kanıtı üretilmez.

Yeni11 + mevcut17 hedefli28 geçti: explicit selection, noauto, locked controls,
lifecycle/focus/monitoring error, pending native start close/late error, system
back/failure lock, safe retry, dark/reduced-motion320px1.8×, parent close before
factory/replacement/failure/disposal ve iki tema a11y. Fake close kuyruğu event
loop bekletilerek test edilir. Son runner exit0 full759 (+11), analyze temiz
3.6sn, format207/0, diff check temiz. Önceki dirty işler
korundu; Agora read-only status temiz. Build/cihaz/API/upload/ödeme/commit/
push/deploy yok. c2 kod/ekran bağlantısı hazır, gerçek playback/device/EDU
ve ürün/yayın kabulü açık. Sıradaki onboarding günlük süre seçimi; otomatik
takip tamamlandı sayılmadı.

## 2026-10-20 — ONB-01 başlangıçta günlük süre seçimi

19 Ekim20:56 TRT heartbeat'i işlendi. GuestOnboardingScreen hedefi draft
tutar; sonra mevcut DailyBudget 5/12/15 seçeneklerini gösterir. Açık kaydet
önce preferences schema1'i, sonra chooseGoal profilini yazar. Süreyi
değiştirmeden devam bütçeyi yazmaz: eski tercih korunur, yoksa mevcut plan
default12. Settings hedef değişimi ve returning profile aynı; yeni şema,
hesap/izin/ses/skor/history/mastery yok. Geri dönüş draft süreyi korur;
yalnız görüntüleme/seçim repository'ye yazmaz.

İki dosya transaction değildir: budget-success/profile-failure halinde süre
kalır ve mesaj bunu açıklar; retry aynı bütçeyi resave etmez. Busy guard iki
continue/back/seçicileri kilitler. Budget await sonrası dispose olmuşsa
profile save başlatılmaz; başlamış dosya yazımı rollback sayılmaz. Hatalar
fixed/safe, skip de hedef kaydı için retry sunar. apple-design agency/
readability/büyük yazı ilkeleri mevcut A+C bileşenlerini yönlendirdi. Selected
AnswerOption fill opaque alphaBlend(theme surface) oldu; diğer state/layout
aynı, iki tema kontrast kılavuzu geçti. Yeni motion/dependency yok.

Yeni9 widget: üç bütçe save-before-goal, skip-preserve, budget failure→skip,
partial profile failure→retry/no-resave, pending double/dispose, system back,
app→gerçek günlük plan seçili5, dark/reduced-motion320px1.8× ve iki tema
a11y. Mevcut18 shell/a11y de doğrulandı; iki eski onboarding testi yeni
confirm/skip adımına uyarlandı, Settings testi aynı. İlk lazy-list testinde
scroll/tall viewport düzeltildi. Son runner exit0 full768 (+9), analyze
temiz3.7sn, format209/0, diff check temiz. Önceki dirty işler korundu;
Agora read-only status temiz. Build/cihaz/API/upload/ödeme/commit/push/deploy
yok. Sıradaki ana sayfa yükleme iskeleti. Gerçek BENCH/device/EDU/yayın
kapıları açık; otomatik takip tamamlandı sayılmadı.

## 2026-10-20 — HOME-01 ana sayfa yükleme ve eski veri koruması

19 Ekim22:59 UTC heartbeat. Home recommendation/path beklerken durağan
iskelet, tek live-region etiketi; dekoratif şekiller semantics dışında.
apple-design okunabilirlik/hareket azaltma ilkeleriyle mevcut tema tokenları
kullanıldı; shimmer, sahte yüzde/seri/süre/skor veya otomatik işlem yok.
FutureBuilder eski veriyi tutabildiğinden d yalnız done/no-error halinde
kullanılır: pending/error sırasında eski seri, beceri yolu ve öneri gizlenir.
Hata açık retry ile toparlanır; repository/planner/skor/yazma aynı.

Yeni4 widget testi: statik semantik/no-write/no-frame; exercise-return refresh
pending→error→retry; repository replacement; iki tema320px1.8× reduced-motion
ve dispose sonrası late error. Hedefli15 geçti. Tam runner exit0 full772
(+4), analyze temiz5.2sn, format209/0; diff check temiz. Önceki dirty işler
korundu. Agora mevcut dirty değişikliklerine dokunulmadı. Build/gerçek cihaz/
API/upload/ödeme/commit/push/deploy yok. Sonraki güvenli iş algı turunda cevap
karşılaştırması ve tekrar dinleme. Gerçek voice/BENCH/device/EDU/yayın
kapıları açık; otomatik takip tamamlandı sayılmadı.

## 2026-10-20 — REVIEW-01a algı sonuçlarında soru bazlı karşılaştırma

Kullanıcının devam talebiyle iki mevcut algı modülüne salt-okunur sekiz
soruluk cevap dökümü eklendi. AnswerComparisonCard başlangıçta kapalı;
bilinen sentetik örnek, seçilen dokunma cevabı ve doğru cevap gösterir.
Doğru/farklı seçim/cevap yok metinle ayrılır. Bu öğrencinin içsel ne duyduğu
veya söylediği hakkında çıkarım değildir; ses kaydı değildir. Ayrıntılar
yalnız mevcut oturumda; schema/controller/skor/retention/history aynı.
Yeni tur eylemi dökümün önünde tutuldu. Yeni ses/autoplay/dependency yok.

apple-design readability/agency/reduced-motion ilkeleri: tema tokenları,
isteğe bağlı disclosure, dar/büyük yazıda alt alta; genişte yan yana.
İlk testte LayoutBuilder intrinsic ölçümü engelledi; Wrap ile değiştirildi.
Shell'de bottom boş olduğunda IntrinsicHeight gerekmiyordu ve açılır içerikte
overflow üretiyordu: bu durumda doğal scroll layout kullanılıyor. Bottom
eylemli soru düzeni ve diagnostic sözleşmesi korundu. Beş yeni widget testi
ve genişletilen iki gerçek ekran akışı hedefli7 geçti; açma/kapama player
çağrısı veya history değişimi üretmiyor. Full runner exit0:777 (+5), analyze
temiz3.5sn, format211/0; diff check temiz. Kod/widget kanıtı, cihaz QA değil.
Önceki dirty işler korundu; Agora kaynaklarına dokunulmadı. Build/cihaz/API/
upload/ödeme/commit/push/deploy yok. REVIEW-01b karşılaştırmalı ses için pending-
load/stop/close/lifecycle güvenceleri sıradaki iş; ana madde açık. Gerçek
voice/BENCH/device/EDU/yayın kapıları açık; tüm geliştirme bitti denmedi.

## 2026-10-20 — GROW-01a, ticari üç referans ve plan eşlemesi

Kullanıcı ticari başarılı üç uygulamanın öne çıkan özelliklerini istedi.
Simply Piano/Simply, Yousician ve Duolingo Music resmî ürün/yardım sayfaları
araştırıldı. Finansal kanıt kapsamı ayrıldı: Simply2020 tarihsel şirket geliri
ikincil haber, Yousician2025 şirket ciro/faaliyet kârı finansal sağlayıcı,
Duolingo2025 SEC toplam gelir/ücretli abone. Bunlar app/modül gelir sıralaması
veya hangi özelliğin daha çok para kazandırdığının kanıtı değil. Kaynak/tarih,
hipotez ve kabul kapıları COMMERCIAL_BENCHMARK_2026-10.md'de. F27/F28 eklendi;
diğer bulgular mevcut backlog işlerine bağlandı, yinelenen modül açılmadı.

Kod: HomeData son7 yerel takvim gününü valid/current-catalog cohort'lardan
üretir; aynı gün tek, düşük doğru da çalışma. Future timestamp (bugünün ilerisi
dahil), invalid/mock/synthetic/unverified/eski/unknown cohort dışarıda. Immutable
gün listesi; RecentPracticeCard tarih+durum metni, tema/Wrap/büyük yazı,
animasyon yok; d yalnız başarılı read'de gösterilir. apple-design readability/
reduced-motion ilkeleri kullanıldı. Veri sayacı aktivite, öğrenme başarısı değil;
streak/planner/scorer/storage/izin/telemetry yok veya aynı.

Yeni4 veri testi +2 iki tema320px1.8× reduced-motion widget; pending regression
genişletildi. İlk invalid fixture puan taşıdığı için sözleşme reddetti; scores
notMeasured yapılarak fixture düzeltildi (ürün guard gevşetilmedi). Full runner
exit0:783 (+6), analyze clean12.8sn, format213/0, diff check clean. Fake/local
kanıt, cihaz/öğrenme/gelir kabulü değil. Agora değiştirilmedi, önceki dirty
işler korundu; build/API/ödeme/upload/commit/push/deploy yok. REVIEW-01b sıradaki
ses işi; GROW-01b hedef/bildirim ve F28 aile işi açık. Tüm ürün bitti denmedi.

## 2026-10-20 — REVIEW-01b karşılaştırmalı sonuç sesi

İki algı sonucu kartında kullanıcı başlatmalı dinle/durdur eklendi; autoplay
yok. Ortak ReviewPlaybackCoordinator stop→load→play kuyruğu, stale pending
başlatmayı geçersiz kılma, son istek kazanır, hata sonrası yeniden deneme ve
close sırasını yönetiyor. Aralık ekranı referans ile dokunarak seçilen dereceyi,
tiz/pes ekranı referans çiftini sentetik üreticiden çalıyor. Review yalnız
bitmiş immutable outcome'u okuyor; skor, plays/retention, history ve mastery
yazmıyor. Arka plan sesi durdurup sonucu koruyor. Route, player close bitmeden
çıkmıyor; close hatası fail-closed açıklamayla ekranda kalıyor.

apple-design kullanıcı iradesi/okunabilirlik ilkeleri: açık eylem, etkin ses
üzerinde Durdur, başka örneğe kesilebilir geçiş, metin durumları; yeni dekoratif
animasyon yok. Yeni4 coordinator +2 route-gate testi; controller ve iki ekran
akışı genişletildi. Hedefli24 ve full791 (+8) geçti; analyze temiz3.2sn,
format216/0, diff check temiz. Fake/sentetik kanıt; gerçek hoparlör/audio-focus,
fiziksel cihaz, VoiceOver/TalkBack ve eğitimci kabulü değil. Agora değişmedi;
build/API/upload/ödeme/commit/push/deploy yok. Sıradaki güvenli iş GROW-01b;
bildirim izni/plugin/cihaz kapıları ve tüm yayın kapıları açık.

## 2026-10-20 — GROW-01b gönüllü son 7 gün hedefi

Ana sayfadaki son7 gün kartına hedef yok veya 2/3/4/5 çalışma günü seçimi
eklendi. İlerleme GROW-01a'nın aynı geçerli/desteklenen cohort günlerinden gelir;
düşük doğru çalışmadır, demo/invalid/future/unknown değildir. Metin hedefin seri,
beceri puanı veya sınav sonucu olmadığını, ceza olmadığını ve her an kapatılıp
değiştirilebildiğini açıklar. Save single-flight; hata önceki hedefi korur ve
özel hata ayrıntısı göstermez.

Yerel tercih schema v2 günlük süre + nullable hedef taşır; strict v1 günlük
süre migration'ı var. Günlük süre/hedef bağımsız ve eşzamanlı kayıtlarda
serialized read-modify-write ile birbirini ezmez. Yeni2 storage +2 widget testi;
hedefli24 ve full795 (+4) geçti, analyze temiz2.9sn, format217/0, diff temiz.
Bildirim/izin/plugin/network/hesap/telemetry/ödül/ödeme eklenmedi; native
hatırlatma ve cihaz QA açık. Agora değişmedi; build/commit/push/deploy yok.

## 2026-10-20 — RETRY-01a yanlışlara hedefli kısa tur

Tiz/pes ve hareketli-do sonuçlarına “Hataları hedefli çalış” eylemi eklendi.
Yalnız önceki tam turdaki yanlış maddeler, aynı frekans/tonik ve sırayla kısa
rehberli tura taşınır; normal dinle→cevap→anlık açıklama kullanılır. Kullanıcı
başlatır, yeni tam tur ayrıca kalır. Ekran Tekrar etiketi ve bunun geçmiş,
beceri/ustalık veya sınav sonucu olmadığını açıkça gösterir; kısa turda 7/8
ölçütü gibi anlamsız tam-tur metni gösterilmez.

Controller guided turda retention'ı kapatır ve history yazmaz. Domain round
`guided` işaretlidir; `toResult` StateError ile fail-closed, böylece ilerideki
bir caller bu turu kanıta çeviremez. Yeni2 controller testi; iki dar/büyük-yazı
ekran akışı genişletildi, pitch hedefli tur uçtan uca tamamlandı. Hedefli15,
full797 (+2), analyze/format ve diff temiz. Sentetik/fake kanıt; cihaz/EDU değil.
Agora değişmedi; build/commit/push/deploy yok. Sırada ritim/ezgi segment bağı.

## 2026-10-20 — RETRY-01b ritim hata kesiti

Ritim sonucunda erken/geç/eksik/fazla olay varsa “Zor bölümü çalış” eylemi
sunulur. İlk hata, özgün desendeki komşu referans vuruşlarıyla kısa kesite
dönüşür; fazla dokunuş bir sonraki beklenen vuruşa bağlanır. Yerel saat sıfıra
alınır, aralık ve sıra değişmez. Kesit “Hedefli tekrar” ve puansız olarak
gösterilir; tam desene dönüş açıktır. Guided sonuç history/next-step'e yazılmaz,
`toResult` da fail-closed reddeder. Yeni2 domain +1 controller testi, mevcut
320px/1.8× ekran yolu genişletildi. Full800, analyze/format/diff temiz.
Sentetik klik/fake player; fiziksel zamanlama, öğrenme ve EDU kanıtı değildir.
Ezgi segmenti açık; Agora değişmedi, commit/push/deploy yok.

## 2026-10-20 — REM-01a hatırlatma sözleşmesi

Günlük saat modeli ve uygulama katmanı izin/schedule/cancel portu eklendi.
Coordinator explicit opt-in dışında izin istemez, aynı anda tek işlem yürütür,
native schedule/cancel doğrulanmadan tercihi değiştirmez. Depolama yazımı native
işlemden sonra düşerse önceki planı yeniden kurmayı veya yeni planı iptal etmeyi
dener; hiçbir durumda sahte başarı dönmez. Tercih belgesi v3'e çıktı, exact v1
ve v2 migration korundu; bütçe/hedef/hatırlatma bağımsız ve seri yazılır.
Üretim fallback unavailable: plugin/izin/UI/alarm yok. Yeni7 coordinator +1
storage; full808, analyze temiz, format219/0, diff temiz. Agora değişmedi;
commit/push/deploy yok.

## 2026-10-21 — REM-01b hatırlatma ayarları kabuğu

Ayarlar ekranına çalışma hatırlatması kartı eklendi. Adapter varsa kullanıcı
saat seçip açıkça etkinleştirir, değiştirebilir veya kapatabilir; izin reddi,
pending ve hata durumları başarıdan ayrıdır. Üretimde REM-01a unavailable
adapter kullanıldığı için kart “Kullanılamıyor” der, izin istemez ve eylem
göstermez. Fake adapter ile enable/disable/denied ve koyu 320px/1.8× testlendi.
Yeni4; full812, analyze temiz, format221/0, diff temiz. Gerçek plugin/alarm/
izin/cihaz doğrulaması ve titreşim ayarı açık; Agora/commit/push/deploy yok.

## 2026-10-21 — HAPTIC-01 dokunuş geri bildirimi tercihi

Ayarlar ekranına varsayılan açık, yerel saklanan “Dokunuş geri bildirimi”
anahtarı eklendi. Tercih belgesi v4'e çıktı; exact v3 migration yeni alanı açık
başlatır. Ortak inherited notifier mevcut `HapticFeedback` kullanan genel
buton, cevap seçeneği, beceri yolu ve ritim dokunma yollarını kapatabilir.
Değişiklik önce diske yazılır, sonra uygulama geneline yayınlanır; yazma
hatasında önceki değer korunur ve hata görünür. Platform kanal testi kapalıyken
vibration çağrısı olmadığını, açıkken geri geldiğini doğrular. Yeni3; full815,
analyze temiz, format222/0, diff temiz. Bu fiziksel cihaz titreşim testi değildir;
native hatırlatma plugin/alarm/izin/teslimat kapısı açık. Agora/commit/push/
deploy yok.

## 2026-10-21 — REM-01c native günlük hatırlatma adapter'ı

REM-01a/b sözleşmesi gerçek Android/iOS yerel bildirim adapter'ına bağlandı.
`flutter_local_notifications` 22.3.2, `flutter_timezone` 5.1.1 ve `timezone`
0.11.2 sabitlendi. Başlatma izin istemez; yalnız kullanıcının “Saat seç ve aç”
eylemi Android 13+/iOS iznini ister. Cihaz IANA bölgesiyle bir sonraki yerel
saat hesaplanır ve günlük tekrar kurulur. Android exact-alarm izni istenmez;
`inexactAllowWhileIdle`, reboot receiver, desugaring ve tek beyaz durum ikonu
kullanılır. iOS bildirim merkezi delegate'i bağlıdır. Ret halinde kullanıcı
uygulamanın bildirim ayarlarını doğrudan açabilir. Coordinator'ın native işlem
sonrası persist/rollback sınırı değişmedi.

Yeni4 driver/zaman testi +1 coordinator recovery testi; ret widget akışı
ayarlar eylemiyle genişletildi. Full820, analyze temiz, format224/0, diff temiz.
Android debug APK 236,7 sn ve iOS simulator debug build 26,2 sn içinde geçti.
Simulator/build gerçek bildirim teslimatı değildir: fiziksel izin ekranı,
seçilen saatte teslimat, reboot/DST ve OEM pil kısıtı iOS/Android cihazda açık.
Push/sunucu/telemetry eklenmedi; Agora/commit/push/deploy yok.

## 2026-10-21 — SHELL-02 mikrofon izin kurtarma

Tek ses, kısa ezgi ve ses laboratuvarında gerçek izin reddi görüldüğünde ortak
“Mikrofon ayarlarını aç” kartı bağlandı. Kart ekran girişinde izin istemez veya
ayar açmaz; eylem kullanıcı dokunuşuyla çalışır, eşzamanlı ikinci çağrıyı
engeller ve platform false/exception sonucunu dürüst hata metnine çevirir.
Kayıt izni hâlâ mevcut record backend tarafından, yalnız kayıt/kalibrasyon
eyleminde istenir. Android pasif status okuması bütün kalıcı retleri güvenilir
ayıramadığı için ayar kurtarması yalnız gerçekleşmiş ret sonrasında sunulur.

MIT `permission_handler` 12.0.3 eklendi. 13.0.2 Android compileSdk37 istediği,
proje compileSdk36 ve AGP9.0.1 kullandığı için build ile uyumlu 12.0.3'e
sabitlendi; iOS SPM mikrofon anahtarını mevcut `Info.plist`ten algılar. Yeni4
widget testi; üç ekranın ret regresyonları genişletildi. Full824, analyze temiz,
format228/0; Android debug APK ve iOS simulator debug build başarılı. Fiziksel
izin diyaloğu, kalıcı ret, OS ayar açılışı ve uygulamaya dönüş test edilmedi.
Agora/commit/push/deploy yok; kirli çalışma ağacı korundu.

## 2026-10-22 — SHELL-03a dürüst başlangıç kontrolü

Yeni öğrencinin Bugün ekranına isteğe bağlı “Başlangıç kontrolü” kartı eklendi.
Akış yalnız mevcut deterministik/dokunma kanıtlı üç turu kullanır: 200 cent
tiz/pes, düzenli dörtlük puls ve ilk hareketli-do derece turu. Her tur mevcut
egzersiz ekranını ve yerel history kaydını kullanır; dönüşte durum yeniden
okunur. Geçersiz kanıt önce yeniden denenir, denenmemiş tur sonra gelir; üçü de
geçerliyse ilk zayıf tur pratik odağı olur. Güçlü tek tur mastery veya kalıcılık
sayılmaz.

Ses üretimi, ezgi, çok sesli duyma ve eğitimci gözlemi gerektiren tüm rota
becerileri “henüz ölçülemiyor” sayılır. Akış toplu yüzde, başlangıç seviyesi,
konservatuvar kabulü veya sınava hazır oluş üretmez. History hatasında eski
öneri gösterilmez; açık retry vardır. Yeni4 domain +3 ekran +1 home entegrasyon
testi; full832, analyze temiz, format233/0. Fiziksel cihaz/öğrenci testi ve
eğitimci seviye bantları yapılmadı. Agora/commit/push/deploy yok.

## 2026-10-22 — SHELL-04f güvenli çalışmaya dönüş

Bugün ekranı desteklenen güncel kohortlardan en son tamamlanmış yerel denemeyi
bulup “Son çalışmaya dön” kartında gösterir. Açık eylem aynı egzersizin yeni
turunu açar; yarım soru, player, ses veya mikrofon oturumu restore edilmez ve
otomatik başlatılmaz. Geçersiz güncel sonuç yeniden denenebilir; gelecek tarih,
eski içerik ve bilinmeyen analizör kanıtı hedef olamaz. Boş geçmişte kart yoktur.

Yeni4 domain +2 home entegrasyon testi; `dart tool/quality_check.dart` exit0:
full838, analyze temiz, format236/0. Native/audio bağımlılığı değişmediğinden
build tekrarlanmadı; fiziksel cihaz/offline acceptance açık. Agora/commit/push/
deploy yok; kirli kullanıcı/ajan ağacı korundu.

## 2026-10-22 — F06a hata sonrası isteğe bağlı kavram tekrarı

Tiz/pes ve ritim sonuçlarında hata varsa kullanıcı ilgili mevcut mikroders metin
taslağını açabilir. Eylem sonucu değiştirmez, otomatik ses/mikrofon başlatmaz ve
ders okuması history, skor, mastery veya sonraki adıma yazılmaz. Tiz/pes akışı
aynı kayıt nesnesini koruduğunu ve player çağrısı eklemediğini; ritim akışı da
ders girişinde playback olmadığını doğrular.

Mevcut iki widget akışı genişletildi; `dart tool/quality_check.dart` exit0:
full838, analyze temiz, format236/0. Bu F06'nın yalnız güvenli bağlantı alt
paketidir: metinler geliştirici taslağı, onaylı ses/eğitmen örneği ve öğretim
pilot ölçümü yok. Native/audio bağımlılığı değişmedi; build tekrarlanmadı.
Agora/commit/push/deploy yok.

## 2026-10-22 — F06b tonik/derece kavram tekrarı

Mevcut mikroders kataloğuna hareketli-do “Tonik ve derece” metin taslağı,
eksiksiz beş faz ve bilinçli boş örnek yuvalarıyla eklendi. Hatalı derece turu
isteğe bağlı olarak bu okuyucuyu açar. Aynı `ExerciseResult` ve player çağrı
sayısı korunur; okuma skor/mastery/history veya sonraki adım değildir.

Catalog ve strict codec regresyonlarıyla interval uçtan uca akışı geçti;
`dart tool/quality_check.dart` exit0: full838, analyze temiz, format236/0.
Metin eğitimci onaylı değildir; ses örnekleri, gerçek öğretim etkisi ve öğrenci
pilot kapıları açıktır. Native/audio bağımlılığı değişmedi, build tekrarlanmadı;
Agora/commit/push/deploy yok.

## 2026-10-22 — GROW-01c haftalık çalışma özeti

Gelişim ekranına seçili hedef rotası ve güncel ölçüm kohortlarıyla sınırlı,
yerel takvim günlerine göre hesaplanan haftalık çalışma özeti eklendi. Son yedi
gün; önceki yedi günle yalnız geçerli tur hacmi açısından karşılaştırılır.
Çalışılan gün, egzersiz bazlı geçerli tur ve tamamlanmamış ölçüm ayrı gösterilir;
gelecek tarihli, eski kohortlu veya bilinmeyen kanıt yok sayılır. Boş geçmişte
ilerleme uydurulmaz. Arayüz bunun beceri artışı, hazır oluş veya sınav başarısı
puanı olmadığını açıkça söyler.

Yeni5 domain +1 widget testi eklendi. `dart tool/quality_check.dart` exit0:
full844, analyze temiz, format238/0. Native/audio bağımlılığı değişmediğinden
build tekrarlanmadı. Gerçek cihaz, kullanıcı dili kabulü ve öğretim etkisi
doğrulaması açıktır. Agora/commit/push/deploy yok; kirli kullanıcı/ajan ağacı
korundu.

## 2026-10-23 — RETRY-01c deneysel ezgi aday bölümü

Puansız kısa ezgi oturumu, kalite kapısından geçen diagnostic frekans
segmentlerini mevcut sıralı pitch aligner ile referans frekanslarına bağladı.
İlk farklı referans için önceki bağlamı koruyan iki seslik sentetik dinleme
seçimi üretilir. Kullanıcı eylemiyle kayıt oturumu güvenle kapanır, ayrı player
açılır ve seçim iki tekrar olarak önceden doldurulur; otomatik oynatma yoktur.
Temiz veya yalnız ekstra aday içeren karşılaştırma hedef uydurmaz.

Bu akış skor, ExerciseResult, history, mastery, retention veya hafıza sonucu
üretmez. Segment/VAD ve insan sesi doğrulanmadığından arayüz “hata” yerine
“deneysel aday bölüm” der. Yeni2 suggestion +1 practice widget +1 uçtan uca
session→practice testi; mevcut session testi alignment sınırını da doğrular.
`dart tool/quality_check.dart` exit0: full848, analyze temiz, format238/0.
Native bağımlılık değişmedi; build tekrarlanmadı. Gerçek cihaz playback,
BENCH/VAD ve eğitimci kabulü açık. Agora/commit/push/deploy yok.

## 2026-10-23 — DATA-03b atomik toplu sonuç içe aktarma

`ResultHistoryRepository` ortak `recordAll` sözleşmesi kazandı. Bellek ve dosya
adapter'ları bütün giriş grubunu aynı attempt-id duplicate/conflict/kapasite
kurallarıyla önce planlar. Dosya adapter'ı kaydedilecek sonuçları tek
`JsonFileStore` temp+rename işlemiyle uygular; depolama yazımı başarısızsa eski
belge korunur ve batch'in kısmi öneki görünmez. Kapasiteye sığmayan öğeler yine
açık `storageFull` sayılır; sessiz silme yapılmaz.

Pano içe aktarma artık bu batch yolunu kullanır. UI depolama hatasında önceki
“eklenenler korunur” belirsizliği yerine bu gruptan hiçbir sonucun eklenmediğini
söyler. Yeni2 memory/file parametrik batch +1 file failure +1 widget failure
testi; mevcut import raporu regresyonu geçti. `dart tool/quality_check.dart`
exit0: full852, analyze temiz, format238/0. Ses/native bağımlılığı değişmedi,
build tekrarlanmadı. Gerçek cihaz panosu, hesap/outbox/backend/senkron ve consent
açıktır; Agora/commit/push/deploy yok.

## 2026-10-23 — SHELL-04g ana ekran ön plan yenilemesi

Today consumer'ı Flutter lifecycle gözlemcisine bağlandı. Yalnız
`paused`/`hidden`/`detached` sonrasındaki ilk `resumed` yerel geçmişi yeniden
okur; izin paneli gibi `inactive` kesintisi ve ardışık `resumed` olayları yeni
okuma üretmez. Yenileme beklerken önceki öneri ve beceri yolu gizlenir; hiçbir
egzersiz, player veya mikrofon otomatik başlatılmaz.

İki widget testi tek-yenileme/idempotency ile stale önerinin bekleme boyunca
gizlenmesini doğruladı. `dart tool/quality_check.dart` exit0: full854, analyze
temiz, format238/0. Native/audio bağımlılığı değişmedi; build tekrarlanmadı.
Fiziksel iOS/Android lifecycle/offline kabulü açıktır; commit/push/deploy yok.

## 2026-10-23 — SHELL-04h ortak yerel consumer yenilemesi

SHELL-04g lifecycle sınırı ortak `ForegroundRefreshState` tabanına taşındı ve
Today'e ek olarak günlük plan, beceri haritası ve çalışma geçmişine uygulandı.
Yardımcı yalnız gerçek arka plan işaretinden sonraki ilk `resumed` olayında
ekranın yerel read future'ını değiştirir; `inactive`, yinelenen `resumed`, rota,
yazma, player ve mikrofon davranışı üretmez. Her consumer kendi mevcut
fail-closed loading görünümünü kullanır; stale plan/rapor/geçmiş eyleme açık
kalmaz.

Plan, harita ve geçmiş için üç yeni widget regresyonu eklendi; Today'in iki
önceki lifecycle testi ortak tabanı doğrulamaya devam ediyor.
`dart tool/quality_check.dart` exit0: full857, analyze temiz, format239/0.
Native/audio bağımlılığı değişmedi; build tekrarlanmadı. Fiziksel cihaz ve
offline depolama kabulü açık; commit/push/deploy yok.

## 2026-10-24 — SHELL-04i bağımlılık değişimi güvenliği

Günlük plan, beceri haritası ve çalışma geçmişi `didUpdateWidget` sınırında
repository/hedef/tercih değişimini algılıyor. Yeni dependency verildiğinde eski
projection görünür tutulmadan mevcut fail-closed loading future'ı kurulur.
Plan tercih repository'si değişirse önceki cihaz bütçesi taşınmaz; varsayılan
değerden yeni repository tercihi yeniden okunur. Yazma, silme, rota veya medya
başlatma eklenmedi.

Üç widget testi, yüklemesi bekleyen yeni repository karşısında eski plan,
beceri raporu ve denemelerin görünmediğini doğruladı.
`dart tool/quality_check.dart` exit0: full860, analyze temiz, format239/0.
Native/audio bağımlılığı değişmedi; build tekrarlanmadı. Bu hesap/sync kanıtı
değildir; fiziksel cihaz/offline kabulü açık, commit/push/deploy yok.

## 2026-10-24 — DATA-03c taşınabilir çalışma tercihleri

Yerel pano export şeması v2 oldu. Günlük çalışma süresi ve gönüllü haftalık
hedef, strict `PortablePracticePreferences` alanıyla dışa/içe aktarılır; v1
belgeleri preferences olmadan okunmaya devam eder. Hatırlatma saati/bildirim
izni ve titreşim cihaz bağlamına ait olduğundan belgeye girmez. File preference
adapter'ı iki taşınabilir alanı tek atomik update ile uygular ve cihaz-özel
alanları korur.

Sonuç batch'i önce mevcut DATA-03b atomik sınırından geçer, ardından tercihler
ayrı store'a yazılır. İkinci yazım düşerse UI sonuçların işlendiğini ama
tercihlerin kaydedilemediğini açıkça söyler; tüm belge için sahte atomiklik
iddiası yoktur. Yeni1 codec/migration +1 file preservation +1 widget uçtan uca
testi; `dart tool/quality_check.dart` exit0: full863, analyze temiz,
format239/0. Ses/native bağımlılığı değişmedi, build tekrarlanmadı. Gerçek iki
cihaz pano, hesap/outbox/backend/sync açık; commit/push/deploy yok.

## 2026-10-25 — DATA-03d çalışan görünümde tercih yenilemesi

Başarılı taşınabilir tercih yazımı artık app-scope revision sinyali yayınlıyor.
Bugün consumer'ı günlük süre ve haftalık hedefi yeniden okuyor; Home widget'ı,
Navigator ve seçili alt sekme değiştirilmediği için kullanıcı bağlamı korunuyor.
Her okuma generation ile kapılı: import öncesi başlamış yavaş bir okuma yeni
değerleri sonradan ezemez. Başarısız tercih yazımı revision yayınlamaz.

Mevcut import testi callback'in tam bir kez çalıştığını doğruluyor; yeni widget
testi 5→15 dakika ve 2→4 gün değişimini, Pratik sekmesinin import revision'ında
seçili kalmasını kapsıyor. `dart tool/quality_check.dart` exit0: full864,
analyze temiz, format239/0. Native/audio bağımlılığı değişmedi, build
tekrarlanmadı. Gerçek iki cihaz pano, fiziksel lifecycle, hesap/backend/sync
açık; commit/push/deploy yok.

## 2026-10-25 — SHELL-04j Today tercih kaynağı değişimi

Today yalnız revision sayısını değil `PracticePreferencesRepository` kimliğini
de dependency olarak izliyor. AppServices altında store aynı revision ile
değiştirildiğinde günlük süre ve haftalık hedef yeni kaynaktan yeniden okunur.
Kaynak kaldırılırsa güvenli 12 dakika/null hedef varsayılanına döner. Her kaynak
değişimi generation artırdığı için eski store'un geç daily/weekly future'ları
yeni projection'ı değiştiremez.

Yeni widget testi eski store okumalarını bekletiyor, yeni store'u bağlıyor ve
15 dakika/4 gün görünümünü doğruladıktan sonra eski 5 dakika/2 gün sonuçlarını
tamamlayarak görünümün geri düşmediğini kanıtlıyor. `dart tool/quality_check.dart`
exit0: full865, analyze temiz, format239/0. Native/audio değişmedi; gerçek
cihaz/offline, hesap/sync kabulü açık; commit/push/deploy yok.

## 2026-10-25 — SHELL-04k bekleyen tercih yazımı izolasyonu

Haftalık hedef kaydı artık başladığı preference store ve load generation ile
bağlıdır. Store değiştiğinde eski pending göstergesi/hata temizlenir ve yeni
kaynak okunur. Eski save daha sonra başarıyla veya hatayla tamamlansa bile yeni
store'un seçimini, loading durumunu ya da hata metnini yayınlayamaz; depolar
arasında iptal/senkron taklidi yapılmaz.

Yeni adversarial widget testi eski store save'ini bekletip yeni store'un 4 gün
hedefini bağlar, ardından eski save'i kontrollü hatayla tamamlar; yeni seçim ve
nötr hata durumu korunur. Disk alanı sınırı nedeniyle yalnız üretilmiş Flutter
build/cache çıktıları `flutter clean` ile temizlendi ve kilitli bağımlılıklar
yeniden kuruldu; kaynak/kullanıcı dosyası silinmedi. `dart tool/quality_check.dart`
exit0: full866, analyze temiz, format239/0. Gerçek cihaz/offline ve hesap/sync
kabulü açık; commit/push/deploy yok.

## 2026-10-25 — SHELL-04l yeni tercih kaynağı bekleme sınırı

Today, `PracticePreferencesRepository` kimliği değiştiği anda önceki kaynağın
günlük bütçesini ve haftalık hedefini artık yeni kullanıcı/projection verisi
gibi göstermiyor. Yeni store okumaları tamamlanana kadar güvenli 12 dakika ve
hedefsiz yerel varsayılan kullanılıyor; aynı store içindeki revision yenilemesi
bu sıfırlamayı yapmadığı için import sırasında gereksiz titreşim oluşmuyor.

Yeni adversarial widget testi önce 5 dakika/2 gün değerlerini gösteriyor, sonra
okumaları bekleyen yeni store'u bağlayıp eski değerlerin hemen kaybolduğunu ve
yeni 15 dakika/4 gün tamamlandığında yayınlandığını kanıtlıyor. Geç eski okumalar
generation kapısında kalmaya devam ediyor. Hedefli 6 test ve sınırlı
paralellikle tam 867 test geçti; analyze temiz, format239/0. Varsayılan yüksek
paralellikteki ilk full-suite koşusu kaynak baskısı altında var olan zamanlama
testlerini düşürdü; `--concurrency=4` tam suite exit0 verdi. Gerçek
cihaz/offline ve hesap/sync kabulü açık; commit/push/deploy yok.

## 2026-10-26 — SHELL-04m tercih okuma hatası kabul matrisi

Yeni preference store bağlandıktan sonra alan okumalarının birbirinden bağımsız
ve fail-closed kaldığı adversarial widget testiyle sabitlendi. Eski store önce
5 dakika/2 gün gösteriyor; yeni store'da günlük bütçe 15 dakika olarak gelirken
haftalık hedef okuması kontrollü hata veriyor. UI 15 dakikayı yayınlıyor, eski
2 günlük hedefi geri getirmiyor, yeni bir hedef uydurmuyor ve async hatayı
widget katmanına sızdırmadan nötr “güvenli varsayılanlar kullanılıyor” uyarısı
gösteriyor. Uyarı yalnız güncel load generation'ından yayınlanabiliyor.

Hedefli 7 test ve sınırlı paralellikle tam 868 test geçti; analyze temiz,
format239/0. Audio/native bağımlılığı eklenmedi; mevcut fail-closed sözleşmenin
hata kolu görünür ve testli hale getirildi. Gerçek
cihaz/offline ve hesap/sync kabulü açık; commit/push/deploy yok.

## 2026-10-26 — SHELL-04n tercih okuma retry recovery

Today'deki güncel tercih okuma uyarısı artık açık “Tercihleri yeniden yükle”
eylemi sunuyor. Otomatik ağ/arka plan retry yapılmıyor. Kullanıcı eylemi bağlı
repository için yeni load generation başlatıyor; eski değerleri geri getirmiyor
ve başka store'a yazmıyor. Başarılı tekrar okumada yeni haftalık hedef görünür,
uyarı ve retry eylemi kalkar. Haftalık hedef save hatası aynı görünür hata
alanını kullanmaya devam eder ancak read-retry eylemi sunmaz.

Yeni widget testi ilk yeni-store hedef okumasını düşürüp retry eylemini
doğruluyor; ikinci okumada 4 günlük hedefin yayınlandığını ve uyarının
temizlendiğini kanıtlıyor. Hedefli 10 test ve sınırlı paralellikle tam 869 test
geçti; analyze temiz, format239/0. Audio/native bağımlılığı değişmedi. Gerçek
cihaz/offline ve hesap/sync kabulü açık; commit/push/deploy yok.

## 2026-10-26 — SHELL-04o tercih yükleme/yazma kapısı

Today preference okumaları artık ortak ve generation-bound bir pending durumu
taşıyor. Yeni repository veya açık retry iki bağımsız alan okumasını başlatıyor;
ikisi de tamamlanana kadar haftalık hedef chip'leri pasif ve “Haftalık hedef
yükleniyor…” durumu görünür. `_setWeeklyGoal` da UI dışı çağrı ihtimaline karşı
aynı kapıyı denetliyor. Okumalar başarı veya görünür hata ile sonuçlanınca kapı
açılıyor; eski generation tamamlamaları yeni görünümü değiştiremiyor.

Mevcut replacement-store testi pending durumda chip'in kapalı olduğunu ve yeni
15 dakika/4 gün değerleri geldikten sonra tekrar açıldığını doğrulayacak biçimde
güçlendirildi. Hedefli 10 ve tam 869 test geçti; analyze temiz, format239/0.
Audio/native bağımlılığı değişmedi. Gerçek cihaz/offline ve hesap/sync kabulü
açık; commit/push/deploy yok.

## 2026-10-26 — REL-08a sınırlı paralel ortak kalite kapısı

Önceki tam suite koşularında makinenin varsayılan yüksek paralelliği altında
var olan zamanlama testleri kaynak baskısıyla kararsızlaşabildiği için ortak
`dart tool/quality_check.dart` test adımı artık açıkça `--concurrency 4`
kullanıyor. CLI planı ve varsayılan argv testi bu sınırı doğruluyor; fetch,
build, upload, deploy veya hosted CI davranışı eklenmedi.

Hedefli runner testleri 10/10 geçti. Ardından ortak kalite komutu baştan sona
exit0 verdi: format239/0, analyze temiz, full869. Bu yalnız yerel kod kapısıdır;
gerçek cihaz, mikrofon/insan sesi, eğitimci pilotu ve mağaza kabulü açık.
Commit/push/deploy yok.

## 2026-10-26 — UI-01b iOS koyu ve renklendirilmiş ikon varyantları

Mevcut Resonia nota/dalga işareti değiştirilmeden ikon üreticisi iOS modern
tek-boyut asset catalog'una geçirildi. Varsayılan 1024 px kaynak opak; koyu
varyant Apple'ın sistem arka planı için saydam ve marka sarısı vurgulu;
renklendirilmiş varyant saydam gri tonlu işaret olarak üretiliyor. Artık
atanmayan eski iPhone/iPad boyut dosyaları kaldırıldı; Xcode bunları 1024 px
kaynaktan üretir. Silinen dosyalar üretilmiş eski varyantlardı, git geçmişinden
geri alınabilir.

Dört asset testi catalog slotlarını/dosyalarını, boyutları, varsayılan alfa,
koyu/tinted saydamlığını ve tinted gri ton sözleşmesini doğruluyor. Xcode 27
`actool` iPhone+iPad simulator catalog'unu uyarısız derledi. Ortak kalite
kapısı exit0: full873, analyze temiz, format240/0. Tam simulator build bilinen
Flutter `debug_unpack_ios` lipo yanlış-negatifiyle ikon derlemesinden önce
durdu; fiziksel iOS, sistem tint görünümü ve mağaza tasarım kabulü açık.
Commit/push/deploy yok.

## 2026-10-27 — CONS-01a incelenmiş piyano kayıt manifesti

Kullanıcının ileride ekleyeceği hazır 2/3/4 sesli gerçek piyano WAV'ları için
uygulama akışından bağımsız strict domain manifesti eklendi. Sözleşme exact
schema/kind/codec/source alanları; 2/3/4 ile eşleşen tek klasörlü portable yol;
aynı sayıda farklı ve alttan üste MIDI hedefi; SHA-256; mono/stereo, 8–48 kHz,
100 ms–10 sn metadata bütçesi; hak ve ayrı nota etiketi inceleme referansı
zorunlu tutuyor. Kimlik/yol/hash tekrarları ve bilinmeyen alan/tip coercion
reddediliyor. Liste ve nota hedefleri immutable snapshot.

10 yeni test round-trip, immutability, cardinality/range/order, traversal ve
yanlış klasör, hash/review alanları, audio bounds, duplicate, exact schema ve
bozuk tip/boş-aşırı manifest kollarını kapsıyor. Hedefli test ve analyze temiz.
Gerçek WAV, byte/header/hash adapter'ı, akort/nota/hak doğrulaması, player,
mikrofon, skor ve UI açılmadı; placeholder kapalı. Ortak kalite kapısı exit0:
full883, analyze temiz, format242/0. Commit/push/deploy yok.

## 2026-10-27 — CONS-01b salt-okunur piyano WAV loader

CONS-01a manifest girişlerini açıkça seçilmiş yerel kökten okuyan güvenli
adapter eklendi. Kök/yol tipi, ara ve final symlink, kök dışına kaçış, byte
bütçesi ve okuma boyunca uzunluk değişimi fail-closed. Hash eşleşmesinden sonra
bounded RIFF chunk parser yalnız PCM16 mono/stereo kabul ediyor; gerçek sample
rate, channel ve frame sayısı manifestle exact karşılaştırılıyor. Sonuç daha
sonraki player için defensive byte kopyası sunuyor, kendisi oynatma yapmıyor.

12 yeni test mono/stereo başarı, defensive copy, eksik kök/dosya, hash,
header metadata mismatch, bozuk RIFF/format/truncation, byte budget, symlink,
directory masquerade, sequential manifest failure ve özel path sızıntısını
kapsıyor. Hedefli12/full895 geçti; analyze temiz, format244/0. Tüm WAV'lar test
tarafından sentetik sıfır PCM olarak geçici klasörde üretildi; gerçek piyano,
nota/tını/hak, cihaz/player/UI/skor kanıtı değildir. Commit/push/deploy yok.

## 2026-10-27 — CONS-01c piyano referans oturum kapısı

Bir reviewed 2/3/4 ses kaydı ve loader'dan gelecek defensive WAV snapshot'ı
için `ChordReferenceSession` eklendi. Otomatik çalma yok; explicit referans
isteği native olarak tamamen bitip player stop ve bounded recall delay
tamamlanmadan sıralı öğrenci cevabı hazır olmaz. Duplicate play bastırılıyor;
stop, background ve route/focus kesintisi epoch'u iptal ederek geç completion'ı
etkisiz bırakıyor ve otomatik resume yapmıyor. Cleanup hatası fail-closed;
close stop/release sırasını tek kez serialize ediyor.

10 fake-player testi autoplay yokluğu ve phase kapısı, defensive byte, input
bounds, duplicate, queued-start cancel, route kesintisi, recall cancel,
retryable start error, cleanup fail-closed ve pending-start close yarışlarını
kapsıyor. Koordinatör mikrofon, capture, segment/alignment, skor, history veya
mastery sahibi değil; placeholder'a bağlanmadı. Gerçek piyano QA, production
player/UI ve CONS-02 açık. Ortak kalite kapısı exit0: full905, analyze temiz,
format246/0. Commit/push/deploy yok.

## 2026-10-27 — CONS-02a sıralı akor cevap diagnostic matcher

Reviewed 2/3/4 piyano kaydındaki MIDI+A4 hedeflerini mevcut target-independent
monofonik segment kanıtıyla exact low→high sırada karşılaştıran saf domain
adapter eklendi. Existing bounded sequence alignment eksik, fazla/mükerrer,
yanlış pitch ve yanlış oktavı koruyor; aynı mutlak hedef notaları farklı sırada
gözlenirse ayrıca `reorderedTargetCandidates` veriliyor. Segment zamanları
nominal sıraya çevrildiği için timing veya akustik onset iddiası yok.

10 sentetik frame testi 2/3/4 exact, reverse order, missing, extra/duplicate,
octave, no-response, invalid, discarded/provenance, A4 tuning ve tolerance
kapılarını kapsıyor. Sonuç yalnız `diagnosticCandidateMatch`; ExerciseResult,
skor/history/mastery/hafıza değildir. Production capture/UI, gerçek insan sesi,
VAD/BENCH, any-order ve cihaz QA açık. Ortak kalite kapısı exit0: full915,
analyze temiz, format248/0. Commit/push/deploy yok.

## 2026-10-28 — CONS-02b any-order akor set matcher

`ChordResponseMatcher` protokolün explicit `ResponseOrder` değerini taşır ve
`anyOrder` için immutable set özeti üretir. En fazla dört reviewed hedefte 2^N
state DP her adayı yalnız bir hedefe atayabilir; exact mutlak pitch öncelikli,
aynı pitch-class yanlış oktav ikinci kanıttır. Kalan hedef/adayı eksik/fazla
olarak bırakır; ilgisiz pitch keyfî substitution yapılmaz. Exact sıra alignment
ve reorder açıklaması her valid karşılaştırmada korunur.

6 ek test reverse any-order, unrelated missing+extra, wrong octave, duplicate,
iki komşu hedefte tek adayın yeniden kullanımını engelleme ve no-response set
sayımını kapsıyor; matcher suite16. Bu da yalnız diagnostic kanıttır; gerçek
capture, VAD/BENCH, skor/history/mastery ve cihaz QA açık. Ortak kalite kapısı
exit0: full921, analyze temiz, format248/0. Commit/push/deploy yok.

## 2026-10-28 — CONS-01d piyano replay ve recall sınav politikası

`ChordReferenceSession` artık `ExerciseMode.learning/recallExam`, completed
playback sayacı ve explicit replay kotası taşıyor. Sayaç yalnız native playback
callback'i başarıyla tamamlanınca artıyor; queued cancel, route/background veya
start failure kota tüketmiyor. Replay başladığında önceki response-ready durumu
kapanıyor; yeni playback+stop+recall tamamlanmadan geri açılmıyor. Learning
1–10 limit, recall exam tek dinleme ve gizli hedef. `PianoChordReference` aynı
recall invariant'ını protocol oluşmadan doğruluyor.

3 yeni session testiyle session suite13; session+reference hedefli20 geçti.
Sayaç duyma/öğrenme kanıtı, skor/history/mastery değil. Gerçek player/UI/event,
piyano QA ve cihaz lifecycle açık. Ortak kalite kapısı exit0: full924, analyze
temiz, format248/0. Commit/push/deploy yok.

## 2026-10-28 — CONS-01e loader→oturum composition sınırı

`ChordReferenceSessionComposer`, tek `LoadedChordRecording` içindeki reviewed
metadata ve defensive WAV snapshot'ını fresh `ReferenceClipPlayer` ile tek
`ChordReferenceSession`'a bağlar. Mode/recall/replay inputları player tahsisinden
önce ortak validation'dan geçer. Her create bağımsız player ister; başarıdan
sonra stop/close sahipliği session'dadır. Oluşturma autoplay, mikrofon, skor,
history/mastery veya placeholder availability başlatmaz.

5 test metadata+byte binding/autoplay yokluğu, recall tek dinleme+hedef gizleme,
invalid policy'de sıfır player tahsisi, factory failure ve iki session'ın ayrı
kaynak sahipliğini kapsıyor. Byte tokenları/fake player gerçek WAV, piyano veya
cihaz kanıtı değildir. Production player/UI/capture, gerçek kayıt QA ve
BENCH/VAD/route kapıları açık. Ortak kalite kapısı exit0: full929, analyze
temiz, format250/0. Commit/push/deploy yok.

## 2026-10-28 — CONS-02c referans→sıralı cevap capture kapısı

`ChordResponseCaptureSession`, reviewed referans playback'i ile öğrencinin tek
sürekli monofonik cevap kaydını aynı yaşam döngüsünde kapıladı. Mikrofon izni
ilk referanstan önce istenir; tam playback+stop+recall tamamlanmadan capture
başlamaz. Replay readiness'i geri kapatır. Stop sonrası metadata ve PCM exact
eşleşir; backend-owned kayıt silinip yalnız immutable ephemeral snapshot kalır.

10 fake test autoplay/auto-capture yokluğu, permission-first/denial, readiness,
snapshot+discard, replay, invalid metadata, interruption, pending start cancel,
cleanup fail-closed ve idempotent ownership'i kapsıyor. Worker/quality/matcher,
nota kararı, skor/history/mastery ve UI bağlanmadı. Mock PCM gerçek mikrofon,
insan sesi veya cihaz kanıtı değildir. Ortak kalite kapısı exit0: full939,
analyze temiz, format252/0. Commit/push/deploy yok.

## 2026-10-28 — CONS-02d kalite kapılı cevap diagnostic zinciri

`ChordResponseCapture` reviewed kayıt metadata'sı ve capture öncesi route
snapshot'ını taşıyor. Yeni `ChordResponseDiagnosticAnalyzer`, mevcut
`CaptureQualityAssessor` ile aynı route/sample-rate'e bağlı noise-floor
kalibrasyonunu zorunlu kılıyor. Yalnız usable kalite bounded worker →
target-independent segmenter → exact/any-order matcher zincirine giriyor.
Worker'ın sample metadata veya provenance kaynağını değiştirmesi fail-closed.

7 test missing/wrong-route calibration, exact ve reverse any-order sentetik
cevap, sessizlik, worker failure ve provenance promotion kollarını kapsıyor.
Mock/sentetik tonlar insan sesi, VAD, cihaz route'u veya öğrenme kanıtı değil;
candidate match skor/history/mastery/AI girdisi yapılmıyor. Ortak kalite kapısı
exit0: full946, analyze temiz, format254/0. Commit/push/deploy yok.

## 2026-10-29 — TRAINER-01 kulak eğitimi ikizi + Koro Atölyesi (yeni giriş noktası)

**Kullanıcı isteği:** Arkadaşın yaptığı kulak eğitimi uygulamasının ekran kaydı (7 dk) incelenip aynı özellik/sayfa/akışla ikizinin kurulması; tek sesli ve 2/3/4 sesli koro eğitimi için ayrı kategori (ses aralığı testi Resonia çekirdek perde tespitiyle, ritim/ezgi tekrarı, aksak ritim). iOS hedefli. Kullanıcı uyurken açık sorular için “en makul cevabı seç” yetkisi verdi.

### Uygulananlar (`lib/trainer/`)

- **Giriş:** `lib/main.dart` artık `TrainerApp`'i açar. Eski `ResoniaApp` ve tüm testleri dokunulmadan duruyor; koro ekranları eski modülleri yeniden kullanıyor.
- **Alan modeli:** `domain/music.dart` (12 perde, solfej/harf, 12 aralık + şarkı kancası, 9 akor, 11 dizi, 9 yürüyüş), `domain/trainers.dart` (5 eğitmen, `SoundFactory`: nota/aralık [çıkan/inen/karışık]/akor/dizi/yürüyüş [kök/çevrim], kulak sıfırlama kümesi), `domain/curriculum.dart` (videodaki yapı: giriş → dersler → kontrol noktaları → final; akor 26, dizi 25, aralık 42, nota 32, yürüyüş 17 düğüm — taslak, eğitimci onaysız).
- **Ses:** `audio/synth.dart` additive sentez (piyano/gitar/çello/klarnet/trompet/sinüs), 22.05 kHz mono PCM16, tepe 0.8; lisanslı/kayıtlı örnek yok. `audio/trainer_audio.dart` `JustAudioClipPlayer` üzerinden çalar; hata quiz'i kırmaz.
- **Quiz motoru:** `quiz/quiz.dart` (tanı / evet-hayır / “bunu bul” soru tipleri, tek öğeli havuzda tanı sorusu üretmez), `quiz/quiz_view.dart` (dinle → cevapla → yeşil/kırmızı çerçeve → “Kulağın sıfırlanıyor…”, süre sınırı, ilk deneme puanlanır, ipucu karşılaştırma kartı, “İpuçları gizlensin mi?”, çıkış onayı, isteğe bağlı piyano klavyesiyle cevap).
- **Öğren yolu:** `learn/path_screen.dart` (zaman çizelgesi, kilit/başla/yıldız/TEKRAR, kontrol noktasıyla test olup atlama), `learn/lesson_flow.dart` (giriş slaytları, kavram/duy [her notadan]/kanca kartları, hızlı kontrol, “Kilitlendi”, ders tamamlandı, pratik, sonuç), `learn/session_end.dart` (doğruluk halkası, oturum kartı, öğe kırılımı, XP, günlük seri kutlaması).
- **Pratik:** `practice/practice_setup.dart` eğitmen başına ayar (öğe seçimi, dizi ön ayarları, yön, kök/çevrim, oktav, süre sınırı, referans Do) cihazda hatırlanır.
- **Sekmeler:** Oyna (selamlama, seri, hafta şeridi, bugünün oturumu, kaldığın yerden devam, beceri ızgarası + Koro kartı, Öğren/Pratik alt sayfası), İstatistik (3 adımda açılır; 7 gün grafiği, eğitmen listesi, öğe ısı haritası, eğilim, en güçlü/çalışılmalı), Sıralama (haftalık XP ve seviye; sahte oyuncu listesi yok), Ayarlar (gösterim, transpozisyon, ses, klavye, ipuçları, bildirim 19:00, bilgi sayfaları, veriyi sil).
- **Onboarding (30 adım, adım kalıcı):** karşılama, 3 tanıtım, anket (enstrüman/seviye/hedef/deneyim/odak/engel/dakika/hedefler), 5 örnek deneme (ipucu ve “dert etme” sayfaları), plan oluşturma animasyonu, kişisel plan (en zayıf alan örnek cevaplardan), kayıt ekranı, ücretsiz beta ekranı, 6 adımlı kurulum (gösterim, ses tercihleri, seviye kontrolü → ilk kontrol noktası testleriyle atlama), bugünkü oturum.
- **Koro Atölyesi (`koro/`):** ses aralığı testi (`range_test.dart`: `PluginAudioLabBackend` + `IsolateRecordingPitchWorker`; kalite kapısı: periodik sinyal, periodicFrameRatio ≥ 0.35, dağılım ≤ 80 cent, aksi hâlde “ölçülemedi” — değer uydurulmaz; tiz ≤ pes ise sonuç kaydedilmez; olası parti yalnız taslak öneri), dinle-söyle / ezgi / ritim tekrarı (mevcut deneysel ekranlar), aksak ritim (5/8, 7/8×2, 9/8, 10/8 taslak desenleri mevcut ritim taklidi motorunda), “Kaç ses duyuyorsun?” 2/3/4 ses algı alıştırması, 2/3/4 sesli piyano tekrarı **kapalı** (kayıt bekleniyor).
- **Kalıcılık:** `state/trainer_store.dart` tek JSON (`ear_trainer`), seri yazma kuyruğu, bozuk alanlarda varsayılana dönüş, tümünü sil.

### Videodan bilinçli sapmalar

- Ad/marka Resonia kaldı (başka bir yayındaki uygulamanın adı/ikonu kopyalanmadı); arayüz Türkçe.
- Abonelik/ödeme ekranları yerine “Beta boyunca ücretsiz” ekranı: ödeme alınmaz, StoreKit yok (AGENTS: canlı ödeme ayrı yetki).
- Uydurma kullanıcı yorumu, “200k+” ve “4.8 yıldız” gibi doğrulanamayan iddialar konmadı; tanıtım grafikleri “gösterim amaçlı” etiketli.
- Apple/Google/e-posta girişi sunucu olmadığı için “yakında” sayfası açar; misafir olarak devam edilir. ATT (izleme) istemi yok.
- Ligler: sunucu yokken yalnız kendi haftalık XP'n ve seviye; başka oyuncu gösterilmez.

### Doğrulama

- Yeni testler: `test/trainer/trainer_domain_test.dart`, `trainer_store_test.dart`, `trainer_app_test.dart` (tam onboarding yürüyüşü, adım kalıcılığı, alt sayfa → yol/pratik, pratik quiz → sonuç → seri, giriş dersi, koro, sıfırlama; her adımda layout/build hatası testi düşürür). Tam paket: **978 geçti, 1 atlandı** (`screenshot_tour_test.dart` yalnız `--dart-define=TOUR_DIR=...` ile 43 ekranın PNG turunu üretir). `flutter analyze` temiz, format 0 değişiklik.
- iOS: `xcodebuild … -sdk iphonesimulator ARCHS=arm64 ONLY_ACTIVE_ARCH=YES` **BUILD SUCCEEDED**. `flutter build ios --simulator` bu makinede eski lipo kontrolüyle düşüyor: Homebrew Flutter yeniden **3.44.4** (log'daki 3.47.7 değil). Simülatör açılamadı: CoreSimulatorService `loadAllBundles` assert'iyle her boot'ta çöküyor, Simulator.app bulunamıyor, disk %98 dolu. Bu yüzden **simülatörde/cihazda elle gezinti, ses çıkışı ve mikrofonla ses aralığı ölçümü yapılmadı**; görsel kontrol gerçek fontlu widget render'ıyla yapıldı.

### Açık kalanlar

- Cihazda ses kalitesi/gecikme, mikrofon ses aralığı eşiklerinin insan sesiyle benchmark'ı, eğitimci içerik onayı (dersler, şarkı kancaları, aksak desenler), hesap/senkron, gerçek abonelik, canlı ligler.
- 2/3/4 sesli tekrar kullanıcı piyano kayıtları gelene kadar kapalı.

## 2026-10-29 — CONS-02e akor oturumu ortam kalibrasyonu

`ChordResponseCaptureSession` artık açık kullanıcı eylemiyle ortam sessizliği
kalibrasyonu yapıyor. Aynı serialized backend kuyruğunda önce eski kayıt
siliniyor; izin alınarak route snapshot'ı tutuluyor; 1.5–5 saniyelik capture
sonrası metadata/PCM exact eşleşmesi doğrulanıyor; native kayıt silindikten
sonra yalnız bellekte `NoiseFloorCalibration` üretiliyor. Gürültü/aktivite,
izin reddi, metadata uyumsuzluğu ve interruption skor değil tarafsız retry.
Başarılı kalibrasyon referans playback boyunca korunuyor; cancel,
interruption ve close ile siliniyor. Diagnostic analyzer route/rate/age'i yine
bağımsız doğruluyor.

6 yeni fake test eklendi. Tam paket 984 geçti, opt-in ekran turu 1 atlandı;
`flutter analyze` temiz, format temiz. Fake PCM/route gerçek mikrofon, oda,
piyano audibility, insan sesi, VAD veya öğretim kanıtı değildir. Placeholder
kapalı; gerçek kayıt QA, production UI/player ve cihaz benchmark kapıları açık.
Commit/push/deploy yapılmadı.

## 2026-10-29 — CONS-02f uçtan uca akor deneme coordinator'ı

Yeni `ChordResponseAttemptCoordinator`, tek reviewed akor denemesinin
kalibrasyon→referans→sıralı monofonik cevap→quality/worker/segment/matcher
akışını birleştiriyor. Ürün seviyesinde usable kalibrasyon olmadan referans veya
cevap açılamıyor. Stop yalnız tam immutable capture oluştuysa analize geçiyor.
Sessiz/güvensiz kalite `qualityRetry`, worker sorunu `analysisUnavailable`,
geçerli karşılaştırma `diagnosticAvailable`; hiçbiri otomatik skor/history/
mastery/AI yan etkisi üretmiyor. Capture identity+epoch sayesinde pending
worker sonucu cancel, replay, interruption veya close sonrasında yayımlanmıyor.
Coordinator session kaynaklarının idempotent kapanışını sahipleniyor.

7 yeni fake/sentetik test eklendi. Tam paket 991 geçti, opt-in ekran turu 1
atlandı; `flutter analyze`, format ve `git diff --check` temiz. Bunlar gerçek
mikrofon, piyano audibility, insan sesi, VAD, hafıza veya öğretim kanıtı değil.
Placeholder kapalı; gerçek kayıt QA, production player/UI/result copy ve cihaz
benchmark kapıları açık. Commit/push/deploy yapılmadı.

### 2026-10-29 sabah — simülatör onarımı ve cihaz doğrulaması (TRAINER-01b)

- **Ortam:** CoreSimulatorService çökmesi (`loadAllBundles` içinde plist okunamıyor) disk boş alanı 8,5 → 19 GB çıkınca kendiliğinden geçti; Xcode 27 kurulumu imza doğrulamasından geçti (Simulator.app yerine `DeviceHub.app`). Kullanıcı onayıyla Homebrew Flutter 3.44.4 → **3.47.8**; `flutter pub get` pubspec.lock'u güncelledi. `flutter run` iPhone 18 Pro (iOS 27) simülatöründe derlenip çalıştı; lipo engeli kapandı.
- **Simülatörde elle doğrulanan:** karşılama + ilk anket adımları, onboarding adımının cihazdaki JSON'a kalıcı yazılması, ana sayfa, eğitmen alt sayfası, pratik ayarı, aralık quiz'i (süre sayacı, dalga animasyonu ses çalarken hareket ediyor, ipucu karşılaştırma sayfası, çıkış onayı), Koro Atölyesi, ses aralığı testi: iOS mikrofon izni (Türkçe açıklama) → 3 sn kayıt → izolatta çekirdek analiz → kalite kapısı “Ölçülemedi — sonuç sayılmadı” (odada şarkı söyleyen yoktu; değer uydurulmadı). Sentezlenen klip cihazda 22,05 kHz mono PCM16, beklenen sürede (aralık 2,15 sn) üretiliyor ve oynatıcıya veriliyor.
- **Düzeltmeler:** (1) Çıkış onay penceresi açıkken soru süresi işliyordu → sayaç duraklıyor, “Devam et” ile kaldığı yerden sürüyor (regresyon testi eklendi). (2) InkSparkle dokunma efekti gradyan butonları pasif gibi soldururdu → InkRipple + beyaz/yumuşak splash.
- **Sınırlar:** Ses çıkışı kulakla dinlenmedi (oturum sesi duyamaz; yalnız dosya/oynatıcı yolu doğrulandı). Giriş seviyesi çubuğu kayıt sırasında hareket etmedi — sessiz oda mı, simülatörde amplitude akışı mı belirsiz; gerçek cihazda bakılmalı. Analiz aşaması simülatörde ~5–6 sn sürdü. Gerçek iPhone, insan sesiyle ses aralığı ölçümü ve onboarding'in tamamının cihazda elle gezilmesi yapılmadı (onboarding'in tamamı widget testiyle doğrulanıyor).
- **Doğrulama:** `dart tool/quality_check.dart` → format/analyze temiz, **992 test geçti, 1 atlandı**.

## 2026-10-29 — TRAINER-02 referans uygulamadan farklılaşma (ADR-033)

**Kullanıcı isteği:** Kopya ifadelerini değiştirmek, tasarımı ve özellikleri farklılaştırmak (mağaza/kopya riski).

**Kod:**
- `ui/kit.dart`: renk token'ları anlamsal adlara geçti (`TC.primary`, `koro`, `sun`, `coral`, `teal`, `magenta`, `amber`, `sky`); Resonia indigo paleti, lavanta zemin, yeni beceri ikonları; `BigButton` alt kenarlı basılan buton; `AppCard` gölge yerine ince çizgi.
- `home/home_shell.dart`: sekmeler Bugün / Koro / İlerleme / Ayarlar; yeni Bugün sayfası (tarih başlığı, güneş seri çipi, parti çipi, haftalık çubuk, iki adımlı "Günün planı" = kulak dersi + koro adımı, ilerleme çubuklu beceri listesi); `showVoicePartSheet`.
- `onboarding/onboarding_flow.dart`: 8 adımlı yeni akış; `samples.dart` ve `level_check.dart` kaldırıldı. Adım kalıcılığı korunuyor.
- `stats/stats_tab.dart`: İlerleme sekmesi; kilit kaldırıldı; koro temalı seviye kartı (Dinleyici → Maestro, yalnız yerel XP). `stats/ranks_tab.dart` silindi; store'da `leagueJoined` yerine `voicePart`.
- `domain/music.dart`: `VoicePart` (SATB aralıkları, `fit(Register)`); `QuizConfig.forNode(voice:)`; dersler seçilen partinin aralığında çalar. Ses aralığı sonucu "X partisinde çalış" ile kaydedilebilir; Ayarlar'da Koro grubu (Partim, Ses aralığım).
- `koro/koro_hub.dart`: sekme modu (`asTab`).
- Belirgin çeviri ifadeler yeniden yazıldı (ör. "Kilitlendi" → "Yerine oturdu", "Harika kulak!" → "Tam isabet!", "N günlük seri!" → "N gün üst üste!").

**Test:** onboarding, sekme, ayarlar testleri yeni akışa göre güncellendi; parti→register ve parti kalıcılığı testleri eklendi; ekran turu yeniden üretildi ve ana ekranlar gözle incelendi. `dart tool/quality_check.dart`: format+analyze temiz, 993 test geçti, 1 atlandı (ekran turu).

**Sınırlar:** Ders/quiz mekaniği tür standardı olsa da işlevsel olarak referansa yakın kalıyor. Cihazda elle inceleme, gerçek iPhone ve insan sesiyle ölçüm hâlâ yapılmadı. Hukuki görüş değildir; yayın öncesi referans sahibinin onayı önerilir.

## 2026-10-29 — TRAINER-03 ders/quiz/müfredatta tam ayrışma (ADR-034)

**Kullanıcı isteği:** Arkadaşın uygulamasıyla ileride sorun yaşamamak için benzerlik kalmasın.

**Kod:**
- `domain/curriculum.dart` baştan yazıldı: `_ladder` üreticisi; beş beceri için Resonia sırası (ör. aralıklar M2 → m2 → M3 → m3 → P5 → P4 → P8 …), kendi tanıtım metinleri. Ders sayıları artık 20–32.
- `domain/music.dart`: aralık `hook` → `anchor` (solfej örneği); tüm açıklamalar teori formülü.
- `learn/lesson_flow.dart` baştan: Dinle (öğe kartı, Çal / Başka yerden, partiye göre bölge) → Söyle (kayıt/puan yok) → Ayırt et. Hızlı kontrol/kilitlendi ekranları kaldırıldı.
- `quiz/quiz_view.dart` baştan: `ListenDisc`, kanıt şeridi, iki sütun seçenek butonları, A/B/C ses satırları, satır içi karşılaştırma; `QuizGenerator.lessonPractice` yeni karışım (çoğunlukla adlandırma, her üçüncü soru "hangisi").
- `learn/skill_screen.dart` (yeni) — `path_screen.dart` ve `home/trainer_sheet.dart` silindi.
- `learn/session_end.dart` tek kart; `maybeCelebrateStreak` kaldırıldı. `practice/practice_setup.dart` "Serbest çalışma" başlığı. İstatistik: beceri listesi çubuklu, beceri ekranı tablo. `kit.dart`: `WaveView`, `FeedbackFrame` silindi; `TrainerBadge` düz.

**Test:** uygulama/domain/tur testleri yeni akışa göre güncellendi; `dart tool/quality_check.dart`: format+analyze temiz, 993 test geçti, 1 atlandı. Ekran turu yeniden üretilip gözle incelendi.

**Sınırlar:** Simülatörde elle gezinti bu tur yapılmadı. Hukuki görüş değildir.

## 2026-10-29 — TRAINER-04a puansız pitch “Söyle” session composition

Yeni `TrainerPitchSingTarget`, yalnız pitch lesson içindeki item/register
çiftini kabul ediyor; seçili tenor/bas partisini sounding register'a indiriyor
ve MIDI/Hz/tını sürümünü immutable tutuyor. `TrainerPitchSingSession`, Resonia
trainer synth referansını mikrofon backend'inden ayrı owned player ile çalıyor;
cevabı mevcut `SingleToneSessionController` kalibrasyon, route, capture quality,
worker ve stale-result kapılarından geçiriyor. Fake kaynağı microphone'a
yükseltmiyor. Cancel/close kaynakları güvenle kapatıyor; close idempotent.

Bu sınıf TrainerStore'a erişmiyor ve score, accuracy, pass, lesson completion,
history, mastery veya unlock üretmiyor. 7 yeni test; ilgili hedefli 22 ve tam
1000 test geçti, 1 opt-in ekran turu atlandı. `flutter analyze --no-pub`, format
ve `git diff --check` temiz. Testlerdeki sentetik/fake PCM gerçek insan sesi,
VAD, fiziksel route, audibility veya öğretim kanıtı değildir. UI bağlantısı
TRAINER-04b olarak açık. Commit/push/deploy yapılmadı.

## 2026-10-29 — TRAINER-04b isteğe bağlı pitch “Söyle” UI

`LessonFlow` pitch derslerinde TRAINER-04a session'ını compose ediyor. Sayfaya
girmek mikrofon izni, playback veya capture başlatmıyor. “Ortamı ölç ve hazırla”
ve “Dinle ve söyle” ayrı açık eylemler; ana “Ayırt etmeye geç” eylemi her zaman
erişilebilir. UI kalibrasyon, referans, hazırlık, cevap, kalite ve analiz
durumlarını ayrı gösteriyor. Çıktı kaynak etiketi ve signed sent farkı taşıyor,
“puan değil” diyor; başarı/başarısızlık üretmiyor.

Production composition `PluginAudioLabBackend` + ayrı `JustAudioClipPlayer` +
`IsolateRecordingPitchWorker`; construction hiçbir native işlem başlatmıyor.
Background/çıkış denemeyi cancel/close ediyor, resume autoplay yapmıyor. Session
factory hatası nötr unavailable metniyle atlanabiliyor. Diğer trainer türleri ve
`liveAudio=false` test/preview bu kontrolü göstermiyor. TrainerStore/history/
mastery/completion/unlock yazımı yok. Ders playback register'ı da node'un gerçek
register'ı ve seçili koro partisiyle aynı sounding hedefe getirildi.

Apple-design ilkeleri doğrultusunda kullanıcı ajansı, anlık/durum bazlı geri
bildirim, özgül eylem adları ve hareket yerine sakin state değişimi korundu.
4 widget testi girişte izin olmaması, uçtan uca fake diagnostic, kaynak etiketi,
puansızlık, liveAudio kapısı, factory failure ve background cancel/no-resume'u
doğruluyor. İlgili 19 test ve tam 1004 test geçti; 1 opt-in ekran turu atlandı.
`flutter analyze --no-pub`, format ve `git diff --check` temiz. Fake/sentetik
kanıt gerçek telefon, insan sesi, audibility, VAD/BENCH veya öğretim kabulü
değildir. Commit/push/deploy yapılmadı.

## 2026-10-29 — E2E-01 simülatörde uçtan uca kullanıcı yolculukları

**Kullanıcı isteği:** Uygulamayı gerçek kullanıcı kullanıyormuş gibi test etmek;
seçenekler arasından otomatik E2E kurulumu seçildi.

`integration_test` (SDK) dev dependency eklendi. `integration_test/app_journeys_test.dart`
`TrainerApp()`'i `main()` ile aynı varsayılanlarla açar (`FileTrainerPersistence`,
`FileResultHistory`, gerçek `TrainerAudio`, gerçek hatırlatma platformu,
`liveAudio: true`). Her test önce uygulama destek dizinindeki `.json` depolarını
siler; soğuk yeniden başlatma yeni anahtarlı `TrainerApp` ile modellenir ve
durum diskten yeniden okunur. Bekleme gerçek zamanlıdır, her adımda framework
istisnası testi düşürür.

Yolculuklar: (1) yeni koro üyesi 8 adımlı onboarding'i bitirir, Bugün/Koro/
İlerleme/Ayarlar sekmelerini gezer, yeniden açılışta karşılama yerine ana
sayfaya gelir; (2) onboarding ortasında çıkan kullanıcı aynı adıma döner;
(3) bugünkü ders tanıtımı tamamlanır, ilerleme diskte kalır; (4) serbest perde
pratiği gerçek ses çalarak 8 soruyu bitirir, tekrar sayısı ve seri diskte;
(5) Koro'da aralık testi girişi (başlatılmadan) ve kaç ses alıştırması;
(6) verileri sil karşılamaya döner ve yeniden açılışta da öyle kalır.

`tool/quality_check.dart` format adımı `integration_test`'i de okur (test
güncellendi); E2E koşusu cihaz gerektirdiği için runner'a eklenmedi.
`docs/ci/README.md` E2E-01 bölümü komutu ve sınırları anlatır.

### Doğrulama

- `flutter test integration_test -d <iPhone 17 Pro, iOS 27 simülatörü>`: **6/6 geçti** (1 dk 22 sn).
- `dart tool/quality_check.dart`: format/analyze temiz, **1004 test geçti**, 1 opt-in ekran turu atlandı.

### Sınırlar

Mikrofon açılmaz (aralık testi/“Söyle” başlatılmaz), bildirim izni sistem
penceresine dokunulmaz (hatırlatma atlanır), çalan ses kulakla doğrulanmaz,
quiz cevapları sabit stratejiyle verilir. Simülatör testi gerçek telefon,
insan sesi, öğretim veya kullanıcı pilotu kapısı değildir.

Ortam notu: `/opt/homebrew/Caskroom/flutter/3.47.8/flutter` sembolik bağı
3.44.4 SDK checkout'una gidiyor; `flutter pub get` `integration_test`'in SDK
sabitlemeleri yüzünden `matcher`/`meta`/`test_api`/`vm_service` lock
sürümlerini bir alt sürüme indirdi. Commit/push/deploy yapılmadı.

## 2026-10-29 — Dış ürün önerisi değerlendirmesi (plan)

**Kullanıcı isteği:** Başka bir LLM'in rakip/konumlandırma/gelir önerisini
değerlendirip yol haritası çıkarmak. Kod değişmedi; test çalıştırılmadı.

- Yeni belge: [PRODUCT_ROADMAP_90D.md](./PRODUCT_ROADMAP_90D.md) — iddiaların
  repo ile karşılaştırması, kabul/uyarla/ertele/reddet listesi, KDV dahil
  düzeltilmiş katkı hesabı (~126 TL/abone; 50–60 bin TL için ~400–475 ödeyen)
  ve Faz 0–4 planı.
- Repo kontrolü: Bugün sekmesinde tek “Günün planı” kartı zaten var; seçilen
  günlük süre (`dailyMinutes`) planı değiştirmiyor; trainer ikizinde
  karışan-çift kısa tekrarı ve nefes adımı yok.
- Sınır: rakip fiyat/özellik iddiaları bu oturumda yeniden doğrulanmadı;
  pazar büyüklüğü varsayımı doğrulanmadı. Commit/push yapılmadı.

## 2026-10-30 — DESIGN-02: tasarım devri (Bugün rotası, Nefes, sonuç, üyelik)

**Kullanıcı isteği:** `design-exports/harmonia-design-handoff.zip` içindeki
taslağa göre tasarımı revize etmek. Taslak HTML ürün kodu sayılmadı; Flutter
trainer bileşenleri (`TC`/`TT`, `AppCard`, `BigButton`) kullanıldı. Mevcut
Bugün/Koro/İlerleme/Ayarlar sekmeleri korundu (devir notu bunu istiyor).

### Uygulananlar

- `lib/trainer/home/daily_route.dart` (HOME-02): `dailyMinutes` artık planı
  belirliyor. ≤3 dk yalnız ders; ≤5 dk 1 dk nefes + ders; daha uzun 2 dk
  nefes + ders + Koro adımı. Deterministik, içerik üretmez.
- `home_shell.dart` Bugün: gradyan rota kartı (“{Parti} için günlük rota”,
  ~N DAKİKA), numaralı adımlar ve “ŞİMDİ” etiketi, tek ana düğme, “kayıtlar
  cihazdan çıkmaz” notu. Parti seçilmemişse kart içinde “Partini seç”.
  Beceri listesi “TÜM BECERİLER” başlığıyla aşağıda.
- `lib/trainer/prepare/breath_screen.dart` (PREP-01): halka + faz kutuları,
  kalan süre, döngü sayısı, “Sessiz mod · mikrofon kapalı”, Duraklat/Devam,
  “Nefesi atla”. Arka plana geçince durur, kendiliğinden devam etmez.
  Bitince yalnız `TrainerStore.breathDay` yazılır; seri, XP, istatistik ve
  ders ilerlemesi değişmez. 4/2/6 düzeni taslaktır, eğitimci onayı yok.
- `session_end.dart` (RESULT-02 + RETRY-02a): skor kartı (ilk deneme
  doğruları, dokunma kaynağı), ÖLÇÜLDÜ (en çok karışan ses), DENEYSEL
  (pitch dersinde Söyle adımı puansız), ÖLÇÜLMEDİ (bugün nefes yapıldıysa),
  sıradaki ders ve açılır soru bazında ayrıntı. “Yanlışları tekrar et”
  karışan seslerden 3 yeni örnekli soru açar; `QuizView(record: false)`.
  Ertesi gün kalıcılık kontrolü bu pakette yok.
- `settings/membership_screen.dart`: Premium/Plus önizlemesi; fiyat
  “henüz belirlenmedi”, düğme kapalı, Plus'ın gerçek eğitimci olduğu ve AI
  metninin eğitimci yorumu sayılmadığı yazılı. Taslaktaki 249/799 TL ve
  “7 gün dene” kullanılmadı (onaylı fiyat/mağaza ürünü yok).
- `kit.dart`: `SoftButton`, `HeroCard`, `HeroPill`.

### Doğrulama

- `dart tool/quality_check.dart`: format/analyze temiz, **1012 test geçti**,
  1 opt-in ekran turu atlandı. Yeni `test/trainer/trainer_route_test.dart`
  (8 test): rota boyutları, breathDay kalıcılığı/sıfırlama ve kanıt dışı
  kalması, 3/10 dk ana sayfa, nefesin bitip derse geçmesi, duraklatma ve
  geri, sonuç kanıt kartları + kaydedilmeyen tekrar, fiyatsız üyelik.
- Mevcut “bugünkü ders” widget ve E2E testleri nefes adımını atlayacak
  şekilde güncellendi; `flutter test integration_test` iOS 26.5 iPhone 17 Pro
  simülatöründe **6/6 geçti** (1 dk 24 sn).
- Ekran turu (`screenshot_tour_test`) Bugün beceri listesi kaydırma, nefes,
  sonuç ve üyelik görüntüleriyle genişletildi ve üretildi.
- iOS 26.5 iPhone 17 Pro simülatöründe (xcodebuild arm64 yedeği; `flutter
  build ios --simulator` bu oturumda Xcode “cancelled” ile düştü) Bugün ve
  Nefes ekranları elle açıldı.

### Sınırlar

Gerçek telefon, haptik his, ekran okuyucu, öğrenci/eğitimci kabulü yapılmadı.
Nefes metni ve ritmi EDU-01 onayı bekliyor. Commit/push yapılmadı.

## 2026-10-30 — Personal + Choir ürün planı (plan)

**Kullanıcı isteği:** Dış LLM'in Personal/Choir önerisi ve “koro ayrı, ses/nefes herkes için” kararıyla geliştirme planı.

- Yeni [PRODUCT_PLAN_PERSONAL_CHOIR.md](./PRODUCT_PLAN_PERSONAL_CHOIR.md): iddia-repo karşılaştırması, ürün yapısı, K1–K6 kullanıcı kararları, Personal kolu (IA-01, ONB-03, PREP-02) ve Choir kolu C0–C3 (CHOIR-D0/ADR/M1, B1–B2, W1–W4, A1–A2, N1, LEGAL-C1, MIDI-01–05, CHOIR-01, CAL-03b, E1–E2, BRIDGE-01/02), KDV/kanal düzeltmeli gelir tablosu, şef iş yükü riski, takvim.
- ADR-035 eklendi; CURRENT_ROADMAP'e özet girdi.
- Kod, test, sunucu, hesap veya dış iletişim değişmedi. `choir_practice` bugün yalnız mod değeri ve mimari kural; koro sunucusu/upload/web paneli/MIDI okuyucu yok.

## 2026-10-30 — IA-01 + ONB-03: Ses sekmesi ve kişisel onboarding (ADR-035)

**Kullanıcı isteği:** Plan §9'daki ilk işi başlatmak.

### Uygulananlar

- `home_shell.dart`: sekme “Koro” → “Ses” (graphic_eq ikonu); rota adımı `route_voice`, alt metinler “Ses ·”; parti sayfası metni Ses sekmesine yönlendirir.
- `daily_route.dart`: `choirStep` → `voiceStep` (davranış aynı).
- `koro_hub.dart`: başlık “Ses Atölyesi”, kahraman etiketi “SES ÇALIŞMASI”, parti seçiliyse “<Parti> aralığında çalışma”. Çalışmalar, etiketler ve anahtarlar (`koro_range`, `koro_voices`) aynı.
- `onboarding_flow.dart`: karşılama “Sesini ve kulağını her gün geliştir”; rol sırası ve dürüst alt metin; aralık adımı `optional` — seçim yokken düğme “Atla”, seçili aralığa yeniden dokunmak temizler, “Bilmiyorum” seçeneği ve `partAsked` yazımı kaldırıldı; odak `koro` → `voice`; Hazır ekranı “Aralık” satırı, ses adımı satırı `DailyRoute` ile tutarlı, korist/şef için “Koro modülü henüz yok”.
- `settings_tab.dart`: Koro Atölyesi atıfları Ses.
- Testler: onboarding/sekme/rota/E2E/ekran turu yeni metin ve anahtarlarla; yeni test “a solo learner can skip the vocal range step”; ilk onboarding testi Koro sekmesi olmadığını ve korist için dürüst satırı doğrular.

### Doğrulama

- `dart tool/quality_check.dart`: format → analyze → **1013 test geçti**, 1 opt-in atlandı. `integration_test` formatı temiz.
- Ekran turu (`TOUR_DIR`) üretildi; rol, hazır ve Ses Atölyesi görüntüleri elle incelendi.
- `flutter test integration_test -d <iPhone 17 Pro, iOS 26.5>`: **6/6 geçti** (~1 dk 23 sn). Bir test adı “voice tab …” olarak düzeltildi.

### Sınırlar

Rol yalnız kaydedilir, içerik/akış değiştirmez. Koro modülü, sunucu, davet ve şef paneli yok. Store şeması değişmedi; eski `focus: ["koro"]` zararsızca yok sayılır. Gerçek cihaz ve kullanıcı kabulü açık.

## 2026-10-30 — CHOIR-M1 koro domain + MIDI-01 SMF okuyucu

**Kullanıcı isteği:** “Bitene kadar devam et” — plan §9'daki kararsız kod işleri.

### Uygulananlar

- `lib/choir/domain/choir_json.dart`: katı okuyucular (eksik/yanlış tip/boş id/UTC olmayan zaman/bilinmeyen enum → `FormatException`).
- `choir.dart`: `Choir`, `ChoirRole`, `ChoirPart` (SATB; divisi yok), `ChoirMember` (şef partisiz, `withPart`), `Invite` (≥6 karakter, mutlaka süreli, `maxUses` null = ortak kod; `check` önceliği iptal → süre → kota; `redeem`/`revoke`).
- `assignment.dart`: `ReferenceAsset` (audio/midi, parti veya tüm koro, `RightsDeclaration`; `unknown` paylaşılamaz), `Assignment` (parti tekilleştirme + SATB sırası, tekil referans, son tarih > oluşturma, kayıt sınırı 10–600 sn; `publishProblems` eksik/başka koro/hak beyansız dosyayı adlandırır; `isLate`).
- `submission.dart`: `SubmissionStatus` durum makinesi, `Submission.start` (yalnız atanmış partideki aynı koro koristi), `attachRecording` (sınır kontrolü), `clearRecording`, `submit`, idempotent `markListened`, `review` (dinlemeyi içerir; metin veya etiket zorunlu; yalnız aynı koronun şefi), `retake` (deneme +1, eski geri bildirim korunur, kayıt referansı düşer). Puan alanı yok. `FeedbackTag.personalArea` BRIDGE-01 için şef etiketi → Personal alanı. `assignmentProgress`: parti başına koristi, gönderilmedi, değerlendirme bekliyor, kabul, tekrar; taslak gönderilmedi sayılır.
- `lib/choir/midi/smf_reader.dart`: `readSmf` + `SmfLimits` (4 MB, 64 track, 200k olay). Tip 0/1, PPQ; tip 2 ve SMPTE reddedilir. Running status, vel-0 note-off, FIFO eşleştirme, başıboş note-off yok sayılır, asılı notalar track sonunda kapatılıp sayılır. Tempo/ölçü işareti normalize (tick 0 varsayılanları, aynı tick'te son kazanır). `secondsAt`, `lengthSeconds`, `measureStarts` (ara değişim yeni ölçü başlatır; en çok 10.000), `measureAt`. Track adı UTF-8.

### Doğrulama

- `test/choir/choir_domain_test.dart` 16 test, `test/choir/smf_reader_test.dart` 10 test (fixture baytları test içinde yazılıyor; üçüncü taraf MIDI kopyalanmadı).
- `dart tool/quality_check.dart`: format → analyze → **1039 test geçti**, 1 opt-in atlandı.

### Sınırlar

Hiçbiri UI'ya, depolamaya veya sunucuya bağlı değil. Gerçek koro MIDI dosyası, notasyon yazılımı çıktıları (Sibelius/MuseScore/Finale) ve seslendirme denenmedi. Divisi, MusicXML, tip 2 ve SMPTE yok. Davet kodu üretimi/güvenliği ve yetki kuralları sunucu ADR'sine kalır.

## 2026-10-30 — IA-01b Personal dil ve iddia tutarlılığı

- `stats_tab.dart`: `choirLevels` → `practiceLevels`, adlar Dinleyici/Çırak/Kalfa/Usta/Üstat/Maestro (XP eşikleri değişmedi); 7 gün etiketleri `Pt Sa Ça Pe Cu Ct Pz`.
- `settings_tab.dart`: profil “Çalışma aralığı: <aralık>”, bölüm “SES”, satır “Çalışma aralığım”, “Solfej (Do Re Mi)”. SATB seçimi bir ses tipi ölçümü gibi sunulmuyor.
- `membership_screen.dart`: Premium maddesi “Konservatuvar hazırlık programları” (koro ayrı modül, ADR-035).
- `home_shell.dart`: seçim sayfası “Sesin hangi aralığa yakın?”, bağlantı “Ses aralığını seç”; `range_test.dart` eğitmen/şefin ses tipi kararının yerini almadığını açık tutuyor.
- `curriculum.dart`: Personal pitch/aralık/akor/yürüyüş açıklamaları koro üyeliği veya parti seçimi varsaymıyor. `voice_count.dart` beklenen içeriği doğru biçimde çok sesli piyano kaydı olarak adlandırıyor.
- Yeni widget testi İlerleme/Ayarlar dilini; yeni domain testi tüm Personal ders düğümü ve giriş metinlerinde koro/parti varsayımının geri gelmemesini doğruluyor. `dart tool/quality_check.dart` → **1041 test geçti**, 1 opt-in atlandı; analyze/format temiz. Ekran turu önceki dilim kapsamında elle incelendi. Bu paket ses motoru, skor, depolama veya rota davranışını değiştirmez; gerçek cihaz/eğitimci kabulü yok.

## 2026-10-30 — AUDIO-01 referans motor fixture sözleşmesi

- `reference_engine_contract_test.dart`: sentetik WAV önce gerçek fixture
  manifesti, SHA-256, RIFF/PCM16 header, sample-rate ve sample-count kapılarından
  geçiyor; doğrudan test çekirdeğine enjekte edilmiyor.
- 256 örnekli A4 fixture dosya doğrulamasını geçse bile frame motorunda
  `insufficientData` kalıyor; frekans veya başarı uydurmuyor.
- C4 ve C5 fixture'ları aynı header saatinden analiz ediliyor. Her biri kendi
  mutlak hedefinde 5 sent içinde kalırken C5, C4'e karşı +1 oktav ve yaklaşık
  +1200 sent olarak korunuyor; hedefe octave-fold yapılmıyor.
- `dart tool/quality_check.dart`: format/analyze temiz, **1043 test geçti**,
  1 opt-in ekran turu atlandı. Fixture'lar testte üretilen sentetik tonlardır;
  gerçek insan sesi, VAD, mikrofon, cihaz, lisans veya pedagojik başarı kanıtı
  değildir. BENCH-01/CAL-02/VAD-01 kapıları açık.

## 2026-10-30 — CHOIR-A0 koro modülü (ADR-036)

- Domain: `AssignmentPiece` (solfej/sözlü, ölçü aralığı, yazılı bölüm, eşlik), `ReferenceAsset.trackParts`, `Submission.pieceId/takeKind/sentLate`, `Feedback.marks/voiceNoteId`, `FeedbackTag.breathLeak`, `ChoirResource`.
- MIDI: `midi_section.dart` (parti adı önerisi, ölçü penceresi), `part_renderer.dart` (tek saatli parti miksi, tempo yeniden render, ön sayım, metronom; dalga tablosu sentezi, örnek ses yok).
- Ses: `take_engine.dart`, `plugin_take_engine.dart` (kayıt + eşlik aynı anda; iOS'ta A2DP, hands-free kapalı), `take_controller.dart`, `wav_io.dart`.
- Veri: `choir_store.dart` (cihazda JSON + medya, okunamayan veriyi ezmez), `choir_bundle.dart` (`.resonia` zip; manifest, hash, kimlik deseni, aşamalı kurulum).
- Arayüz: `lib/choir/app/`; sekme (rol korist/şef ya da koro varsa), Ayarlar girişi, Bugün son tarih kartı, Verilerimi sil koroyu da siler. TR/EN.
- Simülatörde yakalanan hata: `Isolate.run` closure'ı store'u yakalıyordu, kayıt başlamıyordu; işler üst düzey fonksiyonlara alındı, regresyon testi eklendi. Birim testleri bunu fake render yüzünden görmemişti.
- Gözden geçirmede düzeltildi: tekrar kaydedilen kaydın eski dosyası iki tarafta da siliniyor.
- Doğrulama: `flutter test` 1095 geçti + 1 atlandı, analyze/format temiz, simülatör `choir_journey_test` ve `app_journeys_test` 6/6 geçti. Bir `quality_check` koşusu disk neredeyse doluyken sıfır CPU ile takıldı; öldürülüp aynı adımlar tek tek çalıştırıldı ve geçti, kök neden doğrulanmadı.
- Fiziksel cihaz, kulaklık, Bluetooth, gecikme, bleed, Android ve insan pilotu yapılmadı. `flutter build ios --simulator` bu makinede Xcode 255 ile düşüyor (bilinen lipo sorunu); `flutter run/test -d` çalışıyor.

## 2026-10-30 — DESIGN-03 İfade tasarım dili (ADR-037)

- `lib/trainer/ui/kit.dart`: mor + limon renkler, Bricolage + Figtree, hap düğme, düz `HeroCard`, tonal alt menü (`home_shell.dart`).
- `assets/fonts`: Google Fonts değişken kaynaklarından statik kesimler, SIL OFL lisans dosyalarıyla. Türkçe karakterler kontrol edildi.
- Koro: `assignment_screen.dart` öne çıkan tek eser ve üstte geri bildirim balonu; `take_screen.dart` koyu kayıt ekranı, şekil gerçek mikrofon seviyesine bağlı; `review_screen.dart` tekrar eden etiketler kaldırıldı; `DueShape`.
- Türkçe büyük harf hatası `CT.caps` ile düzeltildi; `choir_screenshot_tour_test.dart` opt-in görsel tur.
- Doğrulama: birlikte çalışma alanında 1102 geçti + 2 atlandı, analyze/format temiz; simülatörde yazı tipleri görüldü. Kayıt mantığı değişmedi; gerçek cihaz yapılmadı.

## 2026-10-30 — DESIGN-04 UX Pilot akışı

- 8 ekran kullanıcının PDF'inden uygulandı; `piece_screen.dart` yeni, `assignment_screen.dart` eser listesine indi, `practice_screen.dart` ve `review_screen.dart` yeniden yazıldı, `home_shell.dart` Bugün ekranı değişti.
- `wavePeaks` gerçek örneklerden yükseklik çıkarır; kalite yorumu değildir.
- Gerçek veri olmayan öğeler (söz satırı, foto, arkadaş sayısı, BPM, üç nokta) eklenmedi.
- Üretim sırasında disk bir kez doldu (ENOSPC) ve kendiliğinden açıldı; proje dosyası kaybı görülmedi.

## 2026-10-30 — DESIGN-05 ana tasarım

- `Harmonia.zip` 18 ekranı uygulandı; tema `kit.dart`, tüm `lib/choir/app`, Bugün ve alt menü değişti. Yazı tipleri Inter + Lora Latin alt kümesi; renk ve ölçüler Figma dosyasından (SuYUG25GKXgGN4WjbIn1n6) okundu.
- `AssignmentPiece.voicing` eklendi (eski kayıt okunurken SATB varsayılır). `TakeController.recentLevels` canlı dalgayı besler.
- Doğrulama: tam paket, analyze ve simülatörde şef ekranı; gerçek WAV dalgası ve Inter ve serif başlık görüldü. Kayıt zinciri bu turda gerçek eklentiyle yeniden koşulmadı, gerçek cihaz yapılmadı.

## 2026-10-30 — DESIGN-06 Figma karşılaştırması

- Daha önce 4 ekranın ayrıntısı okunmuştu; kalan 14 ekran `get_design_context` ile okundu ve kodla karşılaştırıldı.
- `lucide_icons_flutter` 4.0.1 (MIT) eklendi. `kit.dart` içindeki `Ic` takma adı `LucideIcons300`; `lib/choir` ve `lib/trainer` içinde Material ikon kalmadı. Paket 7 yazı tipi kaydeder; debug pakette 3,8 MB tutar, release boyutu ölçülmedi.
- Yeni: `OptionChip`, `_ThumbDot`, `TiltTag.color`, `ChoirWave.marks`, `review_restart`, `workHint`, `measureFrom`, `measureTo`. `TT.caps` ve `TT.crumb` 10 pt, alt menü etiketi 9 pt, son tarih kutusu 27/9 pt oldu.
- Geri bildirimde işaret kartları metin alanının altına indi (Figma sırası); ekran dar olunca eklenen işaret kaydırma gerektirir, dalga üzerindeki nokta anında görünür.
- `OptionChip` yüksekliği Figma gereği yaklaşık 34 pt; 44 pt dokunma hedefinin altındadır, gerçek cihazda bakılmalı.
- Testler: `test/choir/choir_design_widgets_test.dart` (dar ekranda satır kırma, seçili durum semantiği, işaret sayısı) eklendi; uzayan sayfalar için iki test ve ekran turu kaydırma ile güncellendi, tur Lucide yazı tipini yükler.
- Doğrulama: `dart tool/quality_check.dart` geçti (1106 geçti, 2 atlandı, diğer oturumun AUDIO-03 dosyaları çalışma ağacındayken). Simülatörde uygulama açıldı, Lucide ikonu görüldü. `integration_test/choir_journey_test.dart` bu turda çalıştırılmadı.

## 2026-10-31 — DESIGN-07 kişisel ekranlar koro diliyle

- `kit.dart`: `CrumbBar`, `PageTitle`, `TT.heroCaps`, `trCaps`; `BackSquare` yalın ok (tooltip'li `IconButton`); `TopBar` başlığı yol etiketi, `titleIcon`/`shadow` kaldırıldı; `ProgressBar.track`; `trainerColor` her beceri için `TC.primary`.
- `ChoirPage` üst satırı `CrumbBar` kullanıyor; koro ekranlarının görüntüsü değişmedi (tur karşılaştırıldı).
- Beceri ekranı: yol etiketi + başlık + patlıcan hero ("Sıradaki ders", Lora ders adı, beyaz "Derse başla", limon "Serbest çalışma"). İlerleme seviye kartı ve Ses Atölyesi kartı hero oldu. Sekme başlıklarına yol etiketi eklendi, kenar boşlukları 24.
- Serbest çalışma, beceri istatistiği, üyelik, ders, quiz, ses aralığı testi ve çok seslilik başlıkları yol etiketi düzeninde. Ses aralığı testinde emoji yerine limon kutuda Lucide ikon, Lora başlık.
- Testler: `test/support/tour_fonts.dart` iki turda ortak; kişisel tur gerçek yazı tipleriyle çalışıyor. İki test beklentisi yeni metne göre güncellendi. Tam **1122 test geçti**, 2 opt-in atlandı; analyze/format temiz.
- Açık: onboarding/nefes/oturum sonu/quiz gövdeleri yalnız renk ve başlık aldı; ♭/♯ Inter alt kümesinde yok (testte kutu, cihaz kontrol edilmedi); simülatör ve gerçek telefon görülmedi. Commit yalnız bu işin dosyalarını içerir; o hâlin testleri disk dolu olduğu için ayrıca çalışmadı (analyze temiz).

## 2026-10-31 — NAME-01 görünen ad Sinyorina

**Kullanıcı isteği:** "sinyorina olacak yeni ad. bunu her yerde kullan tasarımda." (resonia.app başka yerlerde kullanılıyor.)

- Kullanıcıya görünen metinlerde `Resonia` → `Sinyorina`: `ios/Runner/Info.plist` (CFBundleDisplayName, CFBundleName, NSMicrophoneUsageDescription), `AndroidManifest.xml` etiketi, `MaterialApp.title` (iki kabuk), karşılama markası, ayarlar, hatırlatma, izin kurtarma, veri aktarımı, koro dosyası hatası, ses aralığı testi ve onboarding metinleri. Türkçe ekler (’ya, ’nın, ’yı) aynı ünlü uyumuyla kaldı.
- Bilerek değişmedi: paket/sınıf/dosya adları, `RESONIA_CHANNEL`, `.resonia` uzantısı, kod yorumları, dokümanlar, bundle ID.
- Kontrol: `dart tool/quality_check.dart` → 1124 geçti, 2 atlandı. Cihaz/simülatör görünümü, marka ve App Store ad uygunluğu kontrol edilmedi. Commit yok.

## 2026-11-02 — NAME-02 görünen ad Vocalart

**Kullanıcı isteği:** İsim aramasından sonra "Vocalart" (alan adı şart değil, vocalartmusic alınabilir).

- NAME-01'deki 32 görünen metin, iOS `Info.plist` (ad, mikrofon izni), Android etiketi ve test beklentileri `Sinyorina` → `Vocalart`. Ekler: ’ya→’a, ’nın→’ın, ’yı→’ı.
- Ad taraması: App Store ABD/İngiltere temiz; WIPO Global Brand Database'de kayıt yok; vocalart.com kayıtlı, vocalart.app, vocalartmusic.com ve vocalartmusic.app boş (registry RDAP/Verisign whois). Diğer mağazalar ve TÜRKPATENT doğrulanmadı.
- Değişmeyenler: bundle ID, paket/sınıf/dosya adları, `RESONIA_CHANNEL`, `.resonia`, kod yorumları, dokümanların geri kalanı.
- Kontrol: `dart tool/quality_check.dart` → commit'e giren hâlde 1100 geçti, 2 atlandı (çalışma alanındaki diğer işlerle 1146).
- Uygulama kimliği `com.resonia.resonia` → `com.mennansevim.vocalart` (iOS pbxproj, Android gradle namespace/applicationId, MainActivity paketi taşındı). `xcodebuild -showBuildSettings` yeni kimliği gösteriyor.
- iOS simülatör derlemesi başarısız: Flutter 3.44.4 `debug_unpack_ios`, Xcode 27.0 `lipo -verify_arch` çoklu mimari argümanını kabul etmiyor ("requires exactly one input file"); tek mimariyle `lipo -verify_arch arm64` geçiyor. Araç zinciri sorunu; TestFlight öncesi çözülmeli. Android derlenmedi.
- Çözüm: `ios/Flutter/{Debug,Release}.xcconfig` → `ARCHS[sdk=iphonesimulator*]=arm64` (önce `EXCLUDED_ARCHS` denendi, Flutter `ARCHS` ortam değişkenine baktığı için işe yaramadı). Simülatör derlemesi geçti (`com.mennansevim.vocalart`, `Vocalart`), uygulama simülatörde açıldı; imzasız cihaz release derlemesi geçti. Intel simülatör desteği düştü.
