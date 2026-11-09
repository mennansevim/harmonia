# Vocalart — Ses eğitimi modeli: benchmark, ağırlık ve yük incelemesi

**Tarih:** 2026-11-09 · **Kapsam:** aktif `TrainerApp` modeli (ölçüm çekirdeği,
skor ağırlıkları, müfredat/yük dağılımı, tekrar kartları). **Kod değişmedi**;
yalnız `tool/benchmark/` altına tekrar üretilebilir ölçüm betikleri ve bu belge
eklendi.

> **Okuma kuralı.** Aşağıdaki tüm ses ölçümleri **sentetik ses benzeri
> sinyaller ve piyano kayıtlarıdır**; tüm "öğrenci/şarkıcı/öğrenen"
> simülasyondur. Hiçbiri gerçek insan sesi, gerçek telefon mikrofonu, eğitimci
> etiketi veya öğrenme etkisi kanıtı **değildir** (BENCH-01/VAD-01/CAL-02 açık).
> Bu yüzden her bulgu "kod/ölçüm davranışı" düzeyindedir, "ürün kanıtlandı" değil.

---

## 1. Hüküm

"Model"i dört parça olarak ayırdım ve her birine ayrı karar verdim.

| Parça | Ses eğitimi için uygun mu? | Neden (özet) |
|---|---|---|
| **Pitch ölçüm çekirdeği** (YIN tabanlı) | **Evet, koşullu.** Sessiz/orta gürültüde (SNR ≥ 10 dB) C2–C6 sentetik seste ±2 cent; kalite kapısı (15 dB) güvenli bölgede. | SNR ≤ 5 dB'de çöküyor (aynı sinyalde MPM dayanıyor); gerçek insan sesiyle hiç ölçülmedi; literatürde YIN yankıda belirgin bozuluyor (§6) ve benim sentetik testim yankısız. |
| **Skor ağırlıkları** | **Kısmen.** Üç ayrı sorun var (§4). | 50 → 50,5 cent'te 45 puanlık uçurum; vibrato "kararsız" sayılıyor; ses aralığı skorunun %60'ı genişlik; geçiş kapısı 12 soruyla düşük ayırt edicilik. |
| **Müfredat ve yük dağılımı** | **Kulak eğitimi için makul; şan eğitimi için eksik.** | 128 düğümün 1310 puanlı sorusunun tamamı dinleyip adlandırma; ses üretimi ölçülmüyor ve günlük rotada yok; son (zor) öğeler 4–9× az çalışılıyor. |
| **Alkışla ritim** (§5.5) | **Dedektör evet, geçme kuralı hayır.** | Zamanlama jitter'ı ~1,5 ms; ama mutlak ±120 ms kuralı mükemmel bilen performansçıyı ritim süresine göre eliyor (korelasyon −0,99), seviye sırasıyla ilişkisi yok (−0,06). |
| **Tekrar kartları** (HLR-lite) | **Hayır, bugünkü hâliyle.** | Büyüme koşulu ile "vade" eşiği çakışıyor: günlük kullanıcı için her kart 90 günün 90'ında tekrar ediliyor (§5.4). Tek sabitlik düzeltme. |

Hedefe göre uygunluk (§6b.4): **kulak eğitimi evet; konservatuvar sınavı
bugünkü hâliyle hayır** (sınav biçimi tekrar, rota adlandırma); **şan/ses
eğitimi hayır, hazırlık katmanı**. En önemli yapısal bulgu: sınavda en çok
puan taşıyan ezgi/ritim/çok sesli tekrar bileşenleri uygulamada var ama rota ve
ilerleme dışında.

Kısa cevap: bu bir **kulak eğitimi (aural skills) modeli**. Ölçüm çekirdeği
sağlam bir temel. Ders yolları, günlük rota ve ilerleme (yıldız, ustalık,
XP) yalnız algıya dayanıyor. Ölçülen ses üretimi var ama ayrı **Koro / Ses
laboratuvarı** sekmesinde (dinle-söyle, ezgi tekrarı, aralık testi): hedeften
bağımsız, günlük rotaya bağlı değil ve ilerlemeyi beslemiyor
(`melodyEchoLevel` "XP, seri, ustalık veya geçmişi beslemez"). Şan tekniği
(ısınma, rezonans, kayıt geçişi) hiç yok. "Ses eğitimi" iddiası bugün için
kulak hazırlığı + ayrı bir isteğe bağlı eşleme laboratuvarı olarak doğru
konumlandırılmalı.

> **Kapsam notu.** "Alkışla ritim" (aksak dahil) §5.5'te ölçüldü. Dokunarak
> "Ritim tekrarı" aynı analizörü ve çapayı kullanır ama ayrıca ölçülmedi;
> melodi yankısı ve aralık testi yalnız kod ve simülasyonla ele alındı.
> Ders yolu düğüm sayıları çalışan koddan: Nota 28,
> Aralık 32, Akor 20, Dizi 25, Yürüyüş 23 (toplam 128).

---

## 2. Ölçüm çekirdeği benchmark'ı

`YinPitchFrameAnalyzer` + `RecordingPitchAnalyzer` (gerçek sınıflar), aynı
çerçeveleme ve aynı alt-medyan toplama ile üç algoritma karşılaştırıldı:
**app-yin** (bugünkü), **yin+fallback** (aynı YIN, eşik altı dip yoksa global
minimum; periyodiklik kapısı CMNDF<0,30), **mpm** (McLeod NSDF, k=0,9).
Doğruluk için "ground truth" sentezle bilinir.

**Sentetik ses:** formant şekillendirmeli harmonik kaynak (/a/ /i/ /u/),
jitter %0,5, shimmer %3, aspirasyon gürültüsü (HNR), pembe ortam gürültüsü
(SNR), vibrato (5,5 Hz), açılış kayması. 13 perde (C2 65 Hz … C6 1047 Hz),
3 ünlü, 2 tohum = **koşul başına 78 kayıt**, 1,5 sn.

| Koşul | app-yin ±50 c | yin+fallback ±50 c | mpm ±50 c | app-yin medyan hata |
|---|---|---|---|---|
| Temiz, 48 kHz | %100 | %100 | %100 | 0,4 c |
| SNR 30 / 20 dB | %100 | %100 | %100 | 0,4 c |
| SNR 10 dB | %100 | %100 | %100 | 0,9 c (mpm 0,4) |
| **SNR 5 dB** | **%23** (%28 tespit) | %99 | %100 | 3,5 c (p95 1208 c) |
| **SNR 0 dB** | **%0** | %0 | %100 (periyodik oran 0,59) | – |
| Vibrato ±30 / ±60 / ±100 c | %100 | %100 | %100 | 1,0 / 1,7 / 2,7 c |
| Nefesli ses HNR 15 dB | %100 | %100 | %100 | 0,6 c |
| Çok nefesli HNR 8 dB | %100 (±10 c: %90) | %100 (%90) | %100 (±10 c: %100) | 4,1 c (mpm 0,8) |
| Açılış kayması −200 c | %100 | %100 | %100 | 0,7 c |
| 44,1 kHz / 16 kHz | %100 | %100 | %100 | 0,3 / 0,6 c |

- **Perde aralığı:** C2 (65 Hz) … C6 (1047 Hz) boyunca tespit %100, medyan
  hata ≤ 1,5 c (en yüksek hata en pes notada). Bas–soprano kapsaması sentetikte
  yeterli.
- **Çöküş eşiği:** app-yin SNR 10 dB'de sağlam, 5 dB'de çöküyor ve çökerken
  de yanlış değer üretiyor (tespit edilen kayıtların yaklaşık beşte biri
  oktav/kaba hata; p95 1208 c). Kalite kapısı `minSignalToNoiseDb = 15`
  (kalibrasyon yapılmışsa; `capture_quality.dart:343, 441`) bu bölgeyi
  dedektöre ulaşmadan eliyor: **kapı ile dedektör uyumlu, 5 dB güvenlik payı
  var.** Kalibrasyonsuz kayıtta SNR kontrolü atlanır (`snr == null`).
- **MPM** düşük SNR'de belirgin daha dayanıklı (0 dB'de bile bulunuyor);
  bu, "Agora McLeod port'u" adayını gerçek kayıtla denemek için bir işaret —
  **sentetik üstünlük, seçim kararı değil.**
- **Vibrato ve kararlılık:** ölçülen ham dağılım (stabilityCents girdisi)
  ±30/±60/±100 c vibratoda **15,7 / 31,8 / 55,0 c**; gerçek SD (A/√2)
  21,2 / 42,4 / 70,7 c. Yani 85 ms pencere vibratoyu ~%25 yumuşatıyor ama
  klasik vibrato (±50–100 c) yine de 25 c eşiğini aşıyor (§4.1).
- **Gerçek piyano kayıtları** (`assets/audio/piano/notes`, 31 nota, enstrüman —
  ses değil): 27 nota ±5,1 c içinde (A1, C2–G5). **E1/F1/G1** (41–49 Hz)
  dedektörün 50 Hz alt sınırının altında → "yok" (beklenen; insan sesi
  değil). **B1** (61,7 Hz) üç algoritmada da oktav hatası (piyanoda zayıf
  temel); insan aralığının altı.

**Bu benchmark neyi göstermez:** gerçek glottal kaynak, oda yansıması, eşlik
sızıntısı, mikrofon AGC'si, konuşma/öksürük, çocuk/yaşlı ses, kötü
niyetli/hatalı oktav. Hepsi BENCH-01/VAD-01 kapısı.

### 2.1 Hesap yükü (masaüstü AOT, 8 çekirdek — telefon değil)

| İş | Süre |
|---|---|
| YIN çerçevesi 4096 @ 48 kHz | 3,2–3,4 ms |
| YIN çerçevesi 1024 @ 16 kHz (canlı iz) | 0,26 ms |
| `RecordingPitchAnalyzer`, 3 sn / 10 sn @ 48 kHz | 229 ms / 772 ms (234 çerçeve) |
| `LivePitchTracker`, 20 ms bütçeli hop | 0,23 ms/hop = tek çekirdeğin %1,2'si |

İş izole (`Isolate.run`) içinde çalıştığı için UI'yı bloke etmez; telefon için
3–6× yavaşlama varsayımı (ölçülmedi) 10 sn kayıt için ~2–5 sn eder — kabul
edilebilir ama cihazda ölçülmeli. Canlı iz ihmal edilebilir.

---

## 3. Gerçek bağlantı: hangi ağırlık aktif uygulamada kullanılıyor?

`PitchExerciseScorer` (0,6/0,4) **yalnız eski `features/single_tone_exercise`
simülasyon ekranında** kullanılıyor; aktif `TrainerApp` onu çağırmıyor.
Aktif ölçüm yolları: aralık merdiveni (±40 c), melodi yankısı
(`PitchSequenceAligner`, ±50 c), derste "Söyle" adımı (puansız tanısal). Bu
yüzden §4.1 "bugün kullanıcıya zarar veriyor" değil, "bağlandığında riskli"
bulgusudur.

---

## 4. Skor ağırlıkları

### 4.1 Tek ses skoru (`PitchExerciseScorer`: doğruluk .6 + kararlılık .4)

| \|cent\| | SD 0 | SD 25 | SD 35 (±50 c vibrato) | SD 71 (±100 c vibrato) |
|---|---|---|---|---|
| 0 | 100 ✓ | 80 ✓ | 72 ✗ | 60 ✗ |
| 25 | 85 ✓ | 65 ✓ | 57 ✗ | 45 ✗ |
| 49 | 71 ✓ | 51 ✓ | 43 ✗ | 31 ✗ |
| **50** | **70 ✓** | 50 ✓ | 42 ✗ | 30 ✗ |
| **51** | **25 ✗** | 25 ✗ | 25 ✗ | 25 ✗ |
| 100 | 0 ✗ | 0 ✗ | 0 ✗ | 0 ✗ |

1. **Uçurum:** 50,0 c → 70 puan (başarı), 50,5 c → 24,8 puan (başarısız):
   0,5 cent için **45 puan**. Not, ölçümün kendi belirsizliğinden (±1–5 c)
   küçük bir değişimle zıplar.
2. **Vibrato = kararsız:** SD > 25 c "unstable" (extent > ±35 c). Eğitimli
   şarkıcı vibratosu bunu aşar; başarı bayrağı (`isSuccess`) da düşer
   (✗). Sürekli tonda SD ile vibrato ayrılmıyor.
3. Doğruluk puanı `100 − |cent|`: 50 c'de "50" ve hâlâ başarı (kararlılık
   %100 ise 70) — puan ölçeği başarı kararıyla tutarsız.

### 4.2 Ses aralığı skoru (`RangeScore`: genişlik .60 / doğruluk .25 / ilk deneme .15)

- Kaynak yorumu "geniş ama gevşek aralık, dar ve temiz olanı geçemez"
  diyor. Gerçek formülde bu **29 yarım sese kadar doğru**: 30 yarım sesi
  gevşek (doğruluk 60, ilk deneme %0) 65 puan, 14 yarım sesi mükemmel
  (100/%100) 63 puan alıyor. Gerçekçi aralıklarda (12–23) yorum geçerli.
- **Doğruluk bileşeninin gerçek yayılımı yalnız 10 puan** (yalnız ≤40 c
  eşleşmeler sayıldığı için 60–100 arası): ağırlık .25 gerçekte 0–10 puan.
- **Genişlik tek başına 60/100.** Bu, kendi ilkelerimizle çelişir:
  `LEARNING_MODEL.md` "ses aralığı genişliği ilerleme veya yetenek derecesi
  değildir", `ENGAGEMENT_RESEARCH` §5 "aralık genişliğini ödüllendiren yarış
  yok". `personalRank` aynı puanla sıralıyor.
- **Geçerlilik:** simüle şarkıcılarla (gerçek `RangeLadder`, take başına
  pitch gürültüsü σ):

  | gerçek aralık (yarım ses) | σ=10 c | σ=20 c | σ=30 c | σ=40 c | σ=60 c |
  |---|---|---|---|---|---|
  | 18 → ölçülen | 17 | 17 | 15 | 12 | **8** |
  | 30 → ölçülen | 29 | 29 | 24 | 18 | **9** |
  | σ=60 c'de skor yok (null) | %15–20 | | | | |

  σ=60 c'lik şarkıcı 30 yarım seslik gerçek aralıkta ~9 ölçülüyor ve %11–20
  oranında hiç skor çıkmıyor: **test, "aralık"ı değil "aralık × eşleme
  doğruluğu"nu ölçüyor.** Tüm simüle şarkıcılarda puan ↔ gerçek aralık
  korelasyonu 0,52, puan ↔ gürültü −0,66: puan aralıktan çok eşleme
  doğruluğuna bağlı — yani "genişlik %60" ağırlığı fiilen etkisiz, ama ad
  ve arayüz "aralık" diyor.
- **Tekrarlanabilirlik** (sabit şarkıcı 18 yarım ses, σ=25 c, 400 tekrar):
  puan SD 3,7; ölçülen yarım ses SD 1,8 — pratik aracı için kabul edilebilir.

### 4.3 Geçiş kapısı ve yıldızlar (`TrainerStore.completeNode`)

Kurallar: ara durak 12 soru, final 20; geçme ≥ %80; ders her zaman tamamlanır;
yıldız ≥%95 → 3, ≥%80 → 2. Gerçek kapılar için (tüm 5 yol):

| Kapı (n, kesme) | Rastgele geçme | Gerçek %70 | %80 | %85 | %90 |
|---|---|---|---|---|---|
| Ara durak (12, 10/12) | ≤ %0,05 | %25 | %56 | **%74** | %89 |
| Final (20, 16/20) | ≈ 0 | %24 | %63 | %83 | %96 |

- Şansla geçme sorunu yok. **Sorun ayırt edicilik:** %85 doğru öğrencinin
  dörtte biri ara durakta takılıyor; %70'lik öğrencinin dörtte biri geçiyor.
- %60'lık öğrenciyi ≤%5 hatayla eleyip %80'lik öğrenciyi ≥%80 geçirmek için
  **en az 36 soru** (≥27 doğru = %75) gerekir; bugünkü 12 soruluk kapı
  %60'lık öğrenciyi %8,3 geçirir, %80'liği %55,8 geçirir.
- **3 yıldız = 10 soruda 10/10.** Gerçek %90 doğruluk için P(3★) = %35;
  %95 için %60. Yıldız büyük ölçüde şans.
- **XP:** doğru +10, yanlış +2. Rastgele tıklama (2 seçenek) mükemmel
  oturumun %60'ı; 1 sn/tıklama ile saatte 21 600 XP, 15 sn/özenli soru ile
  2 400 XP. XP zaten "pratik puanı, beceri ölçümü değil" etiketli (WIDE-03);
  yine de hacmi ödüllendiriyor.

---

## 5. Müfredat ve yük dağılımı

### 5.1 Yapı

| Yol | Öğe | Düğüm | Ders (yeni/karışık/alıştırma) | Ara durak | Puanlı soru |
|---|---|---|---|---|---|
| Nota | 12 | 28 | 23 (11/10/2) | 3 | 286 |
| Aralık | 12 | 32 | 26 (12/11/3) | 4 | 328 |
| Akor | 9 | 20 | 16 (8/7/1) | 2 | 204 |
| Dizi | 11 | 25 | 20 (10/9/1) | 3 | 256 |
| Yürüyüş | 9 | 23 | 18 (9/8/1) | 3 | 236 |
| **Toplam** | | **128** | | | **1310** |

**Modalite:** 1310 puanlı sorunun tamamı **algı** (duyup adlandır/ayırt et).
Ders akışı Dinle → Söyle → Ayırt et; "Söyle" isteğe bağlı, öz tempolu ve
puansız ("yalnız alışkanlık içindir"). Günlük rota: nefes rehberi (ölçüsüz)
+ 1 ders + isteğe bağlı "Ses" adımı; ilk günden sonra "Ses" adımı **"Kaç ses
duyuyorsun?" (2/3/4 sesli doku ayırt etme)** olur — yani yine dinleme.
Düzenli, ölçülen **fonasyon pratiği rotada yok**; `voice` hedefinin ısınma
içeriği "eğitimci onayı bekliyor" (`daily_route.dart`). Ölçülen eşleme
(dinle-söyle, 6 seviyeli ezgi yankısı, aralık testi) Koro / Ses
laboratuvarı sekmesinde ayrı duruyor; rota, yıldız ve ustalıkla bağı yok.

### 5.2 Öğe başına maruziyet (3000 simüle yol, her düğüm bir kez)

Beklenen puanlı soru sayısı (tanıtım sırasına göre):

- Nota: Do 55, Mi 48, Sol 39, Re 30, Fa 26, La 22, Si 17, Si♭ 15, Fa♯ 13,
  Mi♭ 9, La♭ 6, Re♭ 6 → **ilk/son 8,9×**
- Aralık: M2 58, m2 52, M3 43, m3 33, P5 29, P4 25, P8 20, M6 18, m6 16,
  m7 13, M7 11, A4 10 → **6,0×**
- Akor 4,3×, Dizi 5,3×, Yürüyüş 5,4×.

Zorluk genellikle tanıtım sırasıyla artıyor (kromatik notalar, tritone,
dim7, blues en sonda) → **en zor öğeler en az çalışılıyor.** Bu bir tasarım
sonucu: ders içi örnekleme tekdüze, zayıflığa/hataya göre ağırlıklandırma yok
(`QuizGenerator.identify` havuzdan eşit çeker; `ItemStat`/hafıza derste
kullanılmıyor).

Olumlu: "Yeni: X" derslerinde sorunun ortalama **%48–52'si** yeni öğeye
gidiyor (min %36–38) — bloklu öğrenme sonra karışık tekrar düzeni makul.

### 5.3 Süre yükü

Uyaran sesi (soru başına): nota 1,3 sn, aralık 1,9, akor 1,8, dizi 2,7,
yürüyüş 3,6; **3 seçenekli "bul" sorusunda** toplam 3,9 / 5,7 / 5,4 / 7,9 /
**10,9 sn** (3 ses çalınıyor). Rota tekrar kartı için 15 sn/kart varsayıyor;
yürüyüş/dizi "bul" sorularında yalnız ses 8–11 sn, bu varsayım orada düşük.
Günlük rota **10, 15, 20 dakika için aynı** (nefes 120 sn + 1 ders + isteğe
bağlı Ses); seçilen süre içeriği büyütmüyor (yalnız 3 → 5 → 10 dk
arasında nefes/ses adımı kademeleniyor). Seçenek sayısı havuzla büyüyor:
tek seferde **en çok 12 seçenek** (nota/aralık).

### 5.4 Tekrar kartları (`review_memory.dart`, HLR-lite)

Vade: `p < 0,85` ⇒ son cevaptan **0,234·h** sonra. Büyüme: doğru cevap yalnız
**≥ 0,5·h** sonra verilirse ×2. Çakışma: zamanında (0,23h–0,50h arası)
verilen doğru cevap yarı ömrü **büyütmez**. Sonuç — yarı ömür tavanı ≈
**4 × kullanıcının uygulamaya gelme aralığı**:

| Uygulamaya gelme | 90 günde tekrar (tek kart) | Son yarı ömür |
|---|---|---|
| her gün | **90** | 4 gün |
| 2 günde bir | 45 | 8 gün |
| 3 günde bir | 30 | 8 gün |
| 7 günde bir | 12 | 16 gün |

Doğruluk %70–95 olsa da aynı (günlük kullanıcıda 90 tekrar/kart). 12 kartlı
bir günlük kullanıcıda tur sınırı (8) her gün doluyor: 60 günde **40
tekrar/kart**, tavan 8 kart/gün ≈ 2 dk/gün sabit yük, kart "mezun olmuyor".
Genişleyen takvim (1/3/7/14/30/60 gün) 6 tekrar eder.

**Ne-olursa (what-if)** — yalnız büyüme eşiği "vade süresi"ne (0,234·h)
çekilirse: günlük kullanıcıda 90 günde **10** tekrar (1,2,3,5,9,17,32,47,62,77.
gün), 7 günde bir 7 tekrar. Mevcut `review_cards_test` iki vakası (1,5 gün
→ ×2, 0,01 gün → ×1) geçerliliğini korur. **Dikkat:** bu yalnız yapısal
tavanı kaldırır; ×2 katsayısının doğru olup olmadığı öğrenen benchmark'ı ister
(kaynak dosya zaten "benchmark gelince ayarlanır" diyor); `memoryModelVersion`
değişirse mevcut kartlar sıfırlanır (`trainer_store.dart` `_decode`).

Ayrıca derste verilen her cevap `recordAnswer` ile kart zamanını sıfırlıyor
(büyütmeden); bu vadeyi erteler ama aralık oluşturmaz.

### 5.5 Ritim modülleri (Koro / Ses laboratuvarı → "Alkışla ritim")

`tool/benchmark/rhythm_benchmark.dart`; gerçek `EventRhythmAnalyzer`,
`ClapOnsetDetector` ve gerçek ritim içeriği (12 ritim). İnsan zamanlaması
**simülasyondur** (Wing–Kristofferson tarzı duyarlılık ızgarası, ölçüm
değil); tıkırtılar bağımsız sentezdir, kayıtlı insan alkışı değildir.
"Ritim tekrarı" (dokunma) aynı analizörü ve aynı ilk-vuruş çapasını kullanır
ama ayrıca ölçülmedi.

**Kural:** ilk alkış çapa (t=0); sonraki her alkış referans zaman çizelgesinde
**mutlak ±120 ms** pencereye girmeli; geçme = hepsi eşleşmiş, 0 eksik, 0 fazla
(`clap_rhythm.dart` `_passed`). Skor (`timingAccuracy`) ise ±120 ms kenarında
sürekli (119 ms ≈ 121 ms); ikili geçme sürekli değil.

| Bulgu | Değer |
|---|---|
| En kısa vuruş aralığı | ≥ 375 ms (> 2×120): vuruş belirsizliği yok |
| Pencerenin ritim süresine oranı | %2,4 (10/8, 9/8) … %5,3 (dörtlükler): serbest tempoda gereken tempo doğruluğu |
| **Mükemmel bilen** performansçının geçme oranı (12 ritim ort.) | yetenekli **%85**, tipik **%65**, acemi **%41** |
| Geçme oranı ↔ ritim **süresi** korelasyonu | **−0,99** |
| Geçme oranı ↔ uygulamanın **seviye sırası** korelasyonu | **−0,06** |
| Tempo hatası yok, aralık CV %4 | %90; tempo hatası SD %3 → %65; %5 → %50 |

Yani başarısızlığı belirleyen şey ritmin zorluğu değil **uzunluğu** (süre
biriktikçe sapma ±120 ms'yi aşıyor). Uygulamanın seviye sırası
(senkop → vuruş dışı → en kısa aralık → vuruş sayısı) bunu yansıtmıyor:
Seviye 2 (Sofyan, 4,7 sn) tüm basit ritimler arasında en uzunlardan; mükemmel
bilen tipik performansçı orada %49, Seviye 1'de %84 geçiyor, Seviye 12'de
(tresillo, aynı süre) %49. Geçme yeni seviyeyi açtığı için öğrenci
bilgisinden bağımsız takılabilir.

**Alternatif kurallar** (uygulamada yok; yalnız kaybın ne kadarının tempo
sapması olduğunu göstermek için), aynı performansçılar, 12 ritim ortalaması:

| Kural | Yetenekli | Tipik | Acemi | Yanlış ritmi kabul (150 ms kaydırılmış) | (250 ms) | (alkış eksik) |
|---|---|---|---|---|---|---|
| Bugünkü (mutlak zaman) | %85 | %66 | %40 | %18 | %0 | %0 |
| Tempo normalize (süre oranıyla ölçekle) | %100 | %100 | %93 | **%8** | %0 | %0 |
| En küçük kareler tempo+ofset uyumu | %100 | %100 | %100 | %68 | %0 | %0 |

Tempo normalizasyonu hem geçme oranını yükseltiyor hem yanlış ritmi
kabul etmeyi azaltıyor (sapma gürültüsünü gideriyor); en küçük kareler uyumu
fazla cömert (150 ms'lik yanlışı %68 kabul ediyor). Parametreler varsayımdır;
yönü sağlam, büyüklüğü gerçek öğrencilerle doğrulanmalı.

**Alkış detektörü** (5 ms adım, −42 dBFS taban, tabanın 16 dB üstü, 9 dB
yükselme, 90 ms bekleme), sentetik alkışlar, rastgele alt-adım fazı:

| Tepe (dBFS) \ oda tabanı (dBFS RMS) | −80 | −60 | −50 | −40 | −30 |
|---|---|---|---|---|---|
| −6 | %100 | %100 | %100 | %96 | %21 |
| −12 | %100 | %100 | %100 | %66 | %1 |
| −18 | %100 | %99 | %94 | %5 | %0 |
| −24 | %84 | %90 | %40 | %0 | %0 |
| −30 | %33 | %38 | %2 | %0 | %0 |

- **Zamanlama jitter'ı küçük:** tespit zamanı − gerçek başlangıç ortalama
  −2,0 ms, SD 1,5 ms (−5…+3); seviyeye bağlı gecikme farkı ~2 ms. Sabit
  gecikme çapada kayboluyor; kalan jitter ±10 ms "tam zamanında" bandının
  altında → **ritim ölçümünün sınırı detektör değil insan zamanlaması ve
  mutlak zaman kuralı.**
- **Duyarlılık sınırı:** sessiz odada tepe −24 dBFS'ye kadar iş görüyor
  (%84–90), −30'da %33–38, −36'da yok. −40 dBFS RMS oda gürültüsünde
  (TV/klima) −18 dBFS'lik alkış bile %5. Telefon mikrofonunda gerçek alkış
  seviyesi/AGC **ölçülmedi** (eşikler kod yorumunda "taslak, insan alkışlarında
  benchmark edilmedi" diyor).
- **Alkışa özgü değil:** enerji başlangıcı dedektörü; −18 dBFS tepeli
  "pa" ünsüzü, öksürük, kapı çarpması **%100**, "s" %85 tetikliyor (−30
  dBFS'te %88 / %24 / %97 / %0). Fazladan "alkış" geçmeyi bozar (0 fazla
  şartı). Sentetik çift tetikleme yok (0,0 fazla). Kullanıcı konuşursa veya
  öksürürse deneme düşer; yeniden denenebilir.

---

## 6. Dış kanıt (literatür taraması)

Ayrı bir araştırma ajanı web'den derledi; ben kaynakların hepsini birincil
olarak açmadım. Kalite: **[P]** birincil/hakemli sayfa açıldı, **[S]** ikincil
veya yalnız özet, **[V]** satıcı/blog (düşük). Aşağıda yalnız modelle ilgili
olanlar var; kanıtın bulunamadığı yerler açıkça belirtildi.

**Pitch ölçümü**

| Bulgu | Bu modele etkisi | Kalite |
|---|---|---|
| Eğitimli 13 şarkıcıda YIN temiz kayıtta ~%0,9 kaba hata, **T60=100 ms yankıda ~%7**; ince-pitch hatası bariton ~15 c, soprano ~8 c; kaba hata bariton→soprano 2–4× azalıyor ([Babacan vd.](https://ar5iv.labs.arxiv.org/html/1912.12609)) | Sentetik benchmark'ım yankısız ve hata 0,4–1,5 c: **gerçek ses için iyimser.** Yankı en büyük kör nokta. | P |
| 50 c = mir_eval RPA'sı ("yarım sesin yarısı"); gerekçesi yalnız bu ([mir_eval](https://mir-eval.readthedocs.io/latest/api/melody.html)). 25 c'de pYIN .990→.972 / .919→.890 düşer ([CREPE](https://ar5iv.labs.arxiv.org/html/1802.06182)) | 50 c bir gevşek ölçüt, kutsal değil. | P |
| pYIN RPA yayınlarda %66–87 (parametreye çok bağlı); CREPE/RMVPE %95–97; 0 dB gürültüde RMVPE 92, CREPE 81, pYIN 53 ([RMVPE](https://ar5iv.labs.arxiv.org/html/2306.15412)) | Uygulamanın dedektörü YIN-lite (pYIN değil, HMM yok); **YIN-sınıfı için yayımlanmış şarkı + SNR doğruluğu bulunamadı.** | P |
| vocadito: CREPE RPA .98 ama **sesli/sessiz yanlış alarm .31**; referans etiketler pYIN-tohumlu ([vocadito](https://ar5iv.labs.arxiv.org/html/2110.05580)) | Zayıf nokta pitch değil sesli/sessiz karar (bizde VAD-01 açık). | P |
| Telefonda YIN maliyeti: bulunamadı | §2.1 yalnız masaüstü. | – |

**Şan doğruluğu normları**

| Bulgu | Etki | Kalite |
|---|---|---|
| ±50 c yaygın "doğru" penceresi; eğitimsiz yetişkinlerde **hatalı eşleyici oranı ölçüte göre %2–78**; tek perde görevinde ±50 c'de %58 (ortalama mutlak hata 140 c, medyan 88 c; oktav hataları büyük hata sayılmış) ([Berkowska & Dalla Bella](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2013.00714/full), [Pfordresher](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2015.00271/full)) | §4.2'deki **σ=60 c senaryosu egzotik değil**; aralık testi eğitimsiz şarkıcıların gerçek aralığını sistematik düşük ölçebilir. | P |
| Aralık genişliği doğrulukla ilişkili çıkmadı; ortalama aralık 18,5 yarım ses (SD 4,6) ([Berkowska](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2013.00714/full)) | Genişliğe %60 ağırlık için dayanak yok; "tipik 12–18" bandı (`range_score.dart`) literatürle uyumlu. | P |
| Vibrato hızı 5,5–6,7 Hz, **extent ±34…±123 c (ort. ±71 c)**, 10 profesyonel kayıt ([Prame 1994](https://www.mmdigest.com/Archives/Digests/199910/1999.10.13.09.html)) | Kararlılık eşiği 25 c SD (≈±35 c) en küçük profesyonel vibratoya denk: **normal vibrato "kararsız".** | S |
| Dinleyici tolerans eşiği ~27 c (müzisyen olmayan), uzman ~10 c ([ESCOM özeti](https://orbi.uliege.be/bitstream/2268/186233/3/ESCOM_Abstract.pdf)) | 50 c, algı eşiğinin ~2× üstünde: geri bildirim "tuttu" derken kulak "yanık" duyabilir. | S |
| Algı–üretim ayrışması: algı eksiği üretimi bozar, üretim eksiği algıyı bozmaz ([LDR modeli](https://pmc.ncbi.nlm.nih.gov/articles/PMC3817506)); Hutchins & Peretz: eşleştirmeyi kaydırıcıyla yapıp sesle yapamayanlar var | `LEARNING_MODEL.md`'deki "algı ve üretimi ayrı tut" ilkesi destekleniyor. | P/S |
| Oktav hatası: araştırma ölçümleri hata sayar; iki oyun patenti affeder ([patent](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7164076)) | ADR-006 (oktav başarı sayılmaz) literatürle uyumlu. | S/V |

**Kulak eğitimi sıralaması ve ustalık**

| Bulgu | Etki | Kalite |
|---|---|---|
| Eğitimsiz dinleyiciler komşu aralık boylarını karıştırıyor; aralık başına doğruluk (tritone, M6, m7) **bulunamadı**; ikinci el: yükselen m2 %85, M2 %90, m3 %78 ([Yust](https://people.bu.edu/jyust/YustICMPC2010.pdf)) | Uygulama M2'den hemen sonra m2'yi öğretiyor (komşu boy); sıranın kanıtı yok, tersi de yok. | S (düşük güven) |
| Kodály: pentatonik önce (so-mi, la, do, re), fa/ti geç; gerekçe pedagojik, kontrollü kanıt yok ([özet](https://en.wikipedia.org/wiki/Kod%C3%A1ly_method)) | Uygulama tonik→üçlü→basamak→yeden sırasını izliyor (fa, la'dan önce): savunulabilir ama Kodály'den farklı; kanıta dayalı seçim değil. | V/S |
| 3 seçenek çoktan seçmelide en iyi (genel eğitim meta-analizi, ear-training'e özgü değil); çalışma belleği ~4 öbek (Cowan 2001) ([OSU özeti](https://u.osu.edu/cvmofficeofteachingandlearning/2018/02/02/how-many-options-should-a-multiple-choice-question-have-maybe-just-3/), [Cowan](https://pubmed.ncbi.nlm.nih.gov/11515286/)) | Uygulama aynı anda **12 seçenek** sunabiliyor (kulak eğitiminde seçenek sayısı çalışması bulunamadı). Havuzun kademeli büyümesi (1 öğe/aşama) ilkeyle uyumlu. | S |
| %80–90 ustalık eşiği Bloom'dan gelen gelenek; eşikleri karşılaştıran deney **bulunamadı** ([Slavin 1987](https://www.gwern.net/doc/psychology/1987-slavin.pdf)). "%85 kuralı" (Wilson 2019) eğitim hatası içindir, hatırlama hedefi değil | %80 kesme "kanıtlı eşik" değil gelenek; asıl sorun uzunluk (§4.3). | S |
| Binom hesabı (ajanın): 80% gerçek öğrenci 8/10'u %68, 70%'lik %38 geçer; tümü doğru çalıştırma için n≥16 → Wilson alt sınırı ≥.80 | §4.3 ile aynı yönde. | C |

**Aralıklı tekrar**

| Bulgu | Etki | Kalite |
|---|---|---|
| Duolingo HLR: p=2^(−Δ/h), h=2^(θ·x), **yarı ömür 15 dk–274 gün** kırpılır; öğrenilmiş ağırlıklar bulunamadı ([kod](https://raw.githubusercontent.com/duolingo/halflife-regression/master/experiment.py)) | Bizim "×2 / ÷2" ve 0,5–60 gün sınırı bu kaynaktan türemiyor, **taslak sabit**. HLR'nin bağımsız yeniden üretimi zayıf uyum bildirmiş ([blog](https://papousek.github.io/analysis-of-half-life-regression-model-made-by-duolingo.html), V). | P/V |
| Anki/FSRS varsayılan hedef tutma **%90**; %97 üstü iş yükü hızla artar ([Anki](https://docs.ankiweb.net/deck-options.html)); SuperMemo %10 unutma indeksi | Bizim 0,85 daha düşük (daha çok unutma, daha az iş); gerekçeli bir seçim değil, 0,85 için kaynak **bulunamadı**. | P |
| Cepeda 2008: en iyi aralık, sınav gecikmesine göre %5–40; sabit oran yok | Sabit ×2/yarı-ömür katsayısı tek başına yeterli model değil. | S |

**Ses yükü ve sağlık**

| Bulgu | Etki | Kalite |
|---|---|---|
| Titze vd.: geçici doz sınırı ≈ 17 dk sürekli sesleme (konuşmacılar, 6 kişi); iyileşme verisi konuşma görevinden ([Titze](https://pmc.ncbi.nlm.nih.gov/articles/PMC3158591), [Hunter & Titze](https://pmc.ncbi.nlm.nih.gov/articles/PMC3311979)) | Günlük rotadaki fonasyon ~0: **sesi yorma riski yok**; kusur tersi (yetersiz üretim pratiği). | P |
| Koro/prova dozimetrisinde sesleme süresi payı 1,9–42%, çoğu ~13–28% ([özet](https://acda.org/wp-content/uploads/2022/08/IJRCSVol10Schloneger.pdf)); özel şan dersinde oran **bulunamadı** | Pedagojik "ideal fonasyon payı" yok; 13–28% bir hedef değil gözlem. | S |
| Isınma 5–10 dk tercih (117 öğrenci anketi); fizyolojik fayda kanıtı zayıf; soğuma kanıtı "bebeklik" ([anket](https://read.qxmd.com/read/21439780/vocal-warm-up-practices-and-perceptions-in-vocalists-a-pilot-survey)) | Rotadaki 1–2 dk nefes rehberi kanıtla çelişmez ama kanıt da vermez. | S |
| Aralık uçlarını her gün zorlama: **kanıt bulunamadı**; Singing Carrots gözlemi: kullanıcının en tiz notasının üstünde yalnız %44 doğru ([blog](https://singingcarrots.com/blog/why-do-singers-go-flat-what-632000-missed-notes-taught-us/)) | "Uçları her gün zorlama" ilkesi (LEARNING_MODEL) sezgisel; kanıtlanmış değil. | V |

**Rakipler (satıcı belgeleri ince):** Simply Sing "neredeyse başarısız olunamaz"
(inceleme), Singing Carrots 3 hatada biter / günlük hedef 300 nota,
Yousician yıldızları 1–3, formül yayımlamıyor; Duolingo Music yalnız piyano.
Algı/üretim payı **hiçbir üründe yayımlanmamış** — "rakiplerden farklı"
iddiası ölçülemez. Genel olarak rakipler üretim (şarkı söyleme) odaklı, bu
model algı odaklı: farklı kategori.

**Bulunamayanlar (açık):** aralık/derece başına tanıma doğruluğu, ear-training'de
seçenek sayısı çalışması, ustalık eşiği karşılaştırması, telefonda YIN süresi,
pYIN/YIN/MPM'nin SNR'a göre şarkı doğruluğu, bas <100 Hz / soprano >800 Hz RPA'sı,
sürekli notada SD (eğitimli/eğitimsiz), 0,85 hatırlama eşiği ve 0,5–60 gün
sınırı için kaynak, özel şan dersinde fonasyon payı.

---

## 6b. Rakip ve eğitim mimarisi karşılaştırması

Kaynaklar: repodaki `COMPETITOR_RESEARCH.md` (10 ürün, masa başı, satıcı
beyanı), `docs/product/VOCALART_GROWTH_AUDIT_2026-11-09.md` ve ayrı bir
araştırma ajanının web taraması (aşağıda etiketli; kaynakların hepsini
birincil olarak ben açmadım). **Yayımlanmış hiçbir ürün sayfası soru sayısı
veya sayısal geçme oranı vermiyor**; bu yüzden 10 soru / %80 / 12 soru
parametreleri rakiplere karşı karşılaştırılamaz, yalnız ilke düzeyinde
karşılaştırılabilir.

### 6b.1 Sınav biçimi ↔ uygulama içeriği (en önemli bulgu)

Açılan Türk konservatuvar kılavuzlarında (OMÜ 2026–27, Ankara HBV 2025, Selçuk
2025–26 [P]; İTÜ, İstanbul, MSGSÜ, Ege için cevap biçimi belirtilmemiş veya yalnız
özet) **cevap biçimi tekrar**: şarkıyla "NA", alkış veya kalem vuruşu.
**Çoktan seçmeli işitme maddesi bulunamadı.** Melodi ve ritim ağırlığı:

| Kurum (şablon yılı) | Tek ses | Çift ses | Üç/dört ses | Melodi/ezgi | Ritim | Melodi + ritim payı |
|---|---|---|---|---|---|---|
| OMÜ DK (2026–27) | ses belleği 30 puanın içinde (2/3/4 notalı) | – | – | 50 | 20 | **%70** |
| Ankara HBV (2025) | 5 | 15 | – | 40 (makam) | 40 | **%80** |
| İTÜ TMDK (2023–24) | 5 | 25 | 20 | 30 | 20 | %50 |
| İstanbul Ü. (eski yönerge) | 30 | 10 | 20 (üç sesli) | 40 | – | %40 |

OMÜ piyano programında ayrıca tek ses 4×1, iki ses 4×2, üç ses 4×3, dört ses
4×4 madde var: **sizin seçtiğiniz "hazır 2/3/4 sesli piyano kaydı, öğrenci
sesleri birer birer tekrar eder" yönü sınav yapısıyla birebir örtüşüyor.**

| Sınav bileşeni | Cevap biçimi | Resonia'da karşılığı | Rota / ilerleme bağı |
|---|---|---|---|
| Tek ses | tekrar | Nota yolu (adlandırma) + "Dinle ve söyle" (lab, ölçülen) | yol: tanıma; lab: ayrı |
| İki / üç / dört ses | tekrar | Aralık/Akor yolu (adlandırma); 2/3/4 sesli tekrar **yakında** (kayıt bekliyor) | tanıma rotada, tekrar yok |
| **Ezgi belleği** (en yüksek ağırlık) | tekrar | Melodi yankısı (3–5 nota, 6 seviye) — lab | **rota dışı, XP/ustalığı beslemiyor** |
| **Ritim belleği** | alkış/kalem | Alkışla ritim (12 ritim, aksak dahil) — lab | **rota dışı, ilerlemeyi beslemiyor** |
| Makam melodisi (kanun/tanbur/ud) | tekrar | **Yok** (12-TET; koma aralığı tolerans/ızgara yok) | – |
| Solfej / dikte | sözlü/yazılı | **Yok** (`awaitingContent`) | – |

Uygulamanın `exam` hedefi günlük rotayı **Aralık adlandırma yoluna** bağlıyor.
Yani sınavda en çok puan taşıyan ve tekrar biçiminde sorulan bileşenler
(ezgi, ritim, çok sesli tekrar) rotada değil; rotadaki bileşen (adlandırma)
sınavda küçük pay (İTÜ tek+çift+üç ses %50; diğerlerinde daha az) ve farklı
cevap biçimi. Aksak ölçülerin kılavuzlardaki ritim maddelerinde geçtiği
**bulunamadı** (içerik kararı eğitimcinin).

ABRSM (2025 şan syllabus) ve RCM (2025 Voice) de üretim ağırlıklı: aural
puanın ABRSM'de %12, RCM'de %10'u ve notlandırma bütüncül; **ABRSM aralık
"maddesi" sesten ad bulma değil, adı verilen aralığı şarkıyla çıkarma**; RCM'de
"singback" aural puanın 4/10'u. Trinity ise şarkı söyletmeyen istisna ([P], sayfalar
ajan tarafından açıldı).

### 6b.2 Üretim / algı transferi

| Kanıt | Anlamı | Kalite |
|---|---|---|
| Zarate vd. 2010: 20 müzisyen olmayan, 6 oturum mikro-melodi **ayırt etme** eğitimi; ayırt etme gelişti, **şarkıyla doğruluk gelişmedi**, korelasyon yok ([PLoS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0011181)) | Yalnız dinleme eğitimi şarkı doğruluğunu güvenle iyileştirmiyor (kısıt: yarım sesin altı uyaran, küçük örnek, 2 hafta). | P |
| Pfordresher & Brown 2007: kötü perde şarkıcılarının ~%10–15'i, ayırt etmesi iyi; sorun algı değil algı→ses eşlemesi | Algı iyi olup üretim kötü olabilir; rotadaki "algı puanı" bunu görmez. | P (özet) |
| Berglin, Pfordresher & Demorest 2022: 20 dk eğitimde yalnız **görsel geri bildirim** grubunda anlamlı gelişme | Canlı görsel perde geri bildirimi (uygulamada Aurora/orb var, lab'da) kanıtla uyumlu. | P (özet) |
| Rogers 2013: dikte ↔ solfej r≈0,5–0,6, korelasyonel | Algı ve okuma-söyleme ilişkili ama aynı değil. | P |

Gordon ve Kodály "önce ses/taklit, sonra ad" sıralar ([P/S]); uygulamanın
"Dinle → Söyle → Ayırt et" sırası bu sıraya uyuyor, ama **"Söyle" isteğe
bağlı, bir sayfa ve puansız**, ölçülen taklit lab'da ayrı.

### 6b.3 Rakip mimarileri

| Ürün (kaynak kalitesi) | Yapı | Algı/üretim | Resonia ile fark |
|---|---|---|---|
| Singing Carrots (P) | 19 seviye × 4 kademe (Alıştırma, Temel, Zor, çok Zor): "melodi bir kez dinlenir, hafızadan söylenir, 3 hatada biter"; Zor'da melodi/metronom yok | Her kademe şarkı; **dinleme desteği kademeli çekiliyor** | Resonia'da destek kademeli çekilmiyor; söyleme ölçülmüyor |
| Yousician Singing (V/S) | 5 seviye, açık yol, görevlerin hepsi gerekli; yıldız; ses aralığı, nefes, ritim, performans kategorileri | Üretim ağırlıklı | Rota algıya, rakip üretime dayalı |
| Simply Sing (P/V) | günlük ~5 dk ısınma, XP; "başarısız olmak neredeyse imkânsız" (inceleme) | Üretim | Kısa günlük çalışma ortak; şarkı kataloğu Resonia'da yok (bilinçli) |
| EarMaster (P/S) | ~4000 ders, ABRSM aural 1–5 ve RCM Voice 1–8 kursları; ders skoru = en iyi deneme; modül = ders ortalaması; eşik altı "ek soru" | Karma (adlandırma + söyleme + alkış + solfej) | Resonia'nın en yakın "sınav odaklı" rakibi; **sınav kursları ve söyleme tolerans/geçme oranı yayımlanmamış** |
| Perfect Ear (P) | Kurslar + yüzlerce egzersiz, ritim taklidi, ezgi dikte, söyleme eğitmeni | Karma | Köprü: aynı beceri hem duyma hem söyleme |
| Functional Ear Trainer / Teoria / Tenuto (P/S) | Kullanıcı seçer, sabit yol yok; yalnız algı | Algı | Resonia'nın dinleme yolları bu sınıfla karşılaştırılabilir ve **ondan daha yapılandırılmış**; bir blog kullanıcı uygulamada %95–100 alıp gerçek müzikte zorlanma bildiriyor (V) |
| Duolingo Music (P) | Birim yolu, kısa oyunsu dersler, enstrüman (piyano) | Çalma/okuma | Alışkanlık referansı; ses yok |

Repo analizinin (COMPETITOR_RESEARCH) rakiplerde saptadığı ortak güçler ile
karşılaştırma:

| Rakiplerin ortak gücü | Resonia'da bugün |
|---|---|
| Kısa çalışma → belirli hata → hedefli tekrar → gelişim | Kısa ders ✓; hata sonrası karşılaştırma ✓; kaydedilmeyen kısa tekrar ✓; kalıcı hedefli tekrar (kartlar) ✓ ama §5.4 hatası |
| Nota/vuruş düzeyinde hata açıklaması | Ezgi yankısı ve alkış zaman çizelgesi ✓ (lab) |
| Görsel canlı perde geri bildirimi | ✓ (lab, orb/dalga) |
| Başlangıç/ileri düzey ayrımı, teori kartları | Hedef + süre ✓; aralık adı yardımı ✓; teori kartı sınırlı |
| Özelleştirilebilir egzersiz / öğretmen programı | ✗ (Plus yalnız önizleme) |
| Uyarlanır günlük set (ToneGym) | ✗ (sabit yol + kartlar) |
| Kademeli destek azaltma (Singing Carrots, Gordon) | ✗ |
| Sınav kursları (EarMaster: ABRSM/RCM) | ✗ (Türk şablonları yok; kılavuzlar doğrulanmadı) |

### 6b.4 Hedefe göre uygunluk hükmü

| Hedef | Uygun mu? | Gerekçe |
|---|---|---|
| **Kulak eğitimi** (`ear`, `beginner`) | **Evet**, ödünsüz değil | Kullanıcı seçimli rakiplerden (Teoria/Tenuto/FET) daha yapılandırılmış; eksik: uyarlanır set, gerçek müzik aktarımı, kart hatası |
| **Konservatuvar sınavı** (`exam`) | **Bugünkü hâliyle hayır** | Sınav ağırlığı ezgi/ritim/çok sesli *tekrar*; rota *adlandırma*. Doğru içerik lab'da ama rota ve ilerleme dışında; 2/3/4 sesli tekrar kayıt bekliyor; makam ve solfej/dikte yok |
| **Ses / şan eğitimi** (`voice`) | **Hayır (hazırlık katmanı)** | Isınma/teknik/fonasyon yok (içerik onay bekliyor); yalnız dinleme eğitimi şarkıyı garanti iyileştirmiyor; lab'ın ölçülen eşlemesi doğru yönde ama rota dışı |
| **Koro** (`choir`) | Kısmen | Aralık yolu + ses adımı; koro modülü ayrı ürün kararı |

---

## 7. Öneriler (öncelik sırasıyla)

Kural: AGENTS.md "öğrenci rubriği/toleransını benchmark veya kullanıcı kararı
olmadan değiştirme" — bu yüzden 2–4 numara **karar** ister; 1 numara kod hatası
düzeltmesidir ama yine de onay beklemeli (test + sürüm yükseltme etkisi var).

1. **Tekrar kartı büyüme eşiği** (tek satır): `spaced` koşulu `h/2` yerine
   `h·log2(1/reviewTarget)`. Etki: günlük kullanıcıda 90 → ~10 tekrar/kart.
   `memoryModelVersion` yükselt (kartlar sıfırlanır) ve ×2 katsayısını
   pilot verisiyle ayarla.
2. **Aralık skorunda genişlik ağırlığı** — karar: (a) aralığı skor değil
   betimleyici sonuç yap (genişlik puana girmez; doğruluk/ilk deneme
   "pratik ölçüsü"); (b) genişliği ≤%25'e indir; (c) aynen koru ve
   `LEARNING_MODEL`/`ENGAGEMENT` ilkesini güncelle. Ayrıca aralık
   ölçümünün eşleme doğruluğuna duyarlı olduğunu sonuç ekranında söyle.
3. **Geçiş kapısı ayırt edici gücü** — karar: ≥2 oturumda toplam ≥36 soru
   (LEARNING_MODEL pilot hipotezi zaten "iki oturumda 10'ar soru"), ya da
   sıralı karar (erken durdur). 12 soruluk ara durağı "alıştırma", mastery
   kararını ayrı yap. 3★ eşiğini tek oturum yerine son N soru üzerinden
   hesapla veya tek hata payı ver (≥%90).
4. **Tek ses skoru bağlanmadan önce:** 50/50,5 c uçurumunu sürekli bir
   cezaya çevir; vibratoyu kararsızlıktan ayır (düzleştirilmiş kontur
   veya vibrato algılı ölçü; profesyonel vibrato ±34…±123 c, §6); tolerans
   tablosunu tek yerde topla (40 c aralık/canlı, 50 c aligner/scorer,
   ±100 c çizim kıskacı). 50 c araştırma gelenekidir ama algı eşiğinin
   (~27 c) üstünde; hangisinin "tuttu" demesi gerektiği eğitimci kararıdır.
5. **Ağırlıklı örnekleme:** karışık tekrar / ara durak / final sorularında
   öğeyi `ItemStat` doğruluğu ve hafıza `recall` değeriyle ağırlıklandır;
   hedef ilk/son maruziyet oranı ≤ 2×.
6. **Rota süreyle ölçeklensin** (10/15/20 dk aynı içerik) ve süre tahmini
   uyaran süresini içersin (yürüyüş/dizi "bul" 8–11 sn).
7. **Şan üretimi:** ölçülen eşleme alıştırmalarını (mikrofon) rotaya
   koymadan önce BENCH-01 + eğitimci onaylı ısınma; o zamana kadar rotayı
   "kulak eğitimi" olarak adlandır, `voice` hedefinin "ısınma hazırlanıyor"
   notunu koru.
8. **Dedektör:** MPM ve YIN+fallback'i gerçek insan kaydı benchmark'ında
   (yankılı oda dahil) dene. Kalibrasyonsuz yolda SNR kontrolü yok
   (`snr == null` ise atlanıyor) ve orada dedektör düşük SNR'de oktav hatası
   üretebilir: ya kalibrasyonu zorunlu tut ya da o yolda sonucu "ölçülmedi"
   say.

9. **Alkışla ritim kuralı** — karar: geçmeyi mutlak ±120 ms yerine tempo
   normalize et (süre oranıyla ölçekle) ya da seviye sırasını ritim süresini
   içerecek şekilde yeniden kur; sentetik benchmark'ta yetenekli performansçı
   %85 → %100, yanlış ritmi kabul %18 → %8. Mutlaka gerçek öğrencilerle
   doğrula; en küçük kareler uyumu fazla cömert (150 ms yanlışı %68 kabul).
10. **Alkış detektörü:** kayıtlı insan alkışıyla (farklı cihaz/mesafe/oda) ve
    konuşma/öksürükle ölç; enerji-başlangıcı dedektörü alkışa özgü değil.
    Kullanıcıya "sessiz bir yerde, konuşmadan" demek şimdilik tek önlem.
11. **`exam` rotası** (§6b.1) — karar: sınav biçimi tekrar olduğundan
    rotaya melodi yankısı + alkışla ritim + (kayıtlar gelince) 2/3/4 sesli
    tekrar koy; adlandırma yolu destekleyici kalsın. **Sınır:** bu lab
    ilerlemelerinin ustalığı/XP'yi beslememesi bilinçli (taslak ölçüm, gerçek
    cihaz/insan kapısı açık; AGENTS.md); bu yüzden şimdilik rotaya *alıştırma*
    olarak girmeli, ustalık kararı olarak değil. Makam (koma aralıkları),
    solfej/dikte ve aksak ölçülerin sınav kılavuzlarındaki yeri içerik/eğitimci
    kararı.
12. **Kademeli destek azaltma** (Singing Carrots, Gordon): "Söyle" adımı
    dinle → referansla söyle → referans çekilince hafızadan söyle sırasına
    genişleyebilir; ölçülen sürüm lab'daki melodi yankısıyla zaten var.

## 8. Yeniden üretme

Betikler repo kökünden, `package:resonia` ile çalışır; AOT derleme ölçümler
için önerilir (`dart run` kullanma, AGENTS.md).

```bash
dart compile exe tool/benchmark/detector_benchmark.dart -o /tmp/detector_benchmark
/tmp/detector_benchmark "$PWD" /tmp          # sentetik ses + piyano; ikinci argüman çıktı klasörü
dart compile exe tool/benchmark/model_benchmark.dart -o /tmp/model_benchmark && /tmp/model_benchmark
dart compile exe tool/benchmark/timing_benchmark.dart -o /tmp/timing_benchmark && /tmp/timing_benchmark
dart compile exe tool/benchmark/rhythm_benchmark.dart -o /tmp/rhythm_benchmark && /tmp/rhythm_benchmark
dart tool/benchmark/review_threshold_whatif.dart
```

Tüm rastgele tohumlar sabittir; `model_benchmark` çıktısı iki koşuda
birebir aynı çıktı (doğrulandı). Detektör benchmark'ı koşul başına bir
izolat kullanır (8 çekirdekte birkaç dakika).

## 9. Açık kapılar

Gerçek insan sesi holdout'u (BENCH-01), VAD/konuşma ayırma, gerçek cihaz/route
ve CPU/bellek ölçümü, eğitimci onaylı ısınma/şan içeriği, öğrenme etkisi pilotu,
gerçek öğrenen verisiyle HLR kalibrasyonu. Bu belge hiçbirini kapatmaz.
