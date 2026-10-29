# Harmonia — Dış öneri değerlendirmesi ve 90 günlük ürün yol haritası

**Tarih:** 2026-10-29 · **Girdi:** başka bir LLM'in rakip analizi, konumlandırma,
gelir modeli ve 90 gün planı (kullanıcı tarafından yapıştırıldı).
**Yöntem:** Her öneri repodaki güncel kod (`lib/trainer/`), ADR'ler,
[CURRENT_ROADMAP](./CURRENT_ROADMAP.md), [RELEASE_READINESS](./RELEASE_READINESS.md),
[PRODUCT_SPEC](./PRODUCT_SPEC.md) ve [COMMERCIAL_BENCHMARK](./COMMERCIAL_BENCHMARK_2026-10.md)
ile karşılaştırıldı. Rakip özellik/fiyat iddiaları bu oturumda yeniden
doğrulanmadı; ürün kararı olarak değil hipotez olarak taşınır.

Bu belge plan; kod değişikliği değildir. Gelir garantisi yoktur.

---

## 1. Kısa hüküm

Önerinin **yönü doğru, takvimi ve gelir hesabı düzeltilmeli.**

- **Konumlandırma (kabul):** “Türkçe konservatuvar ve koro hazırlığı için
  günlük, açıklanabilir kulak–ses antrenmanı” mevcut ADR-013/015/032/033 ile
  zaten uyumlu. Genel şarkı uygulamasına dönmeme ve katalog yarışına girmeme
  kararı (ADR-012, F19) korunur.
- **En değerli yeni fikirler:** süreye göre ölçeklenen *tek rota*, mikrofonsuz
  ve ölçümsüz *Hazırla (nefes)* adımı, karışan çifte yeni örneklerle *kısa
  tekrar*, iki katmanlı sonuç ekranı, gün sayılı koro paketleri.
- **Yanlış/eksik olanlar:** gelir hesabında KDV yok; ana ekran sadeleştirmesi
  betadan *sonraya* konmuş (beta eski ekranı test eder); 20–30 ödeyenle üç fiyat
  testi istatistiksel olarak anlamsız; dört dış servis aynı anda öneriliyor ve
  mevcut “veri toplamıyoruz” gizlilik beyanını bozuyor.

## 2. Önerideki durum iddiaları — repo ile karşılaştırma

| İddia | Repo gerçeği | Sonuç |
|---|---|---|
| 1.004 test, 6/6 simülatör yolculuğu | `IMPLEMENTATION_LOG` E2E-01: 1004 test, 6/6 iPhone 17 Pro simülatörü | Doğru |
| Gerçek telefon, insan sesi benchmark'ı, içerik onayı, hukuk–mağaza kapıları açık | RELEASE_READINESS §2–4 aynısını söylüyor | Doğru |
| Ana ekran “özellik dolabı”: beş eğitmen, Koro, deneysel etiketler arasında seçim | TRAINER-02 sonrası **Bugün** sekmesinde zaten tek “Günün planı” kartı + “Derse başla” var (`lib/trainer/home/home_shell.dart`). Altında 5 beceri satırı, Koro sekmesinde 3 `DENEYSEL` kart | **Kısmen eski.** Tek rota iskeleti var; eksik olan süreye göre ölçeklenmesi ve beceri listesinin ikincil olması |
| 3/12/20 dk seçenek yok | Onboarding 3/5/10/15/20 dk seçtiriyor, `dailyMinutes` saklanıyor; ama plan hep “1 ders + 1 koro adımı”, süre yalnız etiket | **Doğru tespit:** seçilen süre planı değiştirmiyor |
| Hata sonrası kısa tekrar yok | Eski kabukta RETRY-01a/b/c vardı; `lib/trainer/` ikizinde yok, yalnız `accuracy < 0.7` ders `review` bayrağı | Doğru (trainer için) — taşınmalı |
| Nefes çalışması | Hiç yok | Yeni |
| İlk değerden sonra paywall, sahte indirim yok | F16 ve ADR-014 zaten bunu söylüyor | Mevcut kararla aynı |
| “Etkileşimli taslak” | Yapıştırılan metinde taslak yok | Değerlendirilemedi |

## 3. Öneri bazında değerlendirme

**K** kod · **Ka** kullanıcı kararı · **D** dış kaynak (cihaz, insan, hesap, hukuk).

### Kabul (doğrudan yol haritasına)

| # | Öneri | Neden | Koşul / sınır |
|---|---|---|---|
| A1 | Süreye göre tek rota (3 / 12 / 20 dk) | Onboarding'deki süre seçimi bugün bir şey değiştirmiyor; en ucuz ve görünür değer artışı | Deterministik plan bileşeni; süre tahmini “yaklaşık” etiketli. 3/5/10/15/20 → 3/12/20 sadeleştirmesi **Ka** |
| A2 | Hazırla → Duy → Söyle akışı | Mevcut Dinle → Söyle → Ayırt et (ADR-034) ile çakışmaz; günlük rotanın üst kabuğu olur | Söyle adımı TRAINER-04b gibi isteğe bağlı ve puansız kalır |
| A3 | Hazırla: görsel/haptik nefes döngüsü, kullanıcının başlatıp durdurduğu “sss” süresi, zorlanmada dur metni | Rakiplerde değerli, ölçüm gerektirmiyor | **Hiçbir nefes metriği yok**: “destek %”, diyafram, kapasite, mikrofonla nefes algılama yok. Süre öz-bildirimdir, beceri/mastery'ye yazılmaz. Metin eğitimci onayına (EDU) gider |
| A4 | Karışan çifte yeni örneklerle 3 soruluk kısa tekrar + ertesi gün kontrol | RETRY-01 + LEARN-03b kalıcılık kontrolünün trainer'a taşınması | Aynı soruyu ezberletmez; kısa tekrar mastery kanıtı sayılmaz, ertesi gün kontrolü sayılır |
| A5 | Sonuç ekranı: tek cümle özet + açılır kanıt (kaynak, tolerans, geçersiz kayıt, yanlış oktav) | ADR-016 ve REVIEW-01 ile tam uyumlu | Kanıt katmanı gerçek ölçülmeyeni “ölçülmedi” gösterir |
| A6 | Paywall sırası: ilk sonuç → kısa tekrar → yarının planı → teklif; şeffaf fiyat/iptal/restore | F16 ile aynı | Güvenlik ve ölçüm kalitesi ücretle açılmaz |
| A7 | Ham sesi varsayılan cihazda tutmak | Mevcut mimari zaten böyle (kayıt analizden sonra silinir) | Plus upload'u ayrı onay + DATA-03 sunucu kapısı |

### Uyarla (fikir doğru, kapsam/sıra değişmeli)

| # | Öneri | Uyarlama |
|---|---|---|
| U1 | Koro paketleri (14/21/10/30 gün) | Önce **paket şeması + 1 paket**: “Aksak ritme giriş” (desenler `aksak_patterns.dart`'ta mevcut). Diğerleri eğitimci içeriği geldikçe. “Çok sesli duyma” piyano kayıtlarına bağlı (AGENTS). “Konservatuvar hazırlığı 30 gün” kabul garantisi dili taşımaz |
| U2 | Haftalık önce/sonra kaydı (Vocal Image) | Yalnız **kendin dinle** karşılaştırması, cihazda, açık izinle; puan/“gelişme %” yok. Faz 3'e |
| U3 | Ana ekran sadeleştirmesi 31–60. güne | **Betadan önceye** alınmalı: beta kullanılabilirlik oturumları yeni değer önerisini test etmeli, eski ekranı değil |
| U4 | RevenueCat + Supabase + PostHog + Crashlytics | Tek tek ADR. Sıra: (1) Crashlytics *veya* Sentry — beta için yeterli, (2) RevenueCat — ödeme fazında, (3) analitik — beta funnel'ı için yerel `ProductEvent` + açık rıza, (4) Supabase — hesap/sync gerçekten gerekince. Her biri PrivacyInfo, App Store etiketi, Play Data safety ve KVKK metnini değiştirir; veri bölgesi (AB) seçilmeli |
| U5 | Üç fiyat × üç yıllık fiyat testi 20–30 ödeyenle | Bu örneklemde fark ölçülemez. Yerine: beta içinde fiyat algısı anketi (Van Westendorp tipi) + **tek** başlangıç fiyatı + 2–3 ayda bir sıralı değişiklik |
| U6 | Plus 799–999 TL | PRODUCT_SPEC: eğitimci maliyeti ve kullanım oranı ölçülmeden fiyatlanamaz. Önce **ücretsiz** 20 kişilik HUM pilotu, dakika/maliyet ölçümü, sonra fiyat |
| U7 | 30 günde “30 günlük özgün müfredat” | İçerik darboğazı eğitimci; 30 günde yazılıp onaylanması gerçekçi değil. Eğitimci arayışı **bugün** başlamalı; betada mevcut taslak müfredat “taslak” etiketiyle kalır |

### Ertele

- Sunucu tarafı AI koçu (AI-01/03) — öneriyle aynı görüş: ilk ücretli sürümde zorunlu değil.
- Aile/çoklu öğrenci (F28), sosyal/lig (F15/F17) — önceki karar korunur.
- Cihazlar arası sync — tek cihaz + mevcut pano taşıma (DATA-03) beta için yeter.

### Reddet

- Nefes/rezonans/göğüs–kafa sesi/zorlanma “algılama” ve klinik çağrışımlı metrikler.
- Güven, yaş, kişilik, “profesyonellik” gibi öznel AI skorları.
- Sahte indirim, geri sayım, kontenjan baskısı.
- Lisanslı şarkı kataloğu ile yarış.

## 4. Gelir hesabının düzeltilmesi

Önerideki hesap KDV'yi atlıyor. Türkiye mağaza fiyatı KDV dahildir; komisyon
KDV hariç tutar üzerinden düşer (oranlar mağaza ve vergi danışmanıyla
doğrulanmalı — PRODUCT_SPEC §formül).

| Kalem | Öneri | Düzeltilmiş |
|---|---:|---:|
| Ağırlıklı brüt (%60 yıllık 1.990 / %40 aylık 249) | 199 TL | 199 TL |
| KDV %20 hariç | — | 166 TL |
| Mağaza %15 sonrası | 169 TL | 141 TL |
| Altyapı/iade/destek rezervi | −15 TL | −15 TL |
| **Abone başı aylık katkı** | **154 TL** | **≈126 TL** |
| 50.000 TL için gereken aktif ödeyen | ~325 | **~400** |
| 60.000 TL için | ~390 | **~475** |

Gelir vergisi, edinim maliyeti ve eğitimci maliyeti bunlara dahil değildir.

**Pazar büyüklüğü riski:** 500 ödeyen × %5–7 dönüşüm ≈ 7–10 bin MAU. Türkçe,
konservatuvar/koro odaklı niş için bu varsayım doğrulanmadı. Betadan önce
bekleme listesi ve koro/konservatuvar hazırlık kurumlarıyla 2–3 ön görüşme
talebi ölçmenin en ucuz yolu. Bu kanıt gelmeden fiyat kesinleşmez.

Önerinin doğru kısmı: %5–6 aylık churn ile 500 ödeyeni korumak için ayda
25–30 yeni ödeyen gerekir; Small Business/abonelik %15 komisyon için kayıt
şarttır.

## 5. Yol haritası

Takvim 2026-11-02 haftası başlar. Her faz, çıkış kapısı geçilmeden bitmiş
sayılmaz. Kod işleri (K) paralel ilerleyebilir; D işleri takvimi belirler.

### Faz 0 — Kararlar ve dış iş başlangıcı (hemen, 1 hafta)

Kod değil ama tüm takvimi bunlar kilitliyor:

| ID | İş | Tür |
|---|---|---|
| GTM-00a | Uygulama kimliği (`com.harmonia.harmonia` geçici → kalıcı alan adı) | Ka |
| GTM-00b | Apple Developer + Play Console hesabı, Android keystore | Ka/D |
| GTM-00c | Eğitimci arayışı: içerik onayı (EDU-01) + Plus pilotu (HUM) için 1 kişi | D |
| GTM-00d | Konumlandırma cümlesinin onayı (bu belgedeki §1) | Ka |
| GTM-00e | Bekleme listesi / kurum ön görüşmesi (talep ölçümü) | D |
| GTM-00f | Hata izleme servisi seçimi (U4 sıra 1) | Ka |

### Faz 1 — Odaklı beta sürümü (Kasım, ~4 hafta, K ağırlıklı)

Amaç: kapalı betaya **yeni değer önerisiyle** girmek.

| ID | İş | Kabul kriteri |
|---|---|---|
| HOME-02 | Süreye göre tek rota: 3 dk (Duy), 12 dk (Hazırla + Duy + kısa tekrar + isteğe bağlı Söyle), 20 dk (+ Koro adımı). Beceri listesi “Tüm beceriler” altına iner | Deterministik plan bileşeni testli; seçilen süre planı gerçekten değiştirir; süre “yaklaşık” |
| PREP-01 | Hazırla adımı: görsel + haptik nefes döngüsü, kullanıcı-zamanlı “sss”, dur metni | Mikrofon açılmaz; hiçbir sayı beceri/mastery/history'ye yazılmaz; “hareket azalt” ve haptik kapalı modları |
| RETRY-02 | Trainer'da karışan çift → 3 yeni örnekli kısa tekrar; ertesi gün kalıcılık kontrolü | Tekrar puanı mastery'ye yazmaz; ertesi gün kontrolü yazar; aynı soru tekrarlanmaz |
| RESULT-02 | Ders sonu: tek cümle + tek sonraki eylem; açılır kanıt katmanı | Ölçülmeyen “ölçülmedi”; mikrofon tanısalı ayrı kaynak etiketli |
| OPS-01b | Seçilen hata izleme servisi + gizlilik manifesti/etiket güncellemesi | Yalnız GTM-00f kararından sonra |
| BETA-01 | Yerel funnel olayları (onboarding bitti, ilk ders, ilk tekrar, D1/D7 dönüş) — gönderim yok, kullanıcı kopyalayıp paylaşır | Açık rıza; ses/kişisel veri içermez |

**Çıkış kapısı (D):** gerçek iPhone + orta/düşük Android'de mikrofon reddi →
Ayarlar, kulaklık/Bluetooth, bildirim, offline turu (CAL-02, SHELL-02,
REM-01c); VoiceOver/TalkBack kısa turu; TestFlight internal / Play internal
yükleme (**ayrı kullanıcı yetkisi**).

### Faz 2 — Kapalı beta ve içerik (Aralık–Ocak, ~6 hafta, D ağırlıklı)

| ID | İş | Tür |
|---|---|---|
| UXR-01 | 5 öğrenci + 1 eğitimci kullanılabilirlik oturumu, HOME-02 akışı üzerinde | D |
| EDU-01 | Taslak müfredat + Hazırla metinleri + ilk koro paketi eğitimci onayı | D |
| PACK-01 | Koro paketi şeması (gün sayısı, içerik sürümü, taslak/onaylı durumu) + “Aksak ritme giriş · 10 gün” | K (içerik D) |
| BENCH-01 / VAD-01 | İzinli etiketli insan sesi kayıtları; geçmeden tek ses puanı açılmaz | D |
| PIANO-01 | Kullanıcının 2/3/4 sesli kayıtları gelince hak/nota/oktav/kalite QA | D |
| LAUNCH-01 | Gizlilik politikası, KVKK, yaş/öğrenci değerlendirmesi, mağaza metinleri | D |
| PRICE-00 | Beta içinde fiyat algısı anketi (para alınmaz) | K/D |

**Çıkış kapısı:** 20+ beta kullanıcısında D7 dönüş ve “yarın ne yapacağımı
biliyorum” anlaşılırlığı ölçüldü; eğitimci içerik onayı en az ilk 2 hafta için
var; hukuk metinleri yayınlanabilir.

### Faz 3 — Ücretli pilot hazırlığı (Şubat–Mart, ~6 hafta)

| ID | İş | Kabul / sınır |
|---|---|---|
| PAY-01–03 | RevenueCat ADR, ürünler, sandbox satın alma, restore, iptal, grace period, offline entitlement | Canlı ödeme ayrı onay |
| PAY-04 | Paywall: A6 sırası; ücretsiz kapsam, deneme bitişi, yenileme, aylık/yıllık toplam görünür | Sahte indirim/geri sayım yok |
| GROW-02 | Haftalık rapor + isteğe bağlı “kendin dinle” önce/sonra kaydı (U2) | Puan/“%gelişme” yok, ses cihazda |
| HUM-07 | 20 kişilik **ücretsiz** Plus pilotu; eğitimci dakikası ve maliyeti ölçülür | Fiyat bundan sonra |
| PACK-02 | Eğitimci içeriği geldikçe “Koro seçmesine hazırlık · 14 gün”, “Partini koru · 21 gün” | Kabul garantisi dili yok |

**Çıkış kapısı:** sandbox'ta tüm abonelik yaşam döngüsü cihazda test edildi;
tek başlangıç fiyatı (öneri: 249 TL / 1.990 TL test noktası) kullanıcı kararı;
Plus fiyatı HUM-07 verisiyle.

### Faz 4 — Ücretli erken erişim (Nisan+)

100–200 kullanıcı, tek fiyat, aylık churn ve deneme→ödeme oranı izlenir.
Genel yayın kararı ancak §6 kapıları kapandığında.

## 6. Genel ücretli yayın için kapatılmamış kapılar

Ücretli genel yayın, aşağıdakiler kapanmadan yapılmaz (AGENTS + RELEASE_READINESS):

1. Gerçek cihaz matrisi (iOS + düşük/orta Android, route'lar).
2. Mikrofonla puan verilecekse BENCH-01/VAD-01; verilmeyecekse mikrofon
   özellikleri “deneysel/tanısal” etiketiyle kalır ve pazarlanmaz.
3. Eğitimci onaylı içerik (en az satılan paketlerin tamamı).
4. Hukuk, gizlilik, yaş beyanı, mağaza metinleri.
5. Sandbox abonelik yaşam döngüsü ve restore.

## 7. Kullanıcıdan beklenen kararlar

1. §1 konumlandırma cümlesi onayı.
2. Süre seçenekleri 3/12/20'ye sadeleşsin mi (bugün 3/5/10/15/20)?
3. Hata izleme servisi (Crashlytics / Sentry / yok).
4. Kalıcı uygulama kimliği ve mağaza hesapları.
5. Eğitimci adayı.
6. Faz 1 kod işlerine HOME-02 → PREP-01 → RETRY-02 → RESULT-02 sırasıyla başlanması.
