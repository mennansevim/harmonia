# Harmonia — Decisions

Bu dosya, ileride “neden böyle yaptık?” sorusunun cevabıdır. Büyük kararlar değişirse eski karar silinmez; yeni karar eklenir.

## ADR-001 — AI ölçüm motorunun yerine geçmeyecek

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

Pitch, ritim ve başarı hesabı deterministik ses işleme ile yapılacak. AI yalnızca ölçüm sonucunu yorumlayacak ve sonraki egzersizi önerecek.

**Neden:** Eğitim uygulamasında skorun tekrarlanabilir ve denetlenebilir olması gerekir.

## ADR-002 — İlk AI modeli `gpt-4o-mini`

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

İlk sürümde `gpt-4o-mini`, kısa koç mesajları, günlük planlar ve yapılandırılmış egzersiz önerileri için kullanılacak.

**Sınır:** Ham ses pitch analizi için kullanılmayacak.

## ADR-003 — Ham ses varsayılan olarak gönderilmeyecek

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

AI’ye frekans, cents, oktav, timing, stability ve hata türü gibi özet ölçümler gönderilecek. Ham kayıt yalnızca açık rıza ve ürün amacı varsa saklanacak.

## ADR-004 — Misafir başlangıç akışı olacak

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

Kullanıcı ilk egzersizi hesap açmadan deneyebilecek. Hesap, ilerlemeyi kaydetmek ve cihazlar arası senkronizasyon için istenecek.

## ADR-005 — Leaderboard varsayılan olarak kapalı olacak

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

Leaderboard takma adla ve açık rıza ile kullanılacak. İlk sürümde leaderboard geliştirmesi yapılmayacak.

## ADR-006 — Oktav hatası başarı sayılmayacak

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

Kullanıcı hedef nota ile aynı nota ailesini fakat yanlış oktavı söylerse bu durum öğretici hata olarak gösterilecek; ses aralığı ve sınav başarısına doğru cevap olarak eklenmeyecek.

## ADR-007 — Flutter UI ile ses motoru ayrılacak

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

Ses yakalama, frame analizi ve scoring UI’dan ayrılacak. Amaç düşük cihazlarda animasyonların ve ses analizinin birbirini etkilememesi.

## ADR-008 — İlk MVP’de içerik genişliği değil öğrenme döngüsü

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

İlk sürüm az sayıda egzersizi iyi geri bildirimle sunacak. Büyük şarkı kütüphanesi, sosyal ağ ve marketplace sonraya bırakılacak.

## ADR-009 — AI çıktısı serbest metin değil sözleşmeli JSON

**Durum:** Kabul edildi  
**Tarih:** 2026-08-15

Flutter ekranları AI’nin rastgele metin formatına bağlanmayacak. `coachMessage`, `errorType`, `nextExercise`, `encouragement` gibi alanlar schema ile doğrulanacak.

## ADR-010 — Çok sesli referans, sıralı vokal cevap

**Durum:** Önerildi; ürün/öğretmen doğrulaması bekleniyor  
**Tarih:** 2026-10-10

İlk 2/3/4 sesli sınavda piyano sesleri birlikte çalınacak, kullanıcı sesleri birer birer söyleyecek. Monofonik motor nota bölümlendirmesi ve eşleştirmeyle genişletilecek; eşzamanlı multipitch ayrı AR-GE. Sıra zorunluluğu egzersiz tanımında tutulacak.

## ADR-011 — Etkileyici ama ölçüme sadık görsel

**Durum:** Önerildi; tasarım seçimi bekleniyor  
**Tarih:** 2026-10-10

Enerji, signed cents, confidence ve kararlılık birbirinden ayrı görsel boyutlara bağlanacak. Oktav/gürültü başarı gibi görünmeyecek. Reduced motion, iptal/pause ve çalışma/sınav ayrımı temel kabul kriteri olacak. Aurora önerilen ana yön; henüz kabul edilmiş marka tasarımı değil.

## ADR-012 — Rakip kapsamı öncelikli backlog, otomatik MVP değil

**Durum:** Önerildi  
**Tarih:** 2026-10-10

Rakip özellikleri F01–F20 olarak izlendi. Yalnız ilk öğrenme döngüsünü güçlendiren işler MVP'de; katalog, marketplace, açık sosyal akış ve multipitch AR-GE'si kapılardan sonra. Ölçülmeyen metriğin 100 gösterilmesi kaldırılacak; bu model değişikliği henüz uygulanmadı.

## ADR-013 — Aurora markası, Konservatuvar sonuç açıklığı

**Durum:** Kullanıcının tercih ettiği yön; kullanılabilirlik doğrulaması bekleniyor  
**Tarih:** 2026-10-11

ADR-011'in tasarım belirsizliği için öncelikli yön hibrittir: Aurora'nın ses alanı ve marka hissi, Konservatuvar'ın açıklayıcı nota/vuruş sonuçları. Diğer konseptler silinmez. Marka görseli gerçek ölçümle bağlıdır; Flutter uygulaması henüz değiştirilmedi.

## ADR-014 — Plus değerlendirmesini gerçek eğitimci yapacak

**Durum:** Kullanıcının istediği ürün sınırı kabul edildi; kota/fiyat/teslim ve operasyon pilotta doğrulanacak  
**Tarih:** 2026-10-11

Gerçek eğitimci öğrencinin izinle paylaştığı kaydı dinler ve yazılı yorumunu kendisi üretir. AI yorumunu insan yorumu olarak gösterme veya eğitimci adına otomatik teslim yok. Coach ve eğitimci raporu ayrı varlıklar/etiketlerdir. İlk sürüm yönetilen küçük havuz; tam marketplace gerekmez. [Hizmet sözleşmesi](./HUMAN_REVIEW.md).

## ADR-015 — Ortak temel, iki hazırlık rotası

**Durum:** Önerildi; eğitimci/müfredat pilotu bekleniyor  
**Tarih:** 2026-10-11

Konservatuvar ve koro aynı core becerilerini paylaşır; sonra farklılaşır. Birlikte duyulan 3/4 sesi sırayla söylemek, başka partiler çalarken kendi partisini korumanın yerine geçmez. Öğrenme, sınav ve koro playback politikaları mod bazlıdır. Makam/usul/çalgı için yeterlilik iddiası ayrı kapsam/uzmanlık gerektirir.

## ADR-016 — Hazırlık puanı değil öğrenme kanıtı

**Durum:** Önerildi; mevcut skor/model henüz değiştirilmedi  
**Tarih:** 2026-10-11

Ölçülmeyen değer ve geçersiz kayıt öğrenci puanına katılmaz. Algı/üretim, ipucu, zorluk, görülmemiş soru, gecikmeli kontrol ve içerik sürümü ayrı tutulur. Evrensel konservatuvar/koro hazırlık yüzdesi, aralık genişliği yarışı veya otomatik kesin SATB ataması üretilmez. [İnceleme](./PRODUCT_AUDIT.md), [öğrenme modeli](./LEARNING_MODEL.md).

## ADR-017 — Güvenilirlik paketiyle uygulama başlangıcı

**Durum:** Kullanıcının başlama isteğiyle uygulandı; ses/pedagoji doğrulaması bekliyor  
**Tarih:** 2026-10-11

İlk paket REL-01–05: typed metrik durumları/sonuç v2, invalid kaydı puanlamama, metrik bazlı cohort gelişimi, monoton ritim event alignment ve ezgi placeholder'ı fail-closed. Pitch toleransları değiştirilmedi. JSON v2 şema sürümü açık; bu paket gerçek mikrofon/ezgi analizi veya canlı AI/ödeme/human review değildir. Tam provenance/sequence/mastery ve cihaz benchmark sonraki işler. [Uygulama kaydı](./IMPLEMENTATION_LOG.md).

## ADR-018 — Gerçek kaynak ayrımı ve dar ses formatı

**Durum:** İlk altyapı uygulandı; capture ve cihaz doğrulaması bekliyor  
**Tarih:** 2026-10-11

Protokol; birlikte referans/sıralı cevap ve recall/choir kurallarını ayrı taşır. Sonuç kanıtı deep snapshot'tır. Mock/synthetic/microphone/unverified ve analyzer sürümü gelişimde karıştırılmaz. Başlangıç formatı mono PCM16 WAV; sample rate header'dan doğrulanır. Sentetik tone gerçek insan holdout'unu karşılamaz. Referans piyano kayıtları kaynak/hak zinciri doğrulanmadan kopyalanmaz. Kayıt adaptörü için record/just_audio adaydır, henüz bağlanmadı. [Teknik durum](./AUDIO_TESTING.md).

## ADR-019 — Hedef bağımsız deneysel frame çekirdeği

**Durum:** Sentetik kod alt paketi uygulandı; algoritma seçimi gerçek benchmark ile doğrulanacak  
**Tarih:** 2026-10-11

İlk saf Dart çekirdeği YIN-style squared-difference, cumulative-mean normalization, ilk eşik altı yerel minimum ve parabolic lag interpolation kullanır. [YIN özgün makalesi](https://pubmed.ncbi.nlm.nih.gov/12002874/) kaynak referansıdır; tam makale PDF erişimi bu tur başarısız oldu. Tam YIN/best-local-estimate/temporal tracking eşdeğerliği veya yayımlanmış doğruluk sonucu iddia edilmez. Agora McLeod motorunun birebir port'u değildir; gerçek insan/cihaz benchmark'ında karşılaştırma bekler.

Detector hedef frekans almaz; oktav adayını hedefe yaklaştırıp başarı yaratmaz. Ayrı `PitchDeviation` raw Hz'yi değiştirmez. Periodicity, seçilen integer lag'deki 1−CMNDF'dir; insan sesi, doğruluk veya başarı olasılığı değildir. Sessizlik, clip, kısa/bozuk ve eşik altında aday bulunamayan veri puanlanmaz. 8–48 kHz ve en çok 8192 örnek pencere; unsupported rate resample edilmez. Eşikler deneysel sinyal kapılarıdır, mevcut pedagojik toleranslar değişmedi. Capture/VAD/aggregation/isolate ve source metadata caller'ın sonraki sorumluluklarıdır; mock ekran otomatik değiştirilmedi.

## ADR-020 — Kayıt diagnostics, voice/skor kanıtından ayrı

**Durum:** Kod/ünite/native isolate testli; VAD/cihaz ve session entegrasyonu bekliyor  
**Tarih:** 2026-10-11

`RecordingPitchEvidence` `PitchAnalysisResult` değildir: periodicFrameRatio tüm full-frame sayısını kullanır, elapsed-time coverage/human voiced ratio değildir. Hiç frame yoksa oran null, analiz edilmiş sessizlikte 0. Tek accepted frame'de dispersion null; ≥2'de population log-frequency std-dev, octave shifts korunur. Örtüşen pencereler bağımsız örnek/başarı denemesi sayılmaz. Representative lower median gerçek gözlenmiş Hz'dir; iki oktavın ortasına hayalî nota üretmez. Buna rağmen tek nota/ezgi segmentleme veya ses kimliği kanıtı değildir.

Kayıt bütçesi 8–48 kHz/10 sn/512 frame; target bağımsız detector defaults sabit, version config dahil. Regular half-hop + gerekirse tek end-anchor (tail sıfır doldurulmaz/atlanmaz); counts duration weighted değil. Native worker bounded snapshot/tek active iş; UI'da DSP fallback yok. [Dart Isolate.run resmi sözleşmesi](https://api.dart.dev/dart-isolate/Isolate/run.html) incelendi. Browser desteklenmez; worker hard cancel yok. Session owner eski sonuçları epoch ile reddetmeden capture/UI'ya bağlanmaz. Mevcut öğrenci başarı rubriği/toleransları değiştirilmedi.

## ADR-021 — Kalibrasyon ve kayıt kalite kapısı skordan önce

**Durum:** Kod/fake/widget testli (CAL-01); cihaz eşik doğrulaması (CAL-02) bekliyor  
**Tarih:** 2026-10-11

Ürün oturumunda her cevap kaydı pitch analizinden önce `CaptureQualityAssessor` kapısından geçer. Yalnız `usable` analiz edilebilir; sessizlik, kırpılma, düşük SNR, yetersiz etkinlik, referans kuyruğu şüphesi, geçersiz/kısa giriş ve eksik/bayat kalibrasyon **nötr yeniden deneme**dir, öğrenci hatası veya sıfır puan değildir. Kalibrasyon route imzası, sample rate ve yaşa (30 dk hipotezi) bağlıdır; biri değişince geçersizdir. iOS aktif route bildirir; Android yalnız mevcut cihaz listesini verdiği için route `inferred` olur ve politika `unverified` döner. Hoparlör+mikrofonda tek ses `sequentialOnly`: referans bitmeden cevap penceresi açılmaz ve ilk 150 ms içindeki enerji referans kuyruğu sayılır. Ritim her route'ta bağımsız ölçülmüş gecikme ister; ölçülmemiş gecikme sıfır kabul edilmez ve cevap otomatik kaydırılmaz. Hoparlörde rehberli koro partisi desteklenmez.

Eşikler (−45 dBFS taban, 12 dB burst yayılımı, 10 dB etkinlik marjı, 0,4 sn etkinlik, 15 dB SNR, %0,1 kırpılma, 150 ms tepki) **benchmark öncesi kayda geçirilmiş hipotezlerdir**; cihaz sonuçlarına bakılarak gevşetilmez, değişiklik gerekçeli ADR ister. Enerji etkinliği insan sesi tespiti değildir; VAD-01 ayrı iştir. Lab kalibrasyonsuz çalışabilir ama SNR/taban null ve etiketlidir.

## ADR-022 — Misafir-önce uygulama kabuğu ve yerel profil

**Durum:** Kod/widget testli (SHELL-01); kullanıcı testi (UXR-01) bekliyor  
**Tarih:** 2026-10-11

İlk değer için hesap yok (ADR-004 uygulaması): uygulama yükleniyor → hedef seçimi (konservatuvar/temel/koro) → home. Profil yalnız hedef ve oluşturma zamanını, uygulamaya özel dizinde atomik (temp + rename) JSON olarak tutar; e-posta, ses veya cihaz kimliği yok, sunucuya gitmez. Bozuk profil sessizce silinmez veya üzerine yazılmaz; yeniden dene ve açık “profili sil ve yeniden başla” sunulur. Home yalnız gerçekte var olanı gösterir: Deneysel (ses/ortam kontrolü), Simülasyon (tek ses sonuç örnekleri), Kayıt bekleniyor (2/3/4 piyano), Henüz yok (planlananlar). Ayarlar satın alma/abonelik/hesap olmadığını açıkça söyler. Sonuç renk token'larında yanlış oktav başarı rengi, geçersiz ölçüm hata kırmızısı değildir; 4,5:1 metin kontrastı birim testlidir. Tasarımın nihai kabulü kullanıcı testine bağlıdır.

## ADR-023 — Gecikme tahmini diagnostic; düzeltme ayrı fiziksel kapı

**Durum:** CAL-03a sentetik kod-testli; CAL-03b/cihaz ölçümü bekliyor.
**Tarih:** 2026-10-11, 21:40 TRT

`LatencyEstimate` LatencyCalibration değildir; otomatik conversion, öğrenci
skoru veya count-in açma yolu yok. Gözlenmiş ortak monoton saat gereklidir;
play() çağrısı/scheduled timestamp fiziksel duyulma anı sayılmaz. Trial eşleme
adapter sorumluluğudur; estimator öğrenci cevaplarından eşleme/shift üretmez.
Tap alignment insan motor yanlılığını içerir. Loopback output+capture+fiziksel
yayılım toplamını ölçebilir; bu toplam output→touch pipeline düzeltmesi olarak
taşınmaz. Bağımsız fiziksel protokol, clock mapping ve ölçüm belirsizliği gerekir.

Kod bütçesi 8–64 trial, 0–500 ms offset, JS-safe mikrosecond timestamp ve
strict chronology. Hipotezler: raw MAD≤5 ms, interpolated P90−P10≤20 ms,
retained≥8, rejected≤%25. Outlier uzaklığı max(10 ms, 3×1.4826×MAD).
Ham dağılım trimming sonrası saklanır; bozuk/negatif/oversize tail tüm batch'i
reddeder. Bu değerler öğrenci rubriği değildir, cihaz kabulüyle doğrulanmamıştır;
sonuçlara bakılarak gevşetilmez. Kaynak korunur; correctionEnabled her zaman false.

## ADR-024 — Solfej yaklaşımı: hareketli do

**Durum:** Kullanıcı kararı (2026-10-11); kod INT-01a'da uygulandı, eğitimci terminoloji onayı bekliyor
**Tarih:** 2026-10-11

Derece/aralık çalışmalarında **hareketli do** kullanılır: “do” her zaman o anki tonun ilk sesidir; ton soru başına değişir, böylece mutlak nota adı ezberi yardım etmez. Cevaplar hece (re, mi, fa, sol, la, ti, do') ile, aralık adı (büyük 2'li … tam 8'li) ikincil etiket olarak verilir; iki terminoloji karıştırılmaz. Mutlak nota adları (C4, Do4) yalnız tek ses/oktav gibi mutlak yükseklik görevlerinde kalır. İleride sabit do kullanan kurum şablonu gerekirse ayrı içerik sürümü ve açık etiketle eklenir; mevcut sonuçlarla aynı cohort'ta karşılaştırılmaz.

## Mevcut kararları değiştirme sınırı

Şu kararlar benchmark veya kullanıcı görüşmesi olmadan değiştirilmemeli:

- Pitch motorunun başarı toleransı.
- Ham ses saklama politikası.
- İlk hedef kullanıcı.
- Aboneliğin ücretsiz sınırı.
- Öğretmen ürününün MVP’ye girip girmemesi.
