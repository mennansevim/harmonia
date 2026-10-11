# Harmonia — 2/3/4 sesli piyano referansları

**Tarih:** 2026-10-11  
**Durum:** Hazır 2/3/4 sesli piyano kayıtları için klasör/katalog ve uygulamada placeholder ekranı var. Gerçek dosyalar/player/capture/cevap alignment yok. Önceki tekil sample mix kodu alternatif altyapı olarak korunuyor; ana içerik yolu değil.

## Kullanıcının seçtiği çalgı ve açık dosya biçimi

Kullanıcı son açıklamasında, tek seslerde olduğu gibi **klasörden gelen hazır 2/3/4 sesli piyano örnekleri → öğrenci tekrar eder** akışını seçti. Piyanoda çalıp sağlayacağı kayıtlar gelince birlikte incelenecek. Otomatik canlı akor transkripsiyonu veya tekil nota sample'larını mix etme ana akış değil; önceki renderer silinmeden alternatif olarak korunuyor.

Agora'da tek ses loader `src/PitchTest/lib/audioPlayer.ts` üzerinden `/sounds/piano/{noteName}.wav` fetch/decode/cache yapıyor. Harmonia'nın tek ses demo ekranı ise hâlâ mock, laboratuvar referansı sentetik. Agora klasöründen ses kopyalanmadı veya kaynak değiştirilmedi.

## Şimdi eklenen placeholder'lar

Harmonia'da `assets/audio/piano/chords/2-notes/`, `3-notes/`, `4-notes/` klasörleri README ile ayrıldı; hiçbir boş/sentetik WAV konmadı. `catalog.json` bundled asset olarak üç reserved slot taşır. Status `awaiting_recording`; assetPath/targetMidiNotes/rightsReference **null**, gerçek dosya veya hedef etiketi uydurulmaz. Placeholder-only parser ready/path/labels ekleyerek oynatmayı sessiz açmaya izin vermez; gerçek kayıt için ayrıca reviewed manifest/player entegrasyonu gerekir.

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

Hazır 2/3/4 akor kaydı gelirse yeniden mix yapılmaz: dosya ve **bilinen hedef nota listesi** eşlenir; mono/stereo/format ve lisans/import adapter'ı ayrıca hazırlanır. Canlı fiziksel piyano seçilirse teacher/reference capture fazı student-response fazından ayrılır. Bilinmeyen akoru otomatik transkribe etmek ayrı multipitch AR-GE; bu altyapının çalıştığı gibi sunulmaz.

## Oturum ve doğrulama kapıları

Playback tamamlanana kadar student capture açılmaz. Renderer settle silence'ın varsayılan 250 ms değeri oda yankısını/cihaz latency'sini ölçmez veya yok etmeyi garanti etmez. Recall delay playback sonrasında session clock tarafından ayrıca uygulanır. Route/çağrı/background/replay/cancel yeni epoch gerektirir; öğrenmede ipucu/replay sayısı kaydedilir, sınavda nota adı/canlı doğru-yanlış gösterilmez. Hazırlanan dosya ile bu session guard'larının gerçek uygulaması farklı işlerdir; yeni chord coordinator/player henüz yok.

Öğrenci cevabı monofonik frame→nota segment→sıra/set alignment ile değerlendirilir. Eksik/fazla/tekrar, doğru pitch-class ama yanlış oktav ve doğru sesler ama yanlış sıra ayrı kanıtlardır. Mevcut record diagnostic median/periodic ratio başarı/ezgi hafızası değildir. Kayıt/skor toleransları değiştirilmedi.

**Kod doğrulaması:** 221 test (+16), analyze temiz, format 58 dosya/0 değişiklik. 2/3/4-key binding/round-trip/tuning/snapshot/runtime bounds; mix simultaneity/headroom/fades/tail, key contribution/determinism, bank metadata/rate/tuning/origin/missing/short/silent/Nyquist. Gerçek piyano veya öğrenci kaydı, fiziksel telefon ve pedagojik doğrulama yok; mobil build tekrarlanmadı.

**Sıradaki işler:** kullanıcı hazır 2/3/4 ses kayıtlarını getirince birlikte nota/oktav/akort/format/seviye/süre/hak QA; reviewed asset manifest/player ve fake-testli playback→settle/recall→response coordinator. Dosyalar gelene kadar placeholder'ı doldurma/oynatmayı açma. Öğrenci segment/alignment ve cihaz kapıları ayrı; lab PCM→diagnostics/cancel ve diğer bağımsız roadmap işleri devam eder.
