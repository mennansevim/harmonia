# Vocalart — Eğitim yöntemi, hatırlatma ve tasarım araştırması

**Tarih:** 2026-11-03 · **Kapsam:** benzer sektördeki başarılı ürünlerin
öğretim yöntemi, tekrar/hatırlatma mekanikleri ve ilgi çekici tasarımı;
Vocalart'a entegre edilebilecek özellikler.
**Önceki çalışmalar:** [COMPETITOR_RESEARCH](./COMPETITOR_RESEARCH.md) (10 ürün),
[COMMERCIAL_BENCHMARK_2026-10](./COMMERCIAL_BENCHMARK_2026-10.md) (Simply,
Yousician, Duolingo), [FEATURE_BACKLOG](./FEATURE_BACKLOG.md) F01–F28. Bu belge
onları tekrar etmez; üç eksene odaklanır: **yöntem, hatırlatma, tasarım**.

> Kanıt düzeyi: ⭐⭐⭐ hakemli çalışma / şirketin yayımladığı deney ·
> ⭐⭐ şirket blogu, resmî yardım sayfası · ⭐ mağaza açıklaması, üçüncü taraf
> inceleme. Şirket deneylerinin etkisi Vocalart için garanti değildir; her
> öneri test edilecek hipotezdir. Hiçbir ekran, metin, ses ya da marka
> kopyalanmaz; yalnız işlev örüntüsü özgün tasarımla uyarlanır.

---

## 1. Yönetici özeti

1. **En büyük teknik boşluk aralıklı tekrar.** Vocalart her öğe için yalnız
   toplam doğru/deneme tutuyor (`ItemStat`); ne zaman görüldüğü yok. Duolingo
   unutma eğrisini öğe başına modelleyerek (yarı ömür regresyonu) Leitner
   kutularına göre hatayı yaklaşık yarıya indirdiğini yayımladı. Aralık, akor
   ve dizi tanıma bunun için ideal: ölçüm zaten deterministik.
2. **Hatırlatma tek ve sabit** (19:00, tek metin). Duolingo'nun yayımladığı
   bildirim algoritmasının asıl dersi ML değil, **iki basit kural**: yakında
   gösterilen metni cezalandır (bayatlamasın), yalnız uygun olana gönder
   (ör. serisi ≥3 olan). Bunu sunucusuz, yerel ve kural tabanlı yapabiliriz.
3. **Müzik pedagojisi "sesten sembole" der** (Kodály, Gordon). Derslerimiz
   zaten Dinle → Söyle → Ayırt et sırasında; eksik olan **iç duyuş (audiation)
   adımı** ve el işaretleri. Ucuz ve farklılaştırıcı.
4. **İlgi çekici tasarımın ölçülmüş kısmı küçük ama gerçek:** Duolingo seri
   animasyonlarının 7. gün aktifliği %1,7 artırdığını yazıyor. Kutlama anları
   ve görünür ilerleme (ana ekran widget'ı) en ucuz kazançlar.
5. **Koro tarafında rakipler hep aynı üçlüyü satıyor** (parti mix'i, kayıt,
   şef geri bildirimi). Bizim basamaklı destek azaltma (`PartStep`) ve şef
   ödevini kişisel rotaya bağlamamız farklılaşma.

**İlk 5 öneri (sıralı):** Tekrar kartları (§4.1) → akıllı yerel hatırlatma
(§4.2) → iç duyuş adımı (§4.3) → kutlama/ilerleme anları (§4.5) → koro
"provaya hazırım" akışı (§4.7).

---

## 2. İncelenen örnekler: ne yapıyorlar, neden işe yarıyor olabilir

### 2.1 Öğretim yöntemi

| Ürün / kaynak | Ne yapıyor | Kanıt | Vocalart için ders |
|---|---|---|---|
| **Duolingo — Half-Life Regression** ([ACL 2016](https://preview.aclanthology.org/fix_video/P16-1174.pdf), [blog](https://blog.duolingo.com/how-we-learn-how-you-learn)) | Her kelime için hatırlama olasılığı `p = 2^(−Δ/h)`; `h` yarı ömür, görülme sayısı ve doğru/yanlış geçmişinden tahmin edilir. Tekrar, unutmadan hemen önce planlanır. | ⭐⭐⭐ Leitner'e göre hata ≈ yarıya indi (şirketin raporu) | Aralık/akor/dizi öğeleri için doğrudan uygulanabilir; sunucu gerekmez. |
| **Duolingo — Birdbrain** ([blog](https://blog.duolingo.com/how-we-learn-how-you-learn), [2026 HLR takibi](https://proceedings.mlr.press/v339/ilidio26a.html)) | Hangi alıştırmanın geleceğini (zorluk) ayrı bir modelle seçer; HLR yalnız zamanlamayı belirler. | ⭐⭐ | Zamanlama ile zorluk seçimini ayrı tut: önce zamanlama. |
| **Anki — FSRS** ([açık benchmark tartışması](https://forums.ankiweb.net/t/update-simulator-for-fsrs-to-compare-with-ankis-built-in-scheduler/23793), [Anki SSS](https://docs.ankiweb.net/faqs/what-spaced-repetition-algorithm.md)) | Zorluk–kararlılık–geri getirilebilirlik modeli; açık kaynak benchmark'ta kullanıcıların çoğunda SM-2'den iyi. | ⭐⭐ (benchmark, hakemli değil) | İleride parametreli model; başlangıçta HLR-lite yeter. |
| **Melodics** ([nasıl çalışır](https://melodics.com/how-it-works), [özellikler](https://support.melodics.com/en/collections/3740818-melodics-features)) | "Bilinçli pratik": beceriyi adımlara böl, bölümü yavaşlat/döngüle, kursu ustalıkla geç. | ⭐ (satıcı) | Zor bölüm döngüsü bizde ezgide kısmi var; ritim/alkışa da gelsin. |
| **Yousician** ([şarkı yolu](https://support.yousician.com/hc/en-us/articles/360000550025-How-the-singing-learning-path-works), [inceleme](https://americansongwriter.com/yousician-review/)) | Görevler → seviyeler; şarkıyı bitirmek ilerletir, "eksik yıldızlar" için zayıf parçaya geri çağırır; anlık erken/geç geri bildirimi. | ⭐ | Geçmeyi kolay, ustalığı ayrı tut; zayıf öğeye geri çağırma. |
| **Kodály / Gordon MLT** ([Gordon, sesten görmeye](https://symposium.music.org/volume-31/forum-essays-1752877059/music-learning-theory-in-collegiate-music-education), [iç duyuş](https://ap-arts.be/en/research/audiation-based-learning)) | Ses → sembol → teori sırası; el işaretleri perdeyi bedene bağlar; iç duyuş: ses bittikten sonra zihinde duyma. | ⭐⭐ (pedagoji literatürü) | Dersin "Söyle" adımından önce **sessiz duy** adımı; el işareti kartları. |
| **Karışık (interleaved) çalışma** ([Carter & Grahn 2016](https://pmc.ncbi.nlm.nih.gov/articles/PMC4989027/)) | Klarnetçilerde karışık çalışma bloklu kadar/biraz daha iyi; katılımcılar karışığı daha faydalı bulup yine de bloklu çalışmayı **tercih etti**. Diğer çalışmalarda etki karışık. | ⭐⭐⭐ (küçük örneklem) | Yeni beceri bloklu, tekrar karışık; kullanıcıya "zor gelmesi normal" de. |

### 2.2 Hatırlatma ve alışkanlık

| Ürün / kaynak | Ne yapıyor | Kanıt | Ders |
|---|---|---|---|
| **Duolingo bildirim bandit'i** ([KDD 2020](https://research.Duolingo.com/papers/yancey.kdd20.pdf)) | Çok sayıda metin şablonu; yakında gönderileni cezalandırır ("recovering"), yalnız uygun olana gönderir ("sleeping": ör. seri ≥3). Ödül: bildirimden sonraki 2 saatte ders. | ⭐⭐⭐ DAU +%0,5, yeni kullanıcı tutma +%2 (şirket) | Kural tabanlı yerel sürüm: uygunluk + tazelik + kullanıcının alışık saati. |
| **Duolingo seri** ([blog](https://blog.duolingo.com/how-duolingo-streak-builds-habit), [podcast özeti](https://www.recall.it/summary/lennys-podcast/behind-the-product-duolingo-streaks-or-jackson-shuttleworth-group-pm-retention-team)) | Seri dondurma (2'ye kadar); seri animasyonları D7'yi %1,7 artırdı; "tek alıştırma seriyi uzatır" denemesi DAU'yu artırmadı. | ⭐⭐ | Affedici seri (dinlenme günü) evet; seriyi ucuzlatmak hayır. |
| **Ana ekran widget'ı** ([teardown](https://duolingo.deconstructoroffun.com/mechanics/streaks)) | Seri ve günün görevi uygulamayı açmadan görünür. | ⭐ (ölçüm yayımlanmamış) | Düşük riskli; native iş gerektirir. |
| **Melodics seri** ([sayfa](https://www.melodics.com/you)) | Seri günlük hedefe bağlı, oyun süresi kupaları. | ⭐ | Bizde günlük rota zaten hedef; seri ona bağlı kalsın. |

### 2.3 Koro uygulamaları

| Ürün | Ne yapıyor | Kanıt |
|---|---|---|
| [VocalCentric](https://apps.apple.com/app/id6739209305) | Parti stem'leri, kayıt, AI perde/ritim geri bildirimi, şef onayı | ⭐ |
| [cori](https://www.appbrain.com/app/cori-the-app-for-choirs/app.cori.android) | Kendi partini yükselten mix, söylerken AI geri bildirimi, takvim/RSVP | ⭐ |
| [Chorilo](https://www.chorilo.com/en/blog/digitale-chorprobe-probenmodus-chor-organisieren) | Şefin başlattığı canlı prova: nota tüm cihazlara eşzamanlı; yoklama; sonraki prova notu | ⭐ |
| [ChorusClass](https://choirgenius.com/choir-success/chorusclass), [ChoirKey](https://apps.apple.com/app/id1488600597) | Çok kanallı learning track, tempo | ⭐ |

Ortak örüntü: **mix + kayıt + şef notu**. Hiçbiri desteği basamaklı azaltıp
koristin "partini tek başına tutabiliyor musun?" sorusunu yapılandırmıyor
(gördüğümüz açıklamalarda). Bu bizim konumumuz.

---

## 3. Vocalart bugün: boşluk analizi

| Alan | Bugün kodda | Boşluk |
|---|---|---|
| Öğe hafızası | `ItemStat(correct, attempts)` toplam | **Zaman yok → aralıklı tekrar yok** |
| Günlük rota | Nefes → ders → ses adımı; dakikaya göre | Tekrar kartı adımı yok |
| Hatırlatma | Tek yerel bildirim, 19:00, sabit metin | Saat kişisel değil, metin tek, durum bilmiyor |
| Seri | Günlük seri, XP, seviye | Affedici gün yok; milestone kutlaması zayıf |
| Ders döngüsü | Dinle → Söyle → Ayırt et, %80 ustalık, karışık tekrar düğümleri | İç duyuş adımı yok; el işareti yok |
| Hata tekrarı | Oturum sonu "Yanlışları tekrar et" | Ertesi güne taşınmıyor |
| Ritim | Ritim tekrarı, aksak, alkış animasyonu | Alkışla birlikte dokunma ölçümü yok |
| Koro | Ödev, mix, `PartStep`, eşlikli kayıt, şef geri bildirimi | Basamak ilerlemesi kalıcı değil; ödev hatırlatması yok |
| Görünürlük | Uygulama içi | Widget yok |

---

## 4. Önerilen özellikler (mühendislik tasarımıyla)

Her öneri: **ne**, **nasıl** (veri/algoritma/ekran), **ölçüm**, **risk**,
**efor** (S ≤2 gün, M ≤1 hafta, L >1 hafta). Tümü AGENTS kurallarına
uygun: deterministik, sunucusuz, ölçülmeyen değer üretmez.

### 4.1 Tekrar kartları — öğe başına aralıklı tekrar · **P1 · M**

**Ne:** Bugün rotasına "Tekrar · 6 kart · 2 dk" adımı. Kart = tek algı
öğesi (ör. "Büyük 3'lü, çıkıcı", "Minör akor", "Dorian dizi").
**Nasıl:**
- Veri: `ItemMemory { halfLifeDays, lastSeen, reps, lapses }`, mevcut
  `stats` haritasının yanında; eski `ItemStat` korunur, göç gerekmez.
- Model (HLR-lite, deterministik): `p = 2^(−Δ/h)`. Doğru → `h ← min(h·2, 60)`;
  yanlış → `h ← max(h/2, 0,5)`, `lapses++`. Başlangıç `h = 1 gün`.
  Kart `p < 0,85` olunca vadesi gelir. Parametreler sürümlü sabit
  (`memoryModelVersion`), benchmark gelince ayarlanır.
- Seçim: vadesi gelenler `p` artan sırada, en çok 8; aynı aileden ardışık
  iki kart yok (karışık tekrar, §2.1).
- Kaynak: yalnız ölçülmüş algı cevapları (quiz). Mikrofon/söyleme kartları
  ölçüm kapıları açılana kadar girmez.
**Ölçüm:** 7 gün sonra aynı öğede ilk deneme doğruluğu (gecikmeli kontrol),
kart adımını tamamlama oranı. **Risk:** kart birikmesi → günlük üst sınır ve
"bugünlük yeter". **Neden önce bu:** ölçümümüz zaten güvenilir olan tek alan.

### 4.2 Akıllı yerel hatırlatma · **P1 · S–M**

**Ne:** Duolingo'nun iki kuralının sunucusuz sürümü.
- **Uygunluk:** her şablonun koşulu var — vadesi gelen kart ≥3; seri ≥3;
  koro ödevinin son günü ≤2; aralık ölçülmedi; 3 gündür girilmedi.
- **Tazelik:** son 7 günde gönderilen şablonun ağırlığı düşer; aynı metin
  art arda gelmez.
- **Saat:** son 14 oturumun başlangıç saatlerinin medyanı − 30 dk;
  veri yoksa kullanıcının seçtiği saat.
- **Durma kuralı:** 7 gün üst üste açılmazsa haftada bire iner ve bunu söyler
  ("Seni rahatsız etmeyelim, haftada bir hatırlatacağız").
**Nasıl:** `PracticeReminderCoordinator` her uygulama kapanışında ertesi
bildirimi yeniden planlar (yerel `flutter_local_notifications` zaten var).
Şablonlar `tr()` ile iki dilli, suçluluk dili yok.
**Ölçüm:** bildirimden sonraki 2 saatte oturum (yerel sayaç; gönderimsiz).
**Risk:** iOS arka plan sınırları → planlama yalnız uygulama açıkken yapılır.

### 4.3 İç duyuş adımı ve el işaretleri · **P1 · S**

**Ne:** Ders "Söyle" adımından önce **Duy → Sus → İçinden söyle → Söyle**:
referans çalar, 2 sn sessizlik (ekranda nefes halkası), sonra söyleme.
Solfej kartlarına Curwen el işareti çizimleri (özgün SVG).
**Neden:** Kodály/Gordon'un ortak ilkesi; sınavda ezgi tekrarı tam bu beceri.
**Ölçüm:** ezgi tekrarı ölçümü açılınca iç duyuşlu/duyuşsuz A/B.
**Risk:** eğitimci onayı gerekir (EDU kapısı).

### 4.4 Affedici seri ve haftalık hedef · **P1 · S**

**Ne:** Haftada 1 otomatik **dinlenme günü** (satın alınmaz); seri milestone
(3, 7, 14, 30 gün) kutlaması. Duolingo'nun bulgusu: seriyi ucuzlatmak (tek
soru yeter) işe yaramadı → seri yine günlük rotanın bir adımıyla uzar.
**Risk:** yok denecek kadar az; GROW-01b haftalık hedefle birleşir.

### 4.5 Kutlama ve ilerleme anları · **P2 · S**

**Ne:** Oturum sonunda kısa animasyon (alkış animasyonu yeniden kullanılır),
ustalık %80'i geçince beceri rozeti, seviye atlayınca tam ekran an.
Haptik zaten var (HAPTIC-01).
**Kanıt:** Duolingo seri animasyonu D7 +%1,7 (⭐⭐). **Kural:** puan
uydurulmaz; kutlanan şey yalnız gerçekten ölçülen veya tamamlanan iş.

### 4.6 Ana ekran widget'ı · **P2 · M**

**Ne:** Seri, bugünkü rota adımı, vadesi gelen kart sayısı, en yakın koro
teslimi. iOS WidgetKit + Android Glance (`home_widget` paketi).
**Risk:** native kod ve yeni bağımlılık; kullanıcı onayı gerekir.

### 4.7 Koro: "provaya hazırım" akışı · **P2 · M**

**Ne:** Her ödev parçası için `PartStep` ilerlemesi kalıcı olur; korist
5. basamakta ("Partin yok") kendini işaretler → şef panosunda parti başına
"hazır" sayısı. Teslim gününden 2 gün önce §4.2 hatırlatması.
**Neden:** rakiplerin hiçbirinde basamaklı hazırlık yapısı görmedik.
**Risk:** öz-bildirim ölçüm değildir; şef ekranında öyle etiketlenir.

### 4.8 Ritim: alkışla birlikte dokun · **P2 · M**

**Ne:** Alkış animasyonu ikinci turda sessizleşir, kullanıcı dokunur;
mevcut ritim değerlendiricisi erken/geç gösterir (Yousician'ın anlık
erken/geç geri bildirimi). Gecikme kalibrasyonu (AUDIO kapısı) önkoşul.

### 4.9 Daha sonra (P3)

- Şefin başlattığı canlı prova modu (Chorilo örüntüsü) — sunucu gerekir.
- Aralığa göre ton değiştirme (Simply Sing) — aralık ölçümü güvenilir
  olunca; Simply Sing için de "aralık tespiti hatalı" şikâyeti var (⭐).
- Normalize, gönüllü lig — F15 kurallarıyla.

---

## 5. Yapmayacaklarımız

- Suçluluk/korku dilli bildirim, sahte aciliyet, geri sayım.
- Ücretli seri kurtarma.
- Ölçülmemiş beceriye yıldız/puan; demo verisinden "gelişim".
- Ses aralığı genişliğini ödüllendiren yarış.
- Rakip ekran, metin, maskot veya ses kopyası.

## 6. Ölçüm planı (yerel, gönderimsiz)

| Özellik | Birincil metrik | Koruyucu metrik |
|---|---|---|
| Tekrar kartları | 7 gün sonraki ilk deneme doğruluğu | Günlük kart süresi ≤3 dk |
| Hatırlatma | Bildirim → 2 saat içinde oturum | Bildirimi kapatma oranı |
| Seri/kutlama | D7, haftalık aktif gün | Oturum başına gerçek soru sayısı |
| Koro hazır | Teslimden önce "hazır" oranı | Şefin "hazır ama değil" notu |

Canlı analitik yok; pilotta rızayla toplanmadan bu metrikler "ölçüldü"
sayılmaz.

## 7. Önerilen sıra

1. **Sprint 1:** 4.1 tekrar kartları (domain + rota adımı + testler), 4.4
   dinlenme günü.
2. **Sprint 2:** 4.2 akıllı hatırlatma, 4.3 iç duyuş adımı (eğitimci
   incelemesine taslak).
3. **Sprint 3:** 4.5 kutlamalar, 4.7 koro hazır akışı.
4. **Sonra:** 4.6 widget (native onay), 4.8 dokunarak alkış (gecikme
   kalibrasyonu sonrası).
