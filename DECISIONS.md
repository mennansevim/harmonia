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

**2026-10-20 ONB-01 eklemesi:** İlk hedef seçimi draft olarak günlük
5/12/15 dakika adımına gider; kaydet veya süreyi değiştirmeden devam ile home.
Süre mevcut ayrı preferences schema1'inde kalır; profil şeması değişmez.
Settings hedef değişimi ve eski profiller bu adıma zorlanmaz. Süre başarı/
garanti değil, değiştirilebilir planlama tercihidir; UXR-01 açık.

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

## ADR-025 — 12TET hedef metadatasının tutarlılığı

**Tarih:** 2026-10-14. **Durum:** REL-06a kod/test; gerçek sample QA değil.

ExerciseProtocol'un 12TET beyanında her absolute target scientific C4/C#4/Db4
biçiminde olmalı (MIDI0–127). A4×2^((MIDI−69)/12) ile suppliedHz kontrol edilir;
absolute ≤0.005000001Hz yalnız iki ondalık yuvarlanmış metadata'yı korur.
Bu pay student/acoustic başarı rubriği değildir; 50cent/25cent/voiced gate aynı.
Enharmonic boundary octave carry uygulanır, wrong-octave folding yok. JSON v1
alanları değişmez, yeniden kuruluş aynı stricter guard'ı uygular. Legacy const
Exercise/mocked demo korunur; mevcut prototype metadata fallback üretilmez.
Movable-do cevap heceleri absolute target label yerine geçmez. Bu doğrulama
real sample tuning/clock/frequency, lisans, voice/device veya educator approval
kanıtı vermez; bu kapılar ayrı. Yeni reader'lar malformed hedefi sessiz düzeltmez.

## ADR-027 — Yerel günlük bildirim ve inexact Android zamanlama

**Tarih:** 2026-10-21. **Durum:** REM-01c kod/test/build; fiziksel cihaz QA bekliyor.

Günlük çalışma hatırlatması push veya sunucu yerine cihaz içi
`flutter_local_notifications` ile kurulur. Cihazın IANA bölgesi
`flutter_timezone`, DST güvenli takvim zamanı `timezone` ile belirlenir. Plugin
başlatılırken izin istenmez; yalnız kullanıcının saat seçip açması izin akışını
başlatır. Reddedilen izin sahte başarı üretmez ve OS bildirim ayarlarına açık
eylem sunar. Coordinator'ın native başarıdan sonra persist, persist hatasında
rollback ilkesi korunur.

Android'de dakikası dakikasına garanti gerektirmeyen çalışma alışkanlığı için
`inexactAllowWhileIdle` seçildi. Böylece `SCHEDULE_EXACT_ALARM`/
`USE_EXACT_ALARM` ve mağaza denetimli alarm yetkisi istenmez; OEM pil yönetimi
nedeniyle teslimat sapabileceği kullanıcı/QA sınırı olarak kalır. Tek kanal v1
ve tek sabit notification id kullanılır. Android reboot receiver ve iOS delegate
yerel yeniden zamanlama/sunum için bağlıdır. Build başarısı teslimat kanıtı
değildir; gerçek izin, saat, reboot, DST ve pil davranışı fiziksel iki platformda
geçilmeden özellik doğrulandı sayılmaz.

## Mevcut kararları değiştirme sınırı

Şu kararlar benchmark veya kullanıcı görüşmesi olmadan değiştirilmemeli:

- Pitch motorunun başarı toleransı.
- Ham ses saklama politikası.
- İlk hedef kullanıcı.
- Aboneliğin ücretsiz sınırı.
- Öğretmen ürününün MVP’ye girip girmemesi.

## ADR-026 — Arayüz yönü A+C (Yol + Atölye) ve gerçek veriye bağlı ses görselleri

**Tarih:** 2026-10-14 · **Karar veren:** kullanıcı (taslak seçimi)

Rakip kalıplarına dayanan üç taslaktan A (Duolingo Music / Simply Piano tipi
beceri yolu, kalın düğmeler, alttan açıklama paneli) ile C (EarMaster /
ToneGym tipi ince kartlar, veri etiketleri, kanıt odaklı sonuç ve rapor)
birleştirildi. Platform yazı tipleri (SF Pro / Roboto) kullanılır: Dynamic
Type, yerel işleme ve indirmesiz çevrimdışı çalışma için. Ses görselleri
yalnız gerçek veriye bağlanır: dinlemede çalınan WAV'ın kendi zarfı ve
örnekleri, kayıtta mikrofonun gerçek dBFS düzeyi. Görsel hiçbir zaman nota
doğruluğu veya puan ima etmez; hareket azaltma ayarında durağan gösterilir.
Sınırlı süreli animasyonlar (kare saatiyle), sonsuz döngü yok. Ölçüt,
tolerans ve skor kuralları değişmedi.

## ADR-028 — Mikrofon reddinde açık OS ayarları kurtarması

**Tarih:** 2026-10-21. **Durum:** SHELL-02 kod/test/build; fiziksel cihaz QA bekliyor.

Mikrofon izninin sahibi kayıt backend'i olarak kalır; ekran yüklenirken izin
istenmez. Tek ses, ezgi veya laboratuvar açık bir ret aldıktan sonra ortak kart
yalnız kullanıcının dokunuşuyla uygulama ayarlarını açar. Ayarların açılması izin
verildiği anlamına gelmez; kullanıcı döndüğünde kayıt eylemi izni yeniden
kontrol eder. Platform false/exception sonucu başarı gibi sunulmaz.

Adapter için MIT `permission_handler` 12.0.3 seçildi. 13.x compileSdk37 istediği
ve mevcut AGP9.0.1 en fazla36 önerdiği için platform araç zinciri yükseltilmeden
alınmadı. Android pasif status kalıcı reddi kesin ayıramadığından ürün sahte bir
kalıcı-ret sınıflaması üretmez; ayar eylemi gerçekleşmiş her ret sonrasında
güvenli çıkış olarak görünür. Fiziksel iki platform testi kabul kapısıdır.

## ADR-029 — Başlangıç kontrolü seviye üretmez

**Tarih:** 2026-10-22. **Durum:** SHELL-03a kod/test; SHELL-03b eğitimci/pilot bekliyor.

İlk kullanımda hızlı değer için yalnız mevcut güvenilir dokunma kaynaklı üç
egzersiz kullanılır: tiz/pes, düzenli puls ve ilk hareketli-do derece turu.
Mevcut scorer/cohort korunur; yeni eşik veya birleşik skor tanımlanmaz. Geçersiz
tur nötr yeniden denemedir, tek güçlü tur mastery değildir ve ölçülemeyen ses
üretimi/ezgi/çok sesli alanlar bilinmiyor kalır.

Eğitimci onaylı seviye bantları ve öğrenci kabul verisi olmadığı için domain'de
“başlangıç/orta/ileri”, konservatuvara hazır veya kabul puanı üreten bir alan
bulunmaz. UI yalnız üç turun durumu ile ilk çalışma odağını açıklar. Bu sınır,
SHELL-03b dış kapıları geçmeden gevşetilmemelidir.

## ADR-030 — “Devam et” tamamlanmış kanıttan yeni tur açar

**Tarih:** 2026-10-22. **Durum:** SHELL-04f kod/test; cihaz/offline kabulü açık.

“Kaldığın yerden devam” yalnız desteklenen güncel kohorttaki en son tamamlanmış
yerel denemeyi işaret eder. Kullanıcı dokunduğunda aynı egzersiz yeni bir turla
başlar. Yarım soru, rastgele tur durumu, player, ses buffer'ı, mikrofon route'u
ve izin durumu saklanmaz veya geri yüklenmez. Gelecek tarihli ve sürüm/provenans
eşleşmeyen kanıt fail-closed davranır. Böylece ürün devamlılık sunarken otomatik
ses/kayıt veya sahte ölçüm riski yaratmaz.

## ADR-031 — Yerel taşımada yalnız cihazdan bağımsız tercihler bulunur

**Tarih:** 2026-10-24. **Durum:** DATA-03c kod/test; gerçek iki cihaz QA açık.

Pano belgesi günlük çalışma süresi ve haftalık hedefi taşıyabilir. Hatırlatma
saati, notification izni/schedule ve titreşim yeni cihaza uygulanmaz; bunlar
platform izni, saat dilimi ve erişilebilirlik tercihine bağlıdır. V1 belgeleri
okunur, yeni belgeler strict v2 olarak yazılır.

Geçmiş ve tercih ayrı atomik dosyalardır. Sonuç batch'i önce uygulanır;
ardından tercih yazımı başarısız olursa bu kısmi durum kullanıcıya açıkça
bildirilir. Hesap/outbox/backend kararı olmadan cross-store transaction veya
bulut senkronu taklit edilmez.

DATA-03d ile yalnız başarılı tercih yazımı process-local revision artırır.
Bugün görünümü bu sinyalle cache'ini yeniler; Navigator/Home kimliği korunarak
seçili sekme sıfırlanmaz. Revision kalıcı senkron sürümü veya hesap revizyonu
değildir ve geç kalan eski async okumalar generation kapısıyla elenir.

## ADR-032 — Kulak eğitimi ikizi ana deneyim; Koro Atölyesi ayrı kategori

**Tarih:** 2026-10-29 · **Durum:** kısmen yerine geçti (ADR-033: tasarım ve akış farklılaştırıldı)

**Karar:** Uygulama girişi `TrainerApp` (5 dinleme eğitmeni: Öğren yolu + Pratik, istatistik, sıralama, ayarlar, kalıcı 30 adımlı onboarding). Harmonia'nın mikrofon/perde çekirdeği ve deneysel tekrar ekranları “Koro Atölyesi” kategorisinde toplanır. Eski `HarmoniaApp` kabuğu korunur ama açılışta kullanılmaz.

**Gerekçe:** Kullanıcı referans uygulamanın akışını birebir istedi; koro hazırlığı ayrı modül olarak eklenecekti.

**Sınırlar:** Marka/ad kopyalanmaz; ödeme, sahte yorum/istatistik, sahte lig oyuncusu yok. Dinleme quiz'leri yalnız dokunma cevabıdır (`touch`), mikrofon skoru değildir. Ses aralığı testi kalite kapısından geçmeyen kaydı “ölçülemedi” sayar; parti önerisi taslaktır. 2/3/4 sesli tekrar kayıtlar gelene kadar kapalı. Dinleme quiz sonuçları ayrı JSON'da tutulur, `ResultHistory`/mastery'ye yazılmaz (ritim ekranları kendi geçmişine yazmaya devam eder).

## ADR-033 — Referans uygulamadan farklılaşma: koro öncelikli Harmonia deneyimi

**Tarih:** 2026-10-29 · **Durum:** kabul (kullanıcı isteği: "kopya ibarelerini değiştirelim, tasarımı ve özellikleri farklılaştıralım")

**Karar:** Eğitmen modülü referans uygulamanın görünümünü ve akışını taşımaz. Görsel kimlik Harmonia A+C markasına geçti (indigo ana renk, güneş sarısı seri, beceri başına ayrı vurgu, alt kenarlı "chunky" buton, ince çizgili kartlar). Sekmeler Bugün / Koro / İlerleme / Ayarlar; Koro Atölyesi birinci sınıf sekme. 30 adımlı onboarding kaldırıldı; yerine 8 adımlı koro akışı (rol, parti, odak, nota adı, günlük süre, hatırlatma, plan). Sıralama/lig ekranı, istatistik kilidi, kullanıcı adı ve topluluk panosu kaldırıldı; yerine koro temalı yerel seviye kartı. Yeni özellik: seçilen parti (SATB) ders sesini öğrencinin aralığına taşır (tenor/bas bir oktav pes). Belirgin çeviri ifadeler Harmonia diliyle yeniden yazıldı.

**Sınırlar:** Parti yalnız çalma register'ını değiştirir; skor/tolerans/rubrik değişmez. Ses aralığı testindeki parti önerisi taslaktır; "partim olarak kaydet" kullanıcının seçimidir. Ders/quiz mekaniği (öğren-pratik, tanı/evet-hayır/bul soru tipleri, kontrol noktası) türün yaygın kalıplarıdır ama hâlâ referansa işlevsel olarak yakındır; mağaza öncesi ek farklılaşma ve referans sahibinin onayı ayrıca değerlendirilmelidir. Hukuki uygunluk görüşü değildir.

