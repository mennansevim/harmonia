# Ses koçu uygulamaları — ortak ekran şablonu (4 Kasım 2026)

**Kapsam:** Masa başı inceleme. Simply Sing, Vocal Image, Vocalista,
Yousician (Singers), Singing Carrots, SingSharp, Smule. Uygulamalar
indirilip ücretli hesapla denenmedi. Ekran akışları ağırlıkla
[ScreensDesign](https://screensdesign.com) kayıtlarından (çoğu ekran Pro
kilitli, yalnız önizlemeler görüldü), mağaza sayfaları ve yardım
belgelerinden çıkarıldı. Doğruluk/öğrenme iddiaları satıcı kaynaklıdır,
bağımsız kanıt sayılmaz. Görseller lisanslı değil; repoya kopyalanmadı,
yalnız bağlantı verildi.

## 1. Ortak şablon (tree)

En başarılı örneklerin (Simply Sing, Vocal Image, Vocalista) neredeyse
aynı iskeleti izlediği görülüyor:

```
Ses koçu uygulaması
├── 0. Açılış
│   ├── Splash / yükleme (ipucu metni)
│   ├── ATT izni (iOS)
│   └── Karşılama: değer önerisi + "Başla" / "Giriş yap"
│
├── 1. Onboarding quiz (6–42 adım; uzun = daha çok kişiselleştirme hissi)
│   ├── Nereden duydun? (atıf anketi)
│   ├── Deneyim seviyesi ("yeni başlıyorum" … "ileri")
│   ├── Özgüven / zorluklar ("nefesim yetmiyor", "detone oluyorum")
│   ├── Hedefler (hobi, sahne, sınav, konuşma)
│   ├── Tür + sevilen sanatçılar (arama ile)
│   ├── Ses tipi / ses yaşı (biliyorsa seç)
│   ├── Ara ekranlar: sosyal kanıt, basın, "%X kişi gibi sen de…" pekiştirme
│   └── Hesap oluşturma (çoğunlukla aralık testinden önce)
│
├── 2. "Aha" anı: ses aralığı testi
│   ├── Giriş + mikrofon izni modalı
│   ├── Okuma / mırıldanma / en pes–en tiz glide görevleri
│   ├── Hata & tekrar ekranı (ses algılanmadı, çok gürültü)
│   ├── Elle aralık seçme kaçış yolu (Vocalista: kullanıcılar testte takılıyor)
│   └── Sonuç: ses tipi etiketi (ör. "Alto") + aralık klavyesi
│
├── 3. Kişisel plan & dönüşüm
│   ├── "Planın hazırlanıyor" / AI koç özeti (sohbet balonu tarzı)
│   ├── Kişisel kanca: "Bazı şarkılar aralığının dışında → hepsini uyarla"
│   ├── Bildirim izni (hatırlatma vaadiyle)
│   └── Paywall
│       ├── Soft paywall (kapatılabilir), 7 gün deneme → yıllık
│       ├── Yıllık = aylık fiyat olarak gösterim, "%35 indirim" rozeti
│       ├── Deneme takvimi ("2. gün hatırlatırız, 7. gün ücret")
│       └── Uygulama içi kilitler: "Unlock Pro", şarkı başına "Get Full Access"
│
├── 4. Ana sekmeler (2–4 sekme; Simply Sing yalnız Home + Profile)
│   ├── Ana sayfa / Bugün
│   │   ├── Günlük ısınma kartı (tek büyük CTA)
│   │   ├── Seri (streak) göstergesi
│   │   ├── Kişisel öneriler (plan sıradaki ders)
│   │   └── Kategori karuselleri (şarkı / egzersiz)
│   ├── Kütüphane / Keşfet
│   │   ├── Egzersiz kataloğu (nefes, pitch, aralık, teknik)
│   │   └── Şarkı ızgarası + arama + sanatçı sayfası (ses tipiyle)
│   ├── İlerleme
│   │   ├── Grafikler (yeni kullanıcıda "henüz yeterli veri yok" boş durumu)
│   │   ├── Vokal analiz radar grafiği (pitch, ritim, nefes, aralık…)
│   │   └── Başarımlar / seviye
│   └── Profil
│       ├── Çoklu profil (aile kullanımı)
│       ├── Kayıtlarım (boş durum)
│       ├── Abonelik, yardım, destek
│       └── Ayarlar (bildirim, mikrofon, transpoze)
│
├── 5. Egzersiz / şarkı döngüsü (çekirdek)
│   ├── Önizleme: ne yapılacak + örnek ses / koç videosu
│   ├── Canlı ekran
│   │   ├── Kayan pitch çizgisi hedef nota bantları üzerinde
│   │   ├── Sözler / hece (karaoke), duraklat
│   │   └── Anlık renk geri bildirimi (isabet/pes/tiz)
│   ├── Sonuç
│   │   ├── Skor (yıldız/yüzde) + metrik kırılımı
│   │   ├── Kısa yorum ("Nefesin kopuk" gibi tek odak)
│   │   └── Örnekle karşılaştır / kaydı dinle / tekrar dene
│   └── Ödül: seri arttı, seviye atladı animasyonu
│
└── 6. Tutma (retention)
    ├── Seri + seri dondurma
    ├── Günlük hatırlatma bildirimi
    ├── Topluluk geri bildirimi (Vocal Image "Voice Arena", Smule düet)
    └── Teorik mini dersler (mekanizma açıklaması)
```

## 2. Uygulama bazında notlar

| Uygulama | Odak | Öne çıkan desen | Zayıf nokta (kaynaklarda) |
|---|---|---|---|
| Simply Sing | Şarkı önce | Aralık testi → "şarkıları aralığına uyarla" upsell; radar analiz | Aralık tespiti hatalı yorumları |
| Vocal Image | Konuşma koçu | 42 adımlı quiz, erken soft paywall, AI koç sohbet özeti, Voice Arena | Uzun program yerine onboarding hissi |
| Vocalista | Egzersiz önce | Kayan pitch grafiği, nefes skoru, elle aralık seçimi | Aralık testinde takılma |
| Yousician | Müfredat | Öğretmen videolu giriş, seviye atlama, not renk ipuçları | — |
| Singing Carrots | AI koç | Ücretsiz aralık testi, oturum sonrası geri bildirim | Kaynaklar satıcının kendi blogu |
| SingSharp | Nefes/teknik | Nefes algılama | Şarkı kütüphanesi küçük |
| Smule | Karaoke/sosyal | Düet, topluluk | Eğitim/ilerleme yok |

## 3. Ekran tasarımları (dış bağlantılar)

Simply Sing ([tüm akış](https://screensdesign.com/apps/simply-sing-my-singing-app/?vs=134355)):

- Karşılama: <https://media.screensdesign.com/avs-pp-640/604b55389aa5413c8f98d7a6ee75e212.webp>
- Özgüven quiz: <https://media.screensdesign.com/avs-pp-640/1751b305a9e5495baca1864572af7a2d.webp>
- Zorluklar quiz: <https://media.screensdesign.com/avs-pp-640/aea6ab8e27af4f3e90b84bd244a3d0b8.webp>
- Hedefler: <https://media.screensdesign.com/avs-pr-640/1d0e6c939a784d16b6dcdfce7147eeb9.webp>
- Ses tipi seçimi: <https://media.screensdesign.com/avs-pr-640/58c4f75b9f344e3a95ca8895b5cf597d.webp>
- Aralık testi girişi: <https://media.screensdesign.com/avs-pr-640/d06a3a634872470a91f2a1599655c414.webp>
- Mikrofon izni: <https://media.screensdesign.com/avs-pr-640/dd8ccc70e68f41b483bfb1a5816c5b04.webp>
- Aralık sonucu ("Alto"): <https://media.screensdesign.com/avs-pr-640/f3a6b6c1efd24f65b9e77157b5eaa771.webp>
- "Bazı şarkılar aralığının dışında": <https://media.screensdesign.com/avs-pr-640/3c066d2677e54d7c8bf091c3989b767f.webp>
- Bildirim izni: <https://media.screensdesign.com/avs-pr-640/5e4c0402819b482389955ba515d7771c.webp>
- Paywall (aylık/yıllık): <https://media.screensdesign.com/avs-pr-640/8f2e1948df794c8f8cc1cfebe24ca142.webp>
- Ana sayfa (günlük ısınma + karuseller): <https://media.screensdesign.com/avs-pr-640/864dca252a2441198964c4d532e1aec9.webp>
- Şarkı pratiği (sözler): <https://media.screensdesign.com/avs-pr-640/1bbf265fea8e462ab50d8f84e8aaac08.webp>
- Canlı pitch geri bildirimi: <https://media.screensdesign.com/avs-pr-640/c93e158cdabb423d97aa1fd38d170a01.webp>
- Vokal analiz radarı: <https://media.screensdesign.com/avs-pr-640/37980351be1e4dfc9b94012ef2f5344a.webp>
- Transpoze seçimi: <https://media.screensdesign.com/avs-pr-640/28077e7196b64d859f604ab32b5b58f3.webp>
- Seri ilerlemesi: <https://media.screensdesign.com/avs-pr-640/650c19834bbd4e708296313fbde7732a.webp>
- Seviye atlama: <https://media.screensdesign.com/avs-pr-640/4e4291540ebb4ecd8e8517f76d5c0317.webp>
- Profil/ayarlar: <https://media.screensdesign.com/avs-pr-640/d4fa4edb831344f2b4e17099d257a203.webp>

Vocal Image ([akış](https://screensdesign.com/showcase/vocal-image-ai-voice-coach)) — önizlemeler
ekranlarla eşlenmemiş:
[01](https://media.screensdesign.com/avs-pp-640/6cd48ee8f90b4c7285b6df799a4aba99.webp) ·
[02](https://media.screensdesign.com/avs-pp-640/1ace9ec94e314d438f0e430ab3606ad4.webp) ·
[03](https://media.screensdesign.com/avs-pp-640/44a255a3e1364e1e94b9bba124a9567a.webp) ·
[05](https://media.screensdesign.com/avs-pp-640/d74a3777be804a06875bf105c09e887b.webp) ·
[06](https://media.screensdesign.com/avs-pp-640/44646c43b203447ab12e45c060c64b68.webp) ·
[07](https://media.screensdesign.com/avs-pp-640/ddccaf2264f5405b867ca67e9ad12ec9.webp)

Vocalista ([akış videosu](https://screensdesign.com/showcase/vocalista-vocal-training)) —
statik görsel yok; canlı pitch, skor, nefes geri bildirimi videoda.

Yousician: [Lazyweb ekran kütüphanesi](https://www.lazyweb.com/company/yousician)
(çoğu üyelikle), [singers başlangıç rehberi](https://support.yousician.com/hc/en-us/articles/360000538749-Get-started-with-Yousician-for-Singers).

Mağaza sayfaları: [Vocal Image](https://apps.apple.com/us/app/vocal-image-ai-voice-coach/id1535324205),
[Simply Sing](https://apps.apple.com/us/app/id1592900217), [Smule](https://apps.apple.com/app/id509993510).

## 4. Vocalart için çıkarımlar (hipotez, karar değil)

- **Aha anı erken:** Aralık testi onboarding içinde, paywall'dan önce.
  Vocalart'ta bu ölçüm deterministik olmalı; algılanmayan/geçersiz
  ölçüm sonuç üretmemeli, yanlış oktav başarı sayılmamalı (AGENTS kuralı).
  Elle aralık seçimi kaçış yolu olarak kalsın ve "ölçülmedi" durumuyla
  işaretlensin.
- **Tek CTA'lı Bugün ekranı:** Günlük ısınma + seri; mevcut tekrar kartları
  ve akıllı hatırlatma bu kalıba oturuyor.
- **Sonuç ekranında tek odak:** Metrik kırılımı + tek cümle geri bildirim +
  "tekrar dinle / tekrar dene". Radar grafiği yalnız ölçülen eksenlerle;
  ölçülmeyen eksen boş/durumlu kalmalı.
- **Kopyalanmayacak:** Satıcı kaynaklı "AI koç" vaatleri, doğrulanmamış
  basın/kullanıcı sayısı sosyal kanıtı, 40+ adımlı quiz. Ses puanlaması
  doğrulanmadan "ses koçu" pazarlaması yapılmamalı
  ([rakip araştırması](../../COMPETITOR_RESEARCH.md)).

## Kaynaklar

- [Simply Sing — ScreensDesign](https://screensdesign.com/apps/simply-sing-my-singing-app/?vs=134355)
- [Vocal Image — ScreensDesign](https://screensdesign.com/showcase/vocal-image-ai-voice-coach)
- [Vocalista — ScreensDesign](https://screensdesign.com/showcase/vocalista-vocal-training)
- [Singing Carrots — best learn to sing apps 2026](https://singingcarrots.com/blog/best-learn-to-sing-apps-2026/) (satıcı blogu)
- [Singing Carrots — top 7 AI vocal coaches](https://singingcarrots.com/blog/top-7-ai-vocal-coaches/) (satıcı blogu)
- [American Songwriter — Simply Sing review](https://americansongwriter.com/simply-sing-review/)
- [Vocal Image overview — Toolmage](https://www.toolmage.com/en/tool/vocal-image/)
- [Yousician — Lazyweb](https://www.lazyweb.com/company/yousician)

## 5. Puan + gelir karşılaştırması ve referans seçimi (4 Kasım 2026)

Gelir rakamları üçüncü taraf tahminleridir (resmî değil, tarih ve araç
farkı büyük). "MRR" burada tahmini aylık mağaza geliri anlamında.

| Uygulama | App Store puanı | Tahmini aylık gelir | Odak | Kaynak |
|---|---|---|---|---|
| Simply Sing | 4,7 · 471K oy | 0,5–0,9 M$ (yalnız IAP 0,5 M$) | Şarkı söyleme | [App Store](https://apps.apple.com/us/app/id1592900217), [Adapty](https://adapty.io/paywall-library/simply-sing-my-singing-app/), [retention.blog](https://www.retention.blog/p/simply-sing-guitar-draw), [Sensor Tower](https://app.sensortower.com/overview/1592900217?country=US) |
| Vocal Image | — | ≈1 M$ (12 M$ ARR, Ağu 2025) | Konuşma koçu | [Sacra](https://sacra.com/c/vocal-image/), [Invest in Estonia](https://investinestonia.com/estonian-ai-startup-vocal-image-raises-36m/) |
| Yousician | 4,6 · ≈65K oy | ≈4–5 M$ (yıllık 50–58 M$, tüm enstrümanlar) | Müfredat, çok enstrüman | [Bloom Vocal](https://www.bloomvocal.site/en/blog/yousician-review-2026), [Lazyweb](https://www.lazyweb.com/company/yousician), [TechCrunch](https://techcrunch.com/?p=2144906) |
| Smule | 4,5 · 182K oy | bulunamadı | Karaoke/sosyal | [App Store](https://apps.apple.com/us/app/smule-sing-duet-record/id509993510) |
| Vocalista | 4,7 · 2,5K oy | <10K–45K $ | Egzersiz | [App Pricing Lab](https://apppricinglab.com/app/apple/6444087548), [AppGoblin](https://appgoblin.info/apps/6444087548) |

**Seçim: Simply Sing.** Yalnız ses eğitimi yapan uygulamalar içinde hem
en yüksek puan × oy hacmi hem en yüksek tahmini gelir onda. Vocal Image
gelirde yakın ama konuşma koçu ve 42 adımlı onboarding'i "sade" hedefine
ters. Yousician'ın geliri tüm enstrümanlardan.

Simply Sing'den alınacak ilkeler (sadelik açısından):

1. **2 sekme** (Ana sayfa + Profil). Her şey ana sayfadan akar.
2. **İlk ders onboarding'in hemen sonunda**: "plan hazır" özeti yerine
   doğrudan ilk alıştırma (aktivasyon = tutma).
3. **Tek büyük kart = tek eylem**: "günlük ısınma" kartı ekranın tepesinde,
   düğme kartın içinde.
4. **Oturum içinde otomatik akış**: önizle → yap → sonuç → sıradaki; ana
   sayfaya dönmeden.
5. **Sonuçta tek odak**: bir skor + bir cümle + "tekrar / devam".

## 6. Vocalart mevcut durum vs. öneri

Mevcut (kod: `lib/trainer/home/home_shell.dart`,
`lib/trainer/onboarding/onboarding_flow.dart`, `lib/trainer/koro/koro_hub.dart`):

| Alan | Şimdi | Sorun | Öneri |
|---|---|---|---|
| Sekmeler | Bugün · Ses · (Koro) · İlerleme · Ayarlar = 4–5 | Karar yükü; Ses ve Bugün aynı işi bölüyor | **Bugün · Keşfet · Ben** (Koro rolüne göre 4.) İlerleme+Ayarlar → Ben |
| Bugün ekranı | Hero + 3–4 adım kartı + CTA + gizlilik notu + koro kartı + 2×N beceri ızgarası | CTA listenin altında; 10+ dokunulabilir öğe | Hero içinde **tek "Başla" düğmesi**; adımlar küçük ilerleme çizgisi (1 Nefes · 2 Ders · 3 Ses); beceri ızgarası Keşfet'e |
| Metin | "KENDİ RİTMİNDE", "Sesine alan aç.", "taslak ölçüm" | Soyut/teknik | Somut: "Sıradaki: Başlarken · 8 dk" |
| Ses sekmesi | 9 kart, DENEYSEL/TASLAK/YAKINDA etiketleri | Kullanıcıya yarım iş gösteriyor | Doğrulanmamışlar Ayarlar › Laboratuvar'a; Keşfet'te yalnız hazır olanlar |
| Onboarding | 7 adım → "Planın kuruldu" özeti → düğme | Aha anı gecikiyor | 5 adım: karşılama → odak (+rol) → aralık testi (atlanabilir, "ölçülmedi") → süre+hatırlatma → **doğrudan ilk ders** |
| Oturum sonu | `session_end.dart` | (incelenmedi) | Tek skor + tek cümle + "Tekrar / Sıradaki"; sıradaki adıma otomatik geçiş |

Sınırlar: Bu bir tasarım önerisidir; kod değişmedi, kullanıcı testi yok.
Ölçüm kuralları (null/status, yanlış oktav, invalid → puan yok) değişmez.
