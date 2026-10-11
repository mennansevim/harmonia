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
