# Vocalart — Faz promptları (ayrı oturumlarda sırayla çalıştırılacak)

**Kaynak:** [VOCAL_MODEL_BENCHMARK_2026-11-09.md](./VOCAL_MODEL_BENCHMARK_2026-11-09.md)
(§4–§7 bulgular ve öneriler). Her prompt tek başına yapıştırılabilir; oturum
önceki konuşmayı bilmez. **Sırayla çalıştırın, bir faz bitmeden sonrakini
başlatmayın.**

| Sıra | Prompt | Dokunduğu ana alan | Ön koşul |
|---|---|---|---|
| 0 | P0 — Tekrar kartı büyüme eşiği | `review_memory.dart` | yok (diğer oturumun yerleştirme işinden önce) |
| 1a | P1 — Alkışla ritim kuralı ve seviye sırası | `clap_rhythm.dart` | yok |
| 1b | P2 — Aralık skoru | `range_score.dart`, `range_test.dart` | `trainer_store.dart` serbest olmalı |
| 2a | P3 — Geçiş kapısı ve yıldız | `trainer_store.dart`, `lesson_flow.dart` | diğer oturumun yerleştirme/parkur işi commit-hazır |
| 2b | P4 — `exam` rotası (tekrar adımları) | `daily_route.dart`, `home_shell.dart` | diğer oturumun parkur işi bitti |
| 3 | P5 — Doğrulama pilotu (protokol, araç, analiz) | belge + `tool/` | P0–P4 bitti |

**Paralel çalışan eş oturum:** "Eğitim modeli ağaç yapısı" aynı checkout'ta
`PracticeGoal` parkuru (sıralı `List<TrainerKind>`), onboarding seviye sorusu,
ara duraklarla yerleştirme testi (erken bitirme) ve eski
`learner_profile.dart` enum'unun birleştirilmesi üzerinde çalışıyor
(`daily_route.dart`, `onboarding_flow.dart`, `trainer_store.dart`,
`curriculum.dart`). Her prompt başlamadan `git status` ve `ListAgents` ile bu
dosyaların durumunu kontrol etmeyi ister.

---

## ORTAK KURALLAR (her promptun başına eklenir)

```
Repo: /Users/sevimm/Documents/Projects/vocalart (branch feat/figma-uyumu).
Önce AGENTS.md, MODEL_HANDOFF.md, CURRENT_ROADMAP.md (üstteki kayıtlar),
IMPLEMENTATION_LOG.md (sondaki kayıtlar) ve
docs/research/VOCAL_MODEL_BENCHMARK_2026-11-09.md dosyalarını oku. Geçmiş log
tarihsel; güncel kod ve bu prompt belirler.

Kurallar:
- Çalışma ağacı KİRLİ ve başka bir oturum da yazıyor. Başlamadan `git status`
  ve `git diff --stat` al; dokunacağın dosyalarda başkasının commit'lenmemiş
  değişikliği varsa onu koru, üstüne yaz, geri alma. ListAgents ile eş oturumu
  ("Eğitim modeli ağaç yapısı") gör; ortak dosyada çakışma ihtimali varsa
  yazmadan önce SendMessage ile haber ver.
- Komşu agoravoiceweb'e dokunma. Commit/push/deploy/PR YAPMA (yalnız kullanıcı
  isterse). Ücretli API, upload, mağaza, ödeme yok.
- Rubrik, tolerans ve eşikleri yalnız bu promptta açıkça yazılan biçimde
  değiştir; fazlasını değiştirme. Gerçek cihaz/mikrofon/insan kapılarını
  sentetik veya sahte testle "geçti" sayma. Sentetik, mock, mikrofon ve
  doğrulanmamış kaynakları karıştırma.
- Kullanıcıya görünen her yeni metin tr('Türkçe','English') ile (const
  içinde kullanma); test/trainer/english_ui_test.dart kalmalı.
- Her değişiklik testle gelsin (önce başarısız olan test, sonra düzeltme).
- Bitirmeden önce:  dart format --output=none --set-exit-if-changed lib test tool
  ve  dart tool/quality_check.dart  (format → analyze → tüm testler) temiz
  olmalı; sayıları (kaç test, kaç skip) kaydet.
- CURRENT_ROADMAP.md'nin başına ve IMPLEMENTATION_LOG.md'nin sonuna kısa kayıt
  ekle. TÜM DOSYAYI YENİDEN YAZMA; Edit ile benzersiz çapa kullan. Kayıtta
  gerçek sınırları yaz ("cihazda denenmedi", "pilot yok" vb.).
- Son raporun biçimi: (1) ne değişti (dosya:satır), (2) hangi test/ölçüm neyi
  kanıtladı, (3) neyi YAPMADIN / doğrulanmadı, (4) kullanıcıdan bekleyen karar.
```

---

## P0 — Tekrar kartı büyüme eşiği (Faz 0)

```
[ORTAK KURALLAR bloğunu buraya ekle]

GÖREV: lib/trainer/domain/review_memory.dart içindeki aralıklı tekrar
modelinin yapısal hatasını düzelt.

BAĞLAM (ölçüldü, docs/research/VOCAL_MODEL_BENCHMARK_2026-11-09.md §5.4):
- Bir kart p = 2^(−Δ/h) < reviewTarget (0,85) olunca vadesi gelir; bu Δ ≈
  0,234·h demektir.
- ItemMemory.answered doğru cevapta yarı ömrü YALNIZ gap ≥ h/2 ise iki katına
  çıkarır ("spaced"). Zamanında (0,23h–0,50h arasında) verilen doğru cevap
  yarı ömrü büyütmez.
- Sonuç: yarı ömür tavanı ≈ 4 × kullanıcının uygulamaya gelme aralığı. Günlük
  kullanıcıda tek kart 90 günde 90 kez tekrar ediliyor (son yarı ömür 4 gün);
  12 kartlı kullanıcıda tur sınırı (8) her gün doluyor, 60 günde 40
  tekrar/kart. Genişleyen takvim 6 tekrar eder.
- `dart tool/benchmark/review_threshold_whatif.dart` büyüme eşiği 0,234·h
  olunca günlük kullanıcıda 90 günde 10 tekrar (1,2,3,5,9,17,32,47,62,77.
  gün) gösteriyor.

YAPILACAK:
1. `answered` içinde `spaced` koşulunu `_days(now) >= halfLifeDays * dueFraction`
   yap; `dueFraction = log2(1/reviewTarget)` (= −log(reviewTarget)/ln2) olarak
   dosyada adlandırılmış sabit/getter tanımla ve `reviewTarget` değişirse
   birlikte hareket etsin. Yorumu (dosya başı ve answered) yeni kurala göre
   güncelle: "vade süresinden önceki (aynı oturum) cevap yığılı pratiktir ve
   aralık oluşturmaz".
2. `memoryModelVersion`'ı 'hlr-lite-2' yap. trainer_store.dart `_decode` zaten
   sürüm farkında kartları sıfırlıyor; bunu bozma. (Bu dosya eş oturumla
   paylaşılıyor: yalnız sürüm sabiti kullanımını doğrula, trainer_store.dart'ı
   DEĞİŞTİRME.)
3. ×2 / ÷2 katsayısına, 0,5–60 gün sınırlarına ve reviewTarget'a DOKUNMA
   (pilot verisiyle ayarlanacak; kaynak dosya bunu söylüyor).
4. Testler (test/trainer/review_cards_test.dart ve gerekirse trainer_store_test):
   - mevcut "a spaced correct answer doubles, a massed one does not"
     (mem(2, daysAgo:1.5) → 4; mem(2, daysAgo:0.01) → 2) geçmeli;
   - vade zamanında (≈0,24·h) verilen doğru cevap yarı ömrü iki katına çıkarır;
   - vadeden önce (≈0,05·h, aynı oturum) verilen doğru cevap büyütmez, reps
     artmaz;
   - yanlış cevap yine h/2 (alt sınır 0,5);
   - günlük gelen kullanıcı simülasyonu: 90 gün, hep doğru → tekrar sayısı
     ≤ 12 ve yarı ömür 60'a ulaşır; 7 günde bir gelen → ≤ 8;
   - %85 doğrulukta (sabit tohumlu) günlük kullanıcı 90 günde < 40 tekrar;
   - eski sürüm ('hlr-lite-1') kayıt yüklenince kartlar sıfırlanır, diğer
     alanlar (xp, nodes, days) korunur.
5. tool/benchmark/review_threshold_whatif.dart'ın "0.234" satırını gerçek
   sınıfla doğrula (kopya mantık yerine ItemMemory'yi içe aktaran küçük bir
   karşılaştırma ekleyebilirsin; zorunlu değil).
6. Etki notu: kullanıcının mevcut kartları sıfırlanır — kayıtta açık yaz.

KABUL: kalite kapısı temiz; günlük simülasyon testi eski davranışta başarısız,
yeni davranışta geçiyor; hiçbir UI metni/akışı değişmedi; başka dosya
değişmedi (review_memory.dart + testler + kayıtlar).

YAPMA: ×2 katsayısını, reviewTarget'ı, reviewRoundSize'ı, hatırlatma
planlayıcısını veya kart seçim mantığını (dueCards) değiştirme.
```

---

## P1 — Alkışla ritim: tempo normalize kural ve seviye sırası (Faz 1a)

```
[ORTAK KURALLAR bloğunu buraya ekle]

GÖREV: lib/trainer/koro/clap_rhythm.dart ("Alkışla ritim") geçme kuralını ve
seviye sırasını düzelt.

BAĞLAM (ölçüldü, rapor §5.5; tool/benchmark/rhythm_benchmark.dart):
- Bugünkü kural: ilk alkış çapa; sonraki her alkış referans zaman çizelgesinde
  MUTLAK ±120 ms içinde olmalı; geçme = hepsi eşleşmiş, 0 eksik, 0 fazla
  (_passed). Serbest tempoda (kullanıcının turunda metronom yok) tempo sapması
  birikir.
- Ritmi MÜKEMMEL bilen simüle performansçının geçme oranı: yetenekli %85,
  tipik %65, acemi %41 (insan modeli duyarlılık ızgarası, gerçek ölçüm değil).
- Geçme oranı ↔ ritim süresi korelasyonu −0,99; ↔ uygulamanın seviye sırası
  −0,06. Seviye 2 (Sofyan, 4,7 sn) en uzunlardan; seviye sırası senkop → vuruş
  dışı → en kısa aralık → vuruş sayısı ile kurulu, süreyi içermiyor.
- Alternatif "tempo normalize" (kullanıcının ilk→son alkış süresini referans
  süreye ölçekle, sonra AYNI ±120 ms ve 0 eksik/0 fazla): yetenekli %100,
  tipik %100, acemi %93; yanlış ritmi kabul (bir alkış 150 ms kaydırılmış)
  %18 → %8, 250 ms ve eksik alkışta %0. En küçük kareler tempo+ofset uyumu
  fazla cömert (150 ms yanlışı %68 kabul) — KULLANMA.
- Detektör zamanlama jitter'ı küçük (SD ~1,5 ms); sınır detektör değil kural.

YAPILACAK:
1. _judge içinde, alkış sayısı referans sayısına eşitse ve kullanıcı süresi >0
   ise: k = referansSüre / kullanıcıSüre; her alkış c için
   ((c − first) * k).round() + reference.first. Sayılar eşit değilse ölçekleme
   YOK (eksik/fazla zaten başarısız). EventRhythmAnalyzer'a ve tolerans
   sabitlerine (120/10 ms) DOKUNMA. Ölçekleme saf bir üst düzey fonksiyon
   olsun (test edilebilir), örn. normalizeClapTempo(reference, claps).
2. Tempo bilgisini kullanıcıya söyle (kural gevşediği için dürüst geri
   bildirim): spanRatio = kullanıcıSüre / referansSüre; |oran−1| > 0,15
   (RhythmImitationOutcome.tempoHintThreshold ile aynı hipotez eşiği) ise
   sonuç ekranında sessiz bir not: "Tempo ≈ %N hızlıydı/yavaştı" (TR/EN).
   Geçme/başarısızlık kararını ETKİLEMEZ; skor/ustalık/XP değişmez.
3. Seviye sırası: clapRhythmsEasyToHard anahtarına ritim SÜRESİNİ (son onset
   ms) ekle. Önerilen sıra: (senkop sayısı, vuruş dışı sayısı, süre ms, en
   kısa aralık (düşük=zor), vuruş sayısı, katalog sırası). Gerekçe: normalize
   sonrası bile uzun ritimde hata birikir. Sırayı sabitleyen testleri
   güncelle ve yeni sırayı testte açıkça yaz.
4. Testler (test/trainer/clap_and_language_test.dart veya yeni dosya):
   - normalizeClapTempo: %5 yavaş/hızlı performans normalize sonrası geçer;
     eşit olmayan alkış sayısı değişmez; tek alkış / sıfır süre güvenli;
   - 150 ms kaydırılmış tek alkış (gürültüsüz) HÂLÂ geçmez; eksik/fazla alkış
     geçmez;
   - tempo notu eşiği (%15 altı yok, üstü var), TR ve EN metin;
   - yeni seviye sırası sabit;
   - mevcut ekran/layout testleri ve accessibility_audit geçer.
5. tool/benchmark/rhythm_benchmark.dart'taki ladder kopyası ve easyToHard
   kopyasını yeni sıraya göre güncelle (dosya başındaki "keep in sync" notu);
   betik yeniden çalıştırılıp çıktı (özellikle "corr(pass, level)") rapora
   işlensin (docs/research/VOCAL_MODEL_BENCHMARK_2026-11-09.md §5.5'e kısa
   "sonrası" satırı).

KABUL: sentetik kural testi eski kuralda başarısız (yavaş mükemmel performans
elenir), yeni kuralda geçer; yanlış ritim reddi korunur; kalite kapısı temiz.

YAPMA: ±120 ms'yi, 10 ms bandı, EventRhythmAnalyzer'ı, ClapOnsetDetector
eşiklerini veya dokunmatik "Ritim tekrarı" (RhythmImitationEvaluator) kuralını
değiştirme; dokunmatik sürüm aynı çapa/drift problemini taşıyabilir — yalnız
kayıtta "ayrıca doğrulanmadı" diye not et. Gerçek insan alkışı ölçülmedi:
kayıtta yaz.
```

---

## P2 — Aralık skoru: genişliği puandan çıkar (Faz 1b)

```
[ORTAK KURALLAR bloğunu buraya ekle]

ÖN KONTROL: trainer_store.dart'ta eş oturumun commit'lenmemiş değişikliği var
mı? Varsa onunla haberleş; bu görev rangeScores kalıcı verisine dokunuyor.

GÖREV: lib/trainer/koro/range_score.dart (RANGE-04) ses aralığı skorundan
genişlik ağırlığını çıkar; aralığı betimleyici sonuç olarak göster.

BAĞLAM (rapor §4.2, §6):
- Bugün total = 0,60·genişlik + 0,25·doğruluk + 0,15·ilk deneme.
- Doğruluk bileşeni yalnız eşleşen (≤40 c) takelerden hesaplandığı için
  60–100 arasında; gerçek yayılımı 10 puan. Genişlik tek başına 60/100.
- Kendi ilkeleriniz çelişiyor: LEARNING_MODEL.md "aralık genişliği ilerleme
  veya yetenek derecesi değildir", ENGAGEMENT_RESEARCH §5 "aralık genişliğini
  ödüllendiren yarış yok". Literatür: aralık genişliği doğrulukla ilişkili
  çıkmadı (Berkowska & Dalla Bella 2013); ortalama aralık 18,5 yarım ses.
- Simülasyon (gerçek RangeLadder, take gürültüsü σ): σ=60 c'lik şarkıcı
  30 yarım seslik gerçek aralıkta ~9 yarım ses ölçülüyor ve %11–20'sinde skor
  çıkmıyor; test "aralık × eşleme doğruluğu"nu ölçüyor.
- personalRank puanla sıralıyor; rangeScores 0–100 olarak kalıcı (store).

YAPILACAK (varsayılan tasarım; kullanıcı farklı isterse ona uy, belirsizse
ORADA SOR):
1. RangeScore.total = 0,625·doğruluk + 0,375·ilkDeneme (eski .25:.15 oranı
   normalize). Genişlik total'e GİRMEZ; `semitones`, `width` alanı ve
   rangeBand (12–18 tipik, ≥23 şarkıcı ortalaması) betimleyici olarak kalır.
   Doğruluk bileşenini anlamlı yayılım için (ortalama closeness − 60)/40·100
   olarak yeniden ölçekle (yalnız eşleşen takeler; 0..100). Sabitleri
   adlandır, yorumu güncelle.
2. Ekran (range_test.dart, sonuç): önce aralık betimi ("E3–B4 · 14 yarım ses",
   nota adları kullanıcının notasyonunda), sonra eşleme ölçüsü ("Eşleme: N");
   sade not: "Bu, ölçülen aralık — hassas eşleyebildiğin aralık; ses tipi
   veya yetenek değil." (TR/EN). Genişliği övücü dil, kıyas, "daha geniş =
   daha iyi" ima yok.
3. Kalıcı veri: store.rangeScores eski ölçekle kaydedilmiş. Yeni puanlarla
   karıştırma: 'rangeScoreModel' sürüm anahtarı ekle; sürüm farkında eski
   skor listesini YOK SAY (sil). trainer_store.dart'a yalnız bu anahtar
   (encode/decode/resetAll) için en küçük değişikliği yap; eş oturumun
   değişikliklerini koru. koroRange (çalışma aralığı) AYRI veri; ona dokunma.
4. personalRank: yeni puana göre kalsın (kişinin kendi geçmişi); genişliği
   ödüllendirme riski kalmadı. Arayüzde "kişisel sıra" metni varsa
   "kendi önceki denemelerine göre" diye netleştir.
5. Testler (test/trainer/range_score_test.dart, range_ladder_test,
   trainer_store_test): geniş-gevşek (36 yarım ses, doğruluk düşük, ilk deneme
   0) dar-temiz (14, yüksek) ile KARŞILAŞTIRILDIĞINDA artık geçemez; aynı
   doğrulukta farklı genişlik aynı puanı verir; oktav/ıskalanmış/ölçülmemiş
   take hâlâ sayılmaz; sürüm farkı eski skorları siler; sonuç ekranı 320 px
   ve 1,8× yazıda taşmaz; english_ui_test.
6. tool/benchmark/model_benchmark.dart rangeSection kopyasını yeni formüle
   göre güncelle ve çıktıyı rapora işle (korelasyon puan↔gerçek aralık).

KABUL: kalite kapısı temiz; aralık testi akışı (merdiven, kalite kapısı, take
yargısı) DEĞİŞMEDİ (range_ladder.dart'a dokunulmadı); eski skorlar yeni
ölçeğe karışmıyor.

YAPMA: range_ladder.dart toleransını (40 c, 2 deneme), canlı iz algoritmasını,
kalite kapısını veya koro aralığı seçimini değiştirme. Ses tipi/SATB kararı
üretme.
```

---

## P3 — Geçiş kapısı, yıldız ve ustalık kanıtı (Faz 2a)

```
[ORTAK KURALLAR bloğunu buraya ekle]

ÖN KOŞUL: eş oturumun yerleştirme/parkur işi (ara durak erken bitirme,
onboarding seviye sorusu) trainer_store.dart ve curriculum.dart'ta
tamamlanmış olmalı. `git diff` ile gör; onun completeNode değişikliklerini
ve API'sini KULLAN, yeniden icat etme; çakışırsa SendMessage ile konuş.

GÖREV: ara durak/yıldız/ustalık kararlarının istatistiksel zayıflığını
gider. %80 geçme eşiği ve ders=her zaman tamamlanır kuralı DEĞİŞMEZ
(kullanıcı yerleştirme için de %80'i onayladı).

BAĞLAM (rapor §4.3):
- Ara durak 12 soru (kesme 10/12), final 20 (16/20). P(geçme): gerçek %70 →
  %25, %80 → %56, %85 → %74, %90 → %89; %60'lık öğrenci %8,3 geçer. Rastgele
  geçme ≈ 0 (≤%0,054).
- %60'ı ≤%5 hatayla eleyip %80'i ≥%80 geçirmek için en az 36 soru gerekir.
- 3 yıldız = ≥%95 = 10 soruda 10/10 (12'de 12/12; 20'de ≥19): gerçek %90
  doğrulukta P(3★) %35.
- Erken bitirmede (10 doğru → geçti, 3 yanlış → kaldı; final 16/5) karar tam
  testle aynıdır ama accuracy'yi "sorulan soru"ya bölersen 10/10 = 1,0 → 3★
  şişer.
- LEARNING_MODEL.md pilot hipotezi: aynı beceride iki ayrı oturumda ≥10'ar
  geçerli yeni soru ve %80; biri ipucusuz/gecikmeli.

YAPILACAK:
1. starsFor: 3★ eşiğini ≥%90'a indir (10 soruda ≤1 hata; 12'de ≤1; 20'de ≤2);
   2★ ≥%80, altı 1★ aynı kalır. Gerekçeyi ve "yıldız ustalık değil
   pratik göstergesi" notunu koda yaz.
2. Accuracy hesabı: PLACE-01 (eş oturum) bunu yerleştirme durakları için
   ZATEN yaptı (GateStop: checkpoint 10 doğru/3 yanlış, final 16/5; store'a
   correct/L yazılır, erken geçiş 10/12 = 2★). Yalnız doğrula: bu görev
   starsFor eşiğini değiştirdikten sonra yeni 3★ eşiğinde (≥%90) 10/12 = 0,83
   hâlâ 2★ ve 11/12 = 0,92 → 3★ olduğunu placement_test.dart'a ekleyerek
   sabitle; GateStop'a dokunma.
3. Başarısız kapı: kilit kalır (önceki düğüm tamamlanmadan ilerlenmez), ama
   sonuç ekranına tek net öneri ekle: "Önceki dersi tekrar et" (kapıdan hemen
   önceki dersi açan düğme) + "Yeniden dene". Yeni TR/EN metin; suçlayıcı
   dil yok.
4. Ustalık kanıtı (yalnız gösterge, kilitleri/ilerlemeyi ETKİLEMEZ):
   trainer_store'a sınırlı (kapı başına son 3) deneme günlüğü: nodeId,
   doğru, toplam, dayKey. "Pekişti" = en az 2 farklı günde, toplam ≥36 soru
   (birleşik), birleşik doğruluk ≥%80. Gelişim ekranında kapı satırında
   küçük rozet; metin: "iki ayrı günde doğrulandı". Kalıcı şemayı geriye
   uyumlu ekle (yeni anahtar, eskisiz yüklemede boş).
5. Yerleştirme ile uyum: yerleştirme durağı kapı gibi completeNode'a gider;
   günlük kayıt yerleştirme denemelerini de sayar. "Yaklaşık" dili ve elle
   düzeltme eş oturumun UI'sında — çakışma varsa ona bırak.
6. Testler: starsFor sınırları (0,89/0,90/0,94/0,95), erken bitirme
   accuracy, günlük ≤3 sınırı ve eski veri yükleme, "pekişti" kuralının
   sınırları, başarısız kapı önerisi, english_ui_test, kilit mantığı
   (isUnlocked) değişmedi.
7. tool/benchmark/model_benchmark.dart kapı/yıldız kopyasını yeni eşiğe göre
   güncelle ve rapora işle (P(3★) tablosu).

KABUL: kalite kapısı temiz; %80 kapı eşiği ve lesson=her zaman tamam
davranışı testle sabit; mevcut kayıtlar yüklenir.

YAPMA: %80'i, 12/20 soru uzunluklarını, ders yolu içeriğini, ders
tamamlanma kuralını veya yerleştirme algoritmasını değiştirme. Mastery
göstergesini kilit/rota kararına bağlama.
```

---

## P4 — `exam` rotası: tekrar tabanlı alıştırma adımları (Faz 2b)

```
[ORTAK KURALLAR bloğunu buraya ekle]

ÖN KOŞUL: eş oturumun parkur işi (PracticeGoal → sıralı List<TrainerKind>,
DailyRoute ilk bitmemiş dersi seçer) bitmiş ve çalışma ağacında olmalı.
daily_route.dart / home_shell.dart / onboarding_flow.dart değişikliklerini
oku ve onun API'sinin üstüne ekle; çakışma varsa SendMessage ile konuş.

GÖREV: `exam` hedefinin günlük rotasına, sınavın asıl biçimi olan TEKRAR
alıştırmalarını ekle.

BAĞLAM (rapor §6b.1):
- Açılan Türk konservatuvar kılavuzlarında (OMÜ 2026–27, Ankara HBV 2025,
  Selçuk 2025–26) işitme cevabı tekrar: şarkıyla "NA", alkış veya kalem
  vuruşu; çoktan seçmeli işitme maddesi bulunamadı. Melodi + ritim payı OMÜ
  %70, HBV %80, İTÜ %50, İstanbul %40. (İTÜ/İstanbul/MSGSÜ cevap biçimi
  doğrulanamadı.) ABRSM/RCM de üretim ağırlıklı.
- Uygulamada karşılıklar Koro/Ses laboratuvarında: melodi yankısı (3–5 nota,
  6 seviye), alkışla ritim (12 ritim), dinle-söyle; hepsi rota ve ilerleme
  dışı; `exam` rotası yalnız adlandırma yollarına bağlı.
- Lab ilerlemeleri (melodyEchoLevel, clapLevel) BİLİNÇLİ olarak XP/seri/
  ustalık/geçmişi beslemez; ölçülen taklit taslak ve gerçek cihaz kapısı
  açık (AGENTS.md). Bu yüzden rotaya ALIŞTIRMA olarak girer.
- 2/3/4 sesli tekrar: kayıtlar yok (assets/audio/piano/chords catalog.json
  "awaiting_recording"); placeholder kapalı kalır.

YAPILACAK:
1. DailyRoute'a `echoStep` (enum: melody, clap) ekle; yalnız goal==exam ve
   süre > 5 dk iken (≤5 dk'da yok). Seçim deterministik: son yapılan echo
   türünün tersi; yoksa melodi. Hangi türün yapıldığı için store'a küçük
   'echoDay'/'echoLast' anahtarı (geriye uyumlu); XP/seri/ustalığa YAZMA.
2. home_shell.dart rota kartına adım: "Tekrar alıştırması · melodi yankısı"
   veya "alkışla ritim", alt başlık: "taslak ölçüm · mikrofon isteğe bağlı"
   (TR/EN); dokununca mevcut MelodyEchoScreen / ClapRhythmScreen açılır
   (yeni ekran yazma). Tamamlama = ekranın bir tur bitmesi; "ölçüldü" değil
   "yapıldı" olarak işaretle.
3. goal.pendingContent (exam): mevcut metni koru ve ekle: "Makam melodileri,
   solfej ve dikte henüz hazır değil; 2/3/4 sesli tekrar kayıt bekliyor."
4. Süre ölçeği: rota adım sayısı ve toplam dakika hesabı (route.stepCount ve
   ekrandaki süre) yeni adımı yansıtsın; yürüyüş/dizi "bul" sorularında
   uyaran sesi 8–11 sn olduğu için süre tahminini düşük yazma.
5. Diğer hedeflerin rotası BİREBİR aynı kalsın (voice/choir/ear/beginner/
   stage). Hedefi olmayan eski kayıtların rotası da.
6. Testler (test/trainer/trainer_route_test, goal_onboarding_test,
   english_ui_test, accessibility_audit_test): exam + 3/5/10 dk adım
   kümeleri; diğer hedeflerde değişiklik yok; echo türü dönüşümlü; echoStep
   tamamlanınca XP/seri/ustalık DEĞİŞMEZ; hazır olmayan içerik (2/3/4) rotada
   önerilmez.

KABUL: kalite kapısı temiz; exam kullanıcısı 10 dk'da nefes + ders + echo
alıştırması görür; hiçbir ölçüm eşiği değişmedi.

YAPMA: 2/3/4 sesli placeholder'ı açma; lab ilerlemelerini ustalığa/XP'ye
bağlama; makam/komalı ölçüm ekleme; ses algoritmasına dokunma.
```

---

## P5 — Doğrulama pilotu: protokol, araç ve analiz (Faz 3)

```
[ORTAK KURALLAR bloğunu buraya ekle]

ÖN KOŞUL: P0–P4 bitti. Bu görevde gerçek katılımcı, rıza, eğitimci veya
kayıt UYDURULMAZ; oturum yalnız hazırlık/araç/analiz yazar. Kayıt toplama ve
insan işleri kullanıcıyla yürütülür.

GÖREV: BENCH-01/VAD-01/CAL-02 kapılarını kapatacak pilot için protokol,
manifest/araç ve analiz hattını hazırla.

BAĞLAM: tool/benchmark/ sentetik/simülasyon sonuçları (rapor §2, §4–§5.5)
gerçek insan sesi, yankı, eşlik sızıntısı, cihaz AGC'si, telefon CPU süresi
ve gerçek alkışı ölçmedi. Literatür: YIN trained singer'larda yankıda (T60
100 ms) ~%7 kaba hata; kaba/ince hata sentetikten çok büyük (Babacan vd.);
eğitimsiz yetişkinlerin tek perde ortalama mutlak hatası geniş (medyan ~88 c,
oktav hataları dahil); detektörler loudness'a bağlı.

YAPILACAK (belge + araç; kod değişikliği küçük):
1. docs/research/PILOT_PROTOCOL_2026-11.md: hedefler ve ölçütler önceden
   kayıtlı:
   a) Pitch: ≥100 etiketli kayıt, kişi ayrık development/holdout
      (AudioFixtureManifest şeması); sınıflar: doğru nota, ±oktav, yanlış
      nota, sessizlik, konuşma/gürültü, kararsız/vibrato, kısa buffer,
      kırpılma, eşlik sızıntısı; oda: sessiz + yankılı + TV/klima;
      cihaz/route: ≥3 telefon modeli, kablolu/Bluetooth.
   b) Alkış/ritim: farklı mesafe (30/60/100 cm), oda ve cihazda gerçek
      alkış; konuşma/öksürük yanlış tetikleme; kullanıcıların kendi tempo
      sapması (serbest tempo SD'si) — normalize kuralın eşiği için veri.
   c) Aralık testi: aynı kişide 2 tekrar (test–tekrar), öğretmen etiketli
      "gerçek aralık".
   d) Tekrar kartı: 4 hafta, ilk deneme doğruluğu (7 gün sonra) ve kart
      yükü; HLR katsayı kalibrasyonu için günlük loglar (yerel, izinli).
   e) Başarı ölçütleri (önceden): ±50 c doğru oranı, oktav hata oranı,
      yanlış-başarı ve çekimserlik oranları, kalite kapısı sonrası kullanılabilir
      kayıt oranı, jitter SD; geçme/kalma ölçütleri sonuca bakılmadan yazılır;
      eşik gevşetme YOK.
   f) Rıza, hak (lisans), anonim subjectGroup, silme, ham sesin cihazdan
      çıkmaması; hukuk metni TASLAK ve hukuk incelemesi bekler; çocuk/ergen
      ayrı aşama.
   g) Eğitimci etiketleme rubriği ve ikili etiketleme (uyum ölçüsü).
2. tool/benchmark/ altında analiz betiği iskeleti (pilot_analysis.dart): gelen
   manifest + WAV'ları AudioFixtureLoader ile okuyup RecordingPitchAnalyzer
   ve karşılaştırma algoritmalarıyla (detector_benchmark.dart'tan yeniden
   kullan) doğruluk/oktav/çekimserlik tablolarını üretir; veri yoksa açık
   hata verir, sahte veri üretmez. Küçük birim testle (geçici sentetik
   fixture, bunun gerçek veri olmadığı yorumla) şema yolunu doğrula.
3. Kayıt rehberi (katılımcı + yönetici için tek sayfa) ve manifest şablonu
   (alanlar: cihaz, route, oda, mesafe, etiket, rıza referansı).
4. Karar kapıları tablosu: hangi sonuç hangi önerinin (P0–P4 sabitleri,
   MPM/yin+fallback seçimi, tolerans 40/50 c, yanlış-ritim kabulü) kapısını
   açar; sonuç kötüyse algoritmayı izinsiz değiştirme yetkisi doğmaz.

KABUL: protokol belgesi, manifest şablonu, analiz iskeleti ve karar tablosu
hazır; format/analyze/test temiz; HİÇBİR sonuç uydurulmadı.

YAPMA: katılımcı çağrısı/mesaj gönderme, upload, ödeme, mağaza, rıza
uydurma, sentetik veriyi gerçek diye raporlama, eşikleri sonuca bakarak
gevşetme.
```
