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

`lib/main.dart` → `HarmoniaApp` → `SingleToneExerciseScreen`.

- Ana ekran C4 **mock** senaryolarıyla scorer/sonuç gösterir. Gerçek öğrenci
  DSP sonucu değil. Yeni motor var diye bu ekran gerçek olmuş sayılmaz.
- App bar mikrofonu → **Ses laboratuvarı**: sentetik C4 referans, açık izinle
  kısa yerel WAV kaydı, header metadata, replay/delete. iOS/Android adapter
  var; fiziksel mic/route QA yapılmadı. Upload/skor yok.
- App bar müzik-kitaplığı → **2 / 3 / 4 Ses** placeholder ekranı: üç kart,
  “Piyano kaydı bekleniyor”; dinle/tekrar disabled. Mikrofon/player/skor yok.
  JSON loading/error/retry/disposal ve büyük yazı testli.

## 4. Kod haritası ve önemli sözleşmeler

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
  yok. Session epoch/stale-result ve lab bağlantısı bekliyor.
- `pcm16_wav.dart` + fixture manifest/loader: narrow mono PCM16, actual header
  rate, bounded reads, hash/path/symlink/rate/count tutarlılığı. Private
  immutable dataset varsayımı; kernel sandbox veya label/consent QA değildir.
- `AudioLabController`: serialized native commands + cancel epoch;
  route/focus/background'ta cancel, auto resume yok. Capture metadata-only;
  raw PCM'yi analiz worker'ına henüz vermez. Plugin backend kendi temp
  reference/recording dosyalarını yönetir. Startup orphan cleanup ve shutdown
  error UI aktarımı açık. Lab timer overshoot ≤11 sn kabulü ile strict 10 sn
  analyzer bütçesi farklı; sessiz truncate veya öğrenci hatası yapma.
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

Son suite: **230 test**, analyze temiz; format **63 Dart dosyası/0 değişiklik**.
Domain/mock/synthetic/widget + native isolate testleri; insan kayıt/gerçek
telefon/öğretim pilotu değil. iOS simulator debug build önceki lab paketinde
geçti, bu commit tesliminde tekrar yapılmadı. Android cmdline-tools/SDK lisans
kapısı önceki kontrolde eksik/unknown; kurulmuş/kabul edilmiş varsayma.
Yerelde Flutter 3.44.4/Dart 3.12.2 kullanıldı; pubspec/lockfile kaynak olsun.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
```

`flutter run` istenen simulator/cihaz seçilerek kullanılabilir. Donanım kaydı
ve ölçüm yapılmadan mic/latency/build başarısı iddia etme.

## 7. En yakın güvenli geliştirme dilimi

Öncelik: lab-owned PCM güvenli okuma + ayrı “kaydını analiz et” diagnostic
akışı. Domain/fake adapter sınırı üzerinden worker'ı bağla; load/analyze
sırasında delete/cancel/background/route/close ve stale callback/new-recording
epoch regresyonlarını yaz. Busy/overshoot/error davranışı açık, score yok.
Worker hard cancel yokken yeni işler/isolate sayısı kontrolsüz büyümesin.

Kayıtlar gelmeden chord placeholder doldurulmaz; bu diğer bağımsız işleri
bekletmez. Sonraki VAD/kalibrasyon/etiketli insan holdout, cihaz performance,
nota segment/alignment, gerçek Aurora evidence UI, öğretim rotaları roadmap
bağımlılıklarıyla ilerler. Frame kod kapısı R1/ürün bitiş kapısı değildir.

Yeni pakette uygun test/format/analyze + CURRENT_ROADMAP/IMPLEMENTATION_LOG
güncelle. Kullanıcı değişikliklerini koru; scope büyütme. Ücretli API/ödeme/
upload/push/deployment/dış mesaj yetkisi yok. Saatlik takip bu sohbette
kurulmuştu; başka model/session'da otomasyon çalışıyor varsayma, tekrarını
kendi kendine oluşturma veya tüm iş bitti demeden kapatma.
