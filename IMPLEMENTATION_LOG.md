# Harmonia — Uygulama kaydı

## 2026-10-11 — İlk güvenilirlik paketi, REL-01–05

**Kullanıcı isteği:** Ayrıntılı roadmap ve uygulamaya başlama. Çalışma Harmonia klasöründe yapıldı; Agora kaynakları değiştirilmedi. Git commit/push/PR, dış yayın, ödeme veya canlı API bağlantısı yapılmadı.

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

**İnceleme:** Agora `src/PitchTest/lib/audioPlayer.ts` `/sounds/piano/{noteName}.wav` fetch/decode/cache yapıyor. Preload hatayı yutuyor, play missing file'da throw; Harmonia placeholder'da eksik kaynak başarıya dönüşmüyor. Agora kaynakları/41 WAV değiştirilmedi/kopyalanmadı. Harmonia tek ses ekranı mock, lab C4 sentetik olarak ayrı kaldı.

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

**SHELL-01:** Aurora tema token'ları ve `HarmoniaResultColors` (yanlış oktav ≠ başarı rengi, geçersiz = nötr; kontrast testli), light/dark. `AppShellController` + `ProfileRepository` + atomik `JsonFileStore`/`FileProfileRepository`. Hedef seçimi (hesap yok), home (Deneysel/Simülasyon/Kayıt bekleniyor/Henüz yok etiketleri), ayarlar: hedef değiştir, mikrofon yardımı, gizlilik, “satın alma yok” abonelik metni, misafir hesap ve onaylı yerel profil silme; bozuk profil için yeniden dene/açık yeniden başla. Simülasyon tek ses ekranındaki kısayollar home'a taşındı; ekranın kendisi değişmedi.

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

**SESSION-02:** `OrphanAudioCleaner` açılışta, ses ekranları oluşmadan çalışır; temp kökünde yalnız `harmonia-audio-lab-*`/`harmonia-clip-*` dizinleri, içlerinde yalnız `recording.wav`/`reference.wav`/`clip.wav` silinir, dizin boşsa kaldırılır; symlink izlenmez, beklenmeyen içerik korunup raporlanır. Başarısızlık ayarlarda anlaşılır uyarı olarak görünür.

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
Runner script root Harmonia guard ile cwd'den bağımsız; immutable argv/process
spawn (shell string yok), read-only lib/test/tool format → no-pub analyze →
full test. İlk tool exit aynen korunur; ProcessException 127, otomatik SDK kurma
yok. --plan hiçbir step çalıştırmaz; --fetch explicit pub get --enforce-lockfile.
Flag yerel help ile kontrol edildi, fetch uygulanmadı. Doğrudan dart giriş
implicit pub/build hooks başlamasını önler; dart run tavsiye edilmez.

**Doğrulama:** Son gerçek `dart tool/quality_check.dart` pipeline exit 0:
**529 test geçti (+10)**, analyze temiz (2.8 sn), **153 dosya/0 format değişikliği**.
CLI plan alternatif temp cwd'de ve read-only Agora cwd'de Harmonia'ya bağlı;
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
- **REL-09:** `lib/app/app_channel.dart` (`--dart-define=HARMONIA_CHANNEL=dev|beta`,
  bilinmeyen değer hata); beta'da ses laboratuvarı, simülasyon ve piyano
  placeholder gizli; Ayarlar → Hakkında kanal. Android label/iOS CFBundleName
  "Harmonia"; release imzalama `android/key.properties` (yoksa uyarı + debug,
  mağazaya yüklenemez); keystore dosyaları gitignore. iOS
  `PrivacyInfo.xcprivacy` (tracking yok, toplanan veri yok, FileTimestamp
  C617.1) Xcode projesine eklendi ve paket içinde doğrulandı. pubspec açıklaması.
- **OPS-01a:** `LocalErrorLog` (bellekte ≤50, mesaj metni tutulmaz; tür + ilk
  `package:harmonia` konumu, dakika hassasiyeti) + `installGlobalErrorHandlers`
  (FlutterError/PlatformDispatcher; release'te sakin placeholder). Ayarlar →
  "Uygulama hataları" yalnız hata varsa; rapor panoya kopyalanır, gönderim yok.

**Doğrulama:** ortak runner exit 0: **626 test**, analyze temiz, 185/0 format
(otomatik ajanın paketleri dahil; bu paket 7 test ekledi: kanal 3, hata 4).
`flutter build ios --simulator --debug --dart-define=HARMONIA_CHANNEL=beta`
başarılı, PrivacyInfo paket içinde, CFBundleName Harmonia. `flutter build apk
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
