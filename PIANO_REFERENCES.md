# Resonia — 2/3/4 sesli piyano referansları

**Tarih:** 2026-10-11  
**Durum:** Hazır 2/3/4 sesli piyano kayıtları için klasör/katalog, placeholder ekranı, CONS-01a–e reviewed yükleme/playback/composer, CONS-02a/b exact-any-order matcher, CONS-02c gated monofonik cevap kaydı, CONS-02d route/kalite kapılı diagnostic zincir, CONS-02e session ortam kalibrasyonu, CONS-02f uçtan uca attempt coordinator, AUDIO-04a puansız UI, AUDIO-04b mobil composition ve AUDIO-04c atomik banka loader'ı var. Gerçek piyano dosyaları ile birlikte nota/hak/tını QA ve gerçek insan sesi/cihaz benchmark'ı yok; kullanıcı rotası kapalı. Önceki tekil sample mix kodu alternatif altyapı olarak korunuyor; ana içerik yolu değil.

## Kullanıcının seçtiği çalgı ve açık dosya biçimi

Kullanıcı son açıklamasında, tek seslerde olduğu gibi **klasörden gelen hazır 2/3/4 sesli piyano örnekleri → öğrenci tekrar eder** akışını seçti. Piyanoda çalıp sağlayacağı kayıtlar gelince birlikte incelenecek. Otomatik canlı akor transkripsiyonu veya tekil nota sample'larını mix etme ana akış değil; önceki renderer silinmeden alternatif olarak korunuyor.

Agora'da tek ses loader `src/PitchTest/lib/audioPlayer.ts` üzerinden `/sounds/piano/{noteName}.wav` fetch/decode/cache yapıyor. Resonia'nın tek ses demo ekranı ise hâlâ mock, laboratuvar referansı sentetik. Agora klasöründen ses kopyalanmadı veya kaynak değiştirilmedi.

## Şimdi eklenen placeholder'lar

Resonia'da `assets/audio/piano/chords/2-notes/`, `3-notes/`, `4-notes/` klasörleri README ile ayrıldı; hiçbir boş/sentetik WAV konmadı. `catalog.json` bundled asset olarak üç reserved slot taşır. Status `awaiting_recording`; assetPath/targetMidiNotes/rightsReference **null**, gerçek dosya veya hedef etiketi uydurulmaz. Placeholder-only parser ready/path/labels ekleyerek oynatmayı sessiz açmaya izin vermez; gerçek kayıt için ayrıca reviewed manifest/player entegrasyonu gerekir.

Ana mock ekranın müzik-kitaplığı düğmesi **2 / 3 / 4 Ses** ekranını açar. Üç kart “Piyano kaydı bekleniyor” der; dinleme/tekrar düğmeleri disabled. No permission/player/capture/scorer; loading/error/retry ve geç gelen katalog sonucu güvenli. Tek ses demo/laboratuvar ayrı korunur.

Son doğrulama **230 test (+9)**, analyze temiz, format 63 dosya/0 değişiklik. Bundled JSON load, schema/null/path/count/duplicates/fail-closed; home navigation, disabled buttons, 320px/1.8× text, load error/retry ve disposal regression. Fiziksel ses, mobil build ve öğrenci değerlendirmesi değil. Kayıtlar gelene kadar bu bölüm placeholder kalır; diğer bağımsız roadmap işleri devam edebilir.

Ürün akışı: **piyano seslerini birlikte duy → referans tamamen bitsin → sessiz geçiş/bekleme → öğrenci notaları birer birer söylesin → nota bazında açıklama**. Exact cevap varsayılanı alttan üste; `anyOrder` isteğe bağlıdır. Cevapta aynı anda 2/3/4 insan sesini ayırma bu iş değildir. Piyano harmonikleri öğrenci cevabında ek notalar sayılmaz. Kaydın tüm median'ı bir akor cevabının yerine kullanılamaz.

## Kodda hazırlanan

- Domain `PianoChordReference`: 2/3/4 farklı MIDI tuşu, immutable/alttan üste liste, 12-TET A4'dan isim/frekans üretimi, learning/recall modları ve exact/anyOrder. `configure(...)` mevcut `ConfiguredExercise`/simultaneous chord protokolüne bağlar; onset'ler sıfır, accompaniment kapalı, recall hedefi gizli. Yeni veri eski tek ses demosunu değiştirmez.
- İlk teknik bütçe: MIDI 21–108, A4 **400–480 Hz** (varsayılan 440), süre **100–5000 ms** (1500), settle silence **0–2000 ms** (250), recall delay **0–10000 ms**, 1–10 reference play. Bunlar altyapı sınırı/varsayılandır; öğretmen onaylı süre/rubrik veya tüm register'da vokal detector desteği değildir.
- Infrastructure `PianoNoteSample`: exact MIDI key, declared A4, actual mono PCM16 decoded Hz, asset ID, rights reference, recordedPiano/syntheticTest origin. 8–48 kHz/en çok 5 sn; boş sample/eksik metadata ve Nyquist üstü etiket reddedilir. Bunlar **etiket ve hak referansı beyanıdır**, nota/tını/izin doğrulaması değildir.
- `PianoChordRenderer`: gereken her tuş için tek sample; aynı gerçek Hz/akort/origin zorunlu. 2/3/4 kaydı **tek PCM/WAV'da sample zero'dan** başlatır; ayrı player start yarışları yok. Eksik, yanlış, duplicate, kısa/silent sample fail-closed; resample, pitch shift veya sinüs fallback yok.
- Ortak mix gain **0.8 / nota sayısı**, worst-case coherent peaks için headroom; kaynaklar arası göreli seviye korunur. 2 ms giriş/12 ms kesim fade, ardından settle silence; kaynak dosya değiştirilmez. Default 1.5 sn için her kaynak en az 1.5 sn olmalı, uzun kuyruk fade'le kesilir. Ses dengesi/tını ve fade seçimi gerçek piyano QA bekler.

Renderer senkron **hazırlama** kodudur; native worker/caching/player entegrasyonu yok. Canlı UI thread'de sürekli karıştırılmaz. Çıktı `RenderedPianoChord.wav.encode()` üzerinden ileride tek player'a hazırlanabilir. Metadata source'ları/rights referanslarını korur; hiçbir dosya bu paket tarafından okunmadı, kaydedilmedi, indirilmedi veya dağıtılmadı. Sinüs ve sabit peak testleri sadece `syntheticTest` olarak etiketlendi; piyano sesi diye sunulmadı.

## Başlangıç içerik tanımları (örnek, eğitimci onayı değil)

```dart
PianoChordReference(midiNotes: [60, 67]);         // C4, G4
PianoChordReference(midiNotes: [60, 64, 67]);     // C4, E4, G4
PianoChordReference(midiNotes: [60, 64, 67, 71]); // C4, E4, G4, B4
```

Dosya bankası MIDI key + declared tuning ile resolve edilir; dosya adından doğru nota/akort çıkarılmaz. Private dataset `AudioFixtureLoader` hash/header bütçe kapısından geçebilir; fixture→piano-bank metadata adapter'ı henüz yazılmadı. Bankanın bütün sample'ları için kaynak/hak zinciri, nota+oktav/A4 etiketleri, peak/seviye/süre ve piyanonun kayıtta netliği doğrulanmalı. Agora'nın lisansı belirsiz sample'ları kopyalanmadı.

Hazır 2/3/4 akor kaydı gelirse yeniden mix yapılmaz: dosya ve **bilinen hedef nota listesi** eşlenir. CONS-01a `ReviewedChordRecordingManifest` yalnız açıkça `user_recorded_piano`, `pcm_s16le_wav`, 2/3/4 ses klasörü, 100 ms–10 sn metadata süresi, mono/stereo, 8–48 kHz, SHA-256, hak referansı ve ayrı etiket inceleme referansı kabul eder. MIDI hedefleri alttan üste ve ses sayısıyla aynı olmalıdır; kimlik/yol/hash tekrarları reddedilir. CONS-01b adapter yalnız seçili kök altındaki normal dosyayı açar; kök/ara/final symlink ve kaçışları reddeder, byte bütçesini okumadan önce uygular, SHA-256 sonrası RIFF/WAVE PCM16 mono/stereo header'ını parse eder ve gerçek sample rate/channel/frame değerlerini manifestle exact karşılaştırır. Başarılı yükleme defensive byte kopyası üretir ama player çağırmaz. CONS-01c bu snapshot'ı dedicated player'a yalnız explicit eylemle verir; tam playback + stop + bounded recall delay sonrasında `readyForSequentialResponse` olur. Stop, background ve route/focus kesintisi kapıyı iptal eder; otomatik resume yoktur. Hash/header veya koordinatör çalışması nota, akort, piyano tınısı, hak sahipliği ya da eğitim uygunluğunu kanıtlamaz. Canlı fiziksel piyano seçilirse teacher/reference capture fazı student-response fazından ayrılır. Bilinmeyen akoru otomatik transkribe etmek ayrı multipitch AR-GE; bu altyapının çalıştığı gibi sunulmaz.

## Oturum ve doğrulama kapıları

Playback tamamlanana kadar student capture açılmaz. CONS-01c bunu soyut player ve test clock'u üzerinde uygular; gerçek UI henüz bu kapıyı tüketmez. Renderer settle silence'ın varsayılan 250 ms değeri oda yankısını/cihaz latency'sini ölçmez veya yok etmeyi garanti etmez. Recall delay playback sonrasında session clock tarafından ayrıca uygulanır. Route/çağrı/background/replay/cancel yeni epoch gerektirir; mevcut koordinatör kesintide kapıyı kapatır ve otomatik devam etmez. Öğrenmede ipucu/replay sayısının kalıcı kaydı ve sınav modu sonraki wiring işidir; sınavda nota adı/canlı doğru-yanlış gösterilmez.

CONS-01d ile replay kotası session içinde uygulanır. Learning 1–10 açık limit
alır; recall exam yalnız bir completed playback kabul eder ve
`targetVisibleDuringResponse=false` yayınlar. Sayaç player completion callback'i
sonrası artar; iptal, route/background kesintisi veya start failure kotayı
tüketmez. Replay başladığı anda response readiness kapanır ve tekrar tam
playback+recall gerekir. Bu sayı sesin gerçekten duyulduğunu kanıtlamaz ve
history/mastery değildir; kalıcı event/UI wiring sonraki iştir.

CONS-01e loader sonucundaki kayıt kimliği/nota metadata'sı ile defensive WAV
snapshot'ını aynı session'a bağlar; UI'nın bunları ayrı kaynaklardan yanlış
eşleştirmesine gerek bırakmaz. Her session fresh player alır, create autoplay
yapmaz ve geçersiz sınav/replay politikası player tahsisinden önce reddedilir.
Mobil player/backend/worker seçimi ve gerçek UI/capture composition kod-testlidir;
kayıt kökü ile kullanıcı navigasyonu gerçek kayıtların ortak QA'sına kadar kapalıdır.

Öğrenci cevabı monofonik frame→nota segment→sıra/set alignment ile değerlendirilir. Eksik/fazla/tekrar, doğru pitch-class ama yanlış oktav ve doğru sesler ama yanlış sıra ayrı kanıtlardır. Mevcut record diagnostic median/periodic ratio başarı/ezgi hafızası değildir. Kayıt/skor toleransları değiştirilmedi.

CONS-02a exact sıra kolunu kodlar: reviewed manifestteki MIDI+A4 hedeflerini
nominal low→high olaylara, diagnostic segmentleri de yalnız gözlenen sıraya
çevirir. Eksik/fazla/mükerrer/wrong-pitch/wrong-octave mevcut bounded sequence
alignment'ında kalır; hedeflerle aynı mutlak pitch seti farklı sıradaysa ayrıca
`reorderedTargetCandidates` görünür. Segment onset'leri timing kanıtı veya
hafıza puanı yapılmaz. Boş cevap `noResponse`, bozuk segment kanıtı
`invalidEvidence`; her ikisinde başarı uydurulmaz.

CONS-02b `ResponseOrder.anyOrder` kolunda exact alignment'ı silmeden ayrı
bounded set özeti üretir. Her aday en fazla bir reviewed hedefe atanır. Doğru
mutlak pitch, doğru pitch-class/yanlış oktav, eksik hedef ve fazla/mükerrer aday
sayılır; ilgisiz perdeyi keyfî bir hedefe “wrong pitch” diye bağlamak yerine bir
eksik + bir fazla bırakır. Setin tamamı doğru olsa bile bu sadece diagnostic
candidate match'tir; VAD/insan benchmark'ı olmadan öğrenci başarısı değildir.

CONS-02c izin diyaloğunu ilk referanstan önce tamamlar ve tam playback+recall
kapısı açılmadan öğrenci kaydı başlatmaz. Öğrenci 2/3/4 hedefi aynı anda değil,
tek sürekli kayıtta sırayla söyler. Stop sonrası backend kaydı silinir; immutable
PCM snapshot sonraki worker için bellekte kalır. Replay, route/focus kesintisi,
iptal ve pending native start readiness'i kapatır; otomatik resume yoktur. Bu
snapshot henüz ses etkinliği, kalite, nota veya başarı kanıtı değildir.

CONS-02d snapshot'ın capture öncesi route'unu korur ve aynı route/sample rate'e
bağlı kullanılabilir noise-floor kalibrasyonu olmadan DSP'yi başlatmaz. Kalite
geçerse mevcut bounded worker, target-independent segmenter ve explicit
exact/any-order matcher sırasıyla çalışır. Worker metadata/provenance capture'ı
değiştiremez. Ortaya çıkan eşleşme yalnız diagnostic candidate evidence'tır;
insan sesi/VAD, hafıza başarısı, konservatuvar puanı veya mastery değildir.

**Kod doğrulaması:** 221 test (+16), analyze temiz, format 58 dosya/0 değişiklik. 2/3/4-key binding/round-trip/tuning/snapshot/runtime bounds; mix simultaneity/headroom/fades/tail, key contribution/determinism, bank metadata/rate/tuning/origin/missing/short/silent/Nyquist. Gerçek piyano veya öğrenci kaydı, fiziksel telefon ve pedagojik doğrulama yok; mobil build tekrarlanmadı.

CONS-02e açık ortam ölçümünü aynı oturum/backend yaşam döngüsüne bağlar; izin,
route, bounded silence, snapshot, discard ve calibration sırası testlidir.
Calibration sonucu skor değildir ve diagnostic aşamasında yeniden doğrulanır.

CONS-02f kalibrasyon→dinle→sırayla söyle→diagnostic durumlarını tek UI-facing
coordinator'da toplar. Pending worker sonucu cancel/replay/close sonrası
yayımlanamaz; kalite retry ve analiz unavailable öğrenci hatası değildir.

**AUDIO-04c banka kapısı:** özel kayıt kökündeki sabit
`reviewed_chords.json` direct-child normal dosya olmalı; bounded UTF-8/strict
schema parse, 2/3/4 kapsamı ve listedeki bütün WAV path/hash/header kontrolleri
bitmeden immutable banka yayımlanmaz. Stream'den gelen başarılı prefix ürün
availability'si değildir. Bu mekanizma nota/akort/tını/hak incelemesi değildir.

**Sıradaki işler:** kullanıcı hazır 2/3/4 ses kayıtlarını getirince birlikte nota/oktav/akort/format/seviye/süre/hak QA; onaylı kökü atomik banka loader'ından geçirip ancak sonra kullanıcı navigasyonunu açma. Dosyalar gelene kadar placeholder'ı doldurma/oynatmayı açma. Kalıcı replay event'i, BENCH/VAD ve cihaz lifecycle/route kapıları ayrı; diğer bağımsız roadmap işleri devam eder.
