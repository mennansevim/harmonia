# Doğrulama pilotu protokolü (TASLAK) — 2026-11

**Durum:** hazırlık belgesi. **Katılımcı yok, rıza yok, kayıt yok, sonuç yok.**
Bu belgedeki hiçbir sayı bir ölçüm sonucu değildir; sayılar önceden yazılan
ölçüt önerileridir ve kullanıcı/eğitimci onayıyla, **veriye bakılmadan**
dondurulacaktır (§4). Hukuk metinleri taslaktır ve hukuk incelemesi bekler (§5).

Kapattığı kapılar: **BENCH-01** (etiketli insan kaydı benchmark'ı), **VAD-01**
(ses etkinliği / çekimserlik), **CAL-02** (cihaz × route matrisi, bkz.
[AUDIO_TESTING.md](../../AUDIO_TESTING.md)). Dayandığı rapor:
[VOCAL_MODEL_BENCHMARK_2026-11-09.md](./VOCAL_MODEL_BENCHMARK_2026-11-09.md) —
oradaki tüm sayılar **sentetik/simülasyon**dur; gerçek insan sesi, yankı, eşlik
sızıntısı, cihaz AGC'si, telefon CPU süresi ve gerçek alkış ölçülmemiştir.

Araçlar ve şablonlar: [pilot/](./pilot/) (kayıt rehberi, manifest ve meta
şablonları, ölçüt şablonu, rıza taslağı) ve
[tool/benchmark/pilot_analysis.dart](../../tool/benchmark/pilot_analysis.dart).

---

## 1. Amaç ve ilkeler

1. Mevcut algoritma ve eşiklerin **gerçek şarkıcı/cihaz verisinde** ne yaptığını
   ölçmek. Sonuç kötüyse algoritma/eşik **bu belge sayesinde değişmez**: sonuç
   raporlanır, karar kullanıcı + eğitimcinindir (§7).
2. Mock, sentetik, mikrofon ve doğrulanmamış kaynaklar karıştırılmaz.
   `AudioFixture` şeması bunu zaten zorlar: sentetik ses holdout olamaz, gerçek
   ses için rıza ve anonim `subjectGroup` zorunludur, bir kişi hem development
   hem holdout'ta bulunamaz.
3. Eşik gevşetme yok. Ölçütler sonuçtan önce yazılır ve dondurulur.
4. Periodicity insan sesi olasılığı değildir; `periodicFrameRatio`
   `voicedRatio` değildir; diagnostic median/dispersion doğrulanmış öğrenci
   başarısı sayılmaz. Pilot bu iddiaları kurmaz, yalnız ölçer.
5. Ölçülmeyen değer boş kalır; "geçersiz" ölçüm puan üretmez.

## 2. Genel tasarım

| Konu | Karar (taslak) |
|---|---|
| Katılımcı | ≥12 kişi önerilir (≥6 development, ≥6 holdout, **kişi ayrık**); en az 4'ü şarkı eğitimi almamış yetişkin, en az 4'ü eğitimli şarkıcı. Sayı bir öneridir; asıl alt sınır 100 etiketli holdout kaydıdır (§3a). Yaş ≥18; çocuk/ergen ayrı aşama (§5). |
| Cihaz | ≥3 telefon modeli (iOS + Android karışık), her biri yerleşik mikrofon; ayrıca kablolu ve Bluetooth kulaklık route'u ≥1 modelde. |
| Oda | sessiz; yankılı (ör. boş oda/banyo/koridor); TV veya klima açık. |
| Ses kaynağı | Katılımcı **piyano referansını dinleyip** istenen notayı söyler; kayıt telefonun kendi mikrofonundan, uygulamanın mevcut kayıt hattıyla veya ayrı bir kayıt uygulamasıyla alınır (yönetici seçer; hangisi olduğu manifestte yazılır). |
| Veri akışı | Ham ses **uygulamadan buluta/sunucuya gitmez**. Pilot kayıtları ayrı bir araştırma kaydıdır: rıza → yerel dosya → şifreli yerel disk → yerel analiz. Yükleme, e-posta, bulut klasörü yok; transfer fiziksel veya yerel kablo (hukuk incelemesi onaylayana kadar başka yol açılmaz). |
| Hak | Her kayıt için `rightsReference`; lisansı belirsiz ses kopyalanmaz/dağıtılmaz. |
| Silme | Katılımcı istediği an kaydının silinmesini isteyebilir; silinen kayıt manifestten ve analizden çıkarılır, sonuçlar yeniden üretilir (§5). |

## 3. Ölçüm planları

### a) Perde (tek ses) — BENCH-01 / VAD-01

- **≥100 etiketli kayıt, holdout'ta** (kişi ayrık development/holdout;
  development algoritma incelemesi içindir, karar holdout'tan çıkar).
- Etiket sınıfları (`labelClass`): `correct_note`, `octave_up`, `octave_down`,
  `wrong_note`, `silence`, `speech_noise`, `unstable_vibrato`, `short_buffer`,
  `clipped`, `accompaniment_leak`. `expectedFrequenciesHz` = katılımcıdan
  **istenen** nota; `labelClass` = katılımcının **gerçekte yaptığı**
  (eğitimci uzlaşısı, §6).
- Dağılım hedefi (öneri): holdout'ta her sınıftan ≥8 kayıt (`correct_note` ≥30);
  üç oda ve ≥3 cihaz tüm sınıflara dağılmış. Küçük hücreler **yorumlanmaz,
  yalnız aralıkla raporlanır**.
- Kısa buffer: <250 ms; kırpılma: uygulama kalite kapısı eşiğini aşan seviye;
  eşlik sızıntısı: referans notayı hoparlörden çalarken kayıt.
- Cihaz/route her kayıtta `pilot_meta.json` içinde (`device`, `route`, `room`);
  uygulama kalite kapısı sonucu kaydedildiyse `gateResult`.
- Karşılaştırma: uygulamadaki YIN (`app-yin`), `yin+fallback` ve `mpm`
  ([detector_benchmark.dart](../../tool/benchmark/detector_benchmark.dart)
  kodu yeniden kullanılır). **Karşılaştırma bilgi içindir, algoritma seçimi
  değildir** (§7).
- Telefon CPU/frame süresi: aynı cihazlarda ayrı ölçüm, ayrı tablo (bu aracın
  kapsamı dışı; AUDIO-03c).

Örnek: 100 gözlemde %90 isabet Wilson %95 aralığı ≈ %82,6–94,5; %95 isabet ≈
%88,8–97,8. Yani 100 kayıt kaba oranlar içindir; sınıf/cihaz bazlı iddialar
için yetmez ve öyle sunulmaz.

### b) Alkış / ritim

- Gerçek alkış; mesafe **30 / 60 / 100 cm**; ≥2 oda; ≥3 cihaz; her koşulda
  ≥20 alkış ritmi denemesi (seviye 1 ve en uzun ritim dahil).
- Yanlış tetikleme: konuşma, öksürük, masaya vurma, ayak sesi (≥20 olay/tür) —
  `ClapOnsetDetector`'ün yanlış sayma oranı.
- **Serbest tempo sapması**: kullanıcının ilk→son alkış süresi / referans süre
  oranı (P1'deki `clapSpanRatio`) dağılımı; SD ve %5/%10/%15 aşım oranı.
  Amaç: tempo notu eşiği (%15) ve normalize kuralın gerçek davranışı için veri.
- Yanlış ritim kabulü: 150 ms kaydırılmış tek alkış, eksik/fazla alkış (yönetici
  yönergeyle yaptırır) — kuralın kabul oranı.
- Veri sayfası (CSV, `clap_trials.csv`): `trialId, subjectGroup, device, route,
  room, distanceCm, rhythmId, instructed (normal|shifted150|missing|extra),
  detectedOnsetsMs (| ile ayrılmış), spanRatio, passedByRule`. Bu sayfa için
  analiz betiği bu görevde **yazılmadı**.

### c) Aralık testi

- Aynı kişide **iki tekrar** (en az 24 saat ara, aynı cihaz) — test–tekrar
  farkı (yarım ses) ve skorun (`match-1`) tekrarlanabilirliği.
- Öğretmen etiketli "gerçek aralık": eğitimci aynı kişiyi piyanoyla çıkarıp
  rahat alt/üst sınırını yarım ses olarak yazar (`teacherLowMidi`,
  `teacherHighMidi`).
- Veri sayfası (CSV, `range_trials.csv`): `subjectGroup, device, run (1|2),
  measuredLowMidi, measuredHighMidi, points, accuracy, firstTry,
  teacherLowMidi, teacherHighMidi`. Analiz betiği yazılmadı.

### d) Tekrar kartı (4 hafta)

- ≥8 katılımcı, 4 hafta, günlük/haftalık kullanım serbest (doğal kullanım);
  uygulama yerel günlükleri **katılımcının izniyle** dışa aktarılır.
- Ölçülecek: ilk deneme doğruluğu **7 gün sonra** (kartın ilk görülmesinden
  7 gün sonraki ilk cevap), tekrar sayısı/gün (kart yükü), yarı ömür
  dağılımı (`ItemMemory`), yanlışlık kaynaklı sıfırlanma; P3 için kapı
  denemeleri (`gateAttempts`) ve "pekişti" oranı.
- HLR katsayı kalibrasyonu (×2/÷2, 0,5–60 gün, `reviewTarget`) bu veriyle
  **değerlendirilir**; değişiklik §7'ye göre karar ister.
- Veri sayfası: uygulama dışa aktarma biçimi **henüz yok** (kod işi: izinli
  yerel günlük dışa aktarma); o güne kadar bu bölüm toplanamaz. Bu bir açık
  eksiktir.

## 4. Başarı ölçütleri (önceden kayıtlı) ve dondurma

Ölçütler [pilot/criteria_template.json](./pilot/criteria_template.json)
dosyasında makine okunur biçimdedir. **Dondurma yordamı:**

1. Kullanıcı + eğitimci şablondaki sayıları gözden geçirir ve gerekirse
   değiştirir — **hiçbir kayıt analiz edilmeden önce**.
2. `frozen: true`, `frozenOn`, `frozenBy` yazılır; dosya değişmez saklanır
   (commit veya imzalı kopya).
3. Analiz aracı yalnız `frozen: true` dosyayla PASS/FAIL/inconclusive üretir;
   taslakla yalnız ölçüm ve aralık yazar.
4. Dondurulduktan sonra eşik değişikliği **yeni bir pilot** gerektirir; sonuca
   bakıp gevşetme yok.

Önerilen taslak ölçütler (hepsi **holdout, `humanRecording`**, 95% Wilson
aralığı üzerinden; min → alt sınır, max → üst sınır):

| Ölçüt | Metrik | Sınıflar | Kural (taslak) |
|---|---|---|---|
| ±50 c doğru oranı | `hit50` | `correct_note` | alt sınır ≥ %85 |
| Oktav hata oranı | `octaveError` | `correct_note` | üst sınır ≤ %5 |
| Yanlış-başarı | `falseSuccess` | `wrong_note`, `octave_up/down` | üst sınır ≤ %10 |
| Perde iddiası (sessiz/gürültü) | `claim` | `silence`, `speech_noise`, `short_buffer`, `clipped` | üst sınır ≤ %10 |
| Çekimserlik | `abstain` | `correct_note` | üst sınır ≤ %15 |

Ek raporlanan, **kabul/ret kapısı olmayan** büyüklükler: ±40 c isabet
(`hit40`), kalite kapısı sonrası kullanılabilir kayıt oranı (`gateResult`
kaydedildiyse), perde dağılımı SD (jitter) medyanı, cihaz/route/oda kırılımı,
etiketleyici uyumu (Cohen kappa).

Duyarlılık notu (hesap, sonuç değil): n=100'de "alt sınır ≥ %85" için
yaklaşık 92/100 isabet gerekir; "oktav üst sınır ≤ %5" için 100'de **0** oktav
hatası gerekir (1/100'ün üst sınırı ≈ %5,4). Daha küçük örnek "inconclusive"
verir; bu, ölçütü gevşetmek için değil örneği büyütmek için gerekçedir.

Alkış (b), aralık (c) ve kart (d) ölçütleri veri sayfaları netleşince **aynı
yordamla** ayrı yazılır; şimdilik tanımlı değildir (yazılmış gibi sunulmaz).

## 5. Rıza, hak, anonimlik, silme (TASLAK — hukuk incelemesi bekler)

- Rıza metni taslağı: [pilot/CONSENT_DRAFT.md](./pilot/CONSENT_DRAFT.md).
  **Hukuk onayı yok;** KVKK kapsamında ses kaydı kişisel veridir ve
  biyometrik/özel nitelikli sayılıp sayılmayacağı hukuk görüşü ister.
- Her kaydın yanında `consentReference` (rıza formu kodu), `rightsReference`
  (kullanım hakkı), anonim `subjectGroup` (ad/soyad **yok**; eşleme tablosu
  ayrı, şifreli ve yalnız yönetici erişimli).
- Ham ses cihazdan/araştırma ortamından çıkmaz: bulut, e-posta, mesajlaşma yok.
- Silme: katılımcı talebiyle kayıt + eşleme satırı + türev dosyalar silinir;
  rapor yeniden üretilir.
- **Çocuk/ergen ayrı aşama**: bu pilotun kapsamı değil; veli rızası, okul/kurum
  izni ve ayrı hukuk incelemesi gerekir.
- Eğitimcinin kendi ürettiği yorum/etiket de telif ve kullanım izni içerir
  (`rightsReference`).

## 6. Eğitimci etiketleme rubriği ve ikili etiketleme

- Her kayıt **iki eğitimci tarafından birbirinden bağımsız** etiketlenir (A, B);
  kayıtların her biri için `labels: {A: ..., B: ...}`.
- Rubrik (kısa): `correct_note` = istenen notaya kulakla yakın, aynı oktav;
  `octave_up/down` = doğru nota adı, farklı oktav; `wrong_note` = başka nota;
  `silence` = ses yok; `speech_noise` = konuşma/öksürük/ortam; `unstable_vibrato`
  = notaya yakın ama belirgin dalgalı/vibrato; `short_buffer` = <250 ms
  kullanılabilir ses; `clipped` = belirgin kırpılma; `accompaniment_leak` =
  belirgin eşlik/referans sızıntısı var. Eğitimci rubriği ve sınır örnekleri
  **eğitimci onayına açıktır**; bu taslağı eğitimci düzenler.
- Uyum: Cohen kappa (araç hesaplar). Taslak eşik: **κ ≥ 0,70** altında etiket
  kümesi güvenilmez sayılır, rubrik düzeltilip yeniden etiketlenir; uyuşmazlık
  üçüncü eğitimci veya uzlaşıyla çözülür ve `labelClass` o karardır.
- Eğitimci etiketi **görmeden** (algoritma çıktısı gösterilmeden) verilir.

## 7. Karar kapıları — hangi sonuç neyin kapısını açar

**Genel kural:** kötü sonuç hiçbir algoritma/eşik/rubrik değişikliği yetkisi
doğurmaz. Her değişiklik ayrı bir kullanıcı kararı ve ayrı görevdir; sonuç
yalnız karar için kanıt sunar. İyi sonuç da yalnız kendi satırındaki kapıyı
açar.

| Öneri / sabit | Hangi veri | Açılan kapı (sonuç iyi) | Sonuç kötü / belirsiz |
|---|---|---|---|
| Algoritma seçimi (`app-yin` vs `yin+fallback` vs `mpm`) | (a) holdout, aynı örnekte yan yana, ölçütler | "Alternatif şu ölçütte uygulama YIN'inden anlamlı iyi" bulgusu → değişiklik **önerisi** (kullanıcı kararı + CPU ölçümü + ayrı görev) | Mevcut algoritma kalır; yetki doğmaz |
| Perde başarı toleransı 40 c / 50 c | (a) `hit40`/`hit50` ve hata dağılımı; eğitimci görüşü | Toleransın veride makul olduğu bulgusu; **değişiklik eğitimci kararıdır** | Tolerans korunur; kullanıcıya veriyle bildirilir |
| Oktav kuralı ("yanlış oktav başarı sayılmaz") | (a) `octaveError`, `octave_*` sınıfları | Kural doğrulanır veya "tespit hatası" sınırı belgelenir | Kural korunur |
| Çekimserlik / VAD (sessiz, konuşma, kısa, kırpılmış) | (a) `claim`, `abstain`, `gateResult` | VAD-01 için "perde iddiası" kanıtı; kalite kapısı eşikleri CAL-02 sonucuyla birlikte değerlendirilir | VAD-01 açık kalır; periodicity "ses var" kanıtı sayılmaz |
| Cihaz/route (CAL-02) | (a) kırılım + `AUDIO_TESTING.md` protokolü | Cihaz × route "denendi" işareti (yalnız o hücre için) | O hücre "doğrulanmadı" kalır; route iddiası yok |
| Alkış `±120 ms`, 10 ms bandı, `ClapOnsetDetector` eşikleri, normalize kural, %15 tempo notu | (b) | Kuralın gerçek alkışta davranışı raporlanır; **eşik değişikliği önerisi kullanıcı kararı** | Eşikler korunur |
| Yanlış-ritim kabulü (150 ms kaydırma) | (b) yönergeli deneme | Kabul oranı raporlanır; "%8 sentetik" iddiası yerine gerçek değer yazılır | İddia düşürülür; kural kararı kullanıcıda |
| Aralık skoru `match-1` (%62,5/%37,5, 40 c yayılım), ölçülen aralık | (c) | Test–tekrar ve öğretmen aralığı ile ilişki raporlanır; "ölçülen aralık ≠ gerçek aralık" farkı sayıyla yazılır | Skor "taslak" kalır; ağırlık değişikliği kullanıcı/eğitimci kararı |
| P0 kart büyüme eşiği (`dueFraction`), ×2/÷2, 0,5–60 gün, `reviewTarget`, tur boyu | (d) | Kart yükü ve 7 gün doğruluğu raporlanır; katsayı **önerisi** | Sabitler taslak kalır |
| P3 yıldız ≥%90, "pekişti" (2 gün, 36 soru, %80) | (d) kapı denemeleri | Pekişti oranı ve sonraki doğrulukla ilişki raporlanır | Taslak kalır; kilit/rota kararına bağlanmaz |
| P4 `exam` tekrar adımı | eğitimci/öğrenci geri bildirimi (nitel) | Kullanılabilirlik bulgusu | Karar kullanıcıda |
| 2/3/4 sesli tekrar | bu pilotun kapsamı dışı (kayıtlar yok) | — | placeholder kapalı kalır |

## 8. Sorumluluk ve sıra

| Adım | Kim | Durum |
|---|---|---|
| Katılımcı çağrısı, rıza toplama, kayıt oturumları | **Kullanıcı** | yapılmadı |
| Hukuk incelemesi (rıza metni, KVKK, saklama) | **Kullanıcı / hukuk** | yapılmadı |
| Eğitimci rubriği onayı, ikili etiketleme | **Eğitimciler** | yapılmadı |
| Ölçüt dondurma (§4) | **Kullanıcı + eğitimci** | yapılmadı |
| Manifest ve meta doldurma (şablonlar) | Yönetici | şablonlar hazır |
| `pilot_analysis.dart` çalıştırma | Geliştirici | araç hazır, veri yok |
| Alkış/aralık/kart analiz betikleri, dışa aktarma | Geliştirici | **yazılmadı** |
| Telefon CPU/frame süresi ölçümü | Geliştirici + cihazlar | yapılmadı |

Çalıştırma (veri varken):

```bash
dart tool/benchmark/pilot_analysis.dart --root <veri klasörü> \
  --criteria <dondurulmuş criteria.json> --out rapor.md
```

Veri yoksa araç **açık hata verir** (çıkış kodu 2) ve hiçbir veri üretmez.

## 9. Sınırlar — bu belge ne yapmaz

- Katılımcı çağırmaz, mesaj/e-posta göndermez, kayıt yüklemez, ödeme/mağaza
  işlemi yapmaz, rıza uydurmaz.
- Hiçbir sonuç içermez; sentetik veriyi gerçek diye sunmaz (araç sentetik ve
  enstrüman satırlarını karar tablosuna **almaz**).
- 2/3/4 sesli tekrar, makam/komalı ölçüm, çocuk/ergen verisi ve gerçek cihaz
  FPS/CPU kapısı kapsam dışıdır.
- Eşik gevşetme, algoritma değiştirme veya "geçti" ilanı yetkisi doğurmaz.
