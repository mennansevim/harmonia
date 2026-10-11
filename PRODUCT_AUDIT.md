# Harmonia — Ürün ve eğitim yeterliliği incelemesi

**Tarih:** 2026-10-11  
**Kapsam:** Yerel Flutter kaynakları, mevcut ürün dokümanları, Agora Voice referans motoru ve resmî eğitim/seçme örnekleri. Kod düzeltmesi veya yeni canlı servis bu incelemede yapılmadı.

## İnceleme sonrası geliştirme kaydı — 2026-10-11

Aşağıdaki inceleme eski 26 testli başlangıç sürümünün tarihsel bulgularını korur; satır numaraları o sürüme aittir. Kullanıcının sonraki “başla” isteğiyle Harmonia kaynakları değiştirildi. Güncel kanıt [IMPLEMENTATION_LOG.md](./IMPLEMENTATION_LOG.md), işler [IMPLEMENTATION_ROADMAP.md](./IMPLEMENTATION_ROADMAP.md).

| Bulgu | Güncel kapanış / kalan sınır |
|---|---|
| AUD-01/05 | Metrik durumları/valid-invalid uygulandı; tek seste timing/memory artık uygulanamaz. Gerçek ölçüm hâlâ yok |
| AUD-02 | Placeholder sahte ezgi başarısı üretmiyor; gerçek sıra/hafıza analyzer hâlâ CORE-03 işi |
| AUD-03/04 | EventRhythmAnalyzer ekstra vuruş/monoton eşleştirme/latency/mutlak sapma kullanır; gerçek tap/clap akışı ve öğretmen kalibrasyonu bekliyor |
| AUD-06 | Metrik örnek sayısı ve zorluk/mod/sürüm cohort ayrımı uygulandı; persistence, hint/tuning/delay ve mastery henüz yok |
| AUD-07/08 | Exercise'a mode/content eklendi; tam sequence/müfredat/öğretim hâlâ bekliyor |

58 test geçti; bu güncelleme gerçek mikrofon veya eğitim yeterliliği kapısını açmaz. Agora motorundaki oktav/kısa-buffer bulguları değiştirilmedi.

## Karar özeti

Bugünkü Harmonia, eğitim ürünü değil: tek sesli senaryoları gösteren Flutter demosu ve ürün planıdır. Planlanan kapsam işitsel hazırlık için iyi bir çekirdek oluşturuyor; tam konservatuvar hazırlığı veya çok sesli koroya hazırlık için tek başına yeterli değildir. Eksik olan yalnız daha çok soru türü değil; öğretim içeriği, kalıcı öğrenmenin ölçümü, parti bağımsızlığı, gerçek repertuvara aktarım ve eğitimci değerlendirmesidir.

**Doğru konumlandırma:** Öğretmen ve prova yerine geçen uygulama değil, onların arasında düzenli ve açıklanabilir çalışma sağlayan hazırlık arkadaşı. Kullanıcının tercih ettiği Aurora marka deneyimi + Konservatuvar sonuç açıklığı, öncelikli tasarım yönü olarak kaydedildi; kullanılabilirlik doğrulaması bekleniyor.

## 1. Gerçekte ne var?

| Alan | Yerel kodda | Ürün planında | Yeterlilik kararı |
|---|---|---|---|
| Flutter uygulaması | Açılıyor; doğrudan tek ses demo ekranına gidiyor | Çok ekranlı mobil ürün | Teknik başlangıç var; kullanıcı rotası yok |
| Tek ses | Sabit C4 ve yedi mock senaryo; oktav hata kuralı | Gerçek dinle-söyle ve canlı görsel | Gerçek kayıt/ölçüm olmadan eğitim değerlendirmesi değil |
| Ses aralığı | Harmonia'da gerçek tarama yok; Agora'da referans var | Rahat aralık ve nota uyarlama | Referans taşınmalı ve oktav güvenilirliği doğrulanmalı |
| Aralıklar / 2–3–4 ses | Skill enum'u dışında çalışma akışı yok | Interval, birlikte duyup sırayla söyleme, çevrim | Katalog, segmentleme ve ölçüm sözleşmesi gerekiyor |
| Ritim | Basit timestamp eşleştiren mock analyzer | Tap, clap, tempo, eksik/fazla vuruş | Ekran/giriş yok; skor eğitim kullanımı için eksik |
| Ezgi | Açıkça placeholder analyzer | Kısa/uzun ezgi, hafıza, bölüm tekrarı | Nota sırası, süre ve hafıza ölçümü henüz yok |
| Teori / solfej / deşifre / dikte | Kod/içerik yok | F06/F07/F10 | Öğretmen onaylı ders ve notasyon gerektirir |
| Adaptif rota / gelişim | Saf ortalama modeli; kalıcı geçmiş yok | Günlük plan, AI koç, beceri raporları | Öğrenme basamakları ve hatırlama kanıtı eksik |
| Offline | Mock demo ağsız çalışabilir | İçerik indirme, gerçek analiz, sync | Tam offline eğitim modu sayılmaz |
| Abonelik / lig / öğretmen paneli | Entegrasyon yok | F15/F16/F17 | Canlı ödeme, gerçek kullanıcı veya sıralama yok |
| Gerçek eğitimci yorumu | Yok | Bu incelemede F21 ve HUMAN_REVIEW.md eklendi | Plus kapsamı; henüz uygulanmadı |
| Koro parti bağımsızlığı | Yok | Bu incelemede F23/F24 eklendi | Çok ses duyma sınavından farklı beceri |

Kanıt: [uygulama başlangıcı](./lib/app/harmonia_app.dart), [tek ses ekranı](./lib/features/single_tone_exercise/single_tone_exercise_screen.dart), [bağımlılıklar](./pubspec.yaml). Ekran analiz isteğinde boş sample listesi gönderir; sonuç mock senaryodan gelir. Gerçek nota çalma, mikrofon, Aurora görseli, AI, satın alma veya kayıt paylaşma bağlı değildir. Önceki beş tasarım da simülasyondur.

**Doğrulama, 2026-10-11:** `flutter test --no-pub`: 26 test geçti. `flutter analyze --no-pub`: sorun bulunmadı. Bu sonuçlar mevcut domain/mock/widget davranışını doğrular; gerçek mikrofon doğruluğunu, konservatuvar başarısını veya eğitim etkisini doğrulamaz.

## 2. Eğitim değerlendirmesini engelleyen bulgular

| ID / önem | Kanıt | Öğrenciye etkisi | Gerekli kabul testi |
|---|---|---|---|
| AUD-01 / P0 | `pitch_exercise_scorer.dart:63–65,89–91,155–157`: timing/memory sabit 100 | Ölçülmeyen beceri gelişmiş görünür; sessizlik bile hafıza 100 üretebilir | Tek ses sonucunda timing/memory `not_applicable`; rapora/AI'ye ölçüm gibi giremez |
| AUD-02 / P0 | `mock_melody_analyzer.dart:28,44–45`: eşit nota sayısı = doğru sıra, timing/memory 100 | Aynı sayıda ters sıra veya yanlış süre, hafıza başarısı sayılabilir | Ters sıra, yanlış oktav, aynı nota tekrarı, eksik/fazla nota, yanlış süre ve gecikmeli hatırlama fixture'ları |
| AUD-03 / P0 | `mock_rhythm_analyzer.dart:44–52`: ekstra vuruş accuracy'yi azaltmıyor | Beklenenlerin yanında sürekli vurmak 100 üretebilir | Beklenen [0,500], yanıt [0,500,900] kusursuz olamaz; boş referans geçersiz tanımdır |
| AUD-04 / P0 | Aynı ritim dosyasında signed ortalama; erken/geç sapmalar birbirini silebilir | Ortalama 0, yüksek ritmik dağınıklığı gizler | Signed bias ile mutlak sapma/dağılım ayrı; latency, tempo ve tolerans sınırı testleri |
| AUD-05 / P0 | `exercise_result.dart`: skorlar non-null; ayrı invalid durumu yok | Gürültü başarısız öğrenci gibi kaydedilebilir | `valid/invalid`, her metrik için ölçüldü/uygulanamaz; geçersiz sonuç mastery'yi düşürmez |
| AUD-06 / P1 | `skill_progress.dart:52–68`: tüm sonuçlara tek koşulsuz ortalama | Kolay-zor, ipuçlu-sınav, ölçülmeyen metrikler karışır | Metrik başına geçerli örnek sayısı; zorluk/mod/içerik sürümü; sıfır örnek = bilinmiyor |
| AUD-07 / P1 | `exercise.dart`: tek hedef nota; sequence/curriculum parametreleri yok | Ezgi, akor, ritim, tonal bağlam tutarlı tanımlanamaz | Referans nota/vuruş listesi, tuning, yanıt sırası, ipucu, tempo, içerik sürümü |
| AUD-08 / P1 | Ders kataloğu, prerequisite, spaced review, cold test yok | Test çözme sayısı öğrenme sanılabilir | Ders → deneme → ipucusuz hatırlama → yeni örneğe aktarım → yeniden kontrol |

Bunlar büyük ölçüde bilerek sade tutulmuş demo davranışlarıdır; üretim değerlendirmesine taşınmadan kapatılmaları gerekir. Toleranslar mevcut kodda 50 cents, kararlılık 25 cents ve voiced ratio 0.6; bunlar eğitimci/cihaz benchmark'ı ile doğrulanmış evrensel eşikler değildir.

### Referans Agora motoru: güçlü başlangıç, henüz doğrulanmış nihai motor değil

`agoravoiceweb/src/PitchTest/lib/pitchDetector.ts` gerçek ses üzerinde frame analizi, frekans filtresi, median ve kararlılık kullanır. Ancak:

- `matchToTarget`, frekansı 2/4 ile katlayıp böler; tam oktav hatası 85 veya 70 alarak `isMatch >= 60` koşulunu geçebilir. RangeTest bu sonucu aralık taramasına başarı olarak aktarır. **Rahat ses aralığı uçları için yanlış oktav başarı olamaz.**
- 2048 sample'dan kısa buffer'da defaults ile aynı rekürsif çağrıya dönme yolu var; kısa kayıt için açık geçersiz sonuç gerekir.
- Tüm kaydın tek medianı, bir ezginin veya üç ayrı cevabın nota sırasını korumaz; zaman sıralı frame ve segmentler gerekir.
- Döndürülen `clarity`, detector'ın ham confidence ortalaması değil, kabul edilen pencere oranıdır. RMS/voiced ratio nefes tekniği veya ses sağlığı teşhisi değildir.

Bu nedenle “çok iyi motor” iddiasını referans prototip olarak koruyup performansını etiketli kayıtlarla ölçmek gerekir. 2/3/4 sesin referansını birlikte çalıp cevabı tek tek almak monofonik motorun doğal genişlemesidir; eşzamanlı dört insan sesini ayırmak değildir. Ayrıntı: [motor planı](./AUDIO_ENGINE_PLAN.md).

## 3. Konservatuvar için yeterli mi?

[Giresun 2026–2027 resmî kılavuzu](https://konservatuvar.giresun.edu.tr/tr/news-detail/2026-2027-ozel-yetenek-sinavi-basvuru-kilavuzu/21862), Müzik Bölümü için çift/üç/dört ses, ezgi, ritim ve solfej/deşifreyi işitme aşamasında birleştiriyor. İşitme/okuma ve çalgı performansı ayrı 50'şer puanlık aşamalar; her birinde ayrı baraj var. Geleneksel Türk Müziği bölümü ayrıca farklı içerik kullanıyor. Bu, yalnız bu kurum/bölüm/yılın örneğidir; bütün okullara veya sonraki yıla genellenemez.

| Hazırlık alanı | Planın kapsamı | Tamamlanması gereken |
|---|---|---|
| İşitme ve tekrar | Tek, aralık, 2/3/4 ses, ezgi ve ritim | Güvenilir skor + ipucusuz okul biçimli deneme |
| Müzik okuryazarlığı | Teori, solfej, deşifre, dikte | Öğretim sırası, porte/anahtar/ölçü/alterasyon içerikleri |
| İşitsel hafıza | Ezgi ve gecikmeli cevap | Gecikme, tekrar sayısı ve ipucunun raporu; yeni soru ölçümü |
| Performans ve repertuvar | Çok sınırlı; F19/F20 | Branşa uygun eser/teknik için gerçek eğitimci; enstrüman eğitimi ayrı kapsam |
| Okul/bölüm uyumu | Genel sınav simülasyonu | Kaynak, yıl ve içerik sürümü; değişen kılavuzun manuel doğrulanması |
| Makam/usul/tavır | İlk Batı müziği çekirdeğinde yok | Ayrı uzmanlık rotası ve tuning sözleşmesi; 12 eşit aralıkla yeterlilik iddiası yok |

**Sonuç:** Core + ileri işitme rotası, sınavın işitsel bölümünde destek ürünü olabilir. Tam konservatuvar hazırlığı iddiası için performans, branş ve kurum koşulları gerekir. Resmî puan dağılımının bir kısmını kapsamak “öğrenci %50 hazır” anlamına gelmez. TYT/başvuru şartları ve seçme sonucu uygulama skorundan çıkarılamaz.

## 4. Çok sesli koro için yeterli mi?

Üç sesi duyup sırayla söylemek ile başka partiler devam ederken kendi partisini korumak farklı görevlerdir. Mevcut plan birincisini içeriyor; ikincisi yeni F23'ün konusu.

[SLSO'nun 2022 seçme rehberi](https://slso.org/tips-for-auditioning-for-the-st-louis-symphony-chorus-from-current-singers/) hazırlanmış solo, deşifre ve vokal çalışmasını örneklendirir; güncel 2026 seçme duyurusu olarak kullanılmaz. [ACDA'nın polifoni eğitim oturumu](https://acda.org/archives/sessions/lessons-from-renaissance-polyphony-for-our-contemporary-choral-toolkit), entonasyon, ritim, artikülasyon, cümleleme ve parti dengesini birlikte ele alır. Bu mesleki kaynaklar bir uygulama etkililik deneyi değildir.

Koro rotasının asgari ekleri:

1. Kendi parti rehberi → rehberi azalt → rehberi kapat, diğer partiler sürerken söyle.
2. Başlangıç sesi alma, suslardan sonra giriş, bitiş ve şef işaretini takip.
3. Basit kanon/iki parti → üç/dört parti, tonal merkez ve zor sıçramalar.
4. Nota okurken söz, ünlü/ünsüz, legato, cümle ve dinamik çalışması.
5. Lisansı doğrulanmış kısa repertuvar, gerçek eğitimci yorumu ve gerçek prova ödevi.

Kulaklıktan diğer partileri çalarken mikrofondan yalnız öğrenciyi analiz etmek ilk yaklaşım olmalı. Hoparlör sızıntısını öğrencinin sesi sanan analiz kabul edilemez. İlk sürüm blend, tını, doğru nefes tekniği veya topluluğun dengesi için otomatik güvenilir skor vaat etmez; eğitimci ve canlı prova gerekir. Ses aralığı tek başına soprano/alto/tenor/bas atamasına yetmez.

## 5. Yeterli çeşitlilik nasıl sağlanır?

Soru sayısından önce beceri matrisi: ayırt etme, sesle üretme, ritim, nota okuma, hatırlama, armonik duyma, parti bağımsızlığı ve repertuvara aktarım. Her beceride başlangıç/orta/ileri, destekli/desteksiz ve alışılmış/yeni örnek bulunmalı.

Çeşitlilik eksenleri: tonal bağlam, aralık/yön, akor çevrimi, ezgi konturu/uzunluğu, tempo, ölçü, sus/senkop, gecikme, tekrar sayısı ve tını. Birden çok eksen aynı anda yükseltilmemeli; rastgele üretim eğitimci onaylı sınırlar içinde kalmalı. “Yanlış söyledin”den, kişinin kulağının mı yoksa vokal üretiminin mi zorlandığı çıkarılamaz: seçmeli algı cevabı ile söyleme sonucu ayrı ölçülmeli.

Uygulanabilir ilk içerik ve basamaklar: [LEARNING_MODEL.md](./LEARNING_MODEL.md). Gerçek eğitimci döngüsü: [HUMAN_REVIEW.md](./HUMAN_REVIEW.md).

## 6. Yayına çıkış kapıları

- **Ölçüm kapısı:** Geçerli/ölçülmedi ayrımı; oktav, sıra ve ritim regresyonları; etiketli gerçek kayıtlar ve desteklenen cihaz matrisi. Kabul eşikleri benchmark öncesi yazılır, sonuç görüldükten sonra başarı tanımı değiştirilmez.
- **Eğitim kapısı:** Eğitimci onaylı içerik; başlangıç ölçümü → tekrarlanan çalışma → görülmemiş ipucusuz son test → gecikmeli kontrol. Skor artışı tek başına yeterli değildir.
- **Koro kapısı:** Diğer partilerle kulaklıklı gerçek kayıt ve rehber kapalı çalışma; algoritma/repertuvar/öğretmen rubriği birlikte doğrulanır.
- **Plus kapısı:** Gerçek eğitimci kapasitesi, kayıt gizliliği, hak/iade akışı ve teslim kalitesi kanıtlanır; otomatik AI mesajı insan yorumu diye sunulmaz.
- **Ticari kapı:** Ödeme isteği, çalışma sürekliliği ve eğitimci maliyeti pilotta ölçülür; gelir veya sınav kazanma garantisi verilmez.

Bu oturum kodu onarmadı. Bulgular backlog/roadmap'e işlendi; öğrenci/öğretmen pilotu ve gerçek audio benchmark henüz yapılmadı.
