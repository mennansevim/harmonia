# Harmonia — Rakiplerden türetilen özellik backlog'u

**Güncelleme:** 2026-10-11. P0: güvenilirlik; P1: ilk değer; P2: Premium/Plus; P3: ölçeklenme. “Planda” kodda tamamlandı demek değildir. Canlı AI, gerçek mikrofon, abonelik, eğitimci servisi ve lig henüz bağlı değildir.

| ID | Özellik | Kaynak/amaç | Mevcut durum → iş | Öncelik / faz | Kabul kriteri |
|---|---|---|---|---|---|
| F01 | Misafir başlangıç, hedef seçimi, kalibrasyon, güvenli aralık | Singing Carrots / Sing Sharp | Planda → izin, sessizlik/gürültü/Bluetooth, tekrar ve ayarlara git akışları | P0 / 1–2 | Hesapsız ilk çalışma; izin reddi çıkmaz yaratmaz; geçersiz kayıt başarısızlık değil yeniden ölçüm olur |
| F02 | Başlangıç tespiti + günlük kısa yol | ToneGym / Complete Ear | Günlük plan planda → kolay/ileri, 3–10 dakika, hata temelli sıra | P1 / 2–3 | Kullanıcı iki dokunuşta kaldığı çalışmaya gider; zorluk gerekçesi açıklanır |
| F03 | Tek ses/aralık/canlı nota bandı | EarMaster / Yousician | Mock ekran var → gerçek ölçüm ve canlı geri bildirim | P0 / 1–2 | Doğru nota ve oktav ayrı doğrulanır; benchmark; ölçülmeyen timing/memory 100 gösterilmez |
| F04 | Ritim tap, sonra clap; ezgi singback | EarMaster / Complete Rhythm | Mock arayüzler var → gerçek giriş, onset ve nota eşleştirme | P1 / 2 | Eksik/fazla/erken/geç ayrılır; latency hesaba katılır; ölçüm tekrarlanabilir |
| F05 | Beceri raporu → zayıf noktaya çalışma | MyEarTraining / ToneGym | Temel geçmiş planda → nota/aralık/vuruş dağılımı; yeterli örnek uyarısı | P1 / 2–3 | Pitch, ritim, ezgi farklı gösterilir; aynı zorlukta tarihsel karşılaştırma |
| F06 | Hata sonrası 30–60 sn teori ve eğitmen örneği | Perfect Ear / Complete Ear / Sing Sharp | Yeni | P1 / 2 | Her temel hata için özgün metin/örnek; kullanıcı dersi atlayabilir; video şart değil |
| F07 | Deşifre + ritim/ezgi dikte | EarMaster / Perfect Ear / Complete Rhythm | Yeni | P2 / 4 | Görerek söyleme ile duyarak hatırlama ayrı skor ve talimata sahip |
| F08 | 2/3/4 sesi birlikte duy → tek tek söyle; akor tanıma ve çevrim | EarMaster / Complete Ear | Çok sesli sınav planda → 3/4 sesli teknik kapsam netleştirildi | P2 / 4; spike 1 | Sıralı/mükerrer/eksik sesler ayrılır; sınavda hedefler cevaptan önce açığa çıkmaz |
| F09 | Hata döngüsü, tempo, zor bölüm tekrarı | Yousician / Complete Rhythm | Yeni | P1 / 2; genişleme 4 | Ezgi/ritim segmentini tekrar et; sınav modunda ipucu/loop kullanımını engelle veya ayrı işaretle |
| F10 | Fonksiyonel duyma, solfej, dizi/progresyon | Functional Ear / MyEar / Perfect Ear | Yeni | P2 / 4 | Tonik kur → derece duy → seç/söyle; fixed-do/movable-do öğretmen kararıyla açıklanır |
| F11 | Egzersiz oluşturucu, sınırlandırılmış parametreler | Complete Ear / MyEar | Özel sınav planda → kişisel preset önce | P2 / 4; öğretmen 5 | Nota sayısı, ton, tempo, aralık, tekrar sayısı versiyonlu tanımda saklanır |
| F12 | Adaptif tekrar + AI koç açıklaması | ToneGym / Sing Sharp / Singing Carrots | Planda → beceriye göre tekrar kuyruğu; AI ölçmez | P2 / 3 | Kurallı fallback vardır; öneri mevcut egzersiz kataloğundan seçilir; farklı model şart değil |
| F13 | Konservatuvar denemesi + çalışmadan ayrı sonuç | EarMaster | Planda → yerel öğretmen şablonları, süre, ipucusuz ölçüm | P2 / 4 | İçerik/sınav/puanlama versiyonu raporda; resmî okul eşdeğerliği iddiası yok |
| F14 | Offline çalışma ve cihazlar arası senkronizasyon | MyEarTraining | Offline prensibi var → sonuç kuyruğu/idempotency/sync çatışması | P1 / 2; bulut 3 | İnternetsiz core; iki cihaz aynı denemeyi iki kere saymaz |
| F15 | İsteğe bağlı haftalık beceri ligi + özel sınıf sıralaması | ToneGym / Complete Ear / Singing Carrots | Kontrollü lig planda → sezon/kurallar/uygun denemeler | P3 / 5 | Aynı test sürümü/zorluk; minimum deneme sayısı; takma ad; çıkış ve silme; sahte demo kullanıcıları üretime girmez |
| F16 | Ücretsiz değer → Premium / yıllık / öğretmen paketi | Birçok rakip | Planda → fiyat araştırması, entitlement, restore, iptal/ağ hataları | P2 / 4 | İlk sonuç ücretsiz; mağaza fiyatı/dönemi/yenileme açık; geri yükleme; kullanıcı izin vermeden satın alma yok |
| F17 | Öğretmen ödevi, sınıf kodu, rapor, grup lisansı | MyEar / Complete / EarMaster | Planda → B2B pilot ve sınıf gizliliği | P3 / 5 | Öğretmen yalnız kendi izinli öğrencisini görür; ödev/teslim/haftalık özet |
| F18 | Alternatif enstrüman bankası ve arcade | Complete Ear / Complete Rhythm | Yeni; ertelendi | P3 / 5+ | Kayıt hakları kontrol; tını değişimi skor kalibrasyonunu bozmaz; arcade sınav skoruna karışmaz |
| F19 | Ses aralığına uygun repertuvar, MIDI içe aktarım | Singing Carrots / Yousician | Yeni; ertelendi | P3 / 5+ | İlk içerik özgün veya lisanslı; MIDI doğrulama; tam katalog MVP dışında |
| F20 | Isınma, sustain, nefes rehberi | Singing Carrots / Sing Sharp | Yeni; içerik pilotu | P2 / 4; ölçüm AR-GE | Eğitmen onaylı, durdurulabilir içerik; yalnız ölçülen süre/kararlılık raporlanır; sağlık/teknik teşhisi yok |
| F21 | Plus: gerçek eğitimciye kayıt + gelişim özeti, yazılı yorum | Kullanıcının isteği | Yeni kapsam; uygulanmadı | P2 / pilot 3, ücretli 4 | Gerçek eğitimci dinler/yazar; imzalı kanıt ve takip; hak/kapasite/iade/erişim; AI ayrı; HUMAN_REVIEW.md |
| F22 | Müfredat, beceri önkoşulları ve kalıcı öğrenme | Eğitim modeli incelemesi | Yeni; salt test bankasının ötesi | P1 / temel 2, adaptif 3 | Mikroders → destekli → ipucusuz yeni soru → gecikmeli kontrol; algı/üretim ayrı; LEARNING_MODEL.md |
| F23 | Koro: parti bağımsızlığı, rehber azaltma, diğer partilerle söyleme | Koro hazırlık açığı | Yeni; koro rotası | P2 / spike 3, içerik 4 | Kulaklıklı tek vokal kayıt; kendi rehberi kapalı ölçüm; referans sızıntısı başarı sayılmaz; yeni parçada kontrol |
| F24 | Koro giriş/bitiş, notalı söz, cümle ve repertuvar ödevi | Koro hazırlık açığı | Yeni; eğitimci onaylı içerik | P2 / 4 | Giriş/cutoff zamanlaması ayrı; ifade/diksiyon öğretmen gözlemi; lisans kontrolü ve gerçek prova ödevi |
| F25 | Okul/bölüm/yıl gereksinim eşlemesi | Resmî sınavların farklılığı | F13 genişlemesi | P2 / 4 | Kaynak URL/yıl/son kontrol/içerik sürümü; çalgı/şan dış kapsamı görünür; otomatik sınav kazanma iddiası yok |
| F26 | Değerlendirme geçerliliği ve sequence/rhythm sözleşmesi | Kod incelemesi AUD-01–07 | REL-01–05 uygulandı: status, progress cohort, rhythm event ve placeholder güvenliği; gerçek sequence/DSP bekliyor | P0 / 1–2 | Nullable/status; octave/sıra/ekstra vuruş fixture'ları; metric-specific geçerli örnekler; öğrenme ve sınav ayrımı |

## Yapılma sırası

**F15 ek kuralı:** Kullanıcının istediği ses aralığına göre karşılaştırma, isteğe bağlı rahat aralık profili/grubu filtresi olarak değerlendirilir. Aralığın genişliğini en yüksek puan/ödül yapan yarışma kurulmaz; beceri sıralaması test zorluğuna göre normalize edilir. Aralık verisini gösterme ve lig katılımı ayrı tercihlerdir.

1. F01/F03/F26: gerçek ses, oktav, geçersiz ölçüm, güvenilir görsel ve skor sözleşmesi.
2. F04/F06/F09/F22: ritim ve ezgi, hatanın öğretici tekrarı, temel müfredat.
3. F02/F05/F14: alışkanlık, gelişim, offline.
4. F12/F22: adaptif öğrenme; AI yalnız açıklama. F21 insan hizmeti ve F23 parti çalışması pilotları.
5. F08/F10/F11/F13/F16/F21/F23/F24/F25: ileri hazırlık, Premium/Plus; her alt rota kendi yayın kapısıyla. Hepsinin aynı tarihte çıkması gerekmez.
6. F15/F17: öğretmen ve normalize lig; F18/F19/F20 kontrollü genişleme.

F08 için **ayrı eşzamanlı mikrofon multipitch AR-GE'si** bu sıranın önkoşulu değildir. Tek sesli cevaplardan akor seslerini değerlendirmek ilk ürüne yeterlidir. Ayrıntı: [AUDIO_ENGINE_PLAN.md](./AUDIO_ENGINE_PLAN.md).

## Ticari doğrulama

Aboneliği bir kez yapılan ses aralığı testine değil, tekrarlanan faydaya bağla: adaptif günlük program, sınav denemesi, hata raporu ve öğretmen ödevi. Free/Premium limitleri ile fiyat henüz deney hipotezi; kesinleştirilmedi. Tasarımdaki 199 TL/ay ve 1.799 TL/yıl yalnız fiyat yerleşimi örneğidir.

Takip: ilk egzersiz tamamlama; D7/D30 geri dönüş; haftalık aktif çalışma; deneme→ödeme; iptal; destek talepleri; kullanıcı başına AI+altyapı maliyeti. Kârlılık hesabı net gelirden mağaza komisyonu, vergi, iade, edinim, içerik ve hizmet maliyetleri düşüldükten sonra yapılır. Büyük gelir garantisi yok; öğretmen pilotu ayrı ödeme isteği testi olmalı.

Plus eğitimci maliyeti kota ve kullanım oranıyla kapasite planına bağlanır; dijital Premium fiyatının üzerine hesap yapmadan insan hizmeti eklenmez. 1 hak/ay önerisi ve teslim hedefi kesin teklif değil. Öğrenme ölçümü yeni/gecikmeli sorularda tutulur; streak/lig başarı kanıtı sayılmaz. [Derin inceleme](./PRODUCT_AUDIT.md).
