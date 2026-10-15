# Harmonia — Ses testi ve kayıt prototipi devam notu

**Güncelleme:** 2026-10-11. Bu dosya uygulanmış altyapıyı ve henüz uygulanmamış cihaz işlerini ayırır.

## Şu an kodda olan

- `ExerciseProtocol`: nota onset/süreleri ve ritim onset'leri beat biriminde; BPM, ölçü pay/payda, 12TET/A4 bağlamı, birlikte/sıralı referans, exact/anyOrder cevap, bekleme, referans dinleme kotası, ipucu/transpozisyon/eşlik politikası. Beat birimi ölçünün paydasına karşılık gelir.
- `ConfiguredExercise`: yeni katalogda metadata/mod/skill/hedef ile protokol çelişkisini reddeder. Eski const `Exercise` demo için korunur; henüz ekran/katalog bu yeni sözleşmeyi kullanmaz.
- Protokol JSON sürümü **1**, sonuç JSON sürümü **2**: aynı sürüm sayacı değildir. Protokol round-trip testi var; katalog ve sonuç persistence/fromJson/migration henüz yok.
- Recall sınavında hedef gizlidir; ipucu/transpozisyon/eşlik reddedilir. Deşifrede hedef görünür. Eşlik koro moduna özgüdür; kulaklık/route koşulu session katmanında uygulanacaktır.
- `MeasurementProvenance`: unverified/mock/synthetic/microphone + analyzerVersion. Mock pitch'in bütün senaryoları etiketli; scorer etiketi korur. Kaynağı bilinmeyen eski sonuç mikrofon sayılmaz. Gelişim cohort'u kaynak/analyzer sürümünü de karşılaştırır.
- Sonucun hedef, ölçüm, hata ve nested evidence verileri defensive deep snapshot'tır. Non-finite ve JSON olmayan evidence reddedilir; scorer bozuk sayıyı önce null'a çevirir. Standalone legacy `ExerciseError` girdisi mutable kalabilir; **sonuca alınan snapshot immutable**.
- `Pcm16Wav`: RIFF/WAVE, mono PCM16 decode/encode; gerçek Hz header'dan okunur; kısmi/uyumsuz chunk, stereo/float codec ve hatalı format reddedilir. Başlangıç destek sınırı 8–192 kHz, 120 saniye. AAC/MP3/RF64/çok kanal/resampling yok.
- Sentetik sinüs üretimi deterministik, sınırları fade'li; referans/codec testi içindir. İnsan sesi veya pitch motoru doğruluk benchmark'ı değildir.
- `AudioFixture`: kaynak, signal türü, development/holdout, gerçek Hz/sampleCount, SHA-256 metni, A4, beklenen frekanslar, hak/consent referansı ve anonim subjectGroup. Metadata manifest doğrulaması duplicate id/hash ve kişi grubunun development/holdout'a sızmasını reddeder. Sentetik veriler gerçek holdout'a giremez. Metadata JSON round-trip eklendi.
- `AudioFixtureManifest` / `AudioFixtureEntry`: sürüm 1, `mono_pcm16_wav` codec, explicit göreli WAV path → metadata eşlemesi. Boş/1024'ten büyük manifest, case-insensitive duplicate path, absolute/URL/traversal/boş segment reddedilir. Bu şema exercise protocol v1 / sonuç v2 sürümleriyle karıştırılmaz.
- `AudioFixtureLoader`: seçilmiş yerel kök altında dosya varlığı/tür/path, byte bütçesi, SHA-256, mono PCM16 header, gerçek sample rate ve sample count doğrulaması. Symlink dosya/parent ve kökten çıkan yol reddedilir. Dataset read-only'dir; eksik/bozuk dosya sessiz atlanmaz. Hatalar tipli reason/id taşır; içeriği/absolute private path'i kendiliğinden loglamaz.

**Sınırlar:** tuning metadatası nota frekansını otomatik üretmez veya isim/frekans/A4 tutarlılığını doğrulamaz. İpucu/dinleme politikası yalnız tanımdır, session sırasında kullanımı henüz kaydedilmez. Loader byte/hash/header tutarlılığını doğrular; nota etiketi, consent/hak referansının gerçek geçerliliği ve pitch doğruluğu doğrulanmaz. Ritim/ezgi provenance entegrasyonu, tuning/hint cohort ve attempt dedup bekliyor. Referans onset'leri cevap timestamp'i değildir; birlikte duyulan akor için vokal segment/alignment daha sonra uygulanır.

## Fixture loader kullanımı ve tamamlanma sınırı

1. İzinli özel dataset kökü seçilir. JSON, `AudioFixtureManifest.fromJson` ile doğrulanır; her entry `path` ve `fixture` içerir. Fixture metadata'nın tüm alanları `AudioFixture.toJson` / `fromJson` sözleşmesindedir; kaynak/partition/consent eksikse gerçek olarak çıkarım yapılmaz.
2. `AudioFixtureLoader(root: Directory(...))` tek entry için `load`, manifest için `loadManifest` sağlar. Varsayılan dosya bütçesi **4.224.044 byte**; en çok **46.080.044** olarak explicit yapılandırılabilir. Bu bir toplam dataset bütçesi değildir.
3. Manifest sequential stream'dir; ilk bozuk entry'de hata verir. Önceden teslim edilmiş entry'ler, **bütün dataset geçti** anlamına gelmez. Stream sonuna ulaşılmadan dataset kabulü verilmez; PCM örnekleri bellekte topluca biriktirilmez.
4. `LoadedAudioFixture` immutable metadata ve decode edilmiş PCM taşır; hak/etiket doğrulaması yaptığını iddia etmez. Loader dosya yazmaz/silmez, upload/export yapmaz. Gerçek insan fixture'ı bu oturumda eklenmedi.

**Güvenlik sınırı:** Manifestlerin göreli ASCII path'leri ve mevcut symlink bileşenleri reddedilir; seçilen root canonicalize edilir. Dataset okunurken aynı dosya handle'ının uzunluğu/byte/hash'i kontrol edilir. Bu, dosyaları eşzamanlı değiştiren kötü niyetli yerel süreçlere karşı kernel-level sandbox veya tüm TOCTOU yarışlarını kapatma garantisi değildir. Güvenilen, değiştirilmeyen private dataset kullanılır; opaque fixture ID'lerine kişisel bilgi koyulmaz. Web/asset/remote loader ve büyük dataset importer henüz yok.

**2026-10-11 heartbeat doğrulaması:** manifest round-trip, malformed schema/source/numeric/consent, path/duplicate/bütçe, disk dosyası missing/hash/rate/count/truncated/stereo/symlink/nested/fail-fast kontrolleri eklendi. **123 test geçti (+23)**; analyze temiz. Test dosyaları geçici klasörde sentetik üretilir/temizlenir, öğrenci kaydı değildir. Bu tur iOS build veya gerçek mikrofon testi yapılmadı.

## Referans kayıt envanteri

Agora'nın `public/sounds/piano` klasöründe **41 WAV** bulundu. Örnek olarak incelenen **C4.wav ve A4.wav: mono, 16-bit PCM, 48.000 Hz**. Diğer 39 dosyanın header/hash/süre/pitch doğrulaması yapılmadı. Bunlar piyano referanslarıdır; insan sesindeki algılama başarısını kanıtlamaz.

Repo kökünde MIT lisansı var; piyano sample'larının özgün üretici/kaynak ve üçüncü taraf hak zinciri bu incelemede doğrulanmadı. Harmonia'ya ses dosyası kopyalanmadı. Envanter loader'ı, tüm dosyaların hash/header/süre/nota etiketini ve kaynak/hak referansını kaydetmeli. Dağıtılabilirlik doğrulanana kadar yerel prototip sentetik referans kullanabilir.

Gerçek insan benchmark: hedef doğru/yanlış nota, +/- oktav, sessizlik, konuşma/gürültü, kararsızlık, kısa buffer, clipping, eşlik sızıntısı. Gerçek cihaz/model/route ve kayıt koşulları ayrı manifest alanlarıyla genişletilmeli. Eğitimci etiketleri ve izinli özel depolama kullanıcı koordinasyonu gerektirir; sahte katılımcı veya onay üretilmez.

## AUD-DEV-02 — Yerel kayıt laboratuvarı eklendi; cihaz kapısı bekliyor

Kullanıcının “şimdi başlat” isteğiyle dar prototip uygulandı. Ana demo ekranının sağ üstündeki mikrofon düğmesi **Ses laboratuvarı** ekranını açar. Ekrana girince izin istenmez/kayıt açılmaz. Sentetik C4 referansı → açık kullanıcı eylemiyle izin → en fazla 10 sn WAV kayıt → header doğrulama → metadata/kendi kaydını dinleme/silme. Bu ekran skor, pitch, AI veya upload üretmez; eski mock tek ses ekranı ayrı kalır.

`AudioCapture` / `ReferencePlayback` / `AudioLabBackend` domain arayüzleri; `AudioLabController` serialized komutlar ve iptal epoch'u; `PluginAudioLabBackend` yerel dosya/record/player adapter'ı eklendi. Sample rate stop'ta WAV header'dan alınır. UI'ya yalnız sample rate/count metadata gider; PCM listesi gelişim veya AI'ye taşınmaz. Playback bitişi komut kuyruğunu bloke etmez. Eski permission/start/stop/playback callback'leri iptal edilmiş oturumu diriltemez.

Arka plan/route/focus kesintisinde kayıt iptal edilir; **otomatik resume yok**. Ön plandaki OS izin diyaloğunun inactive geçişi, kullanıcının izin isteğini yanlışlıkla iptal etmez. Route/focus event'leri audio_session ve recorder pause event'lerinden alınır; gerçek Bluetooth/kulaklık desteği doğrulanmış değildir. Kalıcı izin reddi ayrı OS durum olarak sınıflandırılmaz; izin reddi açıklaması ve manuel ayar yönlendirmesi var.

Adapter yalnız iOS/Android içindir; web laboratuvarı desteklenmez. Her instance kendi benzersiz geçici klasöründe reference.wav/recording.wav üretir; dışarıdan dönen farklı path okunmaz. İptal/replacement/close kendi kayıt dosyasını temizler. Close, bir işlem hatalansa da diğer kaynakları/dosyaları kapatmayı dener; hata gizlenerek başarı sayılmaz. İşletim sistemi uygulamayı zorla öldürürse geçici dosya silinmesini garanti eden startup orphan cleanup henüz yok. Kayıt export/share/upload yok. iOS açıklaması ve Android RECORD_AUDIO izni eklendi.

**Doğrulama:** controller ve widget fake testleri, analiz ve iOS simulator debug build. Bunlar fiziksel telefonun mikrofon/latency/izin/route testini karşılamaz. Android ortamında cmdline-tools eksik, lisans durumu unknown; Android build bu oturumda denenmedi, lisans kabulü yapılmadı.

Resmî paket sayfalarında kontrol edilen adaylar:

- [record](https://pub.dev/packages/record): mikrofon dosya/stream; WAV/PCM16, izin kontrolü, stop/cancel. İnceleme anındaki sayfa 7.1.2 gösterdi. Kurulumda Flutter/platform uyumu tekrar çözülüp lockfile'a kaydedilecek.
- [just_audio](https://pub.dev/packages/just_audio): yerel dosya/referans çalma, stop/dispose, çalma bitişini bekleme. İnceleme anındaki sayfa 0.10.6 gösterdi.

Harmonia lockfile'ında **record 7.1.2, just_audio 0.10.6, path_provider 2.1.6, audio_session 0.2.4** çözüldü. Paket varlığı; latency, route yönetimi veya DSP doğruluğu garantisi değildir. Cihazda kayıt henüz yapılmadı.

### Dar dilimin kabul matrisi / kalanlar

1. Ayrı, açıkça etiketli yerel **ses laboratuvarı** ekranı; mock sonuç ekranıyla karıştırma.
2. `AudioCapture` / `ReferencePlayback` arayüzleri, fake adaptör ve coordinator testleri. İlk akış: idle → referencePlaying → idle → recording → stopping → recorded; error/cancel ayrı.
3. Sentetik C4 referansı. Çalma bitmeden kayıt açılmasın; bu laboratuvar koro eşlik politikasını temsil etmez.
4. Kullanıcı basınca mikrofon izni; kısa açıklama; ret/kalıcı ret anlaşılır çıkış. Otomatik kayıt, upload, AI veya puanlama yok.
5. En fazla 10 sn geçici WAV kaydı; format/Hz istenen config'den tahmin edilmesin, header okunup doğrulansın. Unsupported format açık hata.
6. Kaydı dinle/sil/iptal; sadece oturumun ürettiği kesin dosyaları temizle. Uygulama arka plana giderken, route değişirken ve sayfadan çıkarken kaynaklar kapansın; async eski callback yeni oturuma sızmasın.
7. iOS mikrofon açıklaması / Android izin ve minimum platform uyumu; kaynak kod ve lockfile kontrolü. Web ayrı adaptör işidir.
8. Fake test → analyze → mobil build → gerçek iOS ve Android izin/route/iptal testi. Donanım yoksa cihaz kapısı açıkça beklesin.

Sonraki AUD-DEV-03: gerçek frame analyzer, RMS/VAD/oktav regresyonları. Bu dosyadaki codec veya sentetik tone testinin geçmesi o işi tamamlamaz. Aurora görseli gerçek enerji/cents/confidence akışı sonrası bağlanır.

**Otomatik devam sırası (güncel):** Aşağıdaki frame kod alt kapısı geçti. Bounded kayıt aggregation adapter'ı → laboratuvar PCM/worker/isolate/session bağlantısı → fiziksel iOS/Android QA. Fixture loader kod kapısı testli, gerçek dataset/etiket benchmark açık. Startup orphan cleanup, kapatma hatasının kullanıcıya aktarılması ve düşük cihaz performansı bekliyor; sentetik testle insan kapısını kapatma.

## AUD-DEV-03 — Deneysel frame kod alt paketi (08:41 UTC heartbeat)

`YinPitchFrameAnalyzer`: pure Dart, target-independent YIN-style çekirdek. `PitchFrameEstimate`: status, nullable Hz/RMS dB, periodicity. Yalnız **8–48 kHz**, en çok **8192 örnek**; unsupported rate/büyük/non-finite/[-1,1] dışı PCM → invalidInput. Kısa/boş → insufficientData; fallback/özyineleme yok. Minimum pencere üç en düşük-frekans periyodu + 2 örnek, önerilen power-of-two (48 kHz'de varsayılan 4096). Resampling yok; codec'in daha yüksek rate desteği detector desteği anlamına gelmez.

DC çıkarılmış RMS, finite **−120 dB** tabanı. Varsayılan sinyal kapıları: **50–2000 Hz**, **−50 dB** sessizlik, CMNDF **0.15**, |sample|≥0.999 örnek oranı **>%1** clipping. Bunlar constructor'da doğrulanan deneysel detector ayarları, öğrenci başarı toleransı değildir. İlk eşik altı yerel minimum/parabolic lag interpolation; hedefe göre frequency seçimi yok. Kabul edilemeyen/out-of-band aday → unreliable, Hz null ve periodicity 0. Band dışı fundamental'ın subharmonik olarak bulunmaması garanti edilmez.

**Periodicity:** seçilen integer lag'de **1−CMNDF**, [0,1] diagnostic. İnsan sesi, doğru nota veya başarı olasılığı; kayıt voiced ratio veya stability değildir. Elektronik ton/eşlik/konuşma ayırıcı VAD yok. Sadece clock doğruysa Hz anlamlı; yanlış ama desteklenen sample-rate PCM'den otomatik fark edilemez. Hiçbir frame score, source veya consent üretmez. Silence/clip/invalid/unreliable öğrenciye 0 puan değildir.

`PitchDeviation`, detector'dan sonra explicit Hz ile signed **absolute cents**, nearest-octave **octaveOffset**, **pitchClassCents** residual verir. Frequency folding yok; log farkı extreme finite Hz oran taşmasını önler. Yarım oktav bağları sıfırdan uzağa yuvarlanır; nota/set matcher değildir. Yanlış oktavı başarı saymayan scorer ve 50 cents/25 cents/0.6 toleransları değişmedi.

### Doğrulama / açık kapılar

- **184 test (+61)**, analyze temiz, format **50 dosya/0 değişiklik**. İlk koşuda zero RMS dB tabanının exact floating-point farkı düzeltildi; tam suite tekrar geçti.
- 8/16/44.1/48 kHz × 65.406/130.813/261.626/440/880/1200 Hz sentetik sinüs: determinism, nota/oktav ve <15 cents regression. Zayıf temel/kuvvetli 2./3. harmonik, gain/phase/DC, +/-oktav; silence/sub-gate/3 seeded noise/clip; kısa/NaN/Inf/out-of-range/oversized/unsupported/config/boundaries.
- PCM16 encode→decode→fade dışı frame dört rate'te <5 cents synthetic regression. Yanlış-clock testi caller'ın header/route doğrulamasını atlayamayacağını gösterir. Bunlar gerçek insan doğruluk oranları değil.
- Gerçek insan/mikrofon/eğitimci etiketi, mobil build, CPU/latency ve pedagojik pilot bu tur yapılmadı. Mock ekran ve laboratuvar korunuyor; canlı DSP bağlantısı yok.

**Sonraki paket:** bounded overlap/kayıt aggregation; valid-frame denominator, silence/clip/noise abstention, log-frequency stability/raw oktav, explicit source/version. **Tek frame'den voicedRatio=1/stability=0 uydurup scorer'a bağlama.** Periodic coverage ve insan sesi/VAD iddiasını ayır; sözleşme değişirse açık sürümle. Ardından lab-owned PCM yükleme + worker/isolate/cancel/session epoch; eski frame yeni denemeye sızmasın. Senkron çekirdeği UI isolate'ında sürekli çalıştırma.

Tam YIN/best-local-estimate/temporal tracking veya Agora McLeod port'u değil. Benchmark olmadan algoritma üstünlüğü/nihai seçimi iddia edilmez. AUD-DEV-03 sadece **frame kod alt kapısı**; VAD/kalibrasyon, gerçek holdout ve cihaz kapıları açık. Aurora alanı bu kayıt/kanıt hattından sonra; lisansı belirsiz ses dağıtımı yok.

## AUD-DEV-03 — Kayıt diagnostics ve native worker (kullanıcı devam paketi)

`RecordingPitchAnalyzer`: target bağımsız, sabit frame config; **8–48 kHz, en çok 10 sn/512 frame**. DSP öncesi tüm PCM finite/[-1,1] doğrulanır, bozuk tail temiz prefix'i geçerli yapamaz. Önerilen power-of-two pencere boyundan kısa kayıtta insufficientData, padding/uydurma sonuç yok. Regular half-hop full windows; son grid endpoint kaydın sonu değilse bir full-window end-anchor eklenir. Start indeksleri yinelenmez, sampleCount/startSample ile clock-derived konumlar korunur; bunlar gerçek cihaz latency ölçümü değildir.

`RecordingPitchEvidence`: immutable full frame listesi ve tüm status count'ları, explicit source (default **unverified**) + algoritma/default-config version; PCM içermez. JSON schema 1 local export sözleşmesi; importer/persistence/upload/AI entegrasyonu yok. Status invalidInput/insufficientData/noPeriodicSignal/periodicSignalObserved; none doğru/yanlış öğrenci kararı değildir.

- **PeriodicFrameRatio:** accepted periodic frame sayısı / tüm analyzed full frame sayısı; silence/clipped/unreliable denominator'da kalır. Hiç frame yoksa **null**, analiz edilmiş sessizlik/noise'da **0**. Count based, duration weighted değil; tail anchor farklı overlap taşıyabilir. Bu human voiced ratio veya confidence değildir.
- **RepresentativeFrequencyHz:** observed Hz'lerin lower median'ı; yalnız actual accepted candidate seçilir, iki oktavın ortasına yeni nota üretilmez. Kayıt gerçekten tek nota mı, öğrenci mi veya eşlik mi olduğunu kanıtlamaz. Trace ayrıca incelenir.
- **PitchDispersionCents:** accepted log2(Hz) ×1200 değerlerinin population std-dev'i (Welford). İkiden az accepted frame'de **null**, çok stable tone'da gerçek **0** olabilir. Oktav geçişi ~1200 cents fark olarak kalır, pitch-class'a katlanmaz. Voice stability/timing/memory skoru değildir; overlap'li frame'ler bağımsız deneme sayılmaz.

`RecordingPitchWorker` async domain sınırına native `IsolateRecordingPitchWorker` eklendi: budget dışı PCM kopyalanmaz; bounded valid-size PCM await öncesi immutable snapshot, tek active iş/instance, separate top-level scope ve `Isolate.run` DSP. Hata web/UI fallback ile gizlenmez, finally busy state'i açar. Native VM testte gerçek isolate çalıştırıldı; bu düşük cihaz jank/CPU/bellek/latency benchmark değildir. Snapshot/transfer maliyeti cihazda ölçülmedi. **Hard cancel yok**; worker henüz lab/controller'a bağlı değil. Sahip session epoch ile stale result'ı reddetmeli, iptalden sonra çalışan işi/yeni worker sayısını sınırlamalı.

**Doğrulama:** 205 test (+21: 17 recording + 4 worker), analyze temiz, format 54 dosya/0 değişiklik. Dört rate/determinism/source; denominator/silence/noise/clip-tail; endpoint/immutable/no-padding/late non-finite; octave trace+dispersion ve lower median; 10 sn yüksek-rate silence bütçesi; isolate/sync JSON eşitliği, pending-input mutation, concurrent request/busy reset ve invalid input. Tüm sesler sentetik; insan fixture, gerçek mikrofon veya pilot yok. Native mobil build bu tur tekrar yapılmadı.

**Sonraki paket:** lab-owned PCM güvenli okuma, ayrı “analiz et” diagnostic görünümü ve fake-worker coordinator testleri. load/analyze sırasında delete/cancel/background/route/close; eski worker result/hata yeni kayda sızmasın. UI hiçbir periodic oranı başarı/voice gibi sunmasın. Lab stop timer'ın overshoot kabulü ile analyzer'ın strict 10 sn bütçesi aynı değildir: sınır aşımını sessiz kesme/yanlış öğrenci puanı yapma; açık tekrar/bütçe durumu gerekir. VAD, kalibrasyon, gerçek kayıt+etiket benchmark ve cihaz profili öncesi score ekranı mock kalır. Startup orphan cleanup ve shutdown error görünürlüğü de açık.

## Piyano referans hazırlama — 2/3/4 ses kod alt kapısı

Kullanıcı referans çalgısını piyano seçti. [PIANO_REFERENCES.md](./PIANO_REFERENCES.md) domain MIDI/tuning hedefi, single-clock sample mix, source/hak ve format ayrımını tanımlar. **221 test (+16)**; analyze temiz; format **58 dosya/0 değişiklik**. 2/3/4 distinct hedef/protokol ve round-trip; same-sample contribution/coherent peaks≤0.8, fade/settle, bank ordering/determinism; missing/wrong/duplicate/short/silent/rate/tuning/origin/Nyquist/metadata kapıları testli. Sinüs ve worst-case constant sinyaller sadece test, piyano sample'ı gibi sunulmadı.

Gerçek piyano dosyası/etiket/lisans, import/player/capture ve sıralı öğrenci segment/alignment yok. Settle default 250 ms yankı/latency doğrulaması değildir; yeni chord session'da playback bitene kadar mikrofonun kapalı tutulması ayrıca fake/cihaz testi ister. Bu paragrafın eski biçim sorusu kullanıcı son açıklamasıyla çözüldü: hazır 2/3/4 sesli kayıtlar klasörden çalınacak. Renderer alternatif; ana akış mevcut WAV'ı oynatır. Monofonik record median/periodic ratio chord cevabını doğru saymak için kullanılamaz. Tek ses toleransları ve cihaz/öğretmen kabul kapıları değişmedi.

**Placeholder devam paketi:** 230 test (+9), analyze temiz, format 63 dosya/0 değişiklik. Üç reserved klasör, strict null-file/null-target katalog ve yalnız JSON asset; gerçek kayıt yok. Ana ekran route'undan disabled-action placeholder; bundled load, malformed/ready/path fail-closed, immutable list, narrow/large text, load error/retry/dispose testleri. UI ses çalmaz/mikrofon açmaz/skor üretmez. Kullanıcı dosyaları getirince birlikte QA, sonra reviewed manifest/player/session; sadece dosya varlığı veya placeholder status değişimi feature'ı açmaz. Gerçek ses/telefon/mobil build kapısı bu paketle geçilmedi.

## 13:44 UTC — Lab kayıt/worker diagnostic bağlantısı

`AudioRecordingReader` yalnız backend-owned tamamlanmış kayıt; immutable PCM
snapshot ve explicit source. Plugin gerçek header mono PCM16'yı `readLabWav`
ile okur: regular-file kontrolü, aynı handle length/read/length, 4,224,044 byte
bütçe, malformed/missing/symlink reddi. Private temp sahipliği varsayılır;
kernel sandbox, kötü niyetli eşzamanlı filesystem mutation veya içerik QA değil.
Decode ve snapshot ana isolate'da; cihaz performansı ölçülmedi.

Explicit analyze: controller metadata eşleşmesini ve 8–48 kHz/10 sn bütçesini
worker öncesi doğrular. Lab'ın stop overshoot (≤11 sn) kaydı replay için korur
ama strict 10 sn analiz bütçesini aşanı açıklayıcı hata ile reddeder; truncate yok.
File load kaynak kuyruğundadır, silme/close bounded read bitişini bekler; DSP
queue dışında olduğundan silme/close hesaplamayı beklemez. Epoch eski sonuç/hata
yayınını engeller; tek active iş, iptal edilen iş bitene kadar yeni analiz kapalı.
Hard cancel yok; PCM çalışan worker belleğinde bitişe kadar kalabilir, silme
dosya/UI sonucunu temizler, anlık bellek silme garantisi değildir.

Analysis failure kayıt/replay'i korur. Sonuç ekranı nullable frekans/dispersion
ve bütün full-frame periodic oranını gösterir, VAD/nota başarısı/skor yapmaz.
Source mock/synthetic/microphone korunur; microphone kökeni doğruluk kanıtı değil.
Ana mock scorer, toleranslar, piyano placeholder, AI/upload/progress değişmedi.

**Doğrulama:** 248 test (+18: 12 controller/PCM snapshot/native pipeline,
4 temporary synthetic file IO, 2 widget/lifecycle), analyze temiz; format 67
Dart dosyası/0 değişiklik. Duplicate analysis/load cancel, stale new recording,
worker/load/playback errors, route/background/close ve narrow 320px/1.8× text;
sentetik WAV→gerçek IsolateRecordingPitchWorker 440 Hz regresyonu geçti.
Gerçek mikrofon/insan kaydı/mobil build veya pedagojik pilot çalıştırılmadı.
Sonraki kalibrasyon/route sözleşmesi, VAD/cihaz benchmark, startup orphan cleanup
ve shutdown-error UI kapıları açık; üstteki “henüz bağlı değil” notları tarihsel.

## CAL-01 — Kalibrasyon ve kayıt kalite kapısı (2026-10-11)

**Kodda:** `lib/domain/audio/capture_quality.dart` — 20 ms çerçeve RMS (dBFS); noise-floor = medyan, burst = %90 persentil; 1,5–5 sn kalibrasyon. Kalite kapısı sırası: geçersiz/oran/süre → kısa → desteklenmeyen route → kalibrasyon gerekli → kırpılma → sessizlik → etkinlik yok → referans kuyruğu (yalnız `sequentialOnly`) → yetersiz etkinlik → düşük SNR → usable. Lab `calibrateNoiseFloor()` 2 sn sessizlik kaydeder, ölçer ve kaydı siler; cevap analizinde rapor `requireCalibration: false` ile hesaplanır ve ekranda “insan sesi tespiti değildir” uyarısıyla gösterilir. Route, kayıt başlangıcında alınır; probe hatası `unknown`/`unverified`.

**Testler (31 yeni):** 16 domain (route politikası, sentetik sessiz/gürültülü oda, konuşma burst'ü, kırpılma, kısa/NaN/aşırı uzun, route/rate/yaş geçersizliği, ton SNR'ı, eksik/bayat kalibrasyon, sessizlik/kısa blip/düşük SNR, hoparlörde erken enerji vs kulaklık, latency sözleşmesi), 4 route eşleme, 10 controller (kalibrasyon kaydının silinmesi, route bağlama, route değişimi/süre dolumu, probe hatası, kesinti iptali, izin reddi, metadata uyuşmazlığı, okuyucusuz backend), 1 widget (320px/1,8× kalibrasyon → kalite raporu), shell testleri ayrı. Hepsi sentetik/fake; oda akustiği, gerçek mikrofon AGC'si veya cihaz gecikmesi değildir.

**CAL-02 cihaz protokolü (yapılmadı):** Her cihaz × route (hoparlör, kablolu, Bluetooth, varsa USB) için: (1) sessiz oda 3 kalibrasyon, (2) TV/konuşma açıkken kalibrasyon → `tooNoisy`/`activityDetected` beklenir, (3) referans sonrası hemen ve 0,5 sn sonra söyleme, (4) yalnız referansı hoparlörden çalıp sessiz kalma → `usable` çıkmamalı, (5) fısıltı/kısa “a”/öksürük, (6) yüksek sesle kırpılma. Eşikler yukarıdaki ADR-021 değerleridir; sonuçlar raporlanır, eşik gevşetilmez. Android'de route `inferred` olduğundan kulaklık tespiti iddia edilmez. Bu protokol çalışmadan CAL-01 “cihazda doğrulandı” sayılmaz.

## CAL-03a — Gecikme diagnostic istatistiği (21:40 TRT heartbeat)

`LatencyEstimator` 8–64 explicit paired trial üzerinde çalışır; DSP/onset,
player veya dokunma capture başlatmaz. Reference/response ortak observed clock
token'ında ve strict kronolojik olmalı; saat reset/different clock/scheduled
playback, inferred/unknown route, değişen route/rate ve bozuk tail reddedilir.
Timestamp 0..2^53−1 µs, offset 0..500 ms; out-of-budget list traversal yok.

Stable diagnostic: raw MAD≤5 ms, interpolated raw P90−P10≤20 ms, retained≥8,
rejected≤%25; outlier distance max(10 ms, 3×1.4826×MAD). Median/MAD/spread,
rejected trial indeksleri, source/method ve binding immutable evidence'da
korunur. İstatistik hesaplanamıyorsa retained count ve estimate null; unstable
durumda retained median null. Threshold'lar ADR-023 hipotezi, cihaz kabulü değil.

**21 yeni test:** determinism/source/no-correction; empty/7/retained<8,
isolated outlier/çoklu outlier/bimodal/drift, mixed/reset/invalid/scheduled clock,
route/rate/inferred bağlamı, negative/oversize late offset, gerçek 0/500 ms,
timestamp sınırı/sıralama, pre-traversal budget, immutable sonuç ve tap bias.
Full suite 422 test geçti; format 122/0; analyze ilk iki brace uyarısı sonrası
düzeltilip temiz doğrulandı. Tüm trial'lar sentetik; gerçek
hardware delay, insan tap bias veya cihaz geçerliliği ölçülmedi. Build yapılmadı.

**CAL-03b gerçek protokol kapısı (yapılmadı):** aynı pipeline/route/sample rate
için bağımsız tekrar batch'leri, reference ve observed event'in aynı monoton
saatte fiziksel kaydı, clock mapping/reset ve onset belirsizliği; route değişimi,
kablosuz değişkenlik, cancellation ve geç callback testleri. Scheduled playback
timestamp'ini duyulmuş klik olarak kullanma. Loopback toplamı capture/yayılım
içerebilir; touch correction'a aktarma. Tap insan motor bias'ını ayrı raporla;
hardware offset diye kabul etme. Bu paket LatencyCalibration üretmez ve
correctionEnabled=false; CORE-02b count-in hâlâ kapalı. CAL-02/BENCH-01 açık.

## CORE-03a — Symbolic ezgi sıra kanıtı (2026-10-12 02:47 TRT)

`PitchSequenceAligner` kayıt çözümlemez: önceden segmentlenmiş frequency/onset/
duration olayları karşılaştırır. Reference boş/invalid ise ArgumentError;
response invalid ise alignment yok ve karar null. Cevap yoksa reference missing
adımları gösterilebilir ama öğrenciye ölçülmüş yanlış sıra/0 puan üretilmez.

DP 1:1 monotonic Levenshtein (substitution/missing/extra=1, correct=0); tie
correct count, sonra signed absolute-cents mutlak toplamıyla kırılır. Exact
sıra korunur, reference sıralanmaz ve response duplicate tekrar kullanılamaz.
Octave residual yakın ama raw cents uzaksa wrongOctave; tolerans içinde raw
Hz farkı correct. Varsayılan 50 cent mevcut rubriği değiştirmez. 64 olay ve
60 sn timeline; overlap/zero duration/nonfinite Hz/bozuk tail fail-closed.

**14 yeni test:** correct index/source, reversed same count, missing/extra,
duplicate response/repeated reference, +/-octave, substitution, no-response,
invalid tail, overlap/onset/duration, budget/reference/tolerance, 49/51 cent,
immutable ve tempo/onset'in pitch evidence ile karıştırılmaması. 480 full test,
analyze temiz, format 143/0. Symbolic/sentetik veri; gerçek segmentation,
memory veya timing ölçümü yok. Mock melody adapter/scorer/UI değişmedi.

CORE-03b PCM/frame→segment, VAD/insan ezgi etiketleri, timing/hint/recall
protokolü ve cihaz/öğretmen kapıları açık. Bu sınıf MelodyAnalyzer değildir;
wholeSequenceCorrect yalnız sağlanan event sırası/pitch karşılaştırmasıdır,
öğrencinin ezgi hafızası veya mikrofon doğruluğu kanıtı değildir.

## CORE-03b — Deneysel periodic pitch segmentleme (2026-10-12 07:51 TRT)

Önce tüm trace doğrulanır: 8–48 kHz/10 sn/512 frame, strict start+center order,
window recording içinde, pitched Hz 50–2000 finite; diğer status'ta Hz null.
Invalid tail bütün sonucu reddeder. Window-center midpoint partition; dış
sınırlar observed center'da kalır, gap üzerinden süre üretmez. Frame'lerin
örtüşen süreleri toplanmaz; bunlar bağımsız ses örneği değildir.

Run anchor ilk Hz; ≤35 cent (hipotez). Run≥3 frame ve center-based span≥200 ms
(hipotez), representative observed lower median. Yumuşak glissando komşu farkla
sonsuz chain yapılmaz; octave pitch-class'a katlanmaz. Silence/unreliable/clip
ve coverage gap hard boundary; kısa run/spike discarded indices, nonpitched
indices ayrıca korunur. Artifacts sonucunda gerçek nota bölünebilir; bu durum
VAD/insan benchmark olmadan başarı skoruna çevrilemez. Hızlı ezgiler bu defaults
ile kaçabilir. Onset/süreler fiziksel doğru kabul edilmez.

13 test: stable/source, changes/octave, tekrar+silence, uncertain/clip,
short spike/run, overlap denominator, gap duration, invalid tail/timeline,
anchor drift, immutable adapter ve sentetik iki ton PCM→gerçek DSP→segment→
symbolic alignment. İlk fixed 2Hz assertion 660Hz'de başarısız oldu; existing
frame synthetic regression'ın 15-cent bound'u kullanıldı (production eşik veya
öğrenci rubriği değişmedi). Gerçek waveform/insan/cihaz/pilot kanıtı değil.
Son tam suite/analyze/format sonucu IMPLEMENTATION_LOG'da; build yapılmadı.

## CORE-04a — Puansız ezgi koordinatörü (2026-10-12 13:13 TRT)

10 yeni fake/sentetik test: immutable/bounded 3–5 nota declaration,
kalibrasyonsuz kayıt/playback yok; reference tamamlanmadan capture yok; PCM
DSP'den önce silinir; üç ton aday/source korunur; tam sessizlik neutral retry;
pending permission sırasında restart kapalı; bitmemiş playback cancel sayılmaz;
geciken native start ardından discard; stop hatası sonrası cleanup queue canlı;
route kesintisinden sonra late worker publish yok; close sonrası notification yok.

SESSION-01 kalite/kalibrasyon yeniden kullanılır; segmentleme başarıya, VAD'a
veya nota sırası kararına çevrilmez. Tamamlanan player callback sayısı gerçek
duyma/recall ölçümü değil. İlk sessizlik assertion'ı `insufficientActivity` idi;
tam sıfır sinyalin mevcut doğru status'u `silent` olarak düzeltildi. Serial queue
eklendiğinde eski test pending izin tamamlanmadan cancel cleanup'ını bekleyip
timeout oldu; test iptali başlatıp izin callback'ini çözerek sonra cleanup'ı
bekler hale getirildi. Üretim kalite eşikleri/rubrik değişmedi. Hard cancel yok;
pending native callback bitişi cleanup için gerekebilir, bu fiziksel QA kapısıdır.

503 full test geçti (+10), format 147/0. Son analyze IMPLEMENTATION_LOG'da.
Ekran/home/gerçek reference adapter henüz yok; mobil build/cihaz/insan kaydı
yapılmadı. CORE-04b adapter + puansız ekran sırada; gerçek başarı/hafıza ve bölüm
döngüsü ayrı doğrulama kapıları. Piano placeholder'a dosya eklenmedi.

## CORE-04b1 — Sentetik ezgi reference binding (2026-10-12 18:20 TRT)

Yeni renderer+adapter regresyonları: 3/4/5 ton × 8/48 kHz, PCM16 round-trip,
örnek sayısı/ara sessizlik ve sırada ham Hz (<15 cent existing synthetic frame
bound), amplitüd≤0.25/determinism; unsupported rate; immutable WAV exact
reference; default C4'ü çağırmama ve playback completed bekleme; mock capture
PCM/source/route/replay/interruption forwarding; capability yoksa unverified;
play failure'da fallback yok; stop/close failure'da her iki kaynak cleanup ve
idempotent close; kapandıktan sonra yeni play/capture yok. Session+adapter fake
entegrasyonu reference bitmeden capture açmadığını, cancel'ın iki kaynağı
temizlediğini sınar. Kayıt/Hz ve player olaylarının tamamı fake/sentetik.

600/200/400 ms reference düzeni içerik/detector taslağıdır, eğitimci rubriği veya
fiziksel gecikme ölçümü değil. Capture kesintileri forwarded; gerçek native
audio focus/route/izin/close matrisi cihazda test edilmeli. Mobile factory'nin
varlığı native mic QA/build başarısı sayılmaz. UI/home henüz bağlı değil;
CORE-04b2 sırada. Son suite/format/analyze kanıtı IMPLEMENTATION_LOG'da.

## CORE-04b2 — Ezgi ekranı widget doğrulaması (2026-10-12 23:20 TRT)

8 test: girişte permission/capture yok, uncalibrated start nötr; permission
denial OS ayarı açıklaması; 320px/1.8× kalibrasyon→play→answer→detail ve mock
source; silent quality retry puansız; stuck playback cancel + background/resume
auto capture yok; dispose pending permission late UI/native work reddi; home
synthetic route; Android/iOS tap target, labeled target, text contrast guidelines.
Fake/synthetic testler gerçek mic/voice/reader/jank/pedagoji kanıtı değildir.

Dart pattern guard ve void lifecycle callback await düzeltildi. Pending
permission dispose kontrolünde pumpAndSettle native/stream cleanup'ı tek başına
drain etmedi; mevcut lab testi gibi runAsync içinde permission completion ve
event-loop tick bekletildi. Üretim scorer/quality eşikleri değişmedi. Son tam
suite/analyze/format IMPLEMENTATION_LOG'da. Bölüm loop/recall ve gerçek cihaz/
VAD/benchmark/eğitimci kapıları açık.

## REL-08 — Ortak yerel kod kapısı (2026-10-13 04:20 TRT)

`dart tool/quality_check.dart` format/analyze/full suite'i sequential fail-fast
çalıştırır. Script-root guard invoking cwd'ye dayanmaz; Agora'dan --plan çağrısı
yalnız Harmonia komutlarını gösterir. 10 runner testi: CLI plan/unknown option,
default no-fetch plan, explicit lock fetch, immutable argv, sırayla success,
her adımda failure exit/short-circuit, missing executable, unexpected exception
ve yanlış repo adı. Bunlar test otomasyonu regresyonları, audio QA değil.
Fetch flag yerel CLI help ile doğrulandı, gerçek fetch uygulanmadı. Hosted CI
taslağı etkinleştirilmedi; external accounts/secrets/fixtures/upload yok.
Son suite/format/analyze IMPLEMENTATION_LOG'da. Gerçek mic/voice/device/pilot
ve iOS araç engeli ayrı kapı olarak kalır.

## LEARN-02a — Mikroders domain sözleşme testleri (2026-10-13 09:15 TRT)

9 yeni test: iki text draft graph/dimension/approval-gate; defensive snapshot;
tam faz sırası/missing/duplicate/shuffle; training-independent-delayed ID
sızıntısı; guided training leak; invalid/duplicate/oversize reference ve
malformed step; unknown skill/cross-route/wrong dimension; catalog immutable/
duplicate/128 budget; boş slot pending ve tüm ID'ler dolsa bile assessment/
approval kapalı. Örnekler sadece ID, waveform/telif/etiket/oynatma doğrulanmadı.

Tiz/pes ve puls açıklamaları developer draft; eğitimci onayı, 12 mikroünite,
görülmemiş ses bankası, UI veya pedagojik etki yok. Okumak/mastery kaydetmek
aynı şey değil; assessment/result/history bağlanmadı. Son runner suite/analyze/
format IMPLEMENTATION_LOG'da. BENCH/VAD/cihaz/eğitimci ve piyano kapıları açık.

## LEARN-02b — Draft reader/widget kapısı (2026-10-13 14:17 TRT)

6 test: draft/onay/dimension/no-mastery etiketi ve disabled phase actions;
skill-map→reader→back history boş/status değişmedi; puls üretim route;
custom graph unrelated default lesson yok; 320px/1.8× tüm fazlar overflow yok;
Android/iOS tap target, labeled target, text contrast guideline. Widget kod
kontrolü, gerçek ekran okuyucu/eğitimci/öğrenme etkisi veya cihaz QA değil.
Reader hiç audio/mic başlatmaz; örnek kimlikleri bağlı olsa bile play/assessment
yok. Son full runner test/analyze/format IMPLEMENTATION_LOG'da. Onaylı örnek
bankası ve EDU-01/pilot bekliyor; mastery sonuç kuralları değişmedi.

## LEARN-02c — Draft JSON codec testleri (2026-10-13 19:17 TRT)

11 test: deterministic round-trip/pending gates; exact int schema/kind;
unknown/missing keys her depth; imported approval reddi; invalid types/enums/
strings/refs; graph+duplicate guard; late invalid whole-catalog rejection;
phase/held-out separation; list/text/UTF8 budgets; immutable restore/export
snapshot; malformed parser error source null. Sahte onay/gerçek ses yok.
Standard JSON duplicate-key semantics, canonical/imza/hak/label/hash QA değil.
IO/asset/file import UI yok. Son tam suite ve önceki failures IMPLEMENTATION_LOG'da.
Code gate gerçek mic/cihaz/eğitimci/pedagoji kabulü değil.

## LEARN-03c — Günlük plan testleri (2026-10-13 20:45 TRT)

13 domain testi: yeni öğrenci (beceri başına bir yeni, iki tur, bütçe içi),
5/15 dk yeni sınırı, zayıf kardeş seviyeyi bekletir, dünkü ustalık → 1 günlük
tek tur kontrol, 1→3→7→14 kuyruk ve sonraki gün, başarısız kontrol → tekrar,
en gecikmiş önce + kontrol→tekrar→yeni sırası, gün içi sabit plan, yalnız
retention işaretli kontrol tamamlar, geçersiz tur ilerleme sayılmaz,
nothingDue/noMeasuredContent, immutable. 6 widget testi: bütçe değişimi,
dönüşte ilerleme, kontrol bayrağı, bozuk geçmiş, ölçülemeyen rota,
320px/1.8× + dört a11y kılavuzu; shell testi home kartından plan açar.
Süre/aralıklar öğrenci üzerinde ölçülmedi; pedagojik etki veya cihaz kanıtı değil.

## DATA-03a / LEARN-04a / SHELL-04a testleri (2026-10-13)

Export: 7 birim (round-trip/dakika/ses alanı yok, profilsiz, strict format/
sürüm/anahtar/tip/duplicate, geç bozuk kayıt tüm belgeyi reddeder, boyut
bütçesi, hata metni yankılamaz, import dedup/conflict/kapasite) + 4 widget
(panoya kopyala, onaylı import raporu, bozuk yapıştırma hiçbir şey eklemez,
320px/1.8× + a11y). Rapor: 5 birim + 2 widget (sayılar, bilinmeyen ≠ zayıf,
tekrar dinleme bağımsız saymaz, % yok, odak eylemi). Tercih: 3 birim + 1 widget.
Gerçek pano/cihaz arası taşıma ve dosya sistemi hataları cihazda denenmedi.

## SHELL-04b — Ortak durum testleri (2026-10-13 devam)

6 widget: loading/no retry, empty/no fake result, explicit error retry,
corrupt history→retry→empty, pending/no stale result, 320px/1.8× tap/label/
contrast. İki eski algı/aralık history testi notice sonrası scroll yapar,
result assertions korunur. Son runner 609 test; gerçek reader/cihaz/audio QA
değil. İlk koşudaki layout test failure ve onarım IMPLEMENTATION_LOG'da.

## SHELL-04c — Daily plan retry (2026-10-14 00:13 TRT)

3 new widgets: unavailable history/budget5/manual retry retains selection;
pending retry loading hides prior/error actions; dispose then late load no UI
update. Existing daily-plan duration/retention/budget persistence/narrow/a11y
tests also run. First regression exposed immediate failed future before next
FutureBuilder attaches after budget switch; eager error observer added, original
future retained for visible error. Not a timeout/tolerance relaxation. Final
runner evidence IMPLEMENTATION_LOG; code QA not physical audio/device/pilot.

## SHELL-04d — Skill-map availability/retry (2026-10-14 05:35 TRT)

4 widgets: history unavailable distinct from notMeasured/no report/focus;
explicit retry restores report + empty-history semantics; draft reading/back
no history reload/mastery; pending no stale state/dispose no late UI update.
Existing skill-map/report/microlesson/narrow guidelines also run. First new
reload lambda returned assigned Future to setState; changed to synchronous
block, no threshold or assertion relaxation. Final runner IMPLEMENTATION_LOG.
Fake code QA, not real microphone/evaluator/reader/device teaching evidence.

## REL-06a — Target label/frequency/A4 (2026-10-14 10:36 TRT)

10 new tests: tüm canonical MIDI0–127 formula, enharmonic octave carry,
iki ondalık rounding, wrong-note/octave rejection, A4 mismatch/retuned accept,
invalid scientific/solfege/whitespace/range labels, nonfinite/numeric bounds,
JSON reconstruction guard, invalid tail entire protocol, mevcut 400–480Hz piano
targets ve rhythm-only compatibility. Static metadata test, human benchmark değil.
0.005000001Hz rounding allowance student50cent/stability25cent toleransını
değiştirmez. Protocol guard her note; waveform/hak/clock/voice QA ayrı.
Legacy const Exercise/scorer ve fixtures aynı; schema1 stricter validation,
approval/real engine success yok. Final suite IMPLEMENTATION_LOG'da.

## REL-06b — Protocol JSON decoder tests (2026-10-14 15:39 TRT)

10 tests: valid round-trip/aids; no schema double/string/bool coercion; exact
keys all depths; bool/int policy fields; unknown enums/mode; nonfinite/types;
both counts before malformed prefix; invalid tail/semantic tuning+recall;
snapshot immutability; no private value echo. Last full runner 636 tests,
186/0 format, analyze clean. Shape FormatException, existing semantic
ArgumentError unchanged. No actual audio/device/educator QA, text IO/import
UI/canonical duplicate-key guard or publication activated.

## REL-06c — Rhythm clock numerical preflight (2026-10-14)

10 new tests: tiny tempo/huge beat overflow, rounded-ms collisions, inclusive
30 s reference boundary, single reference, negative timestamps including one
tap, safe large epoch/unsafe integer rejection, backward vs duplicate taps,
replay quota, empty-answer neutrality, controller rejects before rendering.
Stimulus time budget comes from existing click renderer, not timing tolerance.
No response duration limit added. First-tap anchor and scoring unchanged;
tests are fake/touch numeric evidence, not microphone, latency or device QA.

## REL-06d — Learning comparison isolation (2026-10-15)

12 added tests: current rhythm (difficulty2), high/low and interval outcome
codec compatibility; each of eight cohort fields independently excludes
mismatches from learning and rhythm recommendations; invalid same-cohort
retry; sorted mixed history/current mastery; exam cannot advance today route
or fill a learning daily-plan block. Generated synthetic references/touch
answers only; no actual student/device/voice evidence. Existing rhythm policy
fixture now takes bound difficulty/mode (senkop is difficulty2, not default1).
No student score/tolerance change. Protocol fingerprints/hint authenticity and
real audio/educator acceptance are not established by these tests.

## SHELL-04e — Home recovery widgets (2026-10-15)

6 fake-repository widgets: explicit retry/no automatic reload/no writes or
private error text; pending reload removes stale action; late failure after
dispose; repository replacement rejects old completion; immediate failure on
exercise return; retry on 320px at 1.8× text. No mic/playback started, no learner
performance measured. Existing shell/accessibility/learning tests also rerun;
this is code QA, not physical-device/VoiceOver/TalkBack or teaching acceptance.

## CORE-04c1 — Selected melody reference rehearsal (2026-10-15)

8 new tests: original identity/range/order snapshot; invalid ranges not clamped;
repeat count1..3; single/last note; byte-equivalent full-range reference via
independently constructed original samples; repeat order/octave/frequency and
exact silence at8/16/48kHz; max13.8s/662400 samples at48kHz + determinism;
unsupported rate fails without resampling. Pitch checks use generated tones
and diagnostic YIN, NOT human voice holdout accuracy or real device timing.
16 targeted tests include unchanged synthetic backend/session lifecycle tests.
No piano recording added; no score, hint attribution, mic, UI or player started.
