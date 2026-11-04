# Resonia — 10 rakip ve ürün çıkarımları

**4 Kasım 2026 ekran şablonu incelemesi:** Simply Sing, Vocal Image,
Vocalista ve diğerlerinin ortak onboarding → aralık testi → paywall →
Bugün/egzersiz döngüsü ağacı ve ekran bağlantıları
[docs/research/2026-11-04-voice-coach-screen-template.md](./docs/research/2026-11-04-voice-coach-screen-template.md).
Masa başı; uygulamalar denenmedi, kod değişmedi.

**20 Ekim 2026 ticari ek inceleme:** Simply/Simply Piano, Yousician ve
Duolingo Music için finansal kanıt, özellik örüntüleri, mevcut kod farkları
ve kabul kriterleri [ticari benchmark](./COMMERCIAL_BENCHMARK_2026-10.md)
belgesinde. Şirket geliri ile uygulama/modül geliri ayrıldı; “en çok kazanan
ilk üç” veya özellik bazlı gelir sıralaması iddiası yok. Son7 gün çalışma
kartı GROW-01a kodlandı; diğer eksikler mevcut backlog'a bağlandı.

**3 Kasım 2026 pazar ve fiyat ek incelemesi (masa başı, kod değişmedi):**
- *Pazar büyüklüğü:* Kulak eğitimi uygulaması pazarı için yayımlanan tahmin
  2025'te ≈ 488 M$, 2035'e ≈ 1,5 Mr$ (%11,8 YBBO; [WiseGuy](https://www.wiseguyreports.com/reports/ear-training-app-market)).
  Yöntem görülmedi; iş planı girdisi sayılmaz. Tekil uygulama gelir
  tahminleri (AppGoblin) küçük; niş pazar.
- *Fiyat örnekleri (satıcı kaynakları, bağımsız doğrulanmadı):* Singing
  Carrots aylık 19,99/39,99/79,99 $ ([kaynak](https://singingcarrots.com/blog/best-online-singing-courses-prices-2026-updated-guide/));
  Chorilo topluluk başına 10 €/ay veya 100 €/yıl, 60 gün deneme
  ([kaynak](https://www.chorilo.com/en/features)); VocalCentric koltuk paketi
  39,99–199,99 $ ([App Store](https://apps.apple.com/app/id6739209305), veri eski olabilir);
  EarMaster temel ücretsiz + IAP, TR yorumlarında Türkçe talebi
  ([App Store TR](https://apps.apple.com/tr/app/id1105030163)).
- *Türkiye boşluğu:* Türkçe arayüzlü ve konservatuvar özel yetenek sınavına
  odaklı bir mağaza uygulaması doğrulanamadı. Sınavlar ezgi tekrarı, aralık,
  müzikal bellek ve ritim ölçüyor ([Nişantaşı](https://www.nisantasi.edu.tr/Uploads/ozel-yetenek/2025_2026_Sahne_Sanatlar%C4%B1_%C3%96zel_Y.pdf),
  [Sakarya](https://studyatsau.sakarya.edu.tr/wp-content/uploads/2024/07/2024-DEVLET-KONSERVATUARI-OZEL-YETENEK-SINAV-KLAVUZU-TR.pdf)).
  Aynı eksikliği gören bir BAU öğrencisi uygulama geliştirdi
  ([DHA](https://www.dha.com.tr/egitim/baulu-ogrenciden-muzik-pratigini-kolaylastiran-mobil-uygulama-2917846));
  adı/mağazası doğrulanmadı — boşluk kapanabilir.
- *Talep sınırları:* Ulusal aday sayısı bulunamadı (ÖSYM/MEB'den alınmalı);
  bölüm kontenjanları ≈ 20. Sınavlar Ağustos–Eylül ([AKÜ 2026-27](https://konservatuvar.aku.edu.tr/wp-content/uploads/sites/126/2026/07/2026-2027-Akademik-Yili-Ozel-Yetenek-Sinavi-Kilavuzu.pdf));
  talep mevsimsel varsayılmalı.
- *Çıkarım (hipotez):* Fark Türkçe + sınav odağı; koro tarafında VocalCentric
  güçlü. Ses puanlaması açılmadan "ses koçu" diye pazarlanmamalı.

**İnceleme:** 2026-10-10 · **Kapsam:** konservatuvar hazırlığı, kulak eğitimi, ritim ve vokal geri bildirim.

Bu liste indirme/gelir verisine dayalı bir “dünyanın en iyi 10'u” sıralaması değildir. Resonia'nın dört temel becerisine en ilgili 10 karşılaştırma ürünüdür. Resmî ürün sayfaları ve yardım belgeleri üzerinden masa başı araştırması yapıldı; ücretli hesapla derslerin uygulamalı testi veya 10 ürünün tamamında ekran ekran görsel denetim yapılmadı. Doğrulanan özellikler ile aşağıdaki UX yorumları birbirinden ayrıdır. Fiyatlar ülkeye ve mağazaya göre değişebildiği için fiyat karşılaştırması yapılmadı. Pazarlama doğruluk/öğrenme/gelir iddiaları bağımsız kanıt kabul edilmedi.

## Karşılaştırma ve plana aktarım

| Ürün / birincil kaynak | Resmî olarak görülen özellik | Resonia için UX çıkarımı (bizim yorumumuz) | Plandaki karşılığı |
|---|---|---|---|
| [EarMaster](https://www.earmaster.com/products/ear-training-sight-singing/earmaster-software.html) | Mikrofondan söyleme/alkış, canlı pitch eğrisi, deşifre, ezgi/ritim tekrarı ve dikte; akor çevrimleri; özel süreli egzersizler ve sınav kursları | Cevabı yalnızca doğru/yanlış değil, hangi nota/vuruşta hata olduğunu göstererek açıklamak; öğrenme ile sınav görünümünü ayırmak | F03, F04, F07, F08, F13, F17 |
| [Perfect Ear](https://perfectear.app/) | Aralık karşılaştırma/tanıma/okuma; dizi ve akor tanıma, çevrim/progresyon; söyleme; ritim okuma/tıklama/taklit; deşifre ve teori | Aynı becerinin duyma, okuma ve söyleme biçimleri arasında köprü; ilk ekranda bütün kataloğu göstermemek | F03, F06, F07, F08, F10 |
| [Complete Ear Trainer](https://completeeartrainer.com/) | Kolay/klasik mod, ustalıkla bölüm açma, arcade, teori kartları, özel egzersiz/program, özel liderlik tablosu, kayıtlı enstrüman bankaları | Başlangıç düzeyini seçmek; hata sonrası ilgili teori kartı; sınıf rekabetini genel sıralamadan ayırmak | F02, F06, F09, F11, F15, F17, F18 |
| [Functional Ear Trainer / Miles.be](https://www.miles.be/software/functional-ear-trainer-v2/) · [mobil bağlantıları](https://www.miles.be/software/ear-training-on-your-iphone-ipad-and-android/) | Majör/minör tonal bağlamda ses tanıma; öğrenme ve özelleştirilebilir çalışma laboratuvarı. Mobil sürümlerin bağlantıları ayrıca yayımlanmış | Salt “hangi nota?” yerine tonik/derece ilişkisi öğretmek. Masaüstü v2'nin özelliklerini mobil sürümde otomatik var saymamak | F10 |
| [MyEarTraining](https://www.myeartraining.net/) · [okullar](https://www.myeartraining.net/schools) | Aralık, akor, dizi, progresyon, solfej, ritim ve söyleme; özel egzersizler; gün/hafta/ay raporu; cihazlar arası senkronizasyon; öğretmen ödevleri | Zayıf beceriden doğrudan egzersize gitmek; öğretmen için tek bakışta takip; çevrimdışı çalışma sonrası senkronizasyon | F05, F10, F11, F14, F17 |
| [ToneGym](https://www.tonegym.co/) | Beş kısa oyunlu günlük çalışma; düzeye uyarlanan oyunlar; aralık/akor/dizi/ritim/ezgi/deşifre; performans endeksi, haftalık yarışmalar; Pro plan | Karar yorgunluğunu azaltan günlük paket; tek genel skor yerine beceri odaklı gelişim; isteğe bağlı haftalık lig | F02, F05, F12, F15 |
| [Singing Carrots](https://singingcarrots.com/) | Ses aralığı ve pitch testleri, canlı pitch monitorü, MIDI özel ezgileri, sustain/nefes çalışması; aralığa uygun şarkı bulma; gelişim ve ligler; AI koç ve okul paketleri | Ses aralığını bir kişiselleştirme girdisi olarak kullanmak; ilk kısa testi uzun ankete tercih etmek; katalog telifini ayrı ele almak | F01, F05, F12, F15, F17, F19, F20 |
| [Yousician Singing](https://yousician.com/singing) · [resmî başlangıç rehberi](https://support.yousician.com/hc/en-us/articles/360000538749-Get-started-with-Yousician-for-Singers) | Mikrofonla anlık pitch/zaman geri bildirimi; öğretmenlerin hazırladığı yol; parça yavaşlatma, zor kısmı tekrar etme | Çalışma sırasında bütün ekranda tek görev; zor bölüm için döngü ve tempo kontrolü; şarkı kataloğunu MVP'ye taşımamak | F03, F04, F09, F19 |
| [Sing Sharp](https://www.singsharp.com/en/features) | Gerçek zamanlı pitch; göreli kulak eğitimi; kişiye göre vokal egzersizleri; nefes egzersizleri; eğitmen video gösterimleri | “Nasıl yapacağım?” için kısa örnek; görsel efektin yanında anlaşılır yönlendirme. Nefes/teknik teşhisini ölçüm kanıtı olmadan kopyalamamak | F01, F06, F12, F20 |
| [Complete Rhythm Trainer](https://completerhythmtrainer.com/) | Ritim taklidi, okuma, dikte; iki sesli ritim; poliritim; özel program; farklı enstrümanlar; arcade ve özel liderlik tabloları | Ritim için ses testinden farklı, başparmakla erişilebilir çalışma alanı; ileri ritimleri temelden ayrı paketlemek | F04, F07, F09, F11, F15, F17, F18 |

## Rakiplerin ortak güçlü tarafları

- Kısa bir çalışma → belirli hata → hedefli tekrar → gelişim görünümü.
- Başlangıç/ileri düzey ayrımı; teori ile uygulamanın birleşmesi.
- Görsel pitch geri bildirimi ve nota/vuruş düzeyinde hata açıklaması.
- Özelleştirilebilir egzersiz ve öğretmen programı.
- Kısa günlük görevler, ustalık kilitleri ve isteğe bağlı yarışma.

## Resonia'nın konumlandırması — doğrulanacak hipotez

**“Türkçe konservatuvar hazırlığı: duyduğun sesi ayır, doğru oktavda söyle, hatanı gör, her gün zayıf becerini çalış.”**

Farkımız yalnızca AI veya daha parlak bir orb olmayacak. Üç/dört sesli duyma-sıralı söyleme, yerel sınav şablonları, güvenilir oktav değerlendirmesi ve öğretmen tarafından anlaşılabilen rapor aynı döngüde birleşecek. İncelenen 10 üründe benzer alt özellikler var; “piyasada hiç yok” iddiası yapılmamalı. Türkiye'deki sınav formatları öğretmenler ve güncel resmî sınav belgeleriyle ayrıca doğrulanmalı; şimdilik okul adıyla resmî eşdeğerlik vaat edilmez.

## Kopyalanmayacak / erken yapılmayacak

- Kısa sürede kesin başarı, ses genişlemesi veya para kazanma garantileri.
- Gerçek ölçüm olmayan “AI nefes kalitesi” / “ses türü teşhisi”.
- Geniş ticari şarkı kataloğu; telif ve lisans çözülmeden ses/notasyon aktarımı.
- Ses aralığını genişletmeye zorlayan genel sıralama; kişisel aralık ve normalize beceri ligleri ayrılır.
- Rakiplerin ekranlarını, marka öğelerini, egzersiz metinlerini veya kayıtlarını aynen kopyalamak. İşlev örüntüleri özgün tasarımla uygulanır.

## Araştırmanın devamı

- [ ] Bu 10 üründe cihaz üzerinde onboarding → ilk egzersiz → sonuç → ödeme akışını süre tutarak dene.
- [ ] Erişilebilirlik, izin reddi, offline, gürültü ve Bluetooth durumlarını karşılaştır.
- [ ] 10 öğrenci + 3 öğretmenle beş Resonia tasarımını kör test et.
- [ ] Mağaza yorumları için ayrı, örneklem/tarih belirtilen çalışma yap; buradaki ürün iddialarıyla karıştırma.

Özelliklerin uygulama durumu ve kabul kriterleri: [FEATURE_BACKLOG.md](./FEATURE_BACKLOG.md). Tasarımlar: [DESIGN_STUDIES.md](./DESIGN_STUDIES.md).
