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

## 2026-10-30 — AUDIO-03a analiz sonrası tanısal ses alanı

- `visual_feedback_frame.dart`: phase, seviye, ham signed cents, nullable confidence/stability, aktif/tamamlanan notalar, hata ve provenance için tek yönlü UI sözleşmesi. Görsel konum ±1'e sıkıştırılırken ham sent değeri korunuyor.
- `pitch_feedback_field.dart`: Aurora `CustomPainter` alanı; sent konumu, kayıt tepe seviyesi küre boyutunu sürüyor. Başarı rengi/skoru yok; kaynak, ölçülmeyen güven/kararlılık ve “puan değil” metni açık.
- Tek ses oturumu yalnız başarılı kalite + analiz sonucunu eşliyor. Mock kanıt `test` kalıyor; periodic-frame ratio confidence'a, pitch dispersion stability'ye dönüştürülmüyor.
- Domain/widget/akış regresyonlarıyla hedefli **9 test**, tam pakette **1098 test** geçti; 1 opt-in ekran turu atlandı, analyze/format temiz.
- Canlı frame, VAD, puan, cihaz FPS'i, gerçek telefon ve insan sesi doğrulanmadı.

## 2026-10-30 — AUDIO-03b canlı, yalnız enerji görsel frame'i

- `InputLevelSource.inputLevelProvenance`: plugin `microphone`, test backend'i `mock`; kaynak UI'da korunuyor ve yükseltilmiyor.
- `LiveVisualFeedbackProjector`: sonlu ve ≤0 dBFS olaylarını -60..0 gösterim aralığına sınırlar; kalibrasyon/cevap frame'i üretir. Pitch, confidence, stability ve skor üretmez; invalid olayda null döner.
- `LivePitchFeedbackField`: bounded stream aboneliği; tek ses ekranında yalnız mikrofon açıkken görünür. Kalibrasyon ve cevap başlıkları ayrıdır.
- `PitchFeedbackField`: pitch ölçülmeyen canlı fazda tuning ekseni/merkez anlamı çizmez; enerji halkası, kaynak ve “perde ölçülmüyor / cihazlar arası kalibre değil / puan değildir” açıklaması gösterir.
- Eski tek ses canlı-meter regresyonu yeni sözleşmeye taşındı. Hedefli **12 test**, tam **1102 test** geçti; 2 opt-in ekran turu atlandı, analyze/format temiz.
- Gerçek cihaz, FPS/jank, dBFS tutarlılığı, canlı pitch/sent, VAD, insan sesi ve akustik kabul yapılmadı.

## 2026-10-30 — AUDIO-04a reviewed 2/3/4 ses deneme UI'sı

- `ChordDiagnosticScreen`: mevcut `ChordResponseAttemptCoordinator` için calibration → reference → sequential response → quality/analysis durumlarını ve açık iptal/lifecycle davranışını kullanıcıya bağlar.
- Learning modunda reviewed nota/oktav etiketleri görünür; recall modunda hedefler “Ses” olarak gizlenir. Exact ve any-order ayrı yönergelidir.
- Recorder canlı alanı yalnız enerji/provenance gösterir. Sonuçlar aday eşleşmesi, oktav, farklı perde, eksik/fazla ve reordering açıklamasıdır; yüzde/başarı/puan yoktur.
- Silent kayıt tarafsız kalite tekrarıdır ve worker çalışmaz. Placeholder rota ve disabled butonlar değiştirilmedi; ekran yalnız doğrulanmış coordinator injection ile kurulabilir.
- 3 yeni widget testi; tam **1109 test geçti**, 2 opt-in tur atlandı; analyze/format temiz.
- Kullanıcının gerçek piyano kayıtları, reviewed manifest/rights QA, insan sesi/VAD, fiziksel cihaz ve eğitimci kabulü yapılmadı.

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

## 2026-10-31 — AUDIO-04b reviewed attempt composition

- `ChordDiagnosticAttemptComposer`: reviewed loader çıktısından fresh player + PCM reader backend + worker + reference/capture/analyzer/coordinator zinciri kurar; hiçbir IO eylemini otomatik başlatmaz.
- `createMobileChordDiagnosticAttempt`: `JustAudioClipPlayer`, `PluginAudioLabBackend` ve `IsolateRecordingPitchWorker` seçimini tek mobil adapter sınırında yapar.
- Geçersiz policy/tolerans/süre kaynak ayırmadan reddedilir. Backend factory, eksik PCM-reader ve worker factory hatalarında player/backend sahipliği kapatılır; kurulum hatası cleanup hatasıyla değiştirilmez.
- 5 yeni test; tam **1114 test geçti**, 2 opt-in tur atlandı; analyze/format temiz.
- Placeholder rota açılmadı. Gerçek piyano manifest/hak/etiket QA, insan sesi/VAD, fiziksel cihaz ve eğitimci kabulü yapılmadı.

## 2026-10-31 — AUDIO-04c atomik reviewed chord bankası

- `ReviewedChordBankLoader`: sabit `reviewed_chords.json` için root/type/symlink/byte/UTF-8/strict schema kapısı; 2/3/4 ses kapsamı zorunlu.
- Manifestteki bütün WAV kayıtları path/hash/header loader'ından geçmeden immutable `LoadedChordBank` dönmez; tek missing/corrupt kayıt partial availability üretmez.
- Hata nesnesi yalnız bounded failure + kayıt kimliği/kodunu taşır, özel absolute root'u sızdırmaz. Loader hiçbir player, permission, capture veya analyzer başlatmaz.
- 8 yeni test; tam **1122 test geçti**, 2 opt-in tur atlandı; analyze/format temiz.
- Gerçek piyano nota/oktav/akort/tını/seviye/hak/eğitimci QA, insan sesi/VAD ve fiziksel cihaz yapılmadı; placeholder rota kapalı.

## 2026-10-31 — DESIGN-07 kişisel ekranlar koro diliyle

- `kit.dart`: `CrumbBar`, `PageTitle`, `TT.heroCaps`, `trCaps`; `BackSquare` yalın ok (tooltip'li `IconButton`); `TopBar` başlığı yol etiketi, `titleIcon`/`shadow` kaldırıldı; `ProgressBar.track`; `trainerColor` her beceri için `TC.primary`.
- `ChoirPage` üst satırı `CrumbBar` kullanıyor; koro ekranlarının görüntüsü değişmedi (tur karşılaştırıldı).
- Beceri ekranı: yol etiketi + başlık + patlıcan hero ("Sıradaki ders", Lora ders adı, beyaz "Derse başla", limon "Serbest çalışma"). İlerleme seviye kartı ve Ses Atölyesi kartı hero oldu. Sekme başlıklarına yol etiketi eklendi, kenar boşlukları 24.
- Serbest çalışma, beceri istatistiği, üyelik, ders, quiz, ses aralığı testi ve çok seslilik başlıkları yol etiketi düzeninde. Ses aralığı testinde emoji yerine limon kutuda Lucide ikon, Lora başlık.
- Testler: `test/support/tour_fonts.dart` iki turda ortak; kişisel tur gerçek yazı tipleriyle çalışıyor. İki test beklentisi yeni metne göre güncellendi. Tam **1122 test geçti**, 2 opt-in atlandı; analyze/format temiz.
- Açık: onboarding/nefes/oturum sonu/quiz gövdeleri yalnız renk ve başlık aldı; ♭/♯ Inter alt kümesinde yok (testte kutu, cihaz kontrol edilmedi); simülatör ve gerçek telefon görülmedi. Commit yalnız bu işin dosyalarını içerir; o hâlin testleri disk dolu olduğu için ayrıca çalışmadı (analyze temiz).


## 2026-10-31 — Legato ve isim araştırması (uygulama değişikliği yok)

Kullanıcı isteğiyle güncel Trainer/Choir kaynakları Legato'nun resmi mağaza ve ürün sayfalarıyla karşılaştırıldı. Rapor: [Legato ve isim araştırması](docs/research/2026-10-31-legato-and-naming.md). Seçili isimler için TR/US Apple Search API sonuçları aynı klasörde JSON olarak saklandı. Canlı perde/insan sesi doğrulaması, eser bazlı süre günlüğü ve cihazlar arası devamlılık öncelik önerileridir; uygulanmış özellik veya kabul edilmiş yeni kapsam değildir. Uygulama kodu, skor kapıları ve mevcut kullanıcı değişiklikleri değiştirilmedi. Bu araştırmada uygulama kurulmadı, cihaz testi veya test paketi çalıştırılmadı.

## 2026-10-31 — NAME-01 görünen ad Sinyorina

**Kullanıcı isteği:** "sinyorina olacak yeni ad. bunu her yerde kullan tasarımda." (resonia.app başka yerlerde kullanılıyor.)

- Kullanıcıya görünen metinlerde `Resonia` → `Sinyorina`: `ios/Runner/Info.plist` (CFBundleDisplayName, CFBundleName, NSMicrophoneUsageDescription), `AndroidManifest.xml` etiketi, `MaterialApp.title` (iki kabuk), karşılama markası, ayarlar, hatırlatma, izin kurtarma, veri aktarımı, koro dosyası hatası, ses aralığı testi ve onboarding metinleri. Türkçe ekler (’ya, ’nın, ’yı) aynı ünlü uyumuyla kaldı.
- Bilerek değişmedi: paket/sınıf/dosya adları, `RESONIA_CHANNEL`, `.resonia` uzantısı, kod yorumları, dokümanlar, bundle ID.
- Kontrol: `dart tool/quality_check.dart` → 1124 geçti, 2 atlandı. Cihaz/simülatör görünümü, marka ve App Store ad uygunluğu kontrol edilmedi. Commit yok.

## 2026-10-31 — RETRY-01d açıklayıcı ezgi aday sonucu

- `MelodyCandidateComparisonCard`, CORE-03 hizalamasındaki her sembolik adımı
  referans/aday sıra numarasıyla gösterir: toleransa yakın, oktav farkı, farklı
  perde, eşleşmeyen referans veya eşleşmeyen cevap.
- Kart neden hedefli bölüm önerildiğini görünür kılar; bunun nota doğruluğu,
  doğrulanmış hata veya ezgi hafızası puanı olmadığını ve history/mastery/
  sıralamaya yazılmadığını açıklar.
- Beş aday türü, karşılaştırılamayan cevap ve mevcut session akışı widget
  regresyonlarıyla doğrulandı. Tam **1124 test geçti**, 2 opt-in tur atlandı;
  analyze/format temiz.
- Mock/sentetik kanıt gerçek insan sesi, VAD, fiziksel cihaz veya eğitimci
  kabulü değildir; bu kapılar açık, commit/push/deploy yapılmadı.

## 2026-11-01 — REL-06e yapılandırılmış yardım kanıtı

- `AttemptAssistanceEvidence` için schema v1 eklendi: gerçekleşen referans
  çalma sayısı, perde ipucu, transpozisyon, eşlik ve yapılandırılmış hatırlama
  gecikmesi katı tür/alan/sınır doğrulamasıyla taşınıyor.
- `ExerciseProtocol` tekrar ve gecikme üst sınırlarını doğruluyor; izin verilmeyen
  yardım kullanımı sonuç kanıtı üretmeden reddediliyor.
- Ritim sonucu, protocol ile bağlı gerçek `referencePlays` sayacını nested
  `assistance` kanıtına yazıyor. Legacy alan göç uyumluluğu için korunuyor.
- Beceri grafiği yalnız tek dinleme ve yardımsız kanıtı bağımsız sayıyor.
  Malformed/çelişkili/new-assisted sonuçlar destekli kalıyor; eski sonuçlar
  önceki tek-dinleme kuralıyla okunuyor.
- Hedefli 100 test ve tam kalite kapısı geçti: **1131 test başarılı**, 2 opt-in
  tur atlandı; analyze/format temiz. `configuredRecallDelayMs` ölçülmüş latency
  veya hafıza değildir. Puan eşikleri, AI ve ses motoru değişmedi. Gerçek
  cihaz/insan sesi/eğitimci/pilot/yayın kapıları açık; commit/push/deploy yok.

## 2026-11-01 — REL-06f protokol parmak izi ve kohort izolasyonu

- Yeni `ExerciseProtocolFingerprint`, strict `ExerciseProtocol.toJson()`
  çıktısını `exercise-protocol-v1-sha256:<64 hex>` kimliğine dönüştürüyor.
- Nota/ritim, presentation/order, 12TET+A4, tempo/ölçü, recall/tekrar ve üç
  yardım politikası aynı kimliğe bağlı; JSON round-trip aynı değeri üretir.
- `RhythmImitationOutcome.toResult` kimliği immutable measurements'a yazar.
- `ResultCohort.forConfiguredExercise`, `RhythmMeasuredExercise` ve
  `RhythmNextStepPolicy` exact kimlik ister. Eksik/farklı/bozuk kimlik fail-closed
  kalır; geçmiş kayıt silinmez veya dönüştürülmez.
- Beceri haritası, günlük plan, starting check, haftalık rapor ve kaldığın yer
  fixture'ları yeni sözleşmeyle doğrulandı. Algı kohortları etkilenmedi.
- Hedefli 105 ve tam **1136 test geçti**, 2 opt-in tur atlandı; analyze/format
  temiz. İlk kalite denemesi yalnız 6 null-aware test lint'i nedeniyle durdu,
  fixture stili düzeltilip kapı yeniden başarıyla çalıştırıldı. Cihaz/voice/VAD/
  eğitimci/yayın kanıtı yok; commit/push/deploy yapılmadı.

## 2026-11-01 — REL-07e yerel history session dedup

- `classifyRecord`, aynı `sessionId` altındaki birebir aynı sonucu yeni bir
  `attemptId` ile gelse bile duplicate; farklı sonucu conflict sayıyor. İki
  durumda da history ve kapasite değişmiyor.
- `planBatchRecords` aynı kuralı gelen batch'in kendi içinde ve mevcut history'ye
  karşı atomik uygular; kapasite yalnız gerçekten yeni kimliklere harcanır.
- Dosya adapter'ı load sırasında tekrar eden attempt veya session kimliğini
  corrupt sayar ve dosyayı silmez/yeniden yazmaz. Import parse katmanı aynı
  session kayıtlarını okuyabilse de repository sonuç raporunda duplicate/conflict
  olarak çözer; partial write yoktur.
- Gerçekten farklı günlük-plan turlarının test fixture'ları artık zamandan türeyen
  farklı session kimlikleri taşır. İlk tam koşuda bu eski fixture varsayımı iki
  daily-plan testini düşürdü; fixture düzeltildikten sonra hedefli **41 test** ve
  tam kalite kapısı **1141 test + 2 opt-in skip** ile geçti. Analyze/format temiz.
- Skor, AI, ses motoru veya kullanıcı verisi migration'ı değişmedi. Fiziksel
  cihaz/insan sesi/eğitimci/pilot/yayın kapıları açık; commit/push/deploy yok.

## 2026-11-02 — SHELL-04p başlangıç kontrolü foreground/dependency yenileme

- `StartingCheckScreen`, read-only projection'lar için mevcut
  `ForegroundRefreshState` sınırına alındı. `paused/hidden/detached → resumed`
  bir read yapıyor; `inactive → resumed` ve ek `resumed` olayları yapmıyor.
- History repository, çalışma hedefi veya katalog kimliği değişince önceki özet
  yeni kaynağa taşınmıyor; ekran loading gösterip yalnız yeni future sonucunu
  yayımlıyor. Launcher değişimi gereksiz history reload'u üretmiyor.
- Foreground read yalnız özeti yeniliyor. Egzersiz route'u açma, local history
  yazma, playback/capture başlatma veya yarım oturum restore etme yolu yok.
- Ortak consumer regresyonlarıyla hedefli **41 test**, tam kalite kapısında
  **1143 test + 2 opt-in skip** geçti; analyze/format temiz.
- Bu kod testi fiziksel iOS/Android lifecycle, internetsiz kullanım, process
  death veya pedagojik kabul değildir. Commit/push/deploy yapılmadı.

## 2026-11-02 — DATA-03e veri taşıma async kaynak izolasyonu

- Export başlangıcında history/profile/preferences/clock snapshot'lanıyor.
  Kaynak değişirse generation kapısı eski load sonucunu encode/pano aşamasından
  önce durduruyor; stale status yeni ekrana yayınlanmıyor.
- Import başlangıcında history ve preference hedefleri snapshot'lanıyor. Açık
  onay sırasında dependency replacement olursa eski onay hiçbir repository'ye
  uygulanmıyor. Yazma başlamışsa işlem başladığı eski hedefte tamamlanabilir,
  fakat yeni kaynağa dönemez ve stale callback/status yayınlayamaz.
- Dependency replacement bekleyen UI kilidini yeni kaynak için kaldırıyor;
  input korunuyor. Onay metni attempt ve session kimliği tekilliğini açıklıyor.
- İlk hedefli komutta yanlış preference-test yolu nedeniyle yalnız runner load
  hatası oluştu; doğru dosyayla tekrarlandı. Başarılı hedefli koşular toplam
  **48 test**, tam kalite kapısı **1145 test + 2 opt-in skip**; analyze/format
  temiz.
- Hesap/sync/backend, gerçek iki cihaz panosu, process kill ve cross-file
  transaction yok. Commit/push/deploy yapılmadı.

## 2026-11-02 — DATA-03f export preference-read fail-closed

- Export önce history'yi, ardından aynı snapshot'taki taşınabilir tercihleri
  okuyor. Preference adapter'ı hata verirse belge encode edilmiyor ve
  `Clipboard.setData` hiç çağrılmıyor.
- Ekran yalnız bounded kullanıcı mesajı gösteriyor; exception metni veya özel
  path sızmıyor. Busy kilidi finally ile açılıyor ve açık retry mümkün.
- Bu karar sonuç-only belgeyi sessiz başarı saymıyor; profil/sonuç/tercih export
  sözleşmesinin tamamı tek kullanıcı eylemi için eksiksiz kalıyor.
- Hedefli **49 test**, tam kalite kapısında **1146 test + 2 opt-in skip** geçti;
  analyze/format temiz. Gerçek cihaz clipboard, hesap/sync/backend ve iki cihaz
  kabulü yok. Commit/push/deploy yapılmadı.

## 2026-11-02 — DATA-03g bounded export üretimi

- `LocalDataExport.encode`, JSON üretiminden önce `maxEntries=5000` sınırını,
  üretimden sonra clipboard'dan önce `maxUtf8Bytes=4 MiB` sınırını uyguluyor.
  Limitler decoder ile aynı sabitleri kullanıyor.
- Limit aşımı reason-only `LocalDataFormatException('too_large')`; payload veya
  özel içerik exception metnine girmiyor.
- Veri taşıma ekranı bu durumu yakalayıp panoya hiçbir şey yazmadan bounded
  4 MB mesajı gösteriyor ve işlem kilidini açıyor.
- Entry preflight, büyük hedef payload'ı ve widget clipboard guard testleriyle
  hedefli **51 test**, tam **1148 test + 2 opt-in skip** geçti; analyze/format
  temiz. Gerçek cihaz pano kapasitesi/süre davranışı denenmedi; hesap/sync yok.
  Commit/push/deploy yapılmadı.

## 2026-11-02 — NAME-02 görünen ad Vocalart

**Kullanıcı isteği:** İsim aramasından sonra "Vocalart" (alan adı şart değil, vocalartmusic alınabilir).

- NAME-01'deki 32 görünen metin, iOS `Info.plist` (ad, mikrofon izni), Android etiketi ve test beklentileri `Sinyorina` → `Vocalart`. Ekler: ’ya→’a, ’nın→’ın, ’yı→’ı.
- Ad taraması: App Store ABD/İngiltere temiz; WIPO Global Brand Database'de kayıt yok; vocalart.com kayıtlı, vocalart.app, vocalartmusic.com ve vocalartmusic.app boş (registry RDAP/Verisign whois). Diğer mağazalar ve TÜRKPATENT doğrulanmadı.
- Değişmeyenler: bundle ID, paket/sınıf/dosya adları, `RESONIA_CHANNEL`, `.resonia`, kod yorumları, dokümanların geri kalanı.
- Kontrol: `dart tool/quality_check.dart` → commit'e giren hâlde 1100 geçti, 2 atlandı (çalışma alanındaki diğer işlerle 1146).
- Uygulama kimliği `com.resonia.resonia` → `com.mennansevim.vocalart` (iOS pbxproj, Android gradle namespace/applicationId, MainActivity paketi taşındı). `xcodebuild -showBuildSettings` yeni kimliği gösteriyor.
- iOS simülatör derlemesi başarısız: Flutter 3.44.4 `debug_unpack_ios`, Xcode 27.0 `lipo -verify_arch` çoklu mimari argümanını kabul etmiyor ("requires exactly one input file"); tek mimariyle `lipo -verify_arch arm64` geçiyor. Araç zinciri sorunu; TestFlight öncesi çözülmeli. Android derlenmedi.
- Çözüm: `ios/Flutter/{Debug,Release}.xcconfig` → `ARCHS[sdk=iphonesimulator*]=arm64` (önce `EXCLUDED_ARCHS` denendi, Flutter `ARCHS` ortam değişkenine baktığı için işe yaramadı). Simülatör derlemesi geçti (`com.mennansevim.vocalart`, `Vocalart`), uygulama simülatörde açıldı; imzasız cihaz release derlemesi geçti. Intel simülatör desteği düştü.

## 2026-11-02 — LAUNCH-AUDIT canlıya çıkış ve rakip incelemesi

**Kullanıcı isteği:** Canlıya çıkıştaki engelleri araştır, piyasadaki rakiplerle karşılaştır. Uygulama kodu değişmedi.

- Çalıştırıldı: `dart tool/quality_check.dart` (1148 geçti, 2 atlandı), `flutter build appbundle --release --dart-define=RESONIA_CHANNEL=beta` (AAB üretildi, debug imzalı). `--no-pub` ile derleme stale registrant nedeniyle düştü; `pubspec.lock` değişmedi.
- Bulunan hata: Verilerimi sil, sonuç geçmişi, çalışma tercihleri ve zamanlanmış hatırlatmayı kapsamıyor. Kod okumasıyla bulundu, çalıştırılmadı, düzeltilmedi.
- Kaynaklar: Apple upcoming requirements, Google Play Console yardım sayfaları, App Store listeleri (cori, VocalCentric, Legato), Chorilo sitesi. Fiyatlar ABD listesi veya üçüncü taraf; Türkiye fiyatı değil. Rakip uygulamalar kurulup denenmedi.
- Flutter 3.47+ gereği yalnız üçüncü taraf (Mixpanel) sürüm notundan geliyor; Flutter resmî notu doğrulanmadı.

## 2026-11-02 — PRIV-01 Verilerimi sil kapsamı

**Kullanıcı isteği:** LAUNCH-AUDIT'te bulunan silme hatasını düzelt.

- `PracticePreferencesRepository.clear()`, `FilePracticePreferences.clear()` (yazma kuyruğunda), `PracticeReminderCoordinator.wipe()` eklendi.
- `settings_tab.dart`: sıra hatırlatma ve tercihler → sonuç geçmişi → koro → `TrainerStore`. Hata mesajı Ayarlar'da gösterilir, adımlar tekrar edilebilir.
- Widget testlerinde koro deposu sahte: gerçek dosya IO'su sahte saatte tamamlanmıyor. Gerçek dosya yolu integration test ile doğrulandı.
- Doğrulama: `quality_check` 1154 geçti, 2 atlandı. `app_journeys_test` iPhone 17 simülatöründe 6/6. iPhone 17 Pro simülatörüne yeni debug derleme yüklendi.
- Kapsam dışı kalanlar: kilitlenmeden kalan koro geçici dizinleri, gerçek bildirimle iptal denemesi.

## 2026-11-02 — REL-09b yayın kimliği tutarlılık kapısı

- `test/tool/release_identity_test.dart`, Android namespace/applicationId,
  launcher etiketi ve tek `MainActivity` package yolunu; iOS ana/test target
  bundle kimliklerini ve display/bundle adını birlikte doğruluyor.
- Platform yayın dosyalarında emekliye ayrılan `com.resonia.resonia` kimliği
  bulunursa test düşüyor. Bu kontrol tarihsel dokümanları veya migration riski
  nedeniyle korunan iç Dart/data adlarını yeniden adlandırmıyor.
- Android release uyarısı, `pubspec` açıklaması, README başlığı,
  `RELEASE_READINESS.md` kimlik satırı ve AUDIO_TESTING simülatör izin komutu
  Vocalart / `com.mennansevim.vocalart` ile eşlendi. ADR-039, ADR-038'in ad ve
  mağaza kimliği bölümünü açıkça yerine geçiriyor.
- Hedefli `release_identity` + `quality_check` koşusunda **13 test**, tam
  `dart tool/quality_check.dart` koşusunda **1174 test + 2 opt-in skip** geçti;
  format 351/0 ve analyze temiz.
- Test repo yapılandırmasıdır; Apple Team/provisioning, Android keystore,
  mağaza kaydı, imzalı arşiv, gerçek kurulum veya mağaza kabulü değildir.
  Commit/push/deploy yapılmadı.

## 2026-11-03 — QA-iOS-01 simülatör QA turu

**Kullanıcı isteği:** Otonom iOS QA, görsel denetim, doğrulanan hataları düzeltme ve izlenebilir dashboard.

- Kurulum: Homebrew ile Maestro 2.12.1. Patrol ve golden eklenmedi (gerekçe `QA_PLAN.md`).
- Düzeltmeler ve regresyon testleri: QA-DEF-001…011, `qa/defects.json` ve `QA_DEFECTS.md`.
- QA-DEF-010: `TrainerScope` store'u bildirmiyordu, `const` sekmeler bayat kalıyordu. Yeni test düzeltmeden önce düştü.
- QA-DEF-001: `kit_semantics_test` düzeltmeden önce düştü.
- Doğrulama: 1182 test geçti, 2 atlandı; analyze/format temiz; integration 7/7; Maestro 81 koşu, son durum 27/27 kombinasyon (4'ü önceki derleme).
- Çözülemeyen gözlem: `code_gate` matris yükü altında bir kez exit 1 verdi (0 test hatası), tekrar etmedi, adım kaydedilmedi.
- Sınırlar: gerçek cihaz, VoiceOver elle turu, gerçek ses/bildirim, performans, iOS 15–26.4 yok. Commit/push/deploy yapılmadı.

## 2026-11-03 — REL-08b QA kapısı arıza kanıtı

- `scripts/qa/code_gate.py` format/analyze/test süreçlerinin exit code ve
  sürelerini, ilk düşen adımı, en çok 10 başarısız testin bounded ad/hata
  özetini ve tool crash için en çok 12 satırlık diagnostic tail'i kaydediyor.
  Repo kökü kalıcı rapora yazılmadan `<repo>` ile maskeleniyor.
- Flutter test çağrısı canonical `quality_check` ile aynı `--concurrency 4`
  sınırına alındı. Başarısız process, test sayacı sıfır olsa da `status=failed`
  ve `failedStep` ile görünür; dashboard bu adımı gösteriyor.
- `scripts/qa/test_code_gate.py` altında count/skip/hidden ayrımı, test hata
  çıkarımı, bozuk machine satırından toparlanma ve bounded path-redaction için
  **3 Python testi** geçti; py_compile ve dashboard üretimi temiz.
- Gerçek `python3 -I scripts/qa/code_gate.py` koşusu: format exit0/1,29 sn,
  analyze exit0/3,93 sn, tests exit0/79,5 sn; **1182 geçti, 0 başarısız,
  2 opt-in atlandı**. Dashboard yeni JSON'dan yeniden üretildi.
- Önceki tekil exit 1'in nedeni eski koşuda kanıt tutulmadığı için belirlenmedi;
  bu paket geriye dönük neden uydurmaz. Cihaz/ses/pilot/hosted-CI/yayın kanıtı
  değildir. Commit/push/deploy yapılmadı.

## 2026-11-03 — I18N-01 tam İngilizce (QA-DEF-009)

- Karar: kullanıcı "Tam İngilizce ekle" dedi. Kural koro modülüyle aynı: ilk cihaz dili Türkçe ise Türkçe, değilse İngilizce.
- Altyapı: `lib/domain/lang.dart` (`Lang.en`, `tr`, `percent`); `TrainerApp.localeResolutionCallback`; `trCaps` dile duyarlı. `trainerPaths`, `draftAksakPatterns`, `draftRhythmPatterns`, `draftMicroLessons` dile göre önbellekli getter. `IntervalType`, `ChordQuality`, `ScaleType`, `Progression`, `VoicePart`, `BreathPhase` İngilizce alan taşır.
- Çevrilen: `lib/trainer` tüm ekranlar ve domain; Ses Atölyesi'nden açılan `features/` ekranları (tek ses, ezgi + bölüm dinleme, ritim, piyano yer tutucusu, mikroders, sonraki adım metinleri, ortak bileşenler); hatırlatma bildirimi; `AppErrorPlaceholder`; iOS `NSMicrophoneUsageDescription` (`ios/Runner/{en,tr}.lproj/InfoPlist.strings`, `CFBundleLocalizations`, `knownRegions`).
- Düzeltme: Ayarlar `_Item` değeri `Flexible`; İngilizcede "Solfège (Do Re Mi)" satırı 12 px taşıyordu.
- Testler: `test/flutter_test_config.dart` testleri Türkçe cihazda koşturur ve `Lang.en`'i sıfırlar. `trainer_app_test` içindeki "Koro sekmesi yok" beklentisi yalnız İngilizce locale yüzünden geçiyordu; koro üyesi için sekme görünür olarak düzeltildi. Yeni `test/trainer/english_ui_test.dart`: İngilizce cihazda kurulum, tüm sekmeler, beş eğitmenin beceri/pratik/istatistik/ders ekranları, nefes, üyelik, aralık testi, kaç ses; Türkçe harf/kelime veya taşma bulursa düşer.
- Sonuç: format/analyze temiz, **1185 geçti**, 0 başarısız, 2 opt-in atlandı. Maestro `11_english_tour` iPhone Air iOS 27 EN geçti (görüntüler `qa/artifacts/evidence/en/`); Türkçe `01`, `05`, `10` iPhone 17 iOS 27 üzerinde aynı derlemeyle geçti.
- Sınırlar: çeviri kalitesi anadili İngilizce bir eğitimci/editörce gözden geçirilmedi; eski, erişilemeyen `features/` ekranları ve `skill_graph` başlıkları Türkçe; mağaza metinleri yok; gerçek cihaz yok; nota gösterimi varsayılanı İngilizcede de solfej.

## 2026-11-03 — LAUNCH-AUDIT-02 canlıya hazırlık ve pazar araştırması

- Kullanıcı isteği: "uygulama canlıya hazır mı, piyasa araştırması yap". Kod değişmedi.
- Doğrulama: `dart tool/quality_check.dart` exit 0; **1185 geçti**, 0 başarısız, 2 opt-in atlandı.
- Sonuç: açık yayın hazır değil; iç beta açıkları `RELEASE_READINESS.md` §2 ile aynı (imzalama, Apple dağıtım, gizlilik politikası, mağaza formları, gerçek cihaz). Ses puanlaması (`scoringEnabled=false`) açılmadan Core beta yok.
- Pazar: web masa başı arama; bulgular ve kaynaklar `COMPETITOR_RESEARCH.md` 3 Kasım ekinde. Pazar büyüklüğü rakamları rapor firmalarına ait, yöntem görülmedi; fiyatlar satıcı kaynaklı.
- Sınırlar: mağaza içi Türkiye araması elle yapılmadı, rakip uygulamalar indirilip denenmedi, ulusal aday sayısı yok, kullanıcı görüşmesi yok. Commit/push yok.

## 2026-11-03 — REL-10 TestFlight hazırlık kontrolü

- Kullanıcı isteği: "TestFlight'a yüklemeye hazır mı"; ardından şifreleme beyanının eklenmesi onaylandı.
- Kontrol: `flutter build ipa --release --no-codesign --dart-define=RESONIA_CHANNEL=beta` → `build/ios/archive/Runner.xcarchive` (188,6 MB), sürüm 1.0.0+1, iOS 15.0. `assetutil` ile 1024 ana ikon opak. Team `L3Z9U2B39K` (ücretli bireysel); Vocalart için provisioning profile yok; yerelde yalnız Apple Development sertifikası.
- Değişiklik: `ios/Runner/Info.plist` içine `ITSAppUsesNonExemptEncryption=false` (ağ veya özel şifreleme yok). `test/tool/release_identity_test.dart` anahtarı doğruluyor. `plutil -lint` OK.
- Doğrulama: `dart tool/quality_check.dart` exit 0; **1185 geçti**, 0 başarısız, 2 opt-in atlandı.
- Sınırlar: imzalı IPA üretilmedi, App Store Connect kaydı doğrulanmadı, yükleme yapılmadı; ileride ağ/HTTPS eklenirse beyan yeniden değerlendirilmeli. Gerçek cihaz yok. Commit yok.


## 2026-11-03 — CHOIR-SEP-01 / RANGE-02 / IA-02: Koro ayrı ürün, dinle-tekrar et aralık testi, ses grubu sorusu kaldırıldı

**Kullanıcı isteği:** Koro modülü korist için ayrı satılmalı; çok sesli kayıt
üzerine eşlik ederek söyleme düşünülmeli. "Hangi ses grubusunuz" sorusu
yersiz; Agora'daki kendi tek ses aralığı algoritmasını piyano sesleriyle
"play and listen" olarak kullan, kullanıcı geçebilsin. 2/3/4 ses yakında;
ses tespiti için ayrı ekran. Eğitim modelini ve benzer örnekleri araştır.

### Uygulananlar

- `lib/trainer/koro/range_ladder.dart` (saf Dart): Agora `rangeMachine.ts` +
  `matchToTarget` portu. Doğal notalar E1–C7 (41), 2 deneme, yukarı→aşağı,
  `skipDirection`, ±40 sent eşik. Yanlış oktav `octaveOff` (asla ulaşılmış
  değil), kalite kapısı reddi `unmeasured` (perde/yakınlık null). Aralık için
  en az iki ulaşılmış nota; tek nota sonuç değildir.
- `lib/trainer/koro/range_test.dart`: ekran baştan yazıldı — tanıtım (Şimdi
  değil) → izin → rahat "aa" ile başlangıç (ya da La3) → nota çal / söyle /
  geri bildirim döngüsü, yön değişimi, "Tizde/Peste sınırım bu" → sonuç
  (aralık, yarım ses/oktav, nota merdiveni, çalışma aralığı). Sonuç
  `koroRange` ve `voicePart` (çalışma register'ı) olarak kaydedilir; puan,
  history veya ses tipi üretilmez. Kayıt piyano bittikten sonra başlar.
- `lib/trainer/audio/piano_notes.dart` + `assets/audio/piano/notes/catalog.json`:
  kayıtlı piyano notası bankası; `rightsReference` boşken tüm katalog yok
  sayılır, sentez piyanoya düşer. `TrainerAudio.playNote` nota bitene kadar
  bekler.
- Onboarding `Ob.part`: SATB seçimi yerine atlanabilir "Ses aralığını
  ölçelim" adımı (`ob_measure_range`); kalıcı adım adı uyumluluk için `part`.
  Hazır sayfası "Ölçülmedi · Ses sekmesinde ölç". Bugün kartındaki bağlantı
  "Ses aralığını ölç" olup teste gider; dokunma hedefi 44→48 px (erişilebilirlik
  denetimi yakaladı).
- Ses sekmesi: "SES TESPİTİ" bölümü; 2/3/4 sesli tekrar "YAKINDA".
- Koro: `lib/choir/domain/part_ladder.dart` `PartStep` (dinle, partin önde,
  birlikte, partin kısık, partin yok) ve `PracticeScreen` üstünde basamak
  kartı; varsayılan "Dinle" (eşit mix). Elle kaydırıcı "Kendi ayarın" olur.
- Üyelik ekranına üçüncü sekme "Koro · ayrı" (planlanıyor, satış yok).
- ADR-040.

### Araştırma özeti

- Benzer uygulamalar (Choir Player, Choral Practice, Track Tutor,
  ChorusClass, Resonance Link, Soundslice) parti sessize alma/öne alma, hız ve
  döngü sunuyor; bizdeki fark aşamalı destek azaltma ve şef ödeviyle bağ.
- Learning-track rutini (Barbershop Harmony Society): tam mix → kendi parti
  → "u" sonra sözler → parti eksik mix. Kontrollü karşılaştırma bulunamadı;
  bir 2026 yüksek lisans tezi kayda aşırı bağımlılığın içselleştirme yerine
  taklide kaydırabileceğini uyarıyor — bu yüzden son basamak "partin yok".
- Aralık testi güvenilirliği için hakemli test-tekrar verisi bulunamadı;
  eşikler kullanıcının Agora parametreleridir, insan benchmark'ı yoktur.

### Doğrulama

- `test/trainer/range_ladder_test.dart` 13 test (domain, hak kapısı, ekran
  akışı, atlama); `choir_screens_test` +2 (basamak domain/ekran, dar ekran);
  onboarding/İngilizce/erişilebilirlik/tur testleri yeni adıma uyarlandı.
- `dart tool/quality_check.dart`: format/analyze temiz, **1201 test geçti**,
  2 opt-in atlandı.

### Sınırlar

- Gerçek cihazda/mikrofonda denenmedi; hoparlör→mikrofon geçişi (iOS ses
  oturumu) ve 2 sn kayıtla kalite kapısı gerçek seste doğrulanmadı.
- Piyano WAV'ları kopyalanmadı (hak teyidi bekliyor); şimdilik sentez.
- Maestro `01_onboarding_fresh` metni güncellendi ama simülatörde koşulmadı;
  `integration_test` güncellendi, koşulmadı.
- Koro modülünün satış/entitlement altyapısı, yeni örnek eserler ve şef
  tarafı yok. Commit yok.

### 2026-11-03 ek — Piyano notaları (sahibinin onayı)

Kullanıcı Agora'daki 41 WAV'ın kendi kaydı olduğunu onayladı. Perde kontrolü
(harmonik tarak + YIN): **A5–C7 arası 10 dosya adındaki notadan bir beyaz tuş
tiz çalıyor** (A5.wav≈B5 … C7.wav≈D7); Agora web testini de etkiler. Doğrulanan
31 dosya (E1–G5, 9,1 MB) `assets/audio/piano/notes/` altına kopyalandı ve
katalog `rightsReference` ile açıldı; 10 dosya `heldBack`, onlar için sentez
çalar. `test/trainer/piano_notes_bank_test.dart` her kaydın etiketini doğrular;
kaymış 10 Agora dosyasının hepsini yakaladığı ayrıca denendi. Tam kapı:
1203 test geçti, 2 opt-in atlandı (bir koşuda bilinen kararsız test bir kez
düştü, tekrarında geçti). Gerçek cihazda çalınmadı. Commit yok.

## 2026-11-03 — I18N-02 dil ayarı, RHYTHM-CLAP-01 senkron alkış

**Kullanıcı isteği:** Dil Ayarlar'dan değişebilsin; ritim/ezgi tekrarı var mı;
alkış animasyonu Batı ve Türk müziği ritimlerinden rastgele, senkron çalsın.

- Ritim tekrarı ve ezgi tekrarı zaten vardı (Ses sekmesi → TEK SESLİ;
  `RhythmImitationScreen` taslak, `MelodySessionScreen` deneysel). Değişmedi.
- `TrainerStore.language` ('tr'/'en'/null=cihaz); Ayarlar > Tercihler > Dil.
  `TrainerApp` yalnız dil değişince yeniden kurar, `MaterialApp.locale` ve
  `Lang.en` birlikte ayarlanır (cihaz diline dönüşte WidgetsApp callback'i
  çağırmadığı için `Lang.en` elle ayarlanıyor). "Verilerimi sil" dili sıfırlar.
- `lib/trainer/koro/clap_rhythm.dart`: Batı (ritim taslakları + tresillo,
  son clave, vals) ve Türk (aksak taslakları + sofyan) havuzu; art arda aynı
  ritim gelmez. Alkış sesi sentez (üç kısa gürültü patlaması, kayıt yok).
  Eller ve vuruş noktaları sesle aynı onset listesinden Ticker ile sürülür.
  Ses sekmesinde "Alkışla ritim" (TASLAK). Ritimler eğitimci onaylı değil.
- Testler: `test/trainer/clap_and_language_test.dart` (havuz, tekrar etmeme,
  alkışın onset'te başlaması, animasyon sırası, dil değişimi ve geri dönüş).
  Tam kapı: **1208 test geçti**, 2 opt-in atlandı, analyze/format temiz.
- Sınırlar: cihaz çıkış gecikmesi ölçülmedi, görüntü sesten biraz önde
  olabilir; gerçek cihazda denenmedi. Usul/aksak doğruluğu eğitimci onayı
  bekler. Commit yok.

## 2026-11-03 — DESIGN-08 ton düzeltmesi, karşılama ekranı

**Kullanıcı isteği:** Arka plan çok açık; tonları gözden geçir. Karşılama
ekranı kullanışlı mı; giriş ve sekmeleri gözden geçir.

- `TC` (kit.dart): zemin #F8F7F3 → #EDE6DA (sıcak kum; beyaz kartlar artık
  ayrışıyor), primary #7040E8 → #6536D8, primaryDeep/primarySoft/navPill
  birlikte koyulaştı, body/muted/faint/line metin ve çizgi kontrastı için
  koyulaştı. Figma krem zemin yönü korunur, yalnız ton derinleşti.
- Karşılama: SATB çubukları (uygulamayı yalnız koro gibi gösteriyordu) ve
  "Ölçemediğimiz şeyi puanlamayız" (iç ilke) kaldırıldı; yerine Kulak / Ses /
  Koro üç somut satır ve "Bugün sekmesi ne yapacağını söyler" cümlesi.
- Bugün: rota zaten ses aralığı adımını gösteriyorsa kahraman kartındaki
  yinelenen "Ses aralığını ölç" bağlantısı gizlenir.
- Ekran turu testi (`screenshot_tour_test`) ekran dışı öğeye sürükleyerek
  ulaşacak şekilde düzeltildi (yeni ölçüm bağlantısı sonrası düşüyordu).
- Tam kapı: **1208 test geçti**, 2 opt-in atlandı; analyze/format temiz.
  Simülatör/Maestro görsel turu koşulmadı; renkler gerçek ekranda ve koyu
  ortamda denenmedi. Commit yok.

## 2026-11-03 — IA-03 giriş 5 adım: nota gösterimi sorusu kaldırıldı

Kullanıcı onayıyla onboarding'den "Notaları nasıl yazalım?" adımı çıktı.
"Başlayalım"da nota gösterimi dile göre atanır (Türkçe solfej, İngilizce
harf); Ayarlar'dan değişir. Eski kayıtlı `obStep: notation` dakika adımından
devam eder. Adım sayacı 5. Testler, ekran turu, integration ve Maestro 01/11
akışları güncellendi (Maestro/integration koşulmadı). Tam kapı: **1209 test
geçti**, 2 opt-in atlandı. Commit yok.

## 2026-11-03 — REVIEW-02 tekrar kartları (aralıklı tekrar, HLR-lite)

**Kullanıcı isteği:** Araştırmadaki ilk öneri; tekrar kartlarıyla başla.

- `lib/trainer/domain/review_memory.dart` (saf Dart, `hlr-lite-1`):
  `p = 2^(−Δ/h)`; kart `p < 0,85` olunca vadesi gelir. Doğru cevap yarı
  ömrü yalnız gerçek bir aradan sonra (≥ h/2) ikiye katlar — aynı dakikada
  tekrar "yığma çalışma" sayılır, aralık kazandırmaz; yanlış her zaman
  yarıya indirir. Sınırlar 0,5–60 gün, başlangıç 1 gün (yanlışsa 0,5).
  `dueCards` en çok unutulanı önce, en fazla 8 kart, eğitim türlerini
  karıştırarak sıralar.
- `TrainerStore.memory` + `reviewDay`; `recordAnswer` her ilk denemede
  hafızayı günceller; JSON `memoryModel` sürümü uyuşmazsa hafıza yeniden
  yorumlanmaz, sıfırdan başlar. "Verilerimi sil" hafızayı da siler.
  Eski `ItemStat` geçmişine zaman bilgisi olmadığı için kart üretilmez.
- `lib/trainer/learn/review_cards.dart`: her kart için soru; seçenekler
  yalnız öğrencinin daha önce karşılaştığı öğelerden (tek öğe varsa
  "sesi bul" sorusu). Oturum ders tamamlandı sayılmaz; `markReviewDone`.
  Sonuç ekranı her kartın sonraki tekrarını gösterir ("yarın", "3 gün
  sonra").
- Bugün rotası: vadesi gelen kart varken "Tekrar kartları · N kart · ~dk ·
  karışık" adımı; bitince "Bugünlük tamam".
- Testler: `test/trainer/review_cards_test.dart` 12 test (model matematiği,
  aralık kuralı, JSON sınırları, karışık sıra, kalıcılık, sürüm uyuşmazlığı,
  yalnız görülen öğeler, Bugün adımı, sonuç ekranı). Tam kapı: **1221 test
  geçti**, 2 opt-in atlandı; analyze/format temiz.
- Sınırlar: parametreler taslak; öğrenci verisiyle ayar ve 7 gün sonra
  gecikmeli doğruluk ölçümü yapılmadı. Söyleme/mikrofon öğeleri kart olmaz.
  Hatırlatma bildirimi henüz kartları bilmiyor (§4.2). Gerçek cihazda
  denenmedi. Commit yok.

## 2026-11-03 — REM-02 akıllı yerel hatırlatma

**Kullanıcı isteği:** Tekrar kartlarından sonra kartlara bağlı hatırlatma.

- `lib/application/reminder_planner.dart` (saf Dart, sunucusuz, kural
  tabanlı; Duolingo KDD 2020'nin uygunluk + tazelik fikri):
  - Uygunluk: koro teslimi ≤2 gün, vadesi gelen kart ≥3, korunabilir seri
    (≥3 gün ve dün çalışılmış), 3+ gün ara, ölçülmemiş aralık (≥3 aktif gün),
    her zaman "rutin".
  - Tazelik: bugün/dün planlanan tür neredeyse susar (×0,1), sonra bir
    haftada tam ağırlığa döner; ardışık günler farklı metin alır.
  - Saat: son 14 çalışma başlangıcının medyanından 30 dk önce (08:00–21:30);
    5 örnekten azsa kullanıcının seçtiği saat.
  - Takvim: 7 gün günlük, sonra 2 haftalık "haftada bir" mesajı; uygulama
    açılmazsa günlük hatırlatma kendiliğinden durur.
  - Metinler suçluluk/kayıp dili içermez; gelecekteki kart sayısı yazılmaz.
- `PlannedReminderPlatform` / `PlannedNotificationDriver` ayrı arayüzler
  (eski sahte sınıflar bozulmadı). Üretim sürücüsü 1701–1716 id'leriyle
  tek seferlik bildirimler kurar; günlük kurulum ve iptal tüm id'leri temizler.
- `PracticeReminderCoordinator.replan` yalnız hatırlatma açık ve izin varken
  çalışır. `TrainerApp` uygulama arka plana geçince (`paused`) planı yeniden
  kurar. `TrainerStore.practiceMinutes` (son 30 çalışma saati) ve
  `reminderPlan` (geçmişi tazelik için) kalıcı; "Verilerimi sil" ikisini de
  siler. `lib/trainer/app/reminder_context.dart` bağlamı yerel veriden kurar.
- Testler: `test/application/reminder_planner_test.dart` 12 test. Tam kapı:
  **1233 test geçti**, 2 opt-in atlandı; analyze/format temiz.
- Sınırlar: gerçek cihazda bildirim teslimi, iOS arka plan zamanlaması,
  saat dilimi değişimi ve Android tam zamanlı alarm davranışı denenmedi.
  Etki (bildirim → 2 saatte çalışma) ölçülmedi. Commit yok.

## 2026-11-03 — REL-11 imzalı App Store IPA

`flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
--export-method app-store` (commit 8139a96 üzerinde) geçti:
`build/ios/ipa/Vocalart.ipa` 33,4 MB; arşiv 198,3 MB. İmza "Apple
Distribution: MENNAN SEVIM (L3Z9U2B39K)" (Xcode bulut yönetimli dağıtım
sertifikası), App Store profili `com.mennansevim.vocalart`. Sürüm 1.0.0;
Xcode `manageAppVersionAndBuildNumber` ile IPA build numarasını 2 yaptı
(arşiv ve pubspec 1). IPA'da 31 piyano WAV + katalog var;
`ITSAppUsesNonExemptEncryption=false`. Uyarı: açılış görseli Flutter
varsayılanı. Yükleme yapılmadı (ayrı kullanıcı yetkisi). Gerçek cihazda
çalıştırılmadı.

## 2026-11-04 — DESIGN-09 Figma Make teması

Rakip incelemesi (`docs/research/2026-11-04-voice-coach-screen-template.md`)
→ Figma AI promptu (`docs/design/figma-ai-prompt-2026-11-04.md`) → yayınlanan
Make prototipi (<https://outer-cane-45483491.figma.site/>; MCP dosyayı
yetki yüzünden okuyamadı, ekranlar tarayıcıda gezildi) → inceleme ve plan
(`docs/design/figma-make-review-2026-11-04.md`).

- `lib/trainer/ui/kit.dart` `TC`: canvas F7F8FA, ink/hero 222539, body
  45485A, muted 6B6E80, line E6E8EF, primary 6A56E0 (primarySoft üstünde
  4,54:1), primaryDeep 5844C9, primarySoft/navPill F0EDFF, sun F2B96D,
  teal 45B4AC (yalnız dolgu), green 2F7F7A (4,73:1 metin).
- `TT.display` Lora → Inter 22/700 (kart başlığı, sayfa başlığından küçük);
  h1 28/700, h2 22/700. `AppCard` köşe 18 ve beyaz kartta 1px `TC.line`;
  `BigButton` köşe 14, pasif dolgu E4E6ED. `ChoirWave` rest 4A4D66.
- `test/support/visible_text_contrast.dart`: `textContrastGuideline`
  başarısızlıklarından yalnız boya kutusu semantik düğümünü aşan (yani
  kaydırma alanınca kesilen) metinleri düşürür. `accessibility_audit_test`
  bunu kullanıyor; `visible_text_contrast_test` tam görünen soluk metnin
  hâlâ kaldığını ve kesik metnin atlandığını sınar. Sebep: yatay ve 2.0
  ölçekte alt menünün kestiği satırlar zemin + menü çizgisiyle ölçülüp
  1,15 bulunuyordu; renkler değil geometri.
- Kontrol: `dart tool/quality_check.dart` → **1235 test geçti**, 2 opt-in
  atlandı; analyze/format temiz. Bugün, Ses, Koro, İlerleme, Ayarlar test
  görüntüleri `design-exports/tema-2026-11-04/` (gözle kontrol edildi).
- Sınırlar: yerleşim değişmedi (sekme yapısı, Bugün, kütüphane sonraki
  adımlar). Simülatör ve gerçek cihazda bakılmadı. Commit yok.

## 2026-11-04 — NAV-02 dört sekmeli alt menü

- `lib/trainer/home/home_shell.dart`: sekmeler `tab_0` Bugün (ev ikonu),
  `tab_1` Egzersizler (ızgara; gövde hâlâ `KoroHub`), `tab_koro` Koro (rol
  veya koro varsa), `tab_2` Gelişim. `tab_3` Ayarlar kalktı.
- `lib/trainer/settings/settings_tab.dart`: `ProfileButton` (48px dokunma
  alanı, 40px koyu daire, "Ayarlar" semantik etiketi, `open_settings`) ve
  `SettingsScreen` (geri oklu `CrumbBar` + mevcut `SettingsTab`). Veri
  silme başarılı olunca `popUntil(isFirst)` ile girişe dönülür; başarısız
  olunca sayfa ve uyarı kalır.
- Profil düğmesi: Bugün (seri çipinin yanında), Egzersizler ve Gelişim
  (`tabHeader`/`_Header` yeni `trailing` yuvası), Koro (`ChoirTab.trailing`).
  Egzersizler başlığı "Keşfet / Egzersizler", Gelişim "Yolculuğun / Gelişim".
- Metinler: "Ses sekmesi" → "Egzersizler sekmesi", "İlerleme sekmesi" →
  "Gelişim sekmesi" (onboarding, ayarlar, ses parçası seçici, oturum sonu).
- Testler: `tab_3` dokunuşları `open_settings` oldu; İngilizce turu ve dil
  testi ayarlar sayfası alt menüyü örttüğü için kontrolleri yeniden sıraladı.
  `dart tool/quality_check.dart` → **1235 test geçti**, 2 opt-in atlandı;
  analyze/format temiz. Görüntüler `design-exports/menu-2026-11-04/` (gözle
  kontrol edildi).
- Sınırlar: Egzersizler içeriği ve Bugün yerleşimi değişmedi. Simülatör ve
  gerçek cihazda bakılmadı. Commit yok.

## 2026-11-04 — REL-11a iOS artifact doğrulama kapısı

- `scripts/release/verify_ios_ipa.py`: IPA'yı çıkarmadan bounded ZIP olarak
  denetler; traversal/symlink/toplam boyut, tek ana app, bundle adı/kimliği,
  sürüm/build/minimum OS, `ITSAppUsesNonExemptEncryption=false`, executable,
  CodeResources ve embedded profile zorunlu.
- `security cms` ile profile decode edilir; application-identifier,
  `get-task-allow=false`, cihaz/ad-hoc/enterprise işaretlerinin yokluğu ve
  son kullanma tarihi fail-closed kontrol edilir.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: **3 test geçti**;
  yanlış bundle/şifreleme beyanı, development ve süresi dolmuş profile
  senaryoları reddedildi. `py_compile` temiz.
- Gerçek `build/ios/ipa/Vocalart.ipa` exit 0: Vocalart,
  `com.mennansevim.vocalart`, 1.0.0 build 2, minimum iOS 15.0, App Store
  profile 2027-09-25'e kadar geçerli.
- `dart tool/quality_check.dart` exit 0: **1235 test geçti**, 2 opt-in
  atlandı; analyze/format temiz.
- Sınırlar: upload/App Store sunucu kabulü, tüm codesign kriptografik zinciri,
  kurulum ve fiziksel cihaz çalışması doğrulanmadı. Yükleme/push/deploy yok.

## 2026-11-04 — REL-11b iOS sürüm tek kaynağı

- Bulguda arşiv/pubspec `1.0.0+1`, export edilen imzalı IPA `1.0.0+2` idi;
  Xcode export build numarasını sessiz artırmıştı.
- `pubspec.yaml` imzalı artifact ile `1.0.0+2` olarak hizalandı.
  `verify_ios_ipa.py` strict pubspec `semver+build` okur ve IPA marketing/build
  değerlerini exact-match ister; eski veya otomatik değiştirilmiş artifact
  fail-closed reddedilir.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: **5 test geçti**;
  sürüm ayrışması ve bozuk pubspec de kapsandı. Gerçek IPA 1.0.0+2 ile geçti.
- `dart tool/quality_check.dart` exit 0: **1235 test geçti**, 2 opt-in
  atlandı; analyze/format temiz.
- Upload, mağaza işlemi, push/deploy veya cihaz kurulumu yapılmadı.

## 2026-11-04 — REL-11c iOS codesign kapısı

- IPA archive duplicate path'leri artık fail-closed reddediliyor.
- Önceki path/symlink/count/byte bütçelerinden geçen archive geçici klasöre
  açılıyor; `/usr/bin/codesign --verify --deep --strict --verbose=2` ana app
  ve nested imza zincirini doğrulamadan rapor başarı vermiyor.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: **7 test geçti**;
  imza doğrulayıcı hatası ve duplicate archive path regresyonları eklendi.
  `py_compile` temiz.
- Gerçek `build/ios/ipa/Vocalart.ipa`: codesign exit 0 ve önceki kimlik,
  sürüm, profile, şifreleme kapılarının tamamı geçti.
- `dart tool/quality_check.dart` exit 0: **1236 test geçti**, 2 opt-in
  atlandı; analyze/format temiz.
- Apple sunucu kabulü, upload/TestFlight dağıtımı veya fiziksel cihaz kurulumu
  değildir. Upload/push/deploy yapılmadı.

## 2026-11-04 — REL-11d Apple sahiplik zinciri

- Profile `application-identifier` artık suffix değil exact
  `L3Z9U2B39K.com.mennansevim.vocalart`; profile `TeamIdentifier` listesi ve
  `com.apple.developer.team-identifier` entitlement'ı da exact eşleşir.
- `codesign -dv --verbose=4` çıktısında exact bundle ID, Team ID ve ilk
  authority'nin `Apple Distribution:` olması zorunlu; farklı sahibin geçerli
  imzası kabul edilmez.
- Python paketi **9 test**; yanlış profile team ve yanlış signature team
  regresyonları eklendi. Güncel gerçek 1.0.0 build 3 IPA; team
  `L3Z9U2B39K`, Vocalart app id ve Apple Distribution authority ile geçti.
- `dart tool/quality_check.dart` exit 0: **1259 test geçti**, 2 opt-in
  atlandı; analyze/format temiz.
- Upload, App Store sunucu kabulü, cihaz kurulumu, push/deploy yapılmadı.

## 2026-11-04 — DESIGN-10 Bugün yerleşimi

- `PlayTab` (`lib/trainer/home/home_shell.dart`): başlıkta büyük harf tarih,
  seri çipi, profil düğmesi; "Merhaba[, ad]" ve "Bu hafta N gün çalıştın"
  (pazartesiden bugüne soru çözülen günler; tahmini dakika gösterilmez).
- `_DailyRoute`: koyu plan kartı; `_PlanBar` parça sayısı o günkü rota
  adımlarından gelir (sabit 4 değil), tamamlanan adımlar teal. `today_begin`
  kartın içinde; ses aralığı bağlantısı (ADR-040) korunur. Adım kartları ve
  gizlilik notu kart altında.
- Yeni: `_QuickCard` (`quick_<beceri>`) yatay satır, `_ResumeCard`
  (`today_resume`) yalnız son çalışılan beceri varsa, tamamlanan/toplam ders
  ve ilerleme çubuğu.
- Beceri ızgarası `KoroHub` başına "Kulak eğitimi" olarak taşındı
  (`skill_<beceri>` anahtarları aynı).
- `VisibleTextContrastGuideline`: boya kutusu düğümü herhangi bir kenardan
  aşan metin kesik sayılır (yatay satırdaki ekran dışı kart).
- Testler: Bugün'den beceri açan testler `quick_*` ya da önce `tab_1`
  kullanıyor; Egzersizler testi aralık testine kaydırıyor.
- `dart tool/quality_check.dart` exit 0: **1235 test geçti**, 2 opt-in
  atlandı; format/analyze temiz.
- Ekranlar: `design-exports/bugun-2026-11-04/`. Simülatör/cihazda
  bakılmadı; commit yok.

## 2026-11-04 — DESIGN-11 Egzersizler kütüphanesi

- `KoroHub` (`lib/trainer/koro/koro_hub.dart`) StatefulWidget oldu;
  `_Category` filtresi (Tümü, Isınma, Kulak, Ses, Ritim, Çok sesli) ve
  `_Exercise` listesi. "Tümü" kategorileri başlıklı bölümler halinde,
  tek kategori yalnız kendi ızgarasını gösterir.
- `_CategoryChip`: 38 dp hap, 48 dp dokunma alanı, seçili `TC.ink`; çip
  satırı liste dışında, kenardan kenara yatay kayar (`lib_categories`).
- `_RangeCard` (`koro_range`) Tümü ve Ses'te; DENEYSEL etiketi, son ölçüm
  "taslak" ibaresiyle.
- `_ExerciseCard`: ikon, başlık, açıklama; altta yalnız kulak yollarında
  ölçülen ders ilerlemesi, diğerlerinde durum etiketi. Süre/seviye/üye
  gibi ölçülmeyen alanlar eklenmedi (prototip hata 4–7 ilkesi).
- Yeni test: kategori filtresi (Ritim'de 3 TASLAK, Kulak'ta DENEYSEL yok,
  ders sayısı metni, Ses'te aralık kartı). Egzersizler ve tur testleri
  dikey listeyi açıkça seçiyor (yatay çip satırı ikinci Scrollable).
- `dart tool/quality_check.dart` exit 0: **1236 test geçti**, 2 opt-in
  atlandı; format/analyze temiz. Opt-in ekran turu (`TOUR_DIR`) da geçti.
- Ekranlar: `design-exports/egzersizler-2026-11-04/`. Simülatör/cihazda
  bakılmadı; commit yok.

## 2026-11-04 — DESIGN-12 detay → canlı → sonuç

- `skill_screen.dart` `_Summary`: güneş renkli beceri ikonu, başlık 26,
  koyu iz üstünde teal ustalık çubuğu.
- `lesson_flow.dart` isteğe bağlı ses kontrolü:
  - `sing_target` hedef nota; `SingSteps` faz çubuğu (referencePlaying →
    waiting → responding → assessing/analyzing), sözlü durum satırı aynı.
  - `SingDeviationScale` (`sing_scale`): dikey ölçek, tiz yukarıda; yalnız
    `octaveOffset == 0` iken ±100 sentle sınırlı nötr (ink) işaret.
    Yanlış oktavda işaret yok, "Bir oktav tiz/pes söylendi".
  - `_singOutcomeLabel` yanlış oktavda "oktav tiz/pes, hedef perde değil"
    ekler. `SingNotCounted` (`sing_not_counted`): retry ya da kararlı aday
    yoksa renksiz "Ses ölçülemedi · bu deneme sayılmadı".
  - Gerçek zamanlı perde çizgisi eklenmedi: SESSION-01 kaydı sonradan
    analiz eder; canlı akış yok. Skor kapalı (`scoringEnabled=false`).
- `session_end.dart`: koyu kartta `_ScoreRing` (ilk deneme oranı), ölçüm
  kaynağı satırı, `_Stat` çipleri (% ilk deneme, +XP). Kanıt kartları aynı.
- Testler: aynı oktavda ölçek + "Hedef perde"; oktav tiz denemesinde metin,
  "Hedef perde" yok; sessizlikte `sing_not_counted`, ölçek ve fark yok.
  Fake backend/sentetik sinyal — cihaz/insan sesi kanıtı değildir.
- `dart tool/quality_check.dart` exit 0: **1238 test geçti**, 2 opt-in
  atlandı. Ekranlar: `design-exports/detay-canli-2026-11-04/`. Commit yok.

## 2026-11-04 — DESIGN-13 Gelişim ve Koro

- `stats_tab.dart`:
  - `_LevelCard`: başlık 26, teal ilerleme; `_HeroFigure` üçlüsü
    (`totalQuestions`, `activeDayCount`, `streak`). Çalışma süresi
    ölçülmediği için dakika gösterilmez (prototip hata 4).
  - Son 7 gün çubukları: bugün teal, diğerleri açık mor.
  - `_RangeCard` (`stats_range`): `koroRange` yoksa "Ölçülmedi" + aralık
    testine bağlantı; varsa Do2–Do6 şeridi, "TASLAK ÖLÇÜM" etiketi ve
    "doğrulanmış ses aralığı değildir" notu (hata 5).
  - `_suggestion` + `_SuggestionCard` (`stats_suggest`): ≥10 cevaplı
    beceriler arasında en düşük ilk deneme doğruluğu; deterministik, yoksa
    gizli.
- `choir_tab.dart` `_ChoirCard`: güneş ikon kutusu, 26 pt koro adı. Üye
  sayısı, besteci gibi veride olmayan alanlar eklenmedi (hata 7).
- Testler: 9 cevapta öneri yok + "Ölçülmedi"; ölçülmüş aralıkta "TASLAK
  ÖLÇÜM" ve %50 öneri.
- `dart tool/quality_check.dart` exit 0: **1240 test geçti**, 2 opt-in
  atlandı. Ekranlar: `design-exports/gelisim-koro-2026-11-04/`. Commit yok.

## 2026-11-04 — REL-12 tasarım IPA'sı (1.0.0+3)

- Kaynak: commit 4e7591e (tasarım) + çalışma ağacındaki REL-11 değişiklikleri.
- `pubspec.yaml` 1.0.0+2 → 1.0.0+3 (build 2 daha önce export edilmişti).
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<önceki ExportOptions, manageAppVersionAndBuildNumber=false>`
  exit 0; `build/ios/ipa/Vocalart.ipa` 33,2 MB. Uyarı: açılış görseli
  Flutter varsayılanı.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: 7/7.
  `verify_ios_ipa.py` gerçek IPA: passed — com.mennansevim.vocalart,
  Vocalart, 1.0.0 (3), iOS 15.0, codesign doğrulandı, App Store profile
  2027-09-25'e kadar.
- Önceki 1.0.0 (2) IPA `build/ios/ipa-1.0.0+2/` altına taşındı.
- Upload, TestFlight, cihaz kurulumu yapılmadı (ayrı kullanıcı yetkisi).

## 2026-11-05 — REL-11i tüm privacy manifest zinciri

- `verify_all_privacy_manifests`, ana app altındaki tüm app/framework/plugin
  `PrivacyInfo.xcprivacy` dosyalarını bounded plist olarak okuyor (en çok 100).
- Her manifest `tracking=false`, boş tracking-domain ve collected-data listesi
  taşımalı; required-reason API girdilerinde non-empty kategori ve neden listesi
  zorunlu. App-owned exact FileTimestamp/C617.1 kapısı ayrıca korunuyor.
- Embedded tracking ve bozuk required-reason beyanı testleriyle Python paketi
  14/14; pycompile ve diff check temiz.
- Gerçek 1.0.0 (6) IPA'da app manifesti, Flutter framework ve 6 plugin bundle
  olmak üzere 8 privacy manifest geçti.
- Mağaza gizlilik formu, hukuk incelemesi, upload ve cihaz kabulü yapılmadı.

## 2026-11-05 — REL-11h device platform/minimum OS kapısı

- `verify_device_platforms`, ana app ve embedded framework executable'larının
  `LC_BUILD_VERSION` bilgisini `/usr/bin/xcrun vtool -show-build` ile okuyor.
- Exact `IOS` dışında platform reddedilir; böylece `lipo`da arm64 görünen Apple
  Silicon simulator slice'ı da geçemez.
- Ana Mach-O minimum OS app Info.plist ile exact-match; embedded framework
  minimum OS değeri uygulamanınkinden büyük olamaz.
- Simulator ve uyumsuz framework senaryolarıyla Python paketi 13/13;
  pycompile temiz. Gerçek 1.0.0 (6) IPA'da Runner 15.0, App/Flutter/objective_c
  framework'leri IOS 13.0 — 4 bundle geçti.
- Upload, App Store sunucu kabulü, fiziksel cihaz çalışma/performance kanıtı
  değildir.

## 2026-11-04 — MIC-01 mikrofon testi (tanışma + Ayarlar)

- `lib/domain/audio/mic_check.dart`: `MicCheckStatus` (ready, noisyRoom,
  tooQuiet, tooLoud, permissionDenied, notMeasured) + `MicCheckGap`.
  `afterSilence` / `afterVoice` yalnız mevcut `NoiseFloorStatus` ve
  `CaptureQualityStatus` değerlerini eşler; yeni eşik/tolerans yok.
  lowSignalToNoise taban geçtikten sonra geldiği için "kısık" sayılır.
  `scoringEnabled = false`.
- `lib/application/mic_check_session.dart`: `MicCheckController` — izin →
  sessizlik kaydı → hazırlan → ses kaydı → değerlendirme. Her klip bir kez
  okunur ve silinir; ses yolu iki adım arasında tekrar okunur (değişirse
  kalibrasyon geçersiz → "Ölçülemedi"). Kesinti/iptal geç sonuç yayınlamaz.
  Giriş seviyesi yalnız gösterge. Kapanışta önce mikrofon bırakılır.
- `lib/trainer/prepare/mic_check_screen.dart`: adımlar, faz kartı, seviye
  çubuğu, sonuç kartı (öneriler + ham dBFS/ayrışma "cihaza göre
  ayarlanmamış"), izin yoksa "Ayarları aç". Canlı ses yoksa nötr
  "başlatılamadı". Ekran son durumu döndürür.
- Tanışma: `Ob.mic` adımı (Atla/Devam), sayaç 5 → 6; kalıcı adım adları
  uyumlu. Ayarlar: `settings_mic_check`. Mevcut onboarding testleri,
  integration journey ve `.maestro/01_onboarding_fresh.yaml` yeni adım için
  güncellendi (Maestro/integration bu oturumda çalıştırılmadı).
- Testler: `test/application/mic_check_session_test.dart` (7),
  `test/trainer/mic_check_screen_test.dart` (10, a11y/kontrast dahil),
  `trainer_app_test.dart` +2 (tanışma adımı, Ayarlar girişi). Hepsi fake
  backend + sentetik sinyal; cihaz/insan sesi kanıtı değildir.
- `dart tool/quality_check.dart` exit 0: **1259 test geçti**, 2 opt-in
  atlandı. Gerçek cihaz/mikrofon doğrulaması yapılmadı. Commit yok.
- Not: ortak `TopBar`/`BackSquare` 44 pt; Android 48 dp tap hedefine uymuyor
  (kit genelinde ayrı iş).

## 2026-11-04 — DESIGN-14, yeni Figma Make şablonu

**Kullanıcı isteği:** `https://outer-cane-45483491.figma.site/` şablonunu
birebir uygulamak; kararsız noktalarda inisiyatif.

### Uygulananlar

- Kaynak: sitenin derlenmiş `App.tsx`/CSS paketi okundu (indirme yalnız
  scratchpad'e, çalıştırılmadı). Son CSS katmanı esas alındı.
- `lib/trainer/ui/kit.dart`: yeni `TC` paleti, `toneAt`/`ToneIcon` (lavanta,
  mercan, lime döngüsü), `TT.section`, mercan eyebrow, 29 pt w800 başlık.
  `BigButton` varsayılanı lime + koyu "ledge" gölge (basınca iner);
  `AppCard` sert alt gölge, 20 radius; `HeroCard` aubergine, lavanta gölge,
  `HeroOrbs.plan/level` halkaları; `BackSquare` 48 dp hedefli yuvarlak kart.
- `home_shell.dart`: Bugün başlığı, seri çipi, `_WeekChip`, orb'lu plan kartı
  ve etiketli `_PlanBar`, `_SectionHeading` + "Tümünü gör", hızlı/kaldığın
  yerden kartları, koro satırı, alt menü (aktif `#432A72`, pill `#E8DDFF`).
- `settings_tab.dart` `ProfileButton`: baş harf, lime nokta, gölge.
- `koro_hub.dart`: arama (Türkçe I/İ katlamalı), boş durum, mercan aralık
  kartı, tek "Tüm egzersizler" başlığı ve sayaç.
- `stats_tab.dart`: "Sesinin haritası", seviye kartı halkası, lime ilerleme,
  mor çubuklar, cümle düzeni başlıklar.
- Ders, pratik, aralık testi, kaç ses ve koro hero düğmeleri lime; "Hayır"
  düğmesi `coralDeep` (beyaz metin kontrastı).

### Kararlar / sapmalar

- Ölçülmeyen değer üretilmedi: kartlardaki "2 dk", seviye, "%80", "+40 XP"
  gibi örnek veriler yerine gerçek ders/soru/gün sayıları.
- Haftalık hedef store'da yok; çip 7 gün noktası ve gerçek aktif gün sayısı
  gösterir.
- Plan kartının altındaki rota adımları korundu (tekrar kartları ve ses adımı
  başka yerden açılmıyor).
- Kullanıcı onayıyla Manrope eklendi: resmî `googlefonts/manrope` deposundan
  Regular/Medium/SemiBold/Bold/ExtraBold statik TTF ve Google Fonts
  `OFL.txt` (`assets/fonts/OFL-Manrope.txt`). Tema ve ekran turu yükleyicisi
  Manrope kullanıyor; Inter dosyaları pubspec'te duruyor ama trainer teması
  artık kullanmıyor (kaldırma ayrı karar).
- Gerçek font ile kontrast denetimi 12 pt muted metni 3.88, 11 pt menü
  etiketini 3.09 ölçtü: `TT.small` w500, pasif menü etiketi `TC.body` w600
  yapıldı; denetim yeniden geçti.

### Doğrulama

- `dart tool/quality_check.dart`: format → analyze → **1259 test + 2 skip**
  geçti. Değişen testler: rota "~3 DK" metni, aralık kartı başlığı, sonuç
  ekranında kanıt kartına kaydırma.
- Ekran turu: `design-exports/figma-yeni-sablon-2026-11-04/`.
- Simülatör, fiziksel cihaz ve gerçek kullanıcı görsel kabulü yapılmadı.

## 2026-11-04 — RANGE-03, aralık testi algılama incelemesi ve çekim süresi

**Kullanıcı isteği:** Ses algılama "verdiğim Python koduyla" düzgün mü;
algılamada sorun var gibi. Sonra: çekimi 3 sn yap, baştaki sessizliği kırp.

### Bulgular

- Repoda/oturumlarda tek Python adayı `../voice-recognizer/main.py`
  (1024 örnek FFT argmax). Uygulama onu kullanmıyor; aralık testi
  `RecordingPitchAnalyzer` + `YinPitchFrameAnalyzer` (48 kHz, efektsiz kayıt)
  ve Agora `matchToTarget` portu (±40 sent, yanlış oktav ulaşılmadı).
- Geçici sentetik deney (silindi): YIN 14 senaryonun 12'sinde doğru; oktav
  kayması doğru biçimde reddedildi; 1,4 sn geç başlayan doğru ses 2 sn
  çekimde reddedildi. Python yöntemi E2→F2, C6→E11, zayıf temelde oktav
  hatası ve spektrum aynasından "F11" üretti.

### Uygulananlar

- `range_test.dart`: `_takeLength` 3 sn; metinler "3 saniye", düğme
  "Söyle (3 sn)". `evaluateRangeEvidence`: `minVoicedSeconds = 0.7`
  (eski miktarla aynı), `minVoicedContinuity = 0.35` ilk–son periyodik
  çerçeve aralığında; yeni nötr mesajlar ("Ses çok kısa duyuldu", "Ses sık
  sık kesildi"). Dağılım ve oktav kuralları değişmedi.
- Testler: geç başlama/sonda sessizlik kabul, 0,4 sn kısa ses, kesik ses ve
  oktav sıçraması reddi.

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: **1263 test + 2 skip**, analyze/format temiz.
- Sentetik sinyal; mikrofon açılma gecikmesi, gerçek insan sesi ve cihaz
  benchmark'ı ölçülmedi. 0,7 sn/0,35 taslak hipotez olarak kalır.

## 2026-11-04 — REL-13 IPA 1.0.0+4

- Kaynak: commit edilmemiş çalışma ağacı (DESIGN-14, Manrope, RANGE-03 ve
  önceki MIC-01/REL-11 değişiklikleri).
- `pubspec.yaml` 1.0.0+3 → 1.0.0+4; önceki IPA `build/ios/ipa-1.0.0+3/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<REL-12 ExportOptions, manageAppVersionAndBuildNumber=false>`
  exit 0; `build/ios/ipa/Vocalart.ipa` 33,5 MB. Uyarı: açılış görseli
  Flutter varsayılanı.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: 9/9.
  `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (4), iOS 15.0,
  codesign doğrulandı, Apple Distribution L3Z9U2B39K, profile 2027-09-25.
- Upload, TestFlight, cihaz kurulumu yapılmadı (ayrı kullanıcı yetkisi).

## 2026-11-04 — REL-11e imzalı entitlement zinciri

- `verify_codesign`, strict bundle/nested imza doğrulamasından sonra ana app'in
  imzalı entitlement plist'ini `codesign -d --entitlements` ile okuyor; komut
  hatası, bozuk plist veya sözlük dışı sonuç fail-closed.
- IPA kapısı imzalı `application-identifier` değerini profile ile, imzalı team
  kimliğini beklenen `L3Z9U2B39K` ile exact-match karşılaştırıyor ve
  `get-task-allow=false` istiyor.
- Test fake imzası gerçek kanıt biçimine taşındı; başka team/application
  entitlement'ı reddi kapsandı. Paket 9/9 ve pycompile temiz; tam kalite
  kapısı 1269 test + 2 opt-in skip, analyze/format temiz geçti.
- Gerçek `build/ios/ipa/Vocalart.ipa` geçti: 1.0.0 (4), Apple Distribution,
  profile 2027-09-25, imzalı production entitlement zinciri doğrulandı.
- Upload, TestFlight/App Store sunucu kabulü veya fiziksel cihaz kurulumu
  yapılmadı.

## 2026-11-04 — FX-01 Hayalet Şerit ve Transient Hizalama

**Kullanıcı isteği:** Rakip araştırması ve 5 animasyonlu konseptten
(`design-exports/yanki-efektleri/index.html`) önerilen 1 ve 4'ü uygulamaya
taşı.

- `lib/features/melody/ghost_ribbon.dart`: `GhostRibbonData.build/fromEvidence`
  yalnız `aligned` hizalama ve `candidatesObserved` bölümlemede veri üretir.
  Bant zamanı bölümün pencere tahminidir (ölçülmüş onset değil). Kare tonu
  ham `1200·log2(f/f_ref)`; `wrongOctave` adımı ayrı renk, başarı sayılmaz.
  Çizim 1,2–3,2 sn; azaltılmış hareket ayarında anında tam.
- `MelodySessionOutcome.recording`: şerit için analiz kareleri (PCM yok).
- `lib/features/rhythm_imitation/transient_alignment.dart` ve `_Result`
  kartı: zaman çizelgesi girdilerinden bağlar; anchor ilk dokunuş.
- `RhythmImitationOutcome.referenceOnsetsMs/userOnsetsMs` (yalnız measured),
  `matchToleranceMs/onTimeToleranceMs` = `RhythmAnalysisDefaults` (120/10,
  değer değişmedi).
- Testler: `test/features/ghost_ribbon_test.dart` (3),
  `test/features/transient_alignment_test.dart` (3). 320 px/1.8× melodi
  akışında lejant taşması bulundu ve düzeltildi.

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: **1269 test + 2 skip**, analyze/format temiz.
- Ekranlar simülatör/cihazda açılıp görülmedi; gerçek ses ve mikrofonla
  denenmedi. Konsept sayfasındaki ±25 sent iç bant ve ±30/±70 ms örnek
  eşikleri koda alınmadı; mevcut toleranslar kullanıldı.

## 2026-11-04 — REL-14 IPA 1.0.0+5

- Kaynak: commit edilmemiş çalışma ağacı (REL-13 içeriği + FX-01).
- `pubspec.yaml` 1.0.0+4 → 1.0.0+5; önceki IPA `build/ios/ipa-1.0.0+4/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<REL-13 ExportOptions, destination=export,
  manageAppVersionAndBuildNumber=false>` exit 0; `build/ios/ipa/Vocalart.ipa`
  33,5 MB. Uyarı: açılış görseli Flutter varsayılanı.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: 9/9.
  `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (5), iOS 15.0,
  codesign ve imzalı entitlement doğrulandı, Apple Distribution L3Z9U2B39K,
  profile 2027-09-25.
- Upload, TestFlight, cihaz kurulumu yapılmadı (ayrı kullanıcı yetkisi).


## 2026-11-05 — RHY-UX-01 ritim tekrarı sadeleştirme

**Kullanıcı geri bildirimi (TestFlight):** hedefli tekrar sonrası çok fazla
buton/çip, sıradaki adım belirsiz; desenler kolaydan zora değil; vuruş alanı
çok büyük, altı görünmüyor; bitişi anlamak için ~3 sn beklemek gerekiyor.

- `lib/domain/content/rhythm_patterns.dart`: `RhythmPatternDifficulty` ve
  `orderedEasyToHard` — yalnız desen verisinden: yazılı zorluk, senkop
  (vuruşu boş ara giriş), ara vuruş sayısı, en kısa aralık (ms), vuruş
  sayısı; eşitlikte katalog sırası. İçerik sıralama sezgisidir, ölçüm değil.
  Ekran her kataloğu bu sırayla kullanır. Gönderilen `draftRhythmPatterns`
  ve `draftAksakPatterns` zaten bu sıradaydı (testle sabitlendi).
- `RhythmImitationController`: `followingPattern`/`advancePattern` (gezinme,
  kayıt yok), `retry()` (bitmiş denemeden aynı desen/bölümde yeni dinleme
  kotasıyla yeni deneme), `expectedTaps`, `finishWait`: tüm beklenen vuruşlar
  alınınca sessizlik süresi = en uzun referans aralığı + ±120 ms (en az
  600 ms, en çok `idleTimeout`). Eksik vuruşta 2,5 sn aynen.
- Ekran: cevap sırasında dinle kartı (dalga 96 → 64 px) + 136 px vuruş alanı +
  durum `n/N vuruş…` + `Bitirdim`. Sonuçta dinle kartı ve vuruş alanı gizlenir.
  Puanlı sonuç: özet + hizalama grafiği, tek birincil eylem (sonraki adım
  kartı ya da `Tekrar dene`), ikincil `Zor bölümü çalış`, metin bağlantıları
  (sonraki desen, puls kavramı, ölçüm ayrıntısı); vuruş çipleri ayrıntıda
  (grafik yoksa kartta kalır). Hedefli tekrar sonucu: kart içindeki yinelenen
  “Hedefli tekrar — puanlanmadı” öneki, çipler, `Tam zamanında hâlini
  göster` (`TransientAlignmentView.showSnapToggle`) ve ölçüm ayrıntısı kalktı;
  `Devam: tam deseni çal` + `Bu bölümü tekrar et` + `Sonraki desene geç`.
- Testler: `test/domain/content/rhythm_pattern_order_test.dart` (3),
  denetleyici `finishWait`/`retry`/`advancePattern` (2), ekran hedefli tekrar
  akışı (1); mevcut ekran testi yeni yerleşime uyarlandı.

### Doğrulama ve sınırlar

- `dart format --output=none --set-exit-if-changed lib test`: 376 dosya, değişiklik yok.
- `flutter analyze --no-pub`: sorun yok. `flutter test --no-pub`: **1276 geçti, 2 skip**.
- Rubrik, ±120 ms eşleşme/on-time pencereleri ve ustalık ölçütü değişmedi.
  Yakalama penceresi değişti: tam cevaptan sonra en uzun aralık + 120 ms'den
  geç gelen fazladan vuruş artık değerlendirmeye girmez (önceden “fazla”
  sayılırdı). Simülatör/cihazda görülmedi, TestFlight build alınmadı.


## 2026-11-05 — MEL-ECHO-01 ezgi tekrarı yeniden ve alkış çizimi

**Kullanıcı isteği (TestFlight):** “Ezgi tekrarı kısmını baştan yarat: önce
referans, sonra dinle, bitince desenleri karşılaştır ve kullanıcı görsün;
başarılıysa daha zor ezgilere geçsin; ezgileri çeşitlendir.” Ayrıca alkışla
ritim ekranındaki el görseli çok kötü bulundu.

### Uygulananlar

- `lib/trainer/koro/melody_echo_levels.dart`: 6 seviye × 5 ezgi (3–5 nota,
  en fazla bir oktav), `placeMelody` (aralık içine ±2 yarım ses kaydırmalı
  yerleşim, E2–C6), `echoRange` (ölçülen `koroRange` → koro partisi →
  53–69), `pickEchoMelody` (aynı ezgi arka arkaya gelmez).
- `lib/trainer/koro/melody_echo.dart`: `MelodySessionController` üstünde
  trainer görünümlü akış. Ortam ölçümü gerekiyorsa otomatik, sonra referans
  (600 ms ton + 200 ms boşluk zamanlamasıyla nota hapları yanar), 8 sn cevap,
  karşılaştırma (nota başına durum + `GhostRibbonView`, fazladan ses notu).
  Geçme = `wholeSequenceCorrect == true` ve yeniden deneme nedeni yok;
  `melodyEchoLevel` bir artar ve kaydedilir.
- `TrainerStore.melodyEchoLevel` (kayıt/okuma/sıfırlama). `koro_hub.dart`
  yeni ekranı açar (`deviceOnly`; widget testlerinde mikrofon açılmaz).
- `clap_rhythm.dart`: `_Hands` artık `_ClapPainter` — dört parmak +
  başparmaklı tek siluet avuçlar, mor manşet, bilekten dönme, temasta
  kıvılcım çizgileri.
- Test: `test/trainer/melody_echo_test.dart` (seviye kuralları, tüm
  partilerde aralık/80–1200 Hz, aralık önceliği, tekrar etmeyen seçim, sahte
  mikrofonla dinle→söyle→karşılaştır→seviye açıldı akışı, kalıcılık).

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: format/analyze temiz, **1281 test geçti,
  2 skip**.
- Ekran görüntüleri yalnız widget testi render'ı; cihazda/TestFlight'ta
  denenmedi. Akış testi sentetik sinüsle geçti; insan sesiyle (vibrato,
  kayma) `wholeSequenceCorrect` kapısının ne kadar sıkı olduğu ölçülmedi.
- Referans sentetik ton; piyano kayıtları ve eğitimci içerik onayı açık.
- Test fontunda ♭ glifi yok (yalnız test görüntüsünde kutu); cihazda sistem
  fontu düşmesiyle görünmesi beklenir, doğrulanmadı.

## 2026-11-05 — RANGE-VIS-01 aralık testi ışık izi ve klavye haritası

**Kullanıcı isteği:** Animasyon araştırmasındaki B (ışık izi) + C (klavye
haritası) seçeneklerini ses aralığı testine uygula.

### Uygulananlar

- `lib/domain/audio/live_pitch_tracker.dart`: halka tampon, 16 kHz'e ortalama
  ile indirme, 1024 örneklik pencere, 320 örnek adım; yalnız gösterim.
- `PluginAudioLabBackend(livePcm: true)`: `startStream` (pcm16, 48 kHz),
  parçalara bölünmüş baytları taşır, RMS dBFS seviye, `liveSamples`; durdurunca
  aynı sahipli `recording.wav` dosyasını yazar (bütçe `readLabWav` ile aynı).
  Varsayılan (`false`) yol değişmedi.
- `range_test.dart`: `LivePitchProbe` arayüzü, `MicRangeProbe` canlı perde
  akışı; ekran izi tutar (deneme başına en fazla 150 nokta), eşleşmede 0,9 sn
  parlama. `range_visuals.dart`: `PitchTrail`, `KeyboardMap`.
  `_Staircase` kalktı.
- Test: `test/domain/live_pitch_tracker_test.dart` (220 Hz ±10 sent, sessizlik,
  sıfırlama).

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: **1283 test geçti, 2 skip**; format/analyze
  temiz. Görünüm yalnız widget testi render'ıyla kontrol edildi.
- Cihazda/TestFlight'ta denenmedi; PCM akış kaydı ile eski dosya kaydının
  aynı analiz sonucunu verdiği gerçek mikrofonla karşılaştırılmadı.

## 2026-11-05 — ECHO-TRAIN-01 alkış eğitimi, canlı ezgi grafiği, dokunma sesi

**Kullanıcı isteği (simülatör):** Ezgi söylerken ses ve olması gereken
grafik aynı anda çizilsin; alkış sesi düzgün olsun, alkıştan sonra "sıra
sende" denip kullanıcı tekrar etsin; alkış ve ritim tekrarı eğitim modülü
olsun; ritim tekrarında dokundukça "tak" sesi çıksın; sıra kullanıcıya
geçince açık bir işaret verilsin.

### Uygulananlar

- `LiveSampleSource` (audio_capture), `PluginAudioLabBackend` ve
  `SyntheticMelodyBackend` uygular; ezgi kaydı `livePcm: true`.
- `melody_echo.dart`: `_EchoGraph` (referans bantları + canlı iz, örnek
  sayımıyla 20 ms zaman), oktav uyarlama (`_octaveAway`, ±350 sent içinde
  tam oktav), "çok pes/tiz" etiketi, `GhostRibbonView` kaldırıldı.
- `clap_onset_detector.dart`, `clap_rhythm.dart` (yeni sentez, sayım,
  `ClapListener`/`MicClapListener`, `clapRhythmsEasyToHard`, karşılaştırma
  çizimi, seviye), `your_turn.dart` (`YourTurnCue`, `renderGoCue`),
  `tap_sound.dart` (+ `RhythmImitationScreen.tapSound`).
- Testler: dedektör (sentetik alkış ±10 ms, ısınma, sessizlik/uğultu),
  alkış akışı (dinle→sayım→sıra sende→alkış→seviye), zorluk sırası.

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: **1287 test geçti, 2 skip**.
- Simülatörde alkış ekranı, sayım ve "Sıra sende" bandı görüldü; ilk
  denemede mikrofon açılışı 1 sahte alkış saydı → 150 ms ısınma eklendi
  (cihazda doğrulanmadı). Gerçek el alkışı, hoparlör sızıntısı, kulaklık ve
  farklı odalarda dedektör eşikleri ölçülmedi; ritim tekrarı dokunma sesinin
  gecikmesi ölçülmedi.


## 2026-11-05 — FX-02 alkış kutlaması (etkileşim 1/3)

**Kullanıcı isteği:** Ses/aralık uygulamalarında top 5 tasarım incelemesi ve
göz dolduran animasyon seçenekleri; ardından alkış kutlaması, seviye
görselleştirici ve gerçek alkış algılamanın birer birer yapılması. İstenen
"Flutter Animations" skill'i makinede kurulu değildi; yerleşik Flutter
API'leri kullanıldı.

### Uygulananlar

- `docs/design/motion_lab.html`: Yousician, Simply Sing, Smule, Singing
  Carrots, Vanido incelemesi; 6 canlı prototip (kuyruklu yıldız şeridi,
  kilitlenen halka, ışık sütunlu klavye, nefes alan dinleme, kroma çarkı,
  aralık sonucu), katman/araç tablosu ve hareket token'ları. Ses simüle.
- `lib/trainer/ui/applause_burst.dart`: `ApplauseBurst(shot:, child:)`;
  `shot` artınca bir kez çalar, aynı değerle yeniden çizimde tekrar etmez.
  Yay rozeti, 3 dalga halka + konfeti (`ApplausePiece`, sabit tohum),
  dokunsal, azaltılmış hareket yolu, `RepaintBoundary` + `IgnorePointer`,
  semantik dışı (ekranın canlı bölge metni duyurulur).
- `lib/trainer/koro/clap_rhythm.dart`: `_cheers` sayacı yalnız
  `_passed(result)` doğruyken artar; `_Hands` `ApplauseBurst` içine alındı.
- `test/trainer/applause_burst_test.dart`: gizli başlangıç, tek oynatma ve
  temizlenme, yay aşımı, dokunsal sırası, iki dokunsal kapısı, azaltılmış
  hareket, konfeti tekrarlanabilirliği/yerçekimi.

### Değerlendirme

- Lottie: tasarımcı dosyası ve paket gerekir, veri bağlama yok. Rive: data
  binding güçlü ama `.riv` varlığı ve paket gerekir. Yerel `CustomPainter`
  + `SpringSimulation` en basit, test edilebilir ve bağımlılıksız.

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: **1299 test + 2 skip temiz (format, analyze, test)**.
- Fiziksel iPhone'da görülmedi; dokunsal his, 120 Hz kare süresi ve gerçek
  alkışla tetiklenme kanıtsız. Alkış algılama hâlâ enerji onseti
  (`ClapOnsetDetector`); bu genlik eşiği alkış sınıflandırması değildir.

## 2026-11-05 — FX-03 Shazam tarzı dinleme küresi (aralık testi)

**Kullanıcı isteği:** Ses aralığı testinin dinleme kısmında Shazam benzeri,
yumuşak ve gerçekçi, mikrofon genliğine tepki veren dinleme animasyonu.
ShazamKit/müzik tanıma yok. Commit yapılmadı.

### Uygulananlar

- `lib/trainer/ui/audio_reactive_orb.dart`: `AudioReactiveOrb`
  (`phase`, `levelDb`, `size`, `rings` 4–6, `icon`, `onTap`,
  `semanticLabel`, `detectDb`), `OrbPhase`, saf `orbAmplitude` (dBFS → 0–1)
  ve `emaStep` (dt tabanlı, asimetrik zaman sabiti). Halkalar faz
  entegrasyonuyla akar, hız genlikle değişse de sıçramaz; renkler ~0,25 sn'de
  fazlar arası geçer. Durum `ChangeNotifier` modelinde; çizim
  `CustomPainter(repaint:)`, glif `AnimatedBuilder` ile ölçeklenir.
- `lib/trainer/koro/range_test.dart`: rahat ses sayfası ve dinleme sayfası
  küreyi gösterir (aynı konumda, geçiş yumuşak); merdivende 22 px ikon
  yerine 136 px küre (çalarken idle + hoparlör, dinlerken listening, tutunca
  completed, dönüşte ok). Seviye mevcut `RangeProbe.levelDb` akışı.
- `test/trainer/audio_reactive_orb_test.dart`: genlik eşlemesi, kare
  hızından bağımsız EMA, hızlı yükseliş/yavaş bırakış, animasyon + temiz
  dispose, azaltılmış harekette saat durması, etiketli düğme.
- `test/trainer/range_ladder_test.dart`: rahat ses sayfasında
  `pumpAndSettle` yerine sabit pump (idle küre sürekli nefes alır).

### Doğrulama ve sınırlar

- `flutter analyze --no-pub`: sorun yok. `flutter test --no-pub`:
  **1298 geçti, 2 skip, 1 hata** — hata eşzamanlı FX-02 oturumunun
  `applause_burst_test.dart` testi; `dart tool/quality_check.dart` formatı
  da yalnız o oturumun `applause_burst.dart` dosyasında durdu.
- Test içinde PNG'ye çizilip dört durum gözle kontrol edildi.
- Fiziksel iPhone'da görülmedi: kare süresi, gerçek sesle tepki ve
  `detectDb` (−38 dBFS) eşiği kanıtsız; seviye cihazlar arası kalibre değil.

- Fiziksel iPhone (kablosuz, iOS 27.2) için yerel release build kuruldu
  (1.0.0 build 5). İlk deneme Xcode build veritabanı disk I/O hatasıyla
  düştü; `flutter install` bu sırada eski uygulamayı kaldırdı, yerel veri
  kaybolmuş olabilir. Proje DerivedData önbelleği temizlenip yeniden
  build edildi. Kurulum cihaz kabulü değildir; his/dokunsal kullanıcı
  denemesini bekliyor.

## 2026-11-05 — FX-04 ses dalgaları, aralık testi dinleme anı

**Kullanıcı isteği:** Dinleme anında efekt notayla paralel hareket etsin;
"ucube" küre yerine profesyonel tasarım. 15 canlı taslak üretildi, kullanıcı
"ses dalgaları"nı seçti ve daha akışkan/etkili olmasını istedi. Commit yok.

### Uygulananlar

- `docs/design/range_listening_lab.html`: A–O, J+/O+, O1–O3 ve seçilen
  "son hâl" taslakları; ortak simüle ses, elle perde/güç sürgüleri, krem ve
  mor sahne zemini. Taslak sayfası olarak yayınlandı (özel bağlantı).
- `lib/trainer/koro/voice_waves.dart`: `OneEuroFilter`, `WaveSample`,
  `WaveTrack` (120 Hz sabit örnek, kare arası enterpolasyon, 6 sn pencere),
  `waveLock`/`waveColor` (ton üzerinden renk karışımı), `VoiceWaves`
  (`AnimationController` saati, `CustomPainter(repaint:)`,
  `RepaintBoundary`, azaltılmış harekette faz sabit).
- `lib/trainer/koro/range_test.dart`: merdivende küre kaldırıldı, ikon +
  başlık satırı geri geldi; `PitchTrail` yerine `VoiceWaves` (çalarken
  `reference`, dinlerken canlı perde + seviye, eşleşmede `flash`).
- `lib/trainer/koro/range_visuals.dart`: kullanılmayan `PitchTrail`
  silindi; `KeyboardMap` ve `rangeTracePoints` duruyor.
- `test/trainer/voice_waves_test.dart`: titreme bastırma, kayma takibi,
  reset, kare hızından bağımsız örnek sayısı, enterpolasyon/pencere,
  "notada" eşiğinin gerçek `judgeRangeTake` ile uyumu, widget yaşam döngüsü.

### Doğrulama ve sınırlar

- `flutter analyze --no-pub` temiz; `dart format` temiz; tam test
  **1306 geçti, 2 skip**.
- 1€ parametreleri sentetik ±6 sent titremeyle ayarlandı (gerçek perde
  izleyicisinin gürültüsüyle değil).
- Simülatörde piyano dalgası görüldü; ses dalgası test içi PNG ile kontrol
  edildi. Gerçek iPhone, gerçek ses ve 120 Hz his doğrulanmadı.

## 2026-11-05 — FX-05 nabız dizisi, aralık testi nota haritası

**Kullanıcı isteği:** Merdivendeki klavyeyi değiştir; notalar tize ve pese
giderken işaretlensin; estetik ve profesyonel. 20 canlı taslak üretildi
(`docs/design/range_map_lab.html`), kullanıcı 15 "Nabız dizisi"ni seçti.
Commit yok.

### Uygulananlar

- `lib/trainer/koro/pulse_chain.dart`: `ChainMark`, `ChainPhase`,
  `chainMarks(log)` (tutturulan kalır; yoksa son kaçırma/yanlış oktav),
  `PulseChain` (AnimationController saati, yay fiziği, efekt listesi,
  `RepaintBoundary`, azaltılmış harekette dalga/nabız/efekt yok).
- `lib/trainer/koro/range_test.dart`: `_LadderKeys` yerine `_LadderChain`;
  geri bildirimde hedef `last.targetMidi` (hem zincir hem dalgalar).
- `test/trainer/pulse_chain_test.dart`: işaret kuralları; tüm aşamalarda
  çizim ve temiz dispose.

### Doğrulama ve sınırlar

- `flutter analyze --no-pub` temiz; `dart format` temiz; tam test
  **1308 geçti, 2 skip**.
- Simülatörde piyano aşaması, dönüş ve kaçırma işareti görüldü; simülatör
  mikrofonu sessiz olduğundan tutturma görünümü test içi PNG ile kontrol
  edildi. Gerçek cihaz ve sesle doğrulanmadı.

## 2026-11-05 — REL-11f paketlenmiş privacy manifest kapısı

- `verify_app_privacy_manifest`, ana app'in `PrivacyInfo.xcprivacy` dosyasını
  bounded IPA girdisinden plist olarak okuyor; eksik/bozuk dosya reddediliyor.
- Ürün sözleşmesi artifact seviyesinde exact: `NSPrivacyTracking=false`, boş
  tracking-domain ve collected-data listeleri, yalnız FileTimestamp /
  `C617.1` required-reason API beyanı.
- Eksik manifest, tracking, toplanan veri ve yanlış reason senaryoları eklendi;
  Python doğrulayıcı paketi 11/11 ve pycompile temiz. Tam kalite kapısı 1308
  test + 2 opt-in skip, analyze/format temiz geçti.
- Gerçek `build/ios/ipa/Vocalart.ipa` geçti: 1.0.0 (5), App Store imzası,
  entitlement zinciri ve paketlenmiş privacy manifest doğrulandı.
- Bu kapı mağaza gizlilik formunu, hukuk incelemesini, upload'ı veya cihaz
  kabulünü tamamlamaz.

## 2026-11-05 — REL-11g device mimarisi kapısı

- `verify_device_architectures`, bounded extraction sonrasında ana app ve
  doğrudan gömülü `.framework` bundle'larının Info.plist/executable bağını
  doğrulayıp `lipo -archs` çalıştırıyor.
- Her executable exact `arm64` olmalı; eksik/bozuk bundle, x86_64 simulator
  slice veya universal/karışık architecture fail-closed.
- Eksik ve simulator architecture kanıtı testleriyle Python paketi 12/12;
  pycompile ve `git diff --check` temiz.
- Gerçek 1.0.0 (5) IPA geçti: Runner, App.framework, Flutter.framework ve
  objective_c.framework — toplam 4 Mach-O bundle yalnız arm64.
- Bu yerel artifact kapısı App Store sunucu kabulü, upload veya fiziksel cihaz
  çalışma/performance kanıtı değildir.

## 2026-11-06 — FX-06 "sıra sende" sahnesi, aralık testi

**Kullanıcı isteği:** "Şimdi sen söyle" anlaşılır değil; ekran büyüsün,
söylerken ses dalgası belirginleşsin, ilerleme söyleme bitince görünsün.
5 animasyonlu akış taslağı üretildi; kullanıcı 01 "Sahne büyür"ü seçti.
Commit yok.

### Uygulananlar

- `lib/trainer/koro/range_test.dart`: `_LadderView` içeriği
  `TweenAnimationBuilder` ile dinleme aşamasına göre canlanır (azaltılmış
  harekette anında); `_TurnCue` (mercan çip + açıklama, `range_title`
  anahtarı) ve `_TakeTimer` (yalnız gösterge geri sayım); dizi ve sayaç
  aynı yuvayı paylaşır, ekran zıplamaz.
- `lib/trainer/koro/voice_waves.dart`: 7 örnekten kısa parçalar çizilmez.
- `test/trainer/range_ladder_test.dart`: söyleme anında ipucu ve
  açıklama görünür, dizi gizli; sonuçta dizi geri gelir.
- `docs/design/range_scene_lab.html`: 5 akış taslağı.

### Doğrulama ve sınırlar

- Analyze ve format temiz; tam test **1309 geçti, 2 skip**.
- Simülatörde piyano, sıra sende ve geri sayım görüldü. Gerçek ses ve
  cihazla doğrulanmadı.

## 2026-11-06 — REL-15 IPA 1.0.0+6

- Kaynak: commit 915049b (FX-06 dahil). Çalışma ağacında başka oturumun
  commit edilmemiş doğrulayıcı/belge değişiklikleri vardı; uygulama kodu
  commit ile aynı.
- `pubspec.yaml` 1.0.0+5 → 1.0.0+6; önceki IPA `build/ios/ipa-1.0.0+5/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=build/ios/ipa-1.0.0+5/ExportOptions.plist` exit 0;
  `build/ios/ipa/Vocalart.ipa` 33,2 MB. Uyarı: açılış görseli varsayılan.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: 12/12.
  `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (6), iOS 15.0,
  imza, imzalı entitlement, privacy manifest, cihaz mimarisi; Apple
  Distribution L3Z9U2B39K, profile 2027-09-25.
- Upload, TestFlight, cihaz kurulumu yapılmadı (ayrı kullanıcı yetkisi).

## 2026-11-05 — ONB-ROLE-02 çoklu rol seçimi

- Onboarding rol adımı `multi: true`; seçimler `answers['role']` listesinde.
- `TrainerStore.roles` eski tek-string kaydı da okur; `inChoir` Koro sekmesi
  (`home_shell.dart`) ve Hazır özetinde kullanılır.
- Rol eğitim paketini/rotayı değiştirmez; odak (`focus`) ilk trainer'ı seçer.
- `dart tool/quality_check.dart`: format/analyze temiz, 1309 test geçti, 2 skip.
- Açık: cihazda MIC-01 sessiz odada −18 dBFS "ortam gürültülü" raporu
  (kullanıcı gözlemi); eşik değiştirilmedi.

## 2026-11-05 — MIC-02 gürültü tabanı tanı değerleri

- Kullanıcı gerçek iPhone'da sessiz odada "Ortam gürültülü, −18 dBFS" gördü.
  WAV okuma (`Pcm16Wav.decode`) ve 20 ms RMS yolu incelendi, hata bulunmadı.
- `NoiseFloorCalibration` artık yalnız tanı amaçlı `dcOffset`, `peakDb`,
  `centredFloorDb` (DC çıkarılmış medyan) taşır; `toJson`'a eklendi. Status,
  eşikler (−45 dBFS, 12 dB burst) ve skor **değişmedi**.
- Mikrofon testi sonuç kartında ikinci satır: DC · tepe · DC'siz taban ·
  giriş › çıkış route.
- Testler: sabit ofsetli sentetik sessizlik tooNoisy kalır ama DC'siz taban
  ≈ −60 dBFS görünür; analiz edilmeyen girdide tanı null. Tam kapı 1311 test
  geçti, 2 skip; format/analyze temiz.
- Açık: kök neden cihazda tekrar ölçümle belirlenecek (DC mi, hoparlörden çalan
  ses mi, gerçek gürültü mü). Sentetik test cihaz kapısını geçmez.

## 2026-11-05 — REL-16 IPA 1.0.0+7

- Kaynak: commit 915049b + commit edilmemiş ONB-ROLE-02 (çoklu rol) ve MIC-02
  (mikrofon testi tanı satırı). Commit oluşturulmadı.
- `pubspec.yaml` 1.0.0+6 → 1.0.0+7; önceki IPA `build/ios/ipa-1.0.0+6/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=build/ios/ipa-1.0.0+6/ExportOptions.plist` exit 0;
  `build/ios/ipa/Vocalart.ipa` 33,5 MB. Uyarı: açılış görseli varsayılan.
- `python3 -I scripts/release/test_verify_ios_ipa.py`: 14/14.
  `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (7), iOS 15.0,
  imza, entitlement, privacy manifest, cihaz mimarisi; Apple Distribution
  L3Z9U2B39K, profile 2027-09-25.
- Yüklenmedi; TestFlight/cihaz kurulumu kullanıcıda. Yerel artifact kapısı
  cihaz veya mikrofon kanıtı değildir.

## 2026-11-05 — FX-07 ses dalgası kararlılığı + aralık sıralaması araştırması

- Sorun (kullanıcı, cihaz): ses verilince dalganın sol (geçmiş) tarafı
  titriyor. Neden: painter geçmişi her karede sabit 4 px ekran adımlarında
  yeniden örnekliyordu; şekil ve cümle kenarları ±4 px "sürünüyordu".
- `WaveTrack` artık örneklere kaymayan id verir (`newestId`, `byId`,
  `ageOf`); painter geçmişi her 6. örneğe (id ile, ≈3 px) sabitler, her nokta
  kendi anıyla sola kayar. Kısa cümle eşiği nokta sayısı yerine 24 px iz.
- Altı dalga katmanı artık hep sağdan sola, izin hızına yakın (0,85–1,30×
  parallax) akar; önceden tek/çift katmanlar ters yönlere gidiyordu.
- Test: id'ler pencere düşerken kaymaz, yaş düzenli artar. Tam kapı 1312
  test + 2 skip, analyze/format temiz. Akıcılık cihazda görülmedi.
- Sıralama/puan: araştırma yapıldı, kod yok. Rubrik ve "sıralama"
  karşılaştırma tabanı kullanıcı kararı bekliyor (kişisel geçmiş / literatür
  bandı / gerçek kullanıcılar — sonuncusu sunucu + izin gerektirir).
  Referans: eğitimsiz yetişkin şarkı aralığı ≈12–18 yarım ton; 1972 ASHA
  çalışmasında şarkıcı olmayanlar ≈18, şarkıcılar ≈23 yarım ton (modal).

## 2026-11-05 — RANGE-04 aralık puanı, kişisel sıralama, bilgi penceresi

- Kullanıcı kararı: "optimum şekilde hesapla" + nasıl hesaplandığı bilgi
  butonuyla popup'ta. Seçilen: puan + kişisel sıralama + araştırma bandı;
  başka kullanıcılarla sıralama yok (sunucu/izin yok).
- `lib/trainer/koro/range_score.dart`: puan = 0,60·genişlik + 0,25·isabet +
  0,15·ilk deneme (her biri 0–100). Genişlik = yarım ses / 36 (3 oktavda
  tavan). İsabet = eşleşen alımların ortalama `closeness` değeri. İlk deneme =
  öncesinde ölçülmüş ıskalama olmadan eşleşen nota oranı; `unmeasured` aleyhe
  sayılmaz. Octave-off/missed/unmeasured hiç eşleşme sayılmaz. Merdiven eşiği
  ve toleranslar değişmedi.
- Araştırma bandı (sıralama değil): <12 dar, 12–18 eğitimsiz yetişkin için
  tipik, 19–22 tipikten geniş, ≥23 şarkıcı ortalaması (JSHR 1972: şarkıcı
  olmayan ≈18, şarkıcı ≈23; örneklem küçük).
- `TrainerStore.rangeScores` (son 50, 0–100, kalıcı); `personalRank` eşitlikte
  daha iyi sırayı verir.
- Sonuç ekranı: "ARALIK PUANI" kartı (puan/100, üç çubuk, kişisel sıra, bant)
  ve ⓘ butonu → hesaplamayı bu testin sayılarıyla açıklayan AlertDialog.
- Testler: `range_score_test.dart` (ağırlıklar, parçalar, unmeasured, sıra,
  kalıcılık) + akış testinde puan 62, popup açılıp kapanıyor. Tam kapı 1321
  test + 2 skip, format/analyze temiz.
- Sınırlar: ağırlıklar ve 36 yarım ton tavanı benchmark değil, ürün kararı;
  insan/eğitmen holdout ile doğrulanmadı. Cihazda görülmedi.

## 2026-11-05 — REL-17 IPA 1.0.0+8

- Kaynak: commit 915049b + commit edilmemiş ONB-ROLE-02, MIC-02, FX-07
  (dalga kararlılığı) ve RANGE-04 (aralık puanı/sıra/bilgi penceresi).
- `pubspec.yaml` 1.0.0+7 → 1.0.0+8; önceki IPA `build/ios/ipa-1.0.0+7/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=build/ios/ipa-1.0.0+7/ExportOptions.plist` exit 0;
  `build/ios/ipa/Vocalart.ipa` 33,5 MB.
- `test_verify_ios_ipa.py` OK; `verify_ios_ipa.py --pubspec pubspec.yaml`:
  passed — 1.0.0 (8), iOS 15.0, imza, entitlement, privacy manifest, cihaz
  mimarisi; Apple Distribution L3Z9U2B39K, profile 2027-09-25.
- Yüklenmedi; cihaz/mikrofon kanıtı değildir.

## 2026-11-06 — REL-11j iOS izin/ürün beyanı kapısı

- `verify_ios_product_contract`, paketlenmiş ana Info.plist'i iPhoneOS device
  platformu/SDK, `LSRequiresIPhoneOS`, arm64 capability ve exact en+tr
  localization sözleşmesine bağlıyor.
- Beklenmeyen `UIBackgroundModes` ve `NSAllowsArbitraryLoads=true` reddedilir.
- Root, `en.lproj` ve `tr.lproj` InfoPlist metinlerindeki mikrofon açıklaması
  yalnız kullanıcı kayıt başlatınca cihazda kayıt/dinletme ürün beyanıyla exact
  eşleşir; eksik veya generic metin fail-closed.
- Simulator platformu, background audio, eksik localization ve değişmiş izin
  metni testleriyle Python paketi 16/16; pycompile temiz.
- Gerçek 1.0.0 (8) IPA izin/ürün kapısından geçti. Fiziksel izin diyaloğu,
  kalıcı ret → Ayarlar dönüşü, upload ve App Store kabulü yapılmadı.

## 2026-11-06 — FX-08 parçacık akışı, aralık testi

**Kullanıcı isteği:** Ses aralığı ekranındaki ses dalgasını sakin bir
"Parçacık akışı" ile değiştir; ekran düzeni, nota çizgileri, hedef bandı ve
test akışı korunsun; önizlemede hedefin altından A3'e yaklaşıp 3 sn kalan
demo, gerçek mikrofon verisinden ayrı. Commit yok.

### Uygulananlar

- `lib/trainer/koro/particle_flow.dart`: `ParticleFlow` (VoiceWaves ile aynı
  girdiler + `pitchSerial`, `holdSeconds`). 1024'lük sabit havuz, tek
  `drawVertices` çağrısı (yumuşak kenarlı altıgen parçacık), kare başına
  ayırma yok. `PitchSpikeGate` (≥150 sent sıçrama 3 tahminle onaylanır),
  1€ filtresi, `waveLock` ve `voiceWavesOnNoteCents` `voice_waves.dart`'tan
  paylaşılır. `flowColor`: mor → yumuşak yeşil (TC.teal) ton rampası.
  Ses şiddeti yalnız yayım hızı/yayılma; dikey konum yalnız perde. Ses yokken
  yayım yok, filtre 0,15 sn sonra sıfırlanır, her şey söndüğünde ticker durur.
  ✓ yalnız `flash` (kaydın gerçek yargısı) ile; halka hedefteki süreyi
  gösterir, başarı değildir. Azaltılmış harekette parçacık/hale çizilmez.
- `lib/trainer/koro/range_test.dart`: `VoiceWaves` → `ParticleFlow`;
  `pitchSerial: trace.length`, `holdSeconds` = `_takeLength`.
- `lib/trainer/koro/particle_flow_demo.dart`: `ParticleFlowDemoScript`
  (0,4 sn sessizlik, 1,8 sn A3'ün 2,6 yarım ton altından yükseliş, 3 sn
  tutuş, 1,6 sn dinlenme; döngü), `ParticleFlowDemo` ("DEMO · ÖRNEK VERİ"),
  `@Preview`. Uygulama tarafından içe aktarılmaz.
- `test/trainer/particle_flow_test.dart`: sıçrama kapısı, renk uçları, demo
  senaryosu (3 sn pencere içinde, ✓ tutuş bitmeden yok), widget çizimi ve
  sessizlikte ticker'ın durması, azaltılmış hareket, demo önizlemesi.

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: format/analyze temiz, **1329 geçti, 2 skip**.
- Demo kareleri (1,7 / 4,0 / 5,4 sn) test ortamında PNG olarak render edilip
  incelendi: mor başlangıç, A3'te yeşil dengelenme, ✓ yalnız tutuş sonrası.
- Gerçek ses, mikrofon, cihaz performansı ve ekran okuyucu ile
  doğrulanmadı. Sıçrama kapısı eşikleri insan sesi benchmark'ı değildir.
- `voice_waves.dart` içindeki `VoiceWaves` widget'ı artık ekranda
  kullanılmıyor; filtre/kural kaynağı ve mevcut testleri için yerinde
  bırakıldı.

## 2026-11-06 — REL-18 IPA 1.0.0+9

- Kaynak: commit 915049b + commit edilmemiş çalışma ağacı (FX-08 parçacık
  akışı dahil). Öncesinde tam kalite kapısı 1329 geçti, 2 skip.
- `pubspec.yaml` 1.0.0+8 → 1.0.0+9; önceki IPA `build/ios/ipa-1.0.0+8/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=build/ios/ipa-1.0.0+8/ExportOptions.plist` başarılı;
  `build/ios/ipa/Vocalart.ipa` 33,2 MB. Uyarı: açılış görseli varsayılan.
- `test_verify_ios_ipa.py` 16/16; `verify_ios_ipa.py --pubspec pubspec.yaml`:
  passed — 1.0.0 (9), iOS 15.0, imza, entitlement, izin beyanı, 8 privacy
  manifest, 4 Mach-O bundle; Apple Distribution L3Z9U2B39K, profile
  2027-09-25.
- Aynı kaynak release olarak iPhone'a (kablosuz) kurulup açıldı; parçacık
  akışı gerçek sesle henüz değerlendirilmedi. Yüklenmedi, TestFlight yok.

## 2026-11-06 — UI-01c markalı iOS açılış ekranı

- `ios/Runner/Base.lproj/LaunchScreen.storyboard`: varsayılan Flutter
  `LaunchImage` kaldırıldı; native, ortalanmış sistem yazısıyla patlıcan
  `Vocalart`, lime vurgu çizgisi ve krem `LaunchBackground` eklendi.
- `LaunchBackground.colorset` açık tema rengi `#F8F5EF` olarak marka
  paletiyle eşlendi. Kullanılmayan eski LaunchImage asset dosyaları silinmedi;
  storyboard artık onları referanslamıyor.
- `release_identity_test.dart` marka metnini, renkleri, named background'u ve
  `LaunchImage` referansı bulunmadığını fail-closed denetliyor.
- Doğrulama: `ibtool` hata/uyarı/notices vermeden derledi; `flutter build ios
  --simulator --debug --no-codesign --no-pub` başarılı; `flutter analyze
  --no-pub` temiz; hedef test 4/4. Tam `dart tool/quality_check.dart`: **1330
  geçti, 2 opt-in skip**, format/analyze temiz.
- Fiziksel cihazda yeni launch görünümü izlenmedi. REL-18 imzalı 1.0.0+9 IPA
  bu değişiklikten önce üretildi; UI-01c'yi içermez. Yeni imzalı artifact,
  upload veya TestFlight yapılmadı.

## 2026-11-06 — UI-01d Android launch eşitliği ve iOS koyu tema kontrastı

- Android 11 ve öncesi `launch_background.xml` dosyaları artık marka
  foreground simgesini yoğunluğa duyarlı olarak merkezliyor; Android 12+
  açık/koyu `LaunchTheme`, `windowSplashScreenAnimatedIcon` ve icon background
  rengini explicit tanımlıyor. Açık launch rengi `#F8F5EF` ile iOS krem
  yüzeyine eşlendi; gece rengi mevcut `#0F1022` olarak kaldı.
- iOS storyboard sabit metin/vurgu RGB'leri yerine `LaunchBrand` ve
  `LaunchAccent` named color asset'lerini kullanıyor. `LaunchBrand` koyu
  görünümde krem olduğundan patlıcan metin koyu zeminde kaybolmuyor.
- `release_identity_test.dart` iOS dynamic renk sözleşmesini, Android legacy
  simge katmanlarını ve Android 12+ explicit splash özniteliklerini doğruluyor:
  5/5 hedef test geçti. `ibtool` hata/uyarı/notices yok; analyze temiz.
- İlk debug APK denemesi kaynak hatası olmadan disk doluluğunda durdu. İmzalı
  IPA klasörlerine dokunulmadan yalnız yeniden üretilebilir
  `.dart_tool/flutter_build`, `build/test_cache` ve Android intermediates
  temizlendi; ikinci derleme başarılı: `build/app/outputs/flutter-apk/app-debug.apk`.
  `aapt2 dump resources`, krem/koyu launch renklerini, foreground kaynaklarını
  ve v31/v31-night splash özniteliklerini paket içinde doğruladı.
- Tam `dart tool/quality_check.dart`: format/analyze temiz, **1331 geçti,
  2 opt-in skip**. Fiziksel Android/iOS açık-koyu görünümü, imzalı release
  APK/AAB, UI-01c/d içeren yeni IPA ve mağaza kabulü yapılmadı.

## 2026-11-06 — REL-19 yerel Android beta release APK ve izin daraltma

- `ORG_GRADLE_PROJECT_allowDebugReleaseSigning=true flutter build apk
  --release --dart-define=RESONIA_CHANNEL=beta --no-pub` ile yerel release
  varyantı üretildi. Bu explicit istisna olmadan gerçek keystore yoksa Gradle
  fail-closed kalıyor.
- İlk artifact denetimi, ana manifestte istenmeyen fakat `open_filex` ve
  Media3'ten birleşen READ_EXTERNAL_STORAGE, READ_MEDIA_IMAGES/VIDEO/AUDIO ve
  ACCESS_NETWORK_STATE izinlerini buldu. Koro dosya seçimi seçilen girdiyi
  `ChoirStore.addMedia` ile app-owned alana kopyaladığı, oynatma/açma bu kopyayı
  kullandığı için geniş medya izinleri gerekmiyor. Main manifest bunları
  `tools:node="remove"` ile çıkarıyor; mikrofon, reboot, titreşim ve bildirim
  izinleri korunuyor.
- Yeniden üretilen `build/app/outputs/flutter-apk/app-release.apk`:
  76.452.708 byte; SHA-256
  `cd937d250d113b26a52df1747016e8ed0a3daa0bc7ceb377b8629204108ead12`.
  `aapt`: `com.mennansevim.vocalart`, 1.0.0+9, minSdk24/targetSdk36 ve exact
  izin listesi. `apksigner`: tek signer, v2 doğrulandı, sertifika
  `C=US, O=Android, CN=Android Debug`. `aapt2`: UI-01d açık/koyu splash
  renkleri ve v31 icon öznitelikleri artifact içinde.
- Kaynak sözleşmesi 5/5, analyze temiz; tam `quality_check`: **1331 geçti,
  2 opt-in skip**, format/analyze temiz. Debug sertifikalı APK mağazaya
  yüklenemez. Gerçek keystore ile AAB, Play kabulü, fiziksel dosya seç/aç,
  bildirim/reboot/mikrofon ve launch QA yapılmadı.

## 2026-11-06 — FX-09 nefes akışı, nefes egzersizi

**Kullanıcı isteği:** Nefes egzersizi için derin nefes al · tut · bırak
animasyonu; aralık testindeki parçacık akışı kalitesinde ve uygulamanın
çekirdek efektlerinden biri olsun. Commit yok.

### Uygulananlar

- `lib/trainer/ui/breath_flow.dart`: `BreathKind`, `BreathStep`, saf
  `breathAt` (adım, adım içi ilerleme, sinüs eğrili doluluk; tut önceki
  adımın doluluğunu korur) ve `BreathFlow` widget'ı. Rehberin 100 ms'lik
  saati ile arasında ≤0,12 sn önde akan pürüzsüz iç saat; 0,3 sn'den büyük
  farkta senkron. Al/tut/ver için ayrı parçacık davranışı, `flowColor` ile
  mor → mavi-yeşil → yumuşak yeşil, ince adım halkası, `@Preview`.
- `lib/trainer/prepare/breath_screen.dart`: `BreathPhase.kind`; `_RingPainter`
  yerine `BreathFlow` (sayı ve fiil kürenin ortasında, semantik etiket aynı).
  Zamanlayıcı, haptik, duraklatma ve tamamlama mantığı değişmedi.
- `test/trainer/breath_flow_test.dart`: doluluk eğrisi, sıçramasızlık, döngü,
  boş tutma; çalışırken animasyon, duraklat/bitti/azaltılmış harekette
  ticker'ın durması.

### Doğrulama ve sınırlar

- `dart format --output=none --set-exit-if-changed lib test` temiz; tam test
  **1337 geçti, 2 skip**. `flutter analyze` ve `quality_check` format adımı
  yalnız bu işe ait olmayan commit edilmemiş
  `tool/brand/render_icons_test.dart` için uyarı veriyor; dokunulmadı.
- Al/tut/ver kareleri test ortamında render edilip incelendi. Cihazda,
  gerçek kare hızında ve eğitimci onaylı nefes deseniyle görülmedi.


## 2026-11-06 — FX-10 noktalı nefes halkaları

**Kullanıcı isteği:** Nefes egzersizi animasyonu, ses analizindeki halka
efekti kalitesinde yuvarlak halkalar kullansın; Apple Watch tarzı noktalardan
oluşan halka olabilir. Commit yok.

### Uygulananlar

- `lib/trainer/ui/breath_flow.dart`: parçacık havuzu ve `drawVertices`
  kaldırıldı. Yeni çizim: yumuşak parıltı, sayının okunduğu açık orta disk,
  60 noktalı adım kadranı (ilerleme noktaları renge döner, öndeki büyür),
  her biri 44 noktalı 4 akan halka (yolun ortasında en parlak, uçlarda
  söner; komşu halkalar ters yönde yavaş döner, nokta boyunda dalga).
  Akış hızı al −0,32, tut 0,03, ver 0,26 (yol payı/sn), EMA ile değişir;
  `motion` duraklatınca 0'a iner, `settled` ile ticker durur. Kamu API'si
  (`BreathFlow`, `breathAt`, `BreathKind`, `BreathStep`) aynı.
- `test/trainer/breath_flow_test.dart`: duraklatma testinin adı yeni
  davranışa göre güncellendi; 6 test geçti.

### Doğrulama ve sınırlar

- Format temiz; tam test **1337 geçti, 2 skip**. `flutter analyze` yalnız
  bu işe ait olmayan `tool/brand/render_icons_test.dart` bilgisini veriyor.
- 2,0 / 3,9 / 5,0 / 8,0 / 11,5 sn kareleri test ortamında render edilip
  incelendi. Cihazda, gerçek kare hızında görülmedi.

## 2026-11-06 — REL-20 IPA 1.0.0+10

- Kaynak: commit 915049b + commit edilmemiş çalışma ağacı (FX-09 nefes akışı
  dahil). `breath_flow.dart` ve testi derleme sırasında başka bir el
  tarafından güncellendi; IPA güncel kaynaktan (19:27 dosyası) yeniden
  üretildi. Öncesinde analyze (ilgili dosyalar) temiz, tam test 1337 geçti,
  2 skip.
- `pubspec.yaml` 1.0.0+9 → 1.0.0+10; önceki IPA `build/ios/ipa-1.0.0+9/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=build/ios/ipa-1.0.0+9/ExportOptions.plist` başarılı;
  `build/ios/ipa/Vocalart.ipa` 33.737.813 byte, SHA-256
  `0df00194785cc05043c89b64da6cac5ff7f6c9f3875001473185fe8b023db607`.
  Uyarı: Flutter launch image uyarısı (native storyboard UI-01c ile değişti).
- `test_verify_ios_ipa.py` 16/16; `verify_ios_ipa.py --pubspec pubspec.yaml`:
  passed — 1.0.0 (10), iOS 15.0, imza, entitlement, izin beyanı, 8 privacy
  manifest, 4 Mach-O bundle; Apple Distribution L3Z9U2B39K, profile
  2027-09-25.
- Yüklenmedi, TestFlight ve cihaz kurulumu yok.


## 2026-11-06 — IPA 1.0.0+11 (FX-10 noktalı nefes halkaları)

- Kaynak: commit edilmemiş çalışma ağacı (FX-10 dahil).
- `pubspec.yaml` 1.0.0+10 → 1.0.0+11; 19:32'de üretilmiş önceki IPA
  `build/ios/ipa-1.0.0+10/` altına taşındı.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<aynı ExportOptions, manageAppVersionAndBuildNumber=false>`
  exit 0; `build/ios/ipa/Vocalart.ipa` 34,0 MB. Uyarı: açılış görseli
  Flutter varsayılanı.
- `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (11), iOS 15.0,
  codesign doğrulandı, Apple Distribution L3Z9U2B39K, profile 2027-09-25.
- Upload, TestFlight, cihaz kurulumu yapılmadı (ayrı kullanıcı yetkisi).

## 2026-11-06 — BRAND-02 fotogerçekçi uygulama ikonu + IPA 1.0.0+12

- İkon kaynağı vektör çizimden kullanıcının fotogerçekçi render'ına geçti
  (`tool/brand/source/logo_master.webp`, "krem orta" kırpım). Commit
  `0a4b796`: iOS normal (alfasız RGB PNG), koyu ve tinted; Android legacy,
  adaptive ön katman, monochrome; adaptive arka plan `#F7E8D8`.
  Üretim: `flutter test tool/brand/render_icons_test.dart`.
- Kalite kapısı: `dart tool/quality_check.dart` temiz (1337 geçti, 2 skip).
- `pubspec.yaml` 1.0.0+11 → 1.0.0+12; önceki IPA `build/ios/ipa-1.0.0+11/`.
  `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<REL-12 ExportOptions>` exit 0, 35,9 MB.
  `verify_ios_ipa.py`: passed — 1.0.0 (12), Apple Distribution
  L3Z9U2B39K. Pakette 120 px ikon alfasız ve yeni logo.
- Sınır: koyu iOS görünümünde nota alt kenarında hafif krem iz; upload,
  TestFlight ve fiziksel cihaz görünümü yapılmadı.

## 2026-11-07 — REL-21 Android APK fail-closed doğrulama kapısı

- `scripts/release/verify_android_apk.py`: bounded ZIP güvenliği, pubspec
  sürüm/build exact-match, uygulama kimliği, min/target SDK, exact izin kümesi,
  Flutter `libapp.so`, legacy/Android 12+ launch kaynakları ve imza sertifikası
  doğrulaması eklendi. Debug imza yalnız explicit `--allow-debug-signing` ile;
  production imza yalnız beklenen SHA-256 digest ile kabul edilir.
- `scripts/release/test_verify_android_apk.py`: geçerli yerel debug paketi,
  stale sürüm/ek izin, debug flag/production digest, güvensiz ZIP/eksik launch
  ve strict pubspec için 5 adversarial test geçti.
- Önceki 1.0.0+9 APK, güncel 1.0.0+12 pubspec karşısında doğru biçimde
  reddedildi. `RESONIA_CHANNEL=beta` ve explicit yerel debug-signing override
  ile güncel APK yeniden üretildi: 76.780.216 byte, SHA-256
  `43b2a698733ca606d7dd7f2285b2db8c5f4a6366fec76e2a32cb8592fbc8363d`.
  Doğrulayıcı passed: `com.mennansevim.vocalart`, 1.0.0+12, min24/target36,
  exact 5 izin, launch kaynakları ve `Android Debug` sertifikası.
- Proje kalite kapısı temiz: format 408 dosya/0 değişiklik, analyze 0 sorun,
  1337 test geçti ve 2 opt-in test skip edildi.
- Sınır: bu yerel-debug imzalı APK mağaza artifact'ı değildir. Gerçek
  keystore/AAB, Play sunucu kabulü ve fiziksel Android kabul testleri yapılmadı.

## 2026-11-07 — REL-22 Android AAB fail-closed doğrulama kapısı

- `scripts/release/verify_android_aab.py`: AAB bounded ZIP/JAR yapısı,
  bundletool validate, pubspec sürüm/build exact-match, app id, min/target SDK,
  exact izinler, Flutter `libapp.so`, launch renk/stil/ikon kaynakları ve tek
  signer sertifikası için fail-closed kapı eklendi. Bundletool 1.18.3 binary
  SHA-256 ile pinlidir; debug imza explicit yerel flag, production imza ise
  beklenen sertifika SHA-256 gerektirir.
- `scripts/release/test_verify_android_aab.py`: geçerli yerel-debug bundle,
  stale sürüm/ek izin, debug flag/production digest, güvensiz ZIP/eksik launch
  ve bundletool binary bütünlüğü için 5 adversarial test geçti; `py_compile`
  temiz.
- Önceki 1.0.0+1 AAB güncel 1.0.0+12 pubspec karşısında reddedildi. Explicit
  yerel debug-signing override ile güncel AAB üretildi: 73.853.941 byte,
  SHA-256
  `41a4ca46461021e32a36e39adaa6edb77c866ff8748dfc89eb4a0ae9b77b51ee`.
  Bundletool ve doğrulayıcı passed: 1.0.0+12, min24/target36, exact 5 izin,
  markalı launch kaynakları, tek `Android Debug` sertifikası.
- Sınır: yükleme yapılmadı. Gerçek release keystore/digest, Play Console
  sunucu kabulü ve fiziksel Android akışları ayrı kapıdır.

## 2026-11-07 — REL-23 AAB→universal APK teslimat parity kapısı

- `scripts/release/verify_android_delivery.py`: doğrulanmış AAB'den pinli
  bundletool ile geçici, yerel-debug universal APK üretir. APKS ZIP yapısını
  bounded/path-safe doğrular, yalnız `universal.apk` girdisini stream ederek
  geçici dizine çıkarır ve REL-21 APK doğrulayıcısını çalıştırır.
- AAB ve materialize APK arasında app id, version/build, min/target SDK, exact
  izin kümesi, signer DN/digest/modu ve launch kaynak sonucu birebir eşleşmek
  zorundadır. Sonuç `installed:false`, `uploaded:false` taşır; temp çıktılar
  işlem sonunda silinir.
- `scripts/release/test_verify_android_delivery.py`: bounded extraction,
  traversal/eksik arşiv, exact parity, permission/certificate drift ve başarısız
  alt kapılar için 5 adversarial test geçti; `py_compile` temiz.
- Gerçek 1.0.0+12 AAB'den APKS 76.817.920 byte ve universal APK 76.817.611
  byte üretildi; kimlik, +12 sürüm, min24/target36, exact 5 izin, Android Debug
  sertifikası ve launch kaynakları parity kapısından geçti.
- Sınır: Play'e yükleme, Play App Signing, cihaz-özel split, kurulum ve fiziksel
  Android davranışı doğrulanmadı.

## 2026-11-07 — HUM-02a güvenli yerel eğitimci yorumu önizlemesi

- `HumanReviewDraft` hedef, tek soru, seçili gelişim özeti, yerel kayıt belirteci
  ve sürümlü amaç onayını bounded/fail-closed doğruluyor. Yerel tamlık backend
  kabulü veya hak rezervasyonu değildir.
- `HumanReviewGateway` dış portu ve `UnavailableHumanReviewGateway`, backend,
  auth/entitlement, storage, kapasite, hukuk/onay ve credit kapıları hazır değilken
  gönderimi reddediyor.
- Üyelikte Plus “Akışı incele” ile yerel önizlemeyi açıyor. Hedef/soru/özet
  seçimleri çalışıyor; kayıt, onay ve gönderim kapalı. Persist, upload, ağ, hak,
  ödeme, mikrofon ve AI çağrısı yok. Ekran gerçek eğitimcinin kendi yazdığı
  yorum ile AI koçunu açıkça ayırıyor.
- Doğrulama: 5 domain + 3 widget testi; ilgili üyelik/rota regresyonları geçti.
  Tam kalite kapısı format 412/0, analyze temiz, 1345 test geçti ve 2 opt-in
  test skip edildi. 320×720, 1,6× metin ölçeği widget testiyle kapsandı.
- Açık kapılar: hukukça onaylı amaç/saklama/alıcı metni, gerçek eğitimci havuzu
  ve kapasitesi, backend/auth/entitlement, private upload/storage, idempotent
  hak ledger, ödeme ve izinli pilot. Gerçek cihaz/pilot yapılmadı; Agora
  kaynakları değiştirilmedi, commit/push/deploy yok.

## 2026-11-08 — HUM-03a idempotent yerel hak ledger çekirdeği

- `HumanReviewCreditGrant` bounded unit ve UTC geçerlilik aralığı taşır.
  `HumanReviewCreditLedger`, aktif ve en erken sona erecek grant'ten reserve;
  ardından consume veya restore geçişlerini uygular.
- Request token ikinci rezervasyonu engeller. Idempotency key exact komut
  tekrarında aynı sonucu event eklemeden döndürür; başka komutta kullanılırsa
  reddedilir. Süresi geçmiş/tükenmiş grant, geriye giden zaman, restore sonrası
  consume ve çift restore fail-closed.
- Audit event ve reservation snapshot listeleri dışarıdan değiştirilemez.
  Restore unit'i tam bir kez bakiyeye döndürür; aynı request yeniden açılamaz.
- 8 adversarial domain testi ve HUM-02a regresyonları geçti. Tam kalite kapısı
  format 414/0, analyze temiz, 1353 test geçti ve 2 opt-in test skip edildi.
  Bu in-memory aggregate canlı entitlement, ödeme, mağaza iadesi, persist
  edilmiş finansal ledger veya kullanıcıya verilmiş gerçek hak değildir.
- HUM-03b açık: atomik backend transaction/idempotency storage, auth,
  entitlement/purchase/refund kaynağı, kapasite ve hukuk/pilot. Agora
  kaynakları değiştirilmedi; ödeme/API/commit/push/deploy yok.

## 2026-11-08 — HUM-04a eğitimci atama/yorum domain sözleşmesi

- `HumanReviewAssignment`, request/eğitimci/qualification token kapsamını UTC
  access başlangıç-bitişi ve optional revocation ile sınırlar. Yanlış eğitimci,
  expired veya revoked atama feedback kuramaz.
- `HumanReviewWrittenFeedback`: kayıt süresi içindeki evidence offset'leri,
  observation'dan ayrı possible explanation, 1–3 strength, en fazla 2 priority,
  tam 3 benzersiz katalog practice task, follow-up goal ve rubric version.
  Task tekrar/süre ve tüm metin/token alanları bounded; listeler immutable.
- `UnavailableHumanReviewFeedbackGateway`, authenticated backend assignment,
  RBAC/private playback/audit yokken teslimi fail-closed reddeder. AI author veya
  auto-fill alanı yoktur; token eşleşmesi insan yazarlığı/uzmanlık kanıtı değildir.
- 8 adversarial domain testi; HUM-02a/HUM-03a regresyonları geçti. Tam kalite
  format 416/0, analyze temiz, 1361 test geçti ve 2 opt-in test skip edildi.
  Gerçek eğitimci, panel, playback, backend, upload veya pilot yok.
- HUM-04b dış kapıları: kimlik ve uzmanlık doğrulama, atama bazlı API/storage
  yetkisi, kısa ömürlü recording erişimi, teslim idempotency/audit ve gerçek
  eğitimci QA. Agora kaynakları değiştirilmedi; API/ödeme/commit/push/deploy yok.

## 2026-11-09 — HUM-05a güvenli öğrenci teslim sözleşmesi

- `HumanReviewEducatorDelivery` ile `HumanReviewAiCoachCard` ayrı content kind;
  AI kartında educator assignment/qualification/evidence alanı yok. Delivery
  authored zamandan önce kurulamaz.
- `HumanReviewClarificationThread` tek soru için immutable
  available→submitted→answered→closed zinciri. İkinci soru, adım atlama, yanlış
  educator, expired submit penceresi ve geriye giden zaman fail-closed.
- `HumanReviewNotificationEnvelope` exact schema/event/opaque-token payload'ı
  üretir; yorum/soru/cevap/ses/skor/eğitimci içeriği için alan yok.
  `HumanReviewTaskSelection` yalnız feedback'te sunulan benzersiz task subset'ini
  kabul eder ve mastery/history yazmaz.
- `UnavailableHumanReviewStudentGateway` backend yokken teslim veya açıklama
  göndermez. 9 adversarial domain testi; HUM-02a/03a/04a regresyonları ve
  hedefli analiz temiz. Tam kalite kapısı format 418/0, analyze temiz, 1370 test
  geçti ve 2 opt-in test skip edildi.
- Açık kapılar: authenticated delivery API, push provider ve izin, deep-link
  authorization, plan persistence, outbox/idempotency, gerçek eğitimci/öğrenci
  pilotu. Agora kaynakları değiştirilmedi; dış bildirim/API/ödeme/commit/push/
  deploy yok.

## 2026-11-09 — HUM-06a güvenli hizmet operasyonları sözleşmesi

- `HumanReviewServiceCase`; triage/assigned/reviewing/delivered ana yolunu,
  rerecord/reassign/waitlist/delay/withdraw/cancel yan yollarını immutable UTC
  geçişlerle sınırlar. Yanlış educator, geriye zaman, aynı educator'a reassign ve
  geriye deadline fail-closed.
- Rerecord aktif educator/due bilgisini temizler; yeni recording token'ı doğrulanıp
  revision artırılarak triage'a döner. Bu işlem yeni hak tüketmez.
- İlk 20 kabul edilmiş pilot ordinal'ı `qaRequired` politika bayrağı üretir; güvenilir
  backend sırası veya QA tamamlanma kanıtı değildir. `HumanReviewQualityCheck`
  teslim sonrası permission reference ve farklı reviewer zorunlu tutar.
- `HumanReviewAppeal` yalnız teslim sonrası pencere içinde açılır ve bir kez
  çözülür. Replacement review/service-credit yalnız öneridir; hak ledger veya
  finansal iade değişmez. Operations gateway backend yokken fail-closed.
- 11 yeni adversarial test ve HUM-02a/03a/04a/05a regresyonları geçti. Tam kalite
  kapısı format 420/0, analyze temiz, 1381 test geçti ve 2 opt-in test skip edildi.
- Açık kapılar: authenticated workflow/RBAC, gerçek storage revoke/delete,
  persistent audit/outbox, credit transaction, hukukça onaylı itiraz/iade
  politikası ve ilk 20 izinli gerçek ikinci eğitimci QA'sı. Agora değiştirilmedi;
  dış bildirim/API/ödeme/commit/push/deploy yok.


## 2026-11-09 — WIDE-AUDIT-01 geniş kitle ürün incelemesi (yalnız belge)

- Kullanıcı talebi: müzik meraklıları, koristler, ses/tiyatro sanatçıları,
  konuşmacılar ve konservatuvar adayları için eksikler, kullanılabilirlik,
  farklı yaşlarla test edilebilir otomasyon hedefi ve ayrıntılı prompt.
- Aktif main → TrainerApp → HomeShell, onboarding, DailyRoute, katalog,
  nefes, aralık/live görsel bağlantısı, gelişim, analitik ve mevcut QA incelendi.
  Tarihsel belgeler güncel kodla karşılaştırıldı; canlı görsel iz ile puan ve
  sentez akor quiz'i ile kayıt temelli 2/3/4 tekrar ayrımı korundu.
- docs/product/VOCALART_GROWTH_AUDIT_2026-11-09.md: kanıtlı envanter,
  hedef kitle rotaları, WIDE-01–11 backlog, bağımlılık/kabul, 12 haftalık
  öneri ve korunan ses kapsamı. EarMaster/Vocal Tools resmî sayfalarıyla
  sınırlı rekabet taraması; pazar liderliği iddiası yok.
- docs/product/VOCALART_USABILITY_PROTOCOL_2026-11-09.md: iki yetişkin
  turu, dört yaş dilimi, görevler/paydalı hedefler, çocuk/ergen için ayrı
  hazırlık kapısı; kod/simülatör/cihaz/insan/eğitimci kanıtlarını ayıran
  otomasyon tasarımı. Yeni runner veya gerçek katılımcı testi yapılmadı.
- docs/product/VOCALART_IMPLEMENTATION_PROMPT_2026-11-09.md: ilk dar
  WIDE-01/02 uygulama dilimi, kullanıcı değişikliklerini koruma, ses motoru
  dondurma, veri uyumu, test ve teslim talimatları. Bu oturumda yürütülmedi.
- Güncel doğrulama: dart tool/quality_check.dart exit 0; 420 dosya format
  kontrolü/0 değişiklik, analyze 0 sorun, 1381 test geçti, 2 opt-in skip.
  İnceleme sırasında lib/test/tool hash envanteri alındı; son karşılaştırma
  sıfır fark. Uygulama/ses/test kodu değiştirilmedi.
- Sınırlar: yalnız analiz ve belge. Gerçek cihaz, mikrofon benchmark,
  yaş grubu testi, eğitimci içerik onayı, yeni otomasyon/hosted CI, dış mesaj,
  upload, ödeme, commit, push veya deployment yok. Bu kayıt ürün geliştirmesi
  ya da kabul kapılarının tamamlandığı anlamına gelmez.

## 2026-11-09 — BRAND-02 logo renk ve desen varyantları

- tool/brand/logo_variants_test.dart: logo_master.webp'den 30 keşif ikonu
  (10 nota rengi düz zeminde, sarı nota 10 desende, 10 renk+desen karışımı)
  ve dört karşılaştırma tablosu; çıktı yalnız build/logo_variants/. Nota HSV
  ton kaydırmasıyla boyanır, parlama ve bant korunur; alt kenardaki krem
  yansıma da notanın rengine çekilir.
- Bulgu: decodeImageFromPixels rgba8888'i premultiplied okuyor, photo_key
  düz alfa üretiyor; yarı saydam kenar yeşilimsi/açık çıkıyor. Yeni betikte
  premultiply ile giderildi; ardından düzeltme photo_key.imageFromPixels'e
  taşındı (girdi düz alfa, içeride premultiply), tüm betikler yararlanıyor.
- İkonlar yeniden üretildi: iOS koyu + renklendirilmiş 1024 ve Android
  ic_launcher_foreground (5 yoğunluk) değişti; mağaza ikonu, eski launcher,
  monokrom ve adaptive arka plan rengi bayt düzeyinde aynı kaldı. Koyu
  ikonun alt kenarındaki açık/yeşilimsi saçak gitti (9x yakın çekimle bakıldı).
- tool/brand/phone_preview_test.dart: 393x852 pt telefon ana ekranı çizimi;
  iOS açık/koyu/renklendirilmiş ve Android dairesel maske (modlar.png),
  varyantların ana ekranda yan yana görünümü (varyantlar.png), koyu ikon
  yakın çekimi. Çıktı build/phone_preview/. Bu bir çizimdir; iOS'un gerçek
  koyu/tint işleme mantığı yaklaşık, simülatör veya cihaz görüntüsü değil.
- Doğrulama: tool/brand analyze temiz. dart tool/quality_check.dart:
  format/analyze geçti, 1394 test geçti, 2 opt-in skip, 1 başarısız
  (test/choir/take_controller_test.dart "the piece ending stops the take");
  tek başına 3/3 geçti, ilgili koda dokunulmadı, tam paket yükünde zamanlama
  oynaklığı olarak not edildi, çözülmedi. Simülatör/cihazda ikon
  görülmedi; commit yok.

## 2026-11-09 — WIDE-01/02 ilk dilim: hedef → süre → ilk çalışma

**Kullanıcı isteği:** WIDE-AUDIT-01 promptunun ilk dar dilimi (hedef seçimi,
hedefe ve hazır içeriğe göre günlük rota, eski veri uyumu, izin/geri dönüş/
erişilebilirlik regresyonları, ses motoru koruma kontrolü).

### Değişen davranış

- `lib/trainer/home/daily_route.dart`: `PracticeGoal` (yeni başlayan, kulak,
  ses hazırlığı, koro provası, konuşma/sahne, konservatuvar) ve
  `DailyRoute.plan`. Hedef yoksa rota `forMinutes` ile birebir aynı (eski
  kayıtlar). Dinleme hedefleri mikrofon adımı içermez; ses/koro hedefleri
  her zaman nefesle başlar, 5 dk+ isteğe bağlı ses adımı ekler. Konuşma/sahne
  için hazır ders olmadığından ders adımı yok; sessiz aralık-dersi fallback'i
  kaldırıldı. Hazır olmayan içerik (artikülasyon/metin, porte/dikte, onaylı
  ses ısınma) adım olarak değil “Hazırlanıyor” notu olarak gösterilir.
  Yaş sorulmaz; hedef ses tipi, tolerans veya kolay mod türetmez.
- `onboarding_flow.dart`: 8 durumlu akış `karşılama → hedef → süre → hazır`
  oldu (ilk çalışmaya 3 karar). Koro üyeliği hedeften bağımsız bir onay
  kutusu; “Koro provası” seçilince işaretlenir, kaldırılabilir. Mikrofon
  testi, aralık ölçümü ve hatırlatma onboarding'den çıktı (Ayarlar/
  Egzersizler/Bugün'de ilk ihtiyaçta). Eski `obStep` değerleri
  `resumeStep` ile en yakın yeni adıma eşlenir; rol/odak/aralık/süre korunur.
  Hedef kartları seçili/tekli grup, koro kutusu checked semantics taşır.
- “İlk çalışmaya başla” artık `beginTodayRoute` ile Bugün rotasını izler
  (nefes rehberi → hedef dersi). Nefes ekranı ders yoksa “Bitir / Şimdilik
  bitir” der. Atlamak nefes adımını tamamlanmış saymaz; XP/seri yazmaz.
- Bugün: hatırlatma, ilk nefes/ders sonrasında tek seferlik ikincil kart
  (`reminderAsked=false` yalnız yeni kurulumda yazılır; eski kullanıcılara
  tekrar sorulmaz). Ana eylem rotanın tek butonu olarak kalır.
- Ayarlar: “Çalışma hedefi” ve “Günlük süre” sonradan değiştirilebilir
  (daha önce günlük süre onboarding sonrası değiştirilemiyordu).
- Testler: yeni `test/trainer/goal_onboarding_test.dart` (rota birim
  testleri, yeni akış, geri dönüş, koro kutusu, konuşma rotası, eski kayıt
  ve yarım kurulum devamı, hatırlatma, ayarlar). Eski adımları izleyen
  trainer/English/a11y/screenshot/integration testleri ve Maestro 01,
  subflows/onboard_quick, 11 yeni akışa uyarlandı. Ses testlerinin beklenen
  sonuçlarına dokunulmadı.

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: format 423/0, analyze temiz,
  **1395 test geçti, 2 opt-in skip**.
- Başlangıç lib/test/tool hash envanteriyle karşılaştırma: değişen yalnız
  trainer_app, daily_route, home_shell, onboarding_flow, breath_screen
  (yalnız çıkış etiketleri), settings_tab ve dört test dosyası + yeni test.
  `lib/domain/audio`, `domain/scoring`, `infrastructure/audio`,
  `trainer/audio`, `trainer/sing`, `range_*`, mic check/capture dosyaları ve
  native izin ayarları değişmedi. Aynı sürede başka bir oturumun
  `tool/brand/*` ve ikon PNG değişiklikleri görüldü; bu işe ait değil.
- Maestro akışları güncellendi ama çalıştırılmadı (simülatör/cihaz turu
  yok). VoiceOver/TalkBack elle denenmedi; yaş grubu kullanılabilirlik
  testi, eğitimci içerik onayı yapılmadı: ilgili kapılar `not_run`.
  Integration test dosyası güncellendi, cihazda koşulmadı; dosyadaki
  `tab_3`/“Ses Atölyesi” beklentileri bu işten önce de güncel değildi.
- Commit, push, upload, ödeme, dış mesaj yok.

## 2026-11-09 — WIDE-03 sade sonuç ve tek sonraki adım

**Kullanıcı isteği:** WIDE-01/02'den sonra WIDE-03: “ölçülmedi ≠ yanlış”,
“tamamlandı ≠ beceri gelişti”, XP ≠ beceri; skor/eşik değişmeden.

### Değişen davranış

- `lib/trainer/learn/session_end.dart` (ders/ara durak/serbest çalışma sonu):
  - Başlık olgu söyler: her biten ders “Ders tamamlandı” (kayıt zaten her
    durumda tamamlanıyordu); düşük doğrulukta eski “Bu ders bir tur daha
    istiyor” yerine not “Sıradaki ders açıldı. Bu turda karışan sesler oldu;
    önce kısa bir tekrar iyi gelebilir.” Ara durak %80 metni aynı.
  - Yanıt yoksa (`total == 0`): “Bu turda yanıt kaydedilmedi”, puan halkası
    yok, kanıt kartı ÖLÇÜLMEDİ ve “doğru ya da yanlış sayılmadı”; sonraki adım
    önerilmez.
  - Başlık kartındaki XP, soru sayısıyla değişti; XP yalnız ayrıntıda
    “+N XP · pratik puanı, beceri ölçümü değil”.
  - Tek “SONRAKİ ADIM” kartı: karışan varsa kaydedilmeyen kısa tekrar
    (`retry_missed`), yoksa sıradaki ders; başarısız ara durakta öneri yok.
    Ekranda tek ana buton (Bitti) kalır.
  - İstatistik satırı `Wrap` oldu (tam doğrulukta dar genişlikte 6.8 px
    taşma görüldü ve giderildi).
- `lib/trainer/stats/stats_tab.dart`: “SEVİYE” → “PRATİK SEVİYESİ”; kartta
  “Ne kadar çalıştığını gösterir; ses ya da kulak becerisi ölçümü değildir.”
  “Beceriler” başlığı “Dinleme çalışmaları” oldu. Seviye adları ve XP
  formülü değişmedi (adların algısı insan testinde ölçülecek).
- Testler: yeni `test/trainer/result_language_test.dart` (7 test);
  `practice_screens_layout_test` metin beklentisi güncellendi. Mevcut
  `retry_missed` kaydedilmeyen tekrar testi değişmeden geçti.

### Doğrulama ve sınırlar

- `dart tool/quality_check.dart`: format 424/0, analyze temiz,
  **1402 test geçti, 2 opt-in skip**.
- Hash: WIDE-03 başlangıcına göre yalnız session_end, stats_tab, bir test
  ve yeni test değişti; ses kapsamı oturum başındaki envanterle aynı.
  Skor, doğruluk, yıldız, %80/%70 eşikleri ve XP hesabı değişmedi.
- Kapsam dışı kaldı: mikrofonlu egzersiz sonuçları (range test, ezgi
  tekrarı, alkış, dinle-söyle) ses dosyalarıyla iç içe; bu dilimde
  dokunulmadı. Gelişim başlığındaki “Sesinin haritası” ifadesi aynı kaldı.
- Gerçek cihaz, VoiceOver/TalkBack, yaş grubu ve eğitimci değerlendirmesi
  yapılmadı (`not_run`). Commit, push, upload yok.

## 2026-11-09 — iOS IPA 1.0.0+13 (WIDE-01…03 dahil)

- `pubspec.yaml` 1.0.0+12 → 1.0.0+13; önceki IPA `build/ios/ipa-1.0.0+12/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<+12 ExportOptions, destination=export>` exit 0.
  `build/ios/ipa/Vocalart.ipa` 35.680.940 byte, SHA-256
  `7c5ba8b40035fdfb9c8549cbb62f912085c0300fb2b10637ea8fc9f8dcd5650e`.
- `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (13), Apple
  Distribution L3Z9U2B39K, 4 Mach-O bundle, 8 privacy manifest; doğrulayıcı
  testleri 16/16. Flutter'ın varsayılan LaunchImage uyarısı önceki
  build'lerdeki gibi sürüyor (launch ekranı storyboard ile çiziliyor).
- Upload, TestFlight ve fiziksel cihaz denemesi yapılmadı.

## 2026-11-09 — BRAND-03 katmanlı 3D ikon konseptleri

- Araştırma: Apple HIG App icons (katmanlı ikon: arka plan + birkaç dolu
  ön katman, net kenar, foto yerine illüstrasyon, cam/gölge/specular'ı
  sistem ekler; default/dark/clear/tinted), iOS 27 çok katmanlı cam (MacRumors),
  Android adaptive (108 dp katman, 66 dp güvenli alan, monochrome katman).
  Sonuç: fotogerçekçi master Liquid Glass katman modeline uymuyor.
- tool/brand/icon_3d_test.dart: nota ve bant vektör olarak yeniden çizildi
  (Path + aynı geometriden SVG). Üç konsept: Cam Bant (mor, buzlu cam bant),
  Yumuşak 3D (patlıcan + spot, hacimli nota, kumaş bant), Yankı (krem +
  yarı saydam halkalar). Her biri için iOS default/dark/tinted 1024, Icon
  Composer'a düz SVG katmanlar + spec.json, Android fg/bg/mono 432, patlatılmış
  katman görünümü ve sunum tablosu; çıktı build/icon_3d/.
- phone_preview_test.dart: konseptleri dört modda telefon ana ekranında
  gösterir (build/phone_preview/konsept_*.png, konseptler.png).
- Doğrulama: tool/brand analyze temiz, betikler çalıştı, görüntüler gözle
  rafine edildi (figür ölçeği, bant konumu/açısı, bayrak, sap-baş birleşimi).
  Önizlemelerdeki cam/gölge efektleri yaklaşık; Icon Composer'da, simülatörde
  veya cihazda görülmedi. Uygulama ikonu değişmedi; commit yok.

## 2026-11-09 — PATH-01 ders yolu, "Devam et" ve kademeli kutlama

- `lib/trainer/ui/celebration.dart`: `celebrationFor` yalnız oturumun
  kurduğu olaydan kademe seçer: ölçülmüş ders tamamı → küçük patlama;
  geçilen ara durak (%80, mevcut eşik) → 3 havai fişek + bayrak; geçilen
  final ya da biten beceri → 7 havai fişek + kupa. Serbest çalışma, intro,
  yanıtsız oturum ve geçilemeyen kapı kutlanmaz. Kapalı formlu, deterministik
  painter; dokunma ve semantik yok; hareket azaltmada kıvılcım yok, kapılarda
  durağan rozet; haptik ayarına uyar. Yeni bağımlılık/lisanslı animasyon yok.
- `SessionEnd`: kutlama katmanı; geçilen düğümden sonra beceride sıradaki
  düğüm varsa "Devam et: <ders>" + "Şimdilik bitir". `LessonFlow` sıradakini
  `pushReplacement` ile açar. Final için "Final sınavı geçildi", beceri
  bitince "Bu becerinin tüm dersleri tamamlandı." Skor, eşik, XP, yıldız ve
  ilerleme formülleri değişmedi.
- `SkillScreen`: liste yerine zikzak yol (`pathX`, 8 düğümde tekrar), noktalı
  patika (biten kısım yeşil), sıradaki düğümde "BAŞLA", kilitli gri, yıldızlar
  dolu + tekrar önerisi simgesi; her düğüm "başlık, durum" semantik etiketi.
- Test: `test/trainer/path_celebration_test.dart` 14 test. Tam kalite kapısı
  format 427/0, analyze temiz, **1416 test + 2 opt-in skip** (sonrasında
  eklenen final testiyle). Görsel: gerçek fontlu widget render'ında yol,
  ders/ara durak/final kutlaması gözle incelendi; rozet ikon fontu ve kıvılcım
  boyutu buna göre düzeltildi. iOS 26.5 simülatöründe debug build açıldı ama
  oturum sırasında simülatör kapandı; uçtan uca simülatör/cihaz turu,
  VoiceOver ve gerçek kullanıcı algısı doğrulanmadı.

## 2026-11-09 — UX-MOTION-01 rehberli, müzikal ilk açılış ve ortak hareket dili

**Kullanıcı isteği:** Paylaşılan bir onboarding videosunun (X gönderisi,
başka bir ürün) ses ve geçiş hissini Resonia girişine uyarlamak ve bunu
uygulamanın genel animasyon davranışı yapmak. Video kare kare ve ses
spektrogramıyla incelendi: yumuşak "tık"lar, harf belirdikçe yükselen kısa
nota merdivenleri, karakter "cıvıltısı", kademeli girişler, sonda akor +
konfeti. O ürünün karakterleri, metni ve görselleri kopyalanmadı; desen
Resonia'nın kendi diline (nota karoları, mor ses küresi, pentatonik notalar)
çevrildi.

- `lib/trainer/audio/ui_sounds.dart`: `UiCue` (tap/select/deselect/advance/
  back/chatter/hello/success + 10 pentatonik nota) ve deterministik
  `UiCueRenderer` (marimba benzeri toplamalı sentez, seviye ≤ 0,34, uçlarda
  tık yok). `UiSounds` referans sesten ayrı 3 oyunculu havuz; audio session'ı
  aktive etmez (iOS'ta mevcut kategori ve sessiz anahtarı geçerli). Dosyalar
  sabit `resonia-ui-cues` geçici klasörüne bir kez yazılır. Kayıtlı/lisanslı
  ses yok. Sesler hiçbir zaman ölçüm referansı veya skor işareti değildir.
- `TrainerAudio.ui`; `TrainerStore.uiSounds` (varsayılan açık, prefs'te,
  reset'te açık); Ayarlar'da "Arayüz sesleri" anahtarı.
- `lib/trainer/ui/motion.dart`: `Motion` token'ları, `uiCue`/`uiFeedback`
  (ses + haptik ayarına uyar), `Entrance` (kademeli giriş, ≤220 ms gecikme),
  `PopIn`, `Bump`, `GuideBubble` (420 ms "yazıyor" → satır + cıvıltı; ekran
  okuyucuya satır anında), `GuideOrb`, `NoteTile`, `LetterTiles`,
  `FloatingNotes`, `StepSwitcher` (yönlü yatay kayma). Gecikmeler timer değil
  AnimationController ile; hareket azaltmada içerik anında ve durağan.
- Onboarding: `karşılama → isim → hedef → süre → hazır`. Karşılamada Do–Si
  (EN: C–B) karoları kürenin çevresinde belirir ("hello" koşusu). İsim
  isteğe bağlı ("Şimdilik atla"), 24 karakter, yalnız cihazda
  (`username`); her yeni harf bir karo + sıradaki pentatonik nota. Rehber
  sonraki adımda isimle selamlar. Hedef seçimi select, koro kutusu
  select/deselect, dakika seçimi yükselen nota. Hazır ekranında "HAZIRSIN,
  <AD>!", mevcut `Celebration` lesson patlaması ve arpej — kurulumun gerçekten
  bittiği an. Eski kayıtların adım eşlemesi değişmedi; yeni `name` adımı.
- Testler: yeni `test/trainer/ui_motion_test.dart` (8 test: sentez seviyesi/
  determinizm/tıksız uçlar, benzersiz id, pentatonik eşleme, harf→nota akışı,
  atlama, sesler kapalıyken sessizlik, hareket azaltma, tercih kalıcılığı).
  Onboarding süren testler isim adımını geçecek şekilde güncellendi; büyük
  yazı denetiminde karo taşması ve hazır ekranında bağlantının ekran dışına
  itilmesi bulunup düzeltildi. Tam kalite kapısı: format 430/0, analyze
  temiz, **1424 test + 2 opt-in skip**. Ekran görüntüsü turuyla (gerçek
  font) karşılama/isim/hedef/hazır gözle incelendi.
- Sınırlar: Seslerin gerçek hoparlörde duyulması, gecikme, sessiz anahtar ve
  mikrofonlu ekranlarla etkileşim cihazda denenmedi; simülatör/cihaz,
  VoiceOver/TalkBack ve kullanıcı algısı doğrulanmadı. Hareket dili şimdilik
  yalnız onboarding'e bağlı; diğer ekranlara yayılması ayrı dilim.
  `integration_test` içindeki eski `opt_singer` yolculuğu zaten günceldışıydı,
  dokunulmadı.

## 2026-11-09 — UX-MOTION-02 hareket dilinin uygulamaya yayılması

**Kullanıcı isteği:** UX-MOTION-01 hareket dilini sayfa geçişlerine ve
ders/sonuç ekranlarına yaymak.

- Ses kuralı (pedagojik): kulak eğitimi soru ve karşılaştırma ekranlarında
  arayüz notası **çalınmaz**; araya giren tonal ses öğrencinin tuttuğu perdeyi
  bozar. Orada yalnız hareket + mevcut haptik. Ayrıca `uiCue` merkezi
  olarak `TrainerAudio.playing` sürerken susar.
- Sayfa geçişi: `trainerTheme` → `resoniaPageTransitions`. Android/masaüstü
  için `ResoniaPageTransitionsBuilder` (yeni sayfa sağdan hafif kayıp
  belirir, alttaki sola çekilip kararır); iOS/macOS'ta yerel Cupertino
  korunur (kenardan geri kaydırma). Hareket azaltmada geçiş yok.
- Soru ekranı (`quiz_view.dart`): seçenek düğmeleri ve A/B/C ses satırları
  doğruda `Bump`, yanlışta `Shake`. Skor/kayıt/ipucu akışı değişmedi.
- Ders sonu (`session_end.dart`): karar, not ve skor kartı kademeli girer;
  skor halkası 0'dan sonuca dolar (sayı ve semantik etiket anında doğru).
  `Celebration(sound: true)`: ders → `success`, ara durak/final → yeni
  `fanfare` (1,58 sn). Kutlama yoksa (serbest çalışma, geçilemeyen kapı,
  yanıtsız oturum) ses de yok.
- Ders yolu (`skill_screen.dart`): düğümler ilk görünüşte sırayla yükselir.
- `Bump` artık yalnız yeni pozitif tetikte zıplar (seçim kaldırılınca
  durağan); yeni `Shake`.
- Testler: `ui_motion_test.dart` +3 (referans çalarken sessizlik, tema
  geçişleri/iOS yerel, Bump/Shake tetik kuralları); `path_celebration_test`
  kutlama seslerini doğrular (success/fanfare/sessiz). Tam kalite kapısı:
  format 430/0, analyze temiz, **1427 test + 2 opt-in skip**. Ekran görüntüsü
  turu yeni geçişlerle geçti; yol, ders sonu, karşılaştırma ve ayarlar gözle
  incelendi.
- Sınırlar: mikrofon kaydı sırasında arayüz sesi yalnız kurgu gereği yok
  (kayıt ekranlarında `uiCue` çağrısı yok); kayıt durumuna bağlı ayrı bir
  susturma kapısı eklenmedi. Gerçek cihazda ses/gecikme/sessiz anahtar,
  geçiş akıcılığı, VoiceOver/TalkBack ve kullanıcı algısı doğrulanmadı. Ana
  sekme içerikleri (Bugün, Gelişim) ve mikrofonlu egzersiz ekranları bu
  dilimde ele alınmadı.

## 2026-11-09 — iOS IPA 1.0.0+14 (UX-MOTION-01/02 dahil)

- `pubspec.yaml` 1.0.0+13 → 1.0.0+14; önceki IPA `build/ios/ipa-1.0.0+13/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<+13 ExportOptions, destination=export>` exit 0.
  `build/ios/ipa/Vocalart.ipa` 35.734.119 byte, SHA-256
  `cac34fd49745325fbd1fbd6b8ffbc3d2237a6f51658ebeed78acdd307dec5f0a`.
- `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (14), Apple
  Distribution L3Z9U2B39K, 4 Mach-O bundle, 8 privacy manifest, profil
  2027-09-25'e kadar geçerli. Flutter'ın LaunchImage uyarısı önceki
  build'lerdeki gibi (launch ekranı storyboard ile çiziliyor).
- Upload, TestFlight ve fiziksel cihaz denemesi yapılmadı.

## 2026-11-09 — QA-NOTE-01 tek nota adlandırması, açılışta dil, nötr evet/hayır

**Kullanıcı bildirimi (TestFlight 1.0.0+14):** "Do ve Mi soruyorsun, C/E
seçtiriyorsun"; "doğru bildiğim halde başka şık yeşil yanıyor"; açılışta dil
seçeneği isteği; gerçek piyano sesi sorusu.

- Kök neden 1: `itemLabel` notasyon verilmezse solfej varsayıyordu;
  `curriculum.dart` ders başlıklarını notasyonsuz üretiyor ve yollar yalnız
  dile göre önbellekleniyordu. İngilizce cihazda notasyon harf (C–E) iken
  ders adı "New: Do and Mi" çıkıyordu. Ayrıca pitch açıklamaları ("Do'ya
  çeken yeden ses", mod/aralık/akor örnekleri) solfej sabitiydi.
  Düzeltme: `NoteNames.current` (Lang.en gibi uygulama geneli),
  `TrainerStore.notation` setter'ı ile senkron; `itemLabel` varsayılanı
  öğrencinin adlandırması; yol önbelleği dil+notasyon anahtarlı; Türkçe
  açıklamalar `NoteNames.of` ile ek gerektirmeyen kalıpta ("C sesine
  göre"); veri metinlerindeki "Do-Mi-Sol" örnekleri harf modunda "C-E-G",
  İngilizce "C-E-G"/"E → F" dizileri solfej modunda çevrilir (tek "A" gibi
  sözcüklere dokunulmaz).
- Kök neden 2 (olası): seçmeli/"hangi ses"/evet-hayır sorularında doğru
  cevap için yalnız seçilen şıkkın yeşil olduğu 6 tohumlu probla doğrulandı;
  mantık hatası bulunamadı. Evet/hayır sorusunda "Evet, bu" düğmesi cevaptan
  önce de yeşil boyalıydı; "Hayır" doğruyken yeşil başka şık gibi okunuyordu.
  İki düğme nötr kart rengi + ✓/✕ ikonu oldu. Kullanıcının gördüğü ekran
  kesinleşmedi; ekran görüntüsü istenecek.
- Karşılama ekranında Türkçe/English seçimi (Ayarlar'daki aynı `language`
  ayarı); "Başlayalım"daki notasyon varsayılanı seçilen dile uyar. Kahraman
  küre 210→190 px (test fontunda CTA kaydırma gerektiriyordu).
- Testler: yeni `test/trainer/note_names_test.dart` (7 test: iki dilde harf
  modunda pitch yolu/ipuçları/aralık/akor metinlerinde solfej kalmaması,
  solfej modunda İngilizce, metin dönüşüm sınırları, store senkronu, dil
  seçimi ↔ notasyon, nötr evet/hayır). İngilizce denetimi dil adını
  ("Türkçe") istisna sayar. Tam kalite kapısı: format 431/0, analyze temiz,
  **1434 test + 2 opt-in skip**. Karşılama gerçek fontla gözle incelendi.
- Piyano: `assets/audio/piano/notes` içinde kullanıcının kendi kaydı (izin
  2026-11-03, `cleared_partial`) E1–G5 beyaz tuşlar var; bugün yalnız ses
  aralığı testi kullanıyor, sorular sentez. Siyah tuşlar ve G5 üstü yok;
  akorlar için AGENTS kararı hazır 2/3/4 sesli kayıtlar (tekil mix ana yol
  değil). Refactor kullanıcı onayı bekliyor; bu dilimde yapılmadı.
- Sınırlar: cihazda doğrulanmadı; IPA yeniden üretilmedi.

## 2026-11-09 — AUDIO-PIANO-01 tek nota seslerinde kayıtlı piyano

**Kullanıcı isteği:** "Çaldığın nota gerçek piyano sesi olmalı" — onaylandı.

- `lib/trainer/audio/piano_sampler.dart`: kullanıcının izinli kaydı
  (`assets/audio/piano/notes`, E1–G5 beyaz tuşlar, `cleared_partial`;
  ADR-040 ile tutulan A5+ hariç) üzerinden render. Kural: bir `SoundSpec`
  yalnız **her olayı tek nota** ve her nota kayıtla karşılanabiliyorsa
  kayıttan çalar; aksi halde tamamı sentezde kalır (tek seste iki tını
  karışmaz). Siyah tuş: üstteki beyaz tuştan bir yarım ses aşağı, yoksa
  alttakinden yukarı (lineer interpolasyon, ±1 yarım ses). Kayıt başındaki
  0–0,4 sn sessizlik kırpılır (%5 tepe eşiği, 5 ms ön pay); nota yazılı
  süresinde 120 ms sönümle kesilir; tepe 0,8'e normalize (synth ile aynı).
  Akor ve eşzamanlı aralıklar tekil kayıtlardan kurulmaz; AGENTS gereği
  hazır 2/3/4 sesli kayıtlar beklenir.
- `TrainerAudio.render`/`play`: piyano tınısında önce kayıt, olmazsa synth;
  diğer tınılar synth. Kayıt yüklenirken yeni ses/stop gelirse eski ses
  çalınmaz.
- Bilerek değiştirilmeyen: `TrainerPitchSingSession` (mikrofonlu tanı)
  referansı synth'te kaldı; yanıt penceresi/kalibrasyon 1,3 sn synth'e göre
  ve kaydın sönümünün mikrofona sızması ölçülmeden değiştirilmemeli.
- Ayarlar teşekkür metni: piyano notaları Vocalart için kaydedildi; akorlar
  ve diğer enstrümanlar sentez; üçüncü taraf lisanslı kayıt yok.
- Testler: `test/trainer/piano_sampler_test.dart` 4 test — 8 nota (4 beyaz,
  4 kaydırılmış siyah, G♯5 dahil) kendi perdesinde ve komşusunun 2 katı
  üstünde; akor/menzil dışı/boş synth'te; A1'in geç başlangıcı kırpılıp
  melodi zamanlaması ve sönüm sonrası sessizlik korunuyor; TrainerAudio
  tını kuralı. Tam kalite kapısı: format 433/0, analyze temiz, **1438 test
  + 2 opt-in skip**. Dinleme örneği üretildi; cihaz hoparlöründe, gecikme ve
  dosya yükleme süresi ölçülmedi. Tiz bölgede A5 ve üstü synth'te; siyah
  tuşlar ve A5+ kaydedilirse kaydırma ve synth geri dönüşü azalır.

## 2026-11-09 — iOS IPA 1.0.0+15 (QA-NOTE-01, AUDIO-PIANO-01 dahil)

- `pubspec.yaml` 1.0.0+14 → 1.0.0+15; önceki IPA `build/ios/ipa-1.0.0+14/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<+14 ExportOptions>` exit 0.
  `build/ios/ipa/Vocalart.ipa` 35.743.849 byte, SHA-256
  `499fabc9a46ce8e4baa36b62d1ba25714d2e19ae6f1b5e56684e511b657b1542`;
  pakette 31 piyano nota WAV'ı.
- `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (15), Apple
  Distribution L3Z9U2B39K, 4 Mach-O bundle, 8 privacy manifest.
- Upload, TestFlight ve fiziksel cihaz denemesi yapılmadı.

## 2026-11-09 — AUDIO-PIANO-02 notalarda patlama (tık) giderildi

**Kullanıcı bildirimi (1.0.0+15):** "Notalarda patlamalar var."

- Ölçüm: bazı kayıtlar vuruşun ortasından başlıyor (dosyanın ilk örneği
  yüksek). Örnek dizide en büyük örnekler arası sıçrama 0,277 (E4 başı) ve
  0,155 (La başı) idi; sessizlikten tek örnekte bu sıçrama hoparlörde
  patlama olarak duyulur. Kayıtların DC kayması ihmal edilebilir (≤0,02).
- `PianoSampler.mix`: her notaya 5 ms yükseltilmiş kosinüs girişi; sönüm
  doğrusal yerine kosinüs; nota kaydın sonuna ulaşacaksa sönüm kayıt içinde
  biter (kesilme yok). Düzeltmeden sonra başlangıçlardaki en büyük sıçrama
  0,06; kalan en büyükler (0,075) nota içi ve ham kayıtların doğal düzeyi.
- `TrainerAudio.playNote` (ses aralığı testi) ham dosyayı değil örnekleyiciyi
  kullanır; aynı patlama orada da vardı.
- `JustAudioClipPlayer(fadeOnInterrupt:)`: hâlâ çalan klibi yeni ses veya
  stop öncesi ~30 ms'de kısar. Yalnız `TrainerAudio` açar; ölçüm yapan
  akışlar (mikrofonlu tanı, koro, aralık/ritim ekranları) varsayılan
  kapalıyla tam başlangıç zamanlamasını korur.
- Testler: `piano_sampler_test` +2 — E1–G♯5 her erişilebilir nota sessizlikten
  başlar/sessizliğe döner, ilk 2 ms ve son 100 ms'de sıçrama < 0,04 (eski
  kodda E4'te 0,277 ile düşerdi); yazılı süreden kısa, yüksek genlikli
  yapay kayıt kesilmeden söner. Tam kalite kapısı: format 433/0, analyze
  temiz, **1440 test + 2 opt-in skip**.
- Sınırlar: hoparlörde dinlenerek doğrulanmadı; just_audio'nun platform
  tarafı başlatma/durdurma davranışı ve iOS ses oturumu kaynaklı olası tık
  bu testlerin dışında. IPA yeniden üretilmedi.

## 2026-11-09 — iOS IPA 1.0.0+16 (AUDIO-PIANO-02 dahil)

- `pubspec.yaml` 1.0.0+15 → 1.0.0+16; önceki IPA `build/ios/ipa-1.0.0+15/`.
- `flutter build ipa --release --dart-define=RESONIA_CHANNEL=beta
  --export-options-plist=<+15 ExportOptions>` exit 0.
  `build/ios/ipa/Vocalart.ipa` 35744747 byte, SHA-256
  `fa315d46e069008b8ada37edcfeba93da8355c2d3215ed4d8a8fdf2ad5dda44b`.
- `verify_ios_ipa.py --pubspec pubspec.yaml`: passed — 1.0.0 (16), Apple
  Distribution L3Z9U2B39K, 4 Mach-O bundle, 8 privacy manifest.
- Upload, TestFlight ve fiziksel cihaz denemesi yapılmadı.

## 2026-11-09 — QA-INT-01 aralık adlarının yeni başlayana anlatılması

**Kullanıcı bildirimi:** "Küçük 2'li nedir? m2 / M2 bu değerlere hakim
değilim; bunları girişte anlat."

- Aralık açıklamaları (TR/EN, 12 aralık) jargonsuz yeniden yazıldı:
  "dominant/tonik/çevrim" yerine tuş sayısı ve duyuluş ("En küçük adım:
  klavyede hemen yan yana iki tuş"). Öznel duyuluş sözcükleri ("koyu",
  "parlak", "gergin") yaygın eğitim dili; eğitimci onayı alınmadı.
- Aralık "Başlarken"e yeni slayt "Aralık adları nasıl okunur?":
  sayı = kapsanan nota adı (iki uç dahil), yarım ses = yan yana iki tuş,
  küçük/büyük = aynı sayının iki boyu (m/M), tam (P4/P5/P8), artık (A4).
  Metin `intervalNamingRules()` (domain) ile ortak; nota adları ayardan.
- `IntervalKeyboard`: iki oktavlık sessiz klavye; örneğin iki notası dolu,
  kökten itibaren her tuşta yarım ses sayısı. Her yeni aralığın "Dinle"
  sayfasında; "Kısa adı" satırı (m2) ve "Solfej örneği" → "Örnek".
- Soru ekranı (yalnız aralık): seçenekler kısaltmaysa "Bu adlar ne
  demek?", hedef ad gösteriliyorsa "?" → alt sayfa: her kısaltma + tam ad +
  açıklama, tek hedefte klavye, okuma kuralları. Ses çalmaz (cevabı ele
  vermez); açıkken süre durur.
- Nota "Dinle" sayfasındaki "C'ya göre" eki "C sesinden" kalıbına çevrildi.
- Testler: `test/trainer/interval_help_test.dart` 7 test (örnek köklerin
  klavyeye sığması, jargonsuz açıklama, adlandırma slaytı, klavye tuş
  sayımı ve semantik, sessiz yardım sayfası, hedef "?" + klavye, nota
  sorularında yardım yok). Tam kalite kapısı: format 435/0, analyze temiz,
  **1447 test + 2 opt-in skip**. Soru, yardım sayfası ve m2/M2/P5 klavyesi
  gerçek fontla gözle incelendi.
- Sınırlar: cihazda ve gerçek yeni başlayanla denenmedi; akor/dizi adları
  için benzer yardım bu dilimde yok. IPA yeniden üretilmedi.

## 2026-11-09 — BENCH-MODEL-01 ses eğitimi modeli: benchmark, ağırlık ve yük incelemesi

**Kullanıcı isteği:** "Ses eğitimi için model uygun mu? Benchmark et, ağırlık ve
yük dağılımı uygun mu, derin araştır." Uygulama kodu, rubrik, tolerans ve sabitler
**değiştirilmedi**; commit/push/deploy yok.

- Eklenenler: `tool/benchmark/detector_benchmark.dart` (sentetik ses benzeri
  sinyal + gerçek piyano kayıtlarında `YinPitchFrameAnalyzer`/
  `RecordingPitchAnalyzer` ve iki alternatif algoritma),
  `model_benchmark.dart` (skor ağırlıkları, kapı/yıldız istatistiği, müfredat
  maruziyeti, tekrar kartı), `timing_benchmark.dart` (hesap yükü),
  `review_threshold_whatif.dart` (büyüme eşiği ne-olursa). Rapor:
  `docs/research/VOCAL_MODEL_BENCHMARK_2026-11-09.md` (dış kanıt bölümüyle).
- Bulgular (ayrıntı raporda): sentetik seste YIN C2–C6 boyunca ±2 c, SNR ≥10 dB
  sağlam, 5 dB'de çöküş (MPM dayanıklı; kalite kapısı 15 dB); tek ses
  skorunda 50→50,5 c için 45 puan uçurum, vibrato extent >±35 c "kararsız"
  (bu skor aktif TrainerApp'te yok); `RangeScore` genişlik ağırlığı .60 ve
  ölçüm eşleme gürültüsüne duyarlı; ara durak (12 soru, %80) ayırt edici değil;
  1310 puanlı sorunun tamamı algı; son öğeler ilk öğeden 4–9× az çalışılıyor;
  `ItemMemory.answered` büyüme koşulu (h/2) vade eşiğinden (0,234h) büyük →
  günlük kullanıcıda kart 90 günde 90 kez tekrar.
- Ek (aynı gün, kullanıcı onayıyla): `tool/benchmark/rhythm_benchmark.dart`
  — gerçek `EventRhythmAnalyzer`/`ClapOnsetDetector` ve 12 ritimle: mükemmel
  bilen simüle performansçı geçme oranı yetenekli %85/tipik %65/acemi %41;
  ritim süresiyle korelasyon −0,99, uygulamanın seviye sırasıyla −0,06;
  tempo normalize alternatifi %85→%100 ve yanlış ritmi kabul %18→%8 (uygulamada
  yok); detektör tespit−gerçek zaman SD 1,5 ms, hassasiyet tepe −24 dBFS'e
  kadar sessiz odada, enerji başlangıcı olduğundan öksürük/ünsüz de tetikliyor.
  İlk koşuda detektör gecikmesi 0,0 ms çıktı (sentetik alkışlar 5 ms adım
  ızgarasına hizalıydı); rastgele alt-adım fazıyla düzeltildi.
- Rapor §6b: repodaki rakip analizleri + web taraması (ajan): Türk
  konservatuvar kılavuzları (OMÜ, Ankara HBV, Selçuk [P]) tekrar tabanlı;
  melodi+ritim payı %40–80; ABRSM/RCM üretim ağırlıklı; Zarate 2010
  yalnız dinleme eğitiminin şarkıya aktarılmadığını gösteriyor (küçük örnek).
  Rakiplerin soru sayısı/geçme oranı yayımlanmamış. İTÜ/İstanbul/MSGSÜ cevap
  biçimi doğrulanamadı; kaynakların hepsini birincil açmadım.
- Doğrulama: `dart tool/quality_check.dart` format+analyze temiz, **1452 test
  + 2 opt-in skip** (ritim betiği dahil son koşu; ilk koşuda 1447 idi, fark
  çalışma ağacındaki diğer değişikliklerden). `model_benchmark` iki koşuda
  aynı çıktıyı verdi.
- Sınırlar: tüm ses sentetik veya piyano; simüle şarkıcı/öğrenen; yankı, eşlik
  sızıntısı, mikrofon AGC'si, gerçek insan sesi, telefon CPU süresi ve öğrenme
  etkisi ölçülmedi. Dış kanıt ikinci el/özet düzeyinde olanlar raporda
  işaretli. Rubrik/tolerans/ağırlık değişiklikleri kullanıcı/eğitimci kararı
  bekliyor (AGENTS.md).

## 2026-11-09 — QA-INT-02 akor ve dizi adlarının anlatılması

**Kullanıcı isteği:** QA-INT-01'deki yardımı akor ve dizilere de eklemek.

- Akor (9) ve dizi (11) açıklamaları TR/EN jargonsuz yeniden yazıldı (kökten
  yarım ses, "ortadaki nota bir tuş aşağıda", T/Y adımları açıklamalı).
  Eski dizi metinlerindeki "Do'dan" kalıbı harf modunda "C'dan" oluyordu;
  yeni metinler "C sesinden" kalıbında. Her akor/dizi için `exampleRoot`.
- `NotesKeyboard` (sessiz): akor — notalar tuşlarında adıyla, "Do + Mi +
  Sol birlikte · aralar 4 + 3 yarım ses"; dizi — oktava kadar notalar ve
  "Adımlar: T T Y T T T Y · T = 2 tuş, Y = 1 tuş" (EN W/H).
- "Başlarken"e "Akor adları nasıl okunur?" ve "Dizi adları nasıl
  okunur?" slaytları (`chordNamingRules`/`scaleNamingRules`, domain).
- "Dinle" tanış sayfası: akorda klavye + "Kısa adı" (maj), dizide merdivenin
  altında klavye.
- Soru ekranı yardımı aralık + akor + dizi için: "kısa · tam ad" (aynıysa
  tek ad), açıklama, tek hedefte uygun klavye, türe göre okuma kuralları;
  ses çalmaz, süre durur.
- Testler: `interval_help_test.dart` +5 (örneklerin klavyeye sığması ve
  harf modunda ek kalmaması, iki yeni slayt, akor notaları/dizi adımları,
  akor kısaltma yardımı, dizi hedefi klavyesi). Tam kalite kapısı: format
  440/0, analyze temiz, **1452 test + 2 opt-in skip**. Akor yardımı ve
  maj/dom7/majör/Dorian klavyeleri gerçek fontla gözle incelendi.
- Sınırlar: duyuluş sözcükleri eğitimci onaylı değil; akor dizisi
  (progression) adları kapsanmadı; artık üçlüde Sol♯ klavyede La♭ adıyla
  görünür (enharmonik, tek ad tablosu). Cihazda denenmedi, IPA yok.

## 2026-11-09 — PLACE-01 hedef parkuru, seviye sorusu ve yerleştirme testi

**Kullanıcı isteği:** Eğitim modeli esnek olsun; girişte yeni başlayan /
tecrübeli ayrımı, test uzunluğu tecrübeye göre optimize. BENCH-MODEL-01
oturumuyla iş bölümü yapıldı; sayı/yıldız düzeltmeleri oradan geldi.

- Hedef artık tek ders değil, sıralı bir **parkur** (`PracticeGoal.track`,
  taslak, eğitimci onaysız): beginner Nota→Aralık→Akor; ear
  Aralık→Akor→Dizi→Yürüyüş; exam Aralık→Nota→Akor→Dizi→Yürüyüş; choir
  Aralık→Nota→Akor; voice Nota→Aralık; stage boş. `lesson` = parkurun ilki
  (eski davranış aynı). `focusTrainer` hedef varsa parkurdaki ilk bitmemiş
  yolu seçer; hedefsiz eski kayıtlar eski kuralla. Akor/Dizi/Yürüyüş ilk kez
  rotaya giriyor. Ezgi/ritim/çok sesli lab'da, rota ve ustalık dışında.
- Onboarding: hedef → **seviye** (yeni / biraz biliyorum / tecrübeli) →
  dakika. `answers['level']`; Ayarlar'dan değişir. Hedef ve seviye bağımsız;
  ikisi de tolerans, eşik veya içerik değiştirmez.
- **Yerleştirme** (`placement.dart`, `placement_flow.dart`): parkurun ilk
  yolunun kendi kapıları, `QuizConfig.forNode` uzunluğuyla (12 / final 20).
  Erken bitirme `GateStop`: ceil(0,8·L) doğru = geçti, L−ihtiyaç+1 yanlış =
  kaldı (12'de 10/3, 20'de 16/5); karar tam testle birebir aynı (tüm
  doğru/yanlış sıralarıyla test edildi). Store'a doğruluk tam L'ye bölünerek
  yazılır (10/12 = 0,83 → 2★; erken bitirme 3★ şişirmez). Başlangıç:
  biraz → AD1'den yukarı, ilk kalışta durur; tecrübeli → sondan bir önceki
  ara durak, geçerse final dahil yukarı, kalırsa geçene dek birer aşağı.
  Sonuç mevcut `completeNode` kapı kuralıyla yazılır; `answers['placed']`.
  Her turdan sonra "Burada durayım"; sonuç ekranda "yaklaşık".
- `QuizView.stopWhen` (isteğe bağlı; null = eski davranış).
- Ayarlar: Seviye ve "Seviyemi bul" (parkurdaki güncel yol).
- Testler: `placement_test.dart` +18; 6 onboarding yürüyüşüne seviye adımı.
  Tam kalite kapısı: format+analyze temiz, **1470 test + 2 opt-in skip**.
- Sınırlar: 12 soruluk kapı düşük ayırt edici (BENCH-MODEL-01: %85'lik
  öğrenci %74 geçer), yerleştirme ±1 durak yanılabilir; eşik değişmedi.
  Geçen kapı önceki düğümleri stars:1 ile tamamlar ve atlanan öğelere tekrar
  kartı oluşmaz (mevcut kural). Parkur sırası ve seviye metinleri eğitimci
  onaysız; `exam` için ezgi/ritim tekrarı slotu kullanıcı kararı. Eski
  `lib/domain/models/learner_profile.dart` `PracticeGoal`'u ayrı eski
  katmanda (20+ dosya) kullanıldığı için kapsam dışı. Cihazda, gerçek
  öğrenciyle denenmedi; IPA yok.

### 2026-11-09 — P0 tekrar kartı büyüme eşiği
- `lib/trainer/domain/review_memory.dart`: `dueFraction` (= −ln(reviewTarget)/ln2)
  eklendi; `answered` içinde `spaced` koşulu `Δ ≥ h·dueFraction`; sürüm
  `hlr-lite-2`. `trainer_store.dart` değişmedi (sürüm farkında kartları zaten
  sıfırlıyor).
- Testler (`test/trainer/review_cards_test.dart`): vade anında ×2, vadeden
  önce büyümez/reps artmaz, `dueFraction`↔`reviewTarget`, yanlış cevap h/2
  (alt sınır 0,5), 90 günlük ziyaret simülasyonları (günlük ≤12 ve h=60,
  haftalık ≤8, %85 doğrulukta <40), `hlr-lite-1` kaydı sıfırlanır ve xp
  korunur. Eski 0,5 kuralına geri alınınca 4 yeni test başarısız oluyor.
- Kalite kapısı: format+analyze+test temiz, 1477 test + 2 skip.
- Etki: mevcut kullanıcıların tekrar kartları sıfırlanır.
- Sınırlar: katsayı/eşik değerleri taslak, pilot verisiyle ayarlanacak;
  simülasyon sentetik; cihazda ve gerçek öğrenciyle denenmedi.

### 2026-11-09 — P1 Alkışla ritim tempo normalize kuralı ve seviye sırası
- `lib/trainer/koro/clap_rhythm.dart`: `normalizeClapTempo` (sayı eşitse
  ilk→son süreyi referansa ölçekler; eşit değilse, tek alkışta veya sıfır
  sürede ölçeklemez), `clapSpanRatio`, `clapTempoNote` (eşik
  `RhythmImitationOutcome.tempoHintThreshold` = %15; TR/EN). `_judge` normalize
  edilmiş onsetleri analizöre verir; sonuç ipucuna tempo notu eklenir, geçme
  kararı/skor/XP değişmez. `clapRhythmsEasyToHard` anahtarı: senkop, vuruş
  dışı, süre ms, en kısa aralık, vuruş sayısı, katalog.
- `tool/benchmark/rhythm_benchmark.dart` sıra kopyası güncellendi; yeniden
  çalıştırıldı: corr(geçme, seviye) −0,37. Belge §5.5'e "Sonrası" eklendi.
- Testler: %5/%10 yavaş-hızlı mükemmel echo yalnız normalizeyle geçer (eski
  mutlak kural %10 yavaşta başarısız); 150 ms kaydırılmış alkış, eksik ve fazla
  alkış hâlâ geçmez; eşit olmayan sayıda ölçekleme yok; tek alkış/sıfır süre
  güvenli; tempo notu eşiği ve TR/EN; yeni sıra pairwise sabit; ekranda yavaş
  ama doğru echo geçip "Tempo ≈ %30 yavaştı" der.
- Kalite kapısı: format+analyze+test temiz, 1484 test + 2 skip.
- Sınırlar: ±120/10 ms, EventRhythmAnalyzer, ClapOnsetDetector,
  RhythmImitationEvaluator değişmedi. Simülasyon yeni kuralın geçme oranlarını
  yeniden ölçmedi; gerçek insan alkışı ve cihaz denenmedi; dokunmatik Ritim
  tekrarı drift açısından ayrıca doğrulanmadı. Mevcut clapLevel değerleri yeni
  sırada farklı ritme denk gelebilir.

### 2026-11-09 — P2 aralık skorundan genişlik çıkarıldı (`match-1`)
- `lib/trainer/koro/range_score.dart`: `total` = 0,625·doğruluk + 0,375·ilk
  deneme; genişlik ağırlığı kaldırıldı (`semitones`, `width`, `band`
  betimleyici). Doğruluk = (ort. closeness − 60)/40·100 (0..100, yalnız
  eşleşen takeler). `rangeScoreModelVersion = 'match-1'`.
- `lib/trainer/state/trainer_store.dart`: yalnız `rangeScoreModel` anahtarı
  (encode/decode); farklı/yok sürümde `rangeScores` yok sayılır. `resetAll`
  zaten temizliyor; `koroRange` ayrı, dokunulmadı.
- `lib/trainer/koro/range_test.dart`: kart başlığı "EŞLEME", genişlik çubuğu
  yok, not "ses tipi veya yetenek değil", sıra metni "kendi önceki
  denemelerine göre", açıklama diyaloğu yeni formüle göre; puan satırı Row →
  Wrap (320 px / 1,8× yazıda 5,5 px taşıyordu).
- Testler: genişlik puanı değiştirmez; 36 yarım ses gevşek 0, 14 temiz 100;
  doğruluk 0/20/39 cent → 100/50/2,5; ölçülmemiş/ıskalanmış take aralık/skor
  üretmez; eski/başka sürüm skorları silinir (xp, koroRange korunur); ekran
  testi 73 puan, 320 px + 1,8× taşmaz; english_ui_test geçer.
- `tool/benchmark/model_benchmark.dart` §B yeni formüle göre; çıktı belge
  §4.2'ye işlendi: puan↔gerçek aralık 0,52 → −0,01.
- Kalite kapısı: format+analyze+test temiz, 1488 test + 2 skip.
- Sınırlar: kullanıcıların eski aralık skorları silinir; `range_ladder.dart`,
  40 c / 2 deneme ve kalite kapısı değişmedi; ölçülen aralığın gürültülü
  şarkıcıda düşük çıkması ve %11–20 skor-yok oranı sürüyor; gerçek şarkıcı ve
  cihazda denenmedi; "Eşleme" metinleri eğitimci onaysız.

### 2026-11-09 — P3 yıldız eşiği, kapı kanıtı ve başarısız kapı önerisi
- `trainer_store.dart`: `starsFor` 3★ ≥%90 (`threeStarAccuracy`), 2★ ≥%80;
  gerekçe/"pratik göstergesi" notu kodda. `completeNode(node, accuracy,
  {correct, total})`: kapı denemesi günlüğü (`gateAttempts`, son 3, başarısız
  denemeler dahil, ders yazılmaz), `gateEvidence` → `GateEvidence.consolidated`
  (≥2 gün, ≥36 soru, ≥%80 birleşik). Şema geriye uyumlu: yeni anahtar,
  bozuk girişler atlanır, `resetAll` temizler. %80 geçme, kilitler, ders kuralı
  değişmedi.
- `lesson_flow.dart`/`placement_flow.dart`: sorulan soru sayısı ve doğru
  sayısı günlüğe gider; `GateStop` ve yerleştirme algoritması değişmedi
  (erken bitirme yine tam uzunluğa bölünür).
- `session_end.dart`: başarısız kapıda "Önceki dersi tekrar et" önerisi +
  "Yeniden dene" (+ "Şimdilik bitir"); `lesson_flow.dart` önceki dersi veya
  kapıyı yerinde açar.
- `skill_screen.dart`: kapı düğümünde "iki ayrı günde doğrulandı" rozeti
  (ikon + tooltip/semantik; ek satır 132 px düğüm yüksekliğini aştığı için
  metin satırı yerine ikon).
- Testler (`test/trainer/gate_evidence_test.dart`, `placement_test.dart`):
  starsFor sınırları (0,79/0,80/0,89/0,90/0,94/0,95), 9/10 – 11/12 – 18/20,
  10/12 = 2★ ve 11/12 = 3★, kapı 0,79 kalır/0,80 geçer, ders her zaman
  tamam, kilit mantığı, günlük ≤3 ve eski veri, bozuk giriş, pekişti sınırları
  (36 soru, %80, 2 gün), aynı gün konsolide olmaz, kilit/yıldız değişmez,
  başarısız kapı önerisi TR/EN, rozet.
- `tool/benchmark/model_benchmark.dart` §C yeni eşiğe göre; belge §4.3'e
  P(3★) eski/yeni: gerçek %90'da ders %35→%74.
- Kalite kapısı: format+analyze+test temiz, 1507 test + 2 skip.
- Sınırlar: günlükte yerleştirme için sorulan soru sayısı tutulur (erken
  geçiş yukarı yanlı doğruluk verebilir; sınır 36 soru); pekişti eşikleri
  taslak, pilot/eğitimci onayı yok; 3★ daha ulaşılır (gerçek %70'lik öğrenci
  derste %15 3★); ders yolu düğümlerinde 1,8× yazıda eskiden beri 6 px taşma
  ve 320 px'te 1,3 px taşma (bu değişiklikten bağımsız) düzeltilmedi; cihazda
  denenmedi.

### 2026-11-09 — P4 exam rotası tekrar alıştırması
- `daily_route.dart`: `EchoStep {melody, clap}` (+`other`, `fromId`),
  `echoStepMinMinutes = 5`; `DailyRoute.plan/routeFor` `lastEcho` ve
  `echoDoneToday` alır; yalnız `exam` ve dakika >5 iken `echoStep`; `stepCount`
  sayar. `pendingContent` (exam) mevcut metni korur ve "Makam melodileri,
  solfej ve dikte henüz hazır değil; 2/3/4 sesli tekrar kayıt bekliyor."
  ekler (TR/EN).
- `trainer_store.dart`: `echoLast`/`echoDay` (encode/decode/resetAll, eski
  kayıtta null, bilinmeyen tür yok sayılır), `echoedToday`, `markEchoDone`
  (yalnız bunları yazar; XP/seri/gün/düğüm/hafıza/lab seviyesi dokunulmaz),
  `route` getter (`routeFor` + echo geçmişi).
- `home_shell.dart`: `route_echo` adımı "Tekrar alıştırması · melodi
  yankısı/alkışla ritim", alt başlık "taslak ölçüm · mikrofon isteğe bağlı",
  yapılınca "Bugün yapıldı". Mevcut `MelodyEchoScreen`/`ClapRhythmScreen`
  açılır; melodi yankısı canlı ses yoksa Koro'daki gibi "yalnız cihazda" uyarır.
  `beginTodayRoute` ve onboarding özeti `store.route` kullanır (özette echo
  satırı).
- `melody_echo.dart`/`clap_rhythm.dart`: isteğe bağlı `onRoundFinished`
  (melodi: ölçüm alındı ve yeniden deneme gerekmedi; alkış: alkış duyuldu;
  tur başına bir kez). Ölçüm/eşik kodu değişmedi.
- Testler (`exam_echo_route_test.dart`, melody/clap testlerine sayaç): 3/5/10
  dk adım kümeleri, dönüşümlü tür, diğer hedefler ve hedefsiz kayıt aynı, XP/
  seri/ustalık değişmez, tek başına echo pratik günü değil, kalıcılık ve eski
  kayıt, kart TR/EN, 5 dk'da yok, hazır olmayan 2/3/4 önerilmez.
- Kalite kapısı: format+analyze+test temiz, 1525 test + 2 skip.
- Sınırlar: cihazda ve gerçek mikrofonla denenmedi; lab ekranlarının ölçümü
  taslak; yeni adım metinleri eğitimci onaysız; "~N dk" kullanıcı ayarı,
  rotadan hesaplanan süre değil; İTÜ/İstanbul/MSGSÜ cevap biçimi doğrulanmadı
  (rapor); Koro'da melodi "Ezgi tekrarı" diye geçiyor, rota prompt'taki
  "melodi yankısı" adını kullanıyor (ad tutarlılığı kararı açık).

### 2026-11-10 — P5 doğrulama pilotu: protokol, araç, şablonlar
- Belgeler: `docs/research/PILOT_PROTOCOL_2026-11.md`;
  `docs/research/pilot/{RECORDING_GUIDE.md, CONSENT_DRAFT.md,
  manifest_template.json, pilot_meta_template.json, criteria_template.json}`.
  Ölçütler taslaktır ve veriye bakılmadan kullanıcı/eğitimci tarafından
  dondurulur; hukuk metni TASLAKTIR (incelenmedi); çocuk/ergen kapsam dışı.
- `tool/benchmark/pilot_analysis.dart` (+ `detector_benchmark.dart`'tan
  `runAll`/`algs` yeniden kullanımı): `AudioFixtureManifest` v1 + sidecar
  `pilot_meta.json` (labelClass, device, route, room, labels, gateResult).
  Veri yok/şablon/özet uyuşmazlığı/meta eksik → `PilotInputError`, çıkış 2;
  sentetik veya enstrüman satırı karar tablosuna girmez; hüküm yalnız
  `frozen: true` ölçüt dosyasıyla ve Wilson aralığına göre (PASS / FAIL /
  inconclusive).
- Testler (`test/tool/pilot_analysis_test.dart`): Wilson, outcome (doğru/
  oktav/yanlış/çekimser), kappa, hüküm mantığı, eksik veri hatası, şablonların
  reddi, eksik meta, bozuk etiket/route, değiştirilmiş dosya (hash), sentetik
  satırların karar setine girmemesi, taslak ölçütle hüküm yok. Bir test
  sentetik tonu YALNIZ kod yolunu denemek için "human holdout" ilan eder
  (yorumla işaretli, sayılar sonuç değil).
- Kalite kapısı: format+analyze+test temiz, 1538 test + 2 skip.
- Sınırlar: gerçek katılımcı/rıza/kayıt/eğitimci yok; HİÇBİR sonuç üretilmedi
  veya uydurulmadı; ölçüt sayıları öneri; alkış, aralık ve kart analizleri
  için betik ve uygulama içi izinli günlük dışa aktarma YAZILMADI; telefon
  CPU/frame süresi ölçülmedi; hukuk incelemesi ve eğitimci rubrik onayı yok.

### 2026-11-10 — Alkışla ritim: 10 el alkışı animasyonu + kayıtlı alkış sesi yuvası
- `lib/trainer/koro/clap_stage.dart` (yeni): `ClapStage` + `ClapCue` +
  `ClapStagePainter`. Ortak hareket modeli: dinleme sırasında eller bir
  sonraki vuruşa önceden kapanır (`expect`, en fazla 180 ms / aralığın %60'ı,
  hızlanan yaklaşma), temasta avuç basılır, parmaklar geri esner, avuç
  kızarır, 1.6 px sarsıntı; ardından kritik sönümlü geri açılma. Öğrencinin
  alkışında (önceden bilinmez) eller anında kapanıp açılır. 3/4 görünüm:
  ön-yüz el, yaklaşırken birbirine döner (x daralması), temasta biri öne biner.
  Ticker yalnız hareket varken çalışır; azaltılmış harekette yalnız kısa temas.
- 10 stil (`ClapStyle`): Klasik, Ses halkası, Kıvılcım, Hız izi, Tebeşir tozu,
  Palmas (flamenko, parmaklar avuca), Kapalı avuç (boğuk, hava cebi), Işık,
  Dalga formu, Notalar. Seçim alttaki çipten açılan sayfada (hepsi aynı ritmi
  döngüde çalar); `TrainerStore.clapStyle` (geriye uyumlu, varsayılan Klasik).
- Ses: kullanıcının verdiği `assets/audio/post-punk-clap.wav` (stereo 44.1 kHz,
  0.39 s) `afconvert` ile mono PCM16 48 kHz `assets/audio/clap/clap.wav`'a
  çevrildi ve pubspec'e eklendi. `loadClapSample`/`prepareClapSample`:
  yeniden örnekleme, baştaki sessizliği kırpma, 400 ms, tepe 0.9; okunamazsa
  sentez `renderClap` çalar. Lisans/kaynak kullanıcıdan teyit bekliyor.
  Mikrofon alkış algılayıcısı (`ClapOnsetDetector`) bu sesle yeniden
  ayarlanmadı; dinleme sesi hoparlörden gelir, öğrenci turunda çalmaz.
- Testler `test/trainer/clap_stage_test.dart`: 10 stil × 5 faz × reduced boyama,
  önceden kapanma ve durulma, örnek kırpma/normalizasyon, seçim + kalıcılık.
- Kalite kapısı: format+analyze+test temiz, 1544 test + 2 skip.
- Sınırlar: gerçek cihazda kare süresi/akıcılık ölçülmedi; kayıtlı sesin
  lisansı teyit edilmedi; ses ile görsel temasın cihazdaki gecikme hizası denenmedi.

### 2026-11-10 — Kayıtlı alkışta art arda çalışta patlama önlemi
- Sorun: hızlı ritimde bir alkışın ~300 ms kuyruğu sonrakine biniyordu; toplam
  1'i aşınca sert kırpma (çıtırtı) oluyordu; iz son alkıştan 300 ms sonra
  kesiliyordu.
- `renderClapTrack`: davul makinesi "choke" grubu gibi her yeni alkış
  öncekinin kuyruğunu 6 ms'de söndürür (en çok 2 ses, yalnız 6 ms); iz son
  alkış tamamen sönene kadar sürer; tepe >0.95 ise tüm iz ölçeklenir, asla
  kırpılmaz. `prepareClapSample`: DC giderme, 0.5 ms fade-in, tepe 0.8
  (`clapSamplePeak`) headroom.
- Ölçüm (gerçek kayıtla, 16 alkış, 60/90/136/273 ms aralık): tepe 0.80,
  tam ölçek örnek 0, iz 0 ile biter, örnekler arası en büyük sıçrama tek
  alkışın kendi atağını aşmaz. Testle sabitlendi. Kalite kapısı: 1545 test
  + 2 skip. Cihaz hoparlöründe dinleme denenmedi.

### 2026-11-10 — Sonuç ekranı (SessionEnd) sadeleştirme + HeroCard genişlik hatası
- Hata: `HeroCard` içindeki `Stack` varsayılan gevşek fit ile içeriği en geniş
  satırına daraltıp sola yaslıyordu; ortalanmış skor halkası ve çipler kartın
  solunda kalıyor, sağ taraf boş görünüyordu. `StackFit.passthrough` ile içerik
  kartın tüm genişliğini alır (tüm HeroCard kullanımları için geçerli).
- `lib/trainer/learn/session_end.dart` (tüm ders/ara durak/serbest çalışma
  sonuçları): başlık-hüküm-not ortalandı; halka büyütüldü; halkayı tekrar eden
  "%90 ilk deneme" / "10 soru" çipleri yerine tek özet satırı
  ("%90 ilk denemede doğru") + ölçüm kaynağı satırı. Sarı seri bandı ince tek
  satıra indi. Ölçüldü/Ölçülmedi/Deneysel kartları tek kartta satırlara
  birleşti (durum etiketleri ve metinler aynı). "Sonraki adım" iç içe buton
  yerine tek dokunulabilir satır (`retry_missed` satırın kendisi). XP ve soru
  bazlı ayrıntı açılır bölümde kaldı. Ölçüm, skor, eşik ve kayıt mantığı
  değişmedi.
- Rakip inceleme: `design-exports/rakip-vokal-kocu` (Simply Sing sonuç ekranı:
  ortalı başlık, tek skor görseli, kısa metrik satırı, tek ana aksiyon).
- Test: `result_language_test` "soru" çipi beklentisi özet satırına güncellendi.
  `test/trainer` 344 test geçti; format temiz; analyze yalnız bu işe ait
  olmayan `lib/trainer/ui/rhythm_track.dart` 2 bulgusunu gösteriyor. Tam
  koşuda `rhythm_imitation_screen_test` bir kez düştü, tek başına iki kez geçti
  (yük altında zamanlama; bu değişiklikle ilgisiz).
- Sınırlar: gerçek cihazda görsel kontrol yapılmadı (yalnız test render'ı ile
  halka merkezi doğrulandı); diğer özel sonuç ekranları (ritim taklidi, akor
  tanısı, ses aralığı) bu düzene taşınmadı.

### 2026-11-10 — Ritim tekrarı: daha kolay kabul + canlı vuruş noktalarıyla yeniden tasarım
- **Kullanıcı kararı:** "Ritim tekrarı zor; kabul derecesini düşür." Yalnız bu
  alıştırma (dokunarak tekrar, Aksak ritim dahil) için:
  - zamanında penceresi ±10 → **±50 ms**, aynı vuruş penceresi ±120 → **±160 ms**
    (`RhythmImitationOutcome.onTimeToleranceMs/matchToleranceMs`; global
    `RhythmAnalysisDefaults` ve Alkışla ritim değişmedi);
  - tüm vuruşlar varsa ve genel hız referansın 0.8–1.25 katıysa dokunuşlar
    önce referans süresine ölçeklenir (sabit ama biraz yavaş/hızlı tekrar
    "hepsi geç" sayılmaz); hız uyarısı yine gösterilir, sonuçta
    `tempoFitted` saklanır;
  - ustalık ölçütü ortalama |sapma| 60 → **80 ms** (`RhythmNextStepPolicy`).
  - Analizör sürümü `rhythm-imitation-2/first-tap-anchor-tempo-fit`: v1
    sonuçları ayrı kohort; "sonraki adım" ilerlemesi v2 denemeleriyle yeniden
    birikir. Eğitimci kalibrasyonu yok; değerler kullanıcı tercihidir.
- **Ekran yeniden tasarımı** (`rhythm_imitation_screen.dart`, trainer kiti):
  üst çubuk + ilerleme, seviye etiketi ve seçici, vuruş/BPM; ortak
  `lib/trainer/ui/rhythm_track.dart` (`RhythmTrack`): üstte referans, altta
  dokunuşlar. Dinlerken referans vuruşları zamanında yanar; dokunurken her
  nokta anında belirir ve en yakın vuruşa uzaklığına göre renklenir (yeşil
  ≤50, sarı ≤160, mercan dışı), sıradaki vuruşun yeri halka; "70 ms erken"
  rozeti. Sonuçta eşleşen çiftler çizgiyle bağlı, ms etiketi, eksik halka,
  fazla mercan; zamanında/kaymış/eksik-fazla sayaç kartı. Dokunma alanı ve
  Dinle/Bitirdim altta sabit. Geçiş grafiği ve vuruş çipleri "Ölçüm
  ayrıntısı"na taşındı. Alkışla ritim karşılaştırması da `RhythmTrack`'e
  geçti (alkışlar canlı renkli). `TopBar` satırı 44→48 px (dokunma hedefi).
- Kontrolcü: salt-okunur `referenceOnsetsMs`, `liveTapsMs` (yalnız çizim).
- Testler güncellendi/eklendi: v2 pencereleri, tempo uyarlaması (1.2 → uyar,
  1.4 → uyarlama yok), tek düzensiz vuruş geç, ekran akışı yeni düzenle,
  a11y (kontrast, 48 px).
- Kalite kapısı: format+analyze+test temiz, 1548 test + 2 skip. Gerçek
  cihazda dokunma gecikmesi ve yeni eşiklerle öğrenci başarısı ölçülmedi.
