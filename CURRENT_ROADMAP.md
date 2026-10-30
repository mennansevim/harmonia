# Harmonia — Current Roadmap

**Tarih:** 2026-10-30 (son güncelleme: CHOIR-A0 koro modülü)
**Durum:** Faz 1 — güvenilirlik sözleşmeleri, yerel kayıt laboratuvarı, deneysel DSP/worker, kalibrasyon/kalite kapısı ve misafir uygulama kabuğu kod-test seviyesinde. Tek ses skor ekranı hâlâ simülasyon; fiziksel cihaz, insan sesi benchmark'ı, eğitimci içerik onayı ve öğretim pilotu kapıları açık. **Hiçbir modül cihazda/pilotta doğrulanmış veya yayında değil.**
**Sahip:** Mennan Sevim  
**Platform:** Flutter mobil uygulama; ileride web ve öğretmen paneli

**2026-10-30 — CHOIR-A0 Koro modülü (kod + simülatör, ADR-036):** Kullanıcının anlattığı iş akışı uygulandı. Şef: koro oluşturur, tek ödevde birden çok eser, her eser için solfej/sözlü, ölçü aralığı veya yazılı bölüm, eşlikli kayıt isteği, MIDI + kanal→parti eşlemesi + hak beyanı, son tarih; dinleme sırası, 1/1,25× hız, ana işaret (nefes kaçağı dahil), etiket, yazılı yorum, kendi sesiyle not, kabul/tekrar iste. Korist: pakete katılır, ödev/eser/son tarih görür, MIDI ile çalışır (kendi partisi öne, diğerleri kısık, %50–120 hız, metronom, ön sayım, döngü), tek telefonda eşlikli kayıt alır, hizalama kaydırıcısıyla düzeltir, başka cihaz kaydını dosyadan ekler, şefe gönderir, geri bildirimi ve şefin sesini dinler, Personal çalışmaya geçer. Kaynaklar: nota, ders kaydı, not. Bugün sekmesinde en yakın son tarih. Sunucu yok: `.harmonia` paketleri kişinin kendi paylaşımıyla taşınır; paket boyut/şema/hash/kimlik denetimli, bozuksa hiçbir şey kaydedilmez. TR/EN metin, yerel saat dilimi, yaygın dillerde parti adı önerisi. Yeni bağımlılıklar: `file_picker`, `share_plus`, `archive`, `open_filex`, `flutter_localizations`. **1095 test geçti**, 1 opt-in atlandı; analyze/format temiz. iPhone 17 Pro simülatöründe `integration_test/choir_journey_test.dart` (gerçek `record` + `just_audio` ile aynı anda çalma/kayıt, miks, hizalama, paket gidiş-dönüşü) ve `app_journeys_test.dart` 6/6 geçti; ekranlar elle gezildi, simülatör hoparlör rotasında engel doğru çıktı. **Kapılar açık:** gerçek telefonda kulaklık, bleed, gecikme ve Bluetooth (CAL-03b, CHOIR-01), Android derlemesi, gerçek koro MIDI'si, gerçek şef/koro pilotu, hukuk metni, paket imzası/kimlik, sunucu kararı (K2), son tarih bildirimi, divisi, AAC sıkıştırma (kayıt WAV, ~5 MB/2 dk). Modül ürün olarak bitmiş değildir.

**2026-10-30 — AUDIO-01 kod kapısı:** Fixture manifesti → hash/header/sample
rate/count doğrulaması → PCM16 decode → hedef bağımsız pitch frame zinciri tek
entegrasyon sözleşmesinde sabitlendi. 256 örnekli kısa WAV dosya kapılarını
geçse bile `insufficientData` kalıyor ve Hz uydurmuyor; C4/C5 fixture'ları WAV
header saatini koruyup ayrı oktavlar olarak çıkıyor, C5→C4 karşılaştırması
`octaveOffset: 1` ve yaklaşık +1200 sent. İki yeni sentetik fixture testi var;
lisanslı/etiketli insan kaydı, VAD, mikrofon, cihaz veya öğrenci başarısı kanıtı
değil. **1043 test geçti**, 1 opt-in ekran turu atlandı; analyze/format temiz.

**2026-10-30 — DESIGN-02 (tasarım devri uygulandı):** `design-exports/harmonia-design-handoff.zip` taslağı mevcut trainer bileşenleriyle uygulandı. Bugün: gradyan rota kartı + süreye göre adımlar (HOME-02: ≤3 dk yalnız ders, ≤5 dk 1 dk nefes + ders, daha uzun 2 dk nefes + ders + Koro). Yeni `BreathScreen` (PREP-01): görsel/haptik, mikrofonsuz, duraklatılabilir, arka planda durur; yalnız günün adımını işaretler, seri/XP/mastery'ye yazmaz; 4/2/6 ritmi taslak, eğitimci onayı yok. Ders sonu (RESULT-02): skor kartı + ÖLÇÜLDÜ/ÖLÇÜLMEDİ/DENEYSEL kanıt kartları + açılır ayrıntı; “Yanlışları tekrar et” (RETRY-02a) karışan seslerle 3 yeni örnek sorar, `record:false`. Ertesi gün kalıcılık kontrolü yok. Ayarlar › Üyelik önizlemesi fiyatsız ve satın alma düğmesi kapalı (taslaktaki 249/799 TL kullanılmadı). Sekmeler korunuyor. 1012 test, analyze/format temiz; iOS 26.5 simülatöründe Bugün ve Nefes elle, sonuç/üyelik ekran turuyla görüldü. Gerçek telefon, kullanıcı ve eğitimci kabulü açık.

**2026-10-30 — IA-01b Personal dil ve iddia tutarlılığı:** Ekran turunda bulunan koro dili temizlendi: İlerleme seviyeleri rol-nötr (Dinleyici → Çırak → Kalfa → Usta → Üstat → Maestro; eşikler aynı), son 7 gün iki harfli gün adlarıyla (Bugün çubuğuyla aynı), Ayarlar “SES” bölümü / “Çalışma aralığım” / “Çalışma aralığı: Alto”, nota gösterimi “Solfej (Do Re Mi)” (♭ işareti hem anlamsızdı hem test fontunda kare çıkıyordu), Premium özelliğinden “Koro” çıkarıldı. SATB seçimi uygulamanın ölçmediği bir “ses tipi” değil yalnız çalışma aralığı olarak sunuluyor; aralık testinin eğitmen/şef kararının yerini almadığı korunuyor. Personal pitch/aralık/akor/yürüyüş müfredatı koro üyeliği veya parti seçimini varsaymıyor; çok ses sonucu gelecekteki piyano kayıtlarını doğru adlandırıyor. Domain testi bu sınırı, widget testi İlerleme/Ayarlar dilini koruyor. **1041 test geçti**, 1 opt-in ekran turu atlandı; analyze/format temiz. Ses motoru, SATB sınıflandırması, gerçek cihaz ve eğitimci kabulü değişmedi.

**2026-10-30 — CHOIR-M1 + MIDI-01 (kod, UI/sunucu yok):** `lib/choir/domain/`: `Choir`, `ChoirMember` (şefin partisi olamaz), süreli `Invite` (kişisel/ortak kod, iptal > süre > kota önceliği), `ReferenceAsset` + `RightsDeclaration` (hakkı `unknown` dosya ödeve konamaz), `Assignment` (SATB sırası, kayıt sınırı 10–600 sn, varsayılan 120), `Submission` durum makinesi (taslak → gönderildi → dinlendi → kabul / tekrar iste → yeniden kayıt; puan alanı yok; yalnız aynı koronun şefi değerlendirir), `Feedback` (metin veya etiket zorunlu; etiketin Personal alanı şefin yargısıdır), parti bazlı nötr takip (taslak = gönderilmedi; parti değiştiren koristin eski kaydı sayılmaz). Katı UTC JSON. `lib/choir/midi/smf_reader.dart`: SMF tip 0/1, PPQ bölümü; running status, vel-0 note-off, FIFO çakışan nota, asılı nota sayımı, tempo haritası → saniye, ölçü işareti → ölçü başları; SysEx/kontrol/bilinmeyen chunk atlanır; tip 2, SMPTE, bozuk/kesik/sınır aşan dosya `MidiFormatException`. Fixture'lar testte üretiliyor, dış dosya kopyalanmadı. 26 yeni test; tam paket 1039 geçti, analyze/format temiz. Bağlı ekran, sunucu, gerçek koro MIDI'si ve seslendirme yok.

**2026-10-30 — IA-01 + ONB-03 (ADR-035 uygulandı):** “Koro” sekmesi herkes için **Ses** sekmesi oldu (Ses Atölyesi: aynı ses aralığı, tek sesli, aksak, kaç ses, piyano yer tutucusu; etiketler değişmedi). Günlük rotanın son adımı “Ses” (`DailyRoute.voiceStep`, `route_voice`). Onboarding: karşılama kişisel çalışma diliyle; rol sırası bireysel → enstrüman → korist → şef, alt metin “koro modülü ayrı ve henüz hazır değil”; aralık (eski parti) adımı **Atla** ile geçilebilir, “Bilmiyorum” seçeneği kaldırıldı, seçili aralığa tekrar dokunmak temizler; odak seçeneği `koro` → `voice`. Hazır ekranındaki ses satırı artık odak seçimine değil gerçekten rotada ses adımı olup olmadığına bağlı (eski satır 3–5 dk'da yanlış söz veriyordu); korist/şef rolüne “Koro modülü henüz yok” satırı. Eski kayıtlar migration gerektirmiyor (`focus: koro` yok sayılır, `partAsked` artık okunmuyor). Rol hâlâ yalnız kaydediliyor, akışı değiştirmiyor. 1013 test geçti, 1 opt-in atlandı; analyze/format temiz; ekran turu görüntüleri elle kontrol edildi. Entegrasyon yolculukları iPhone 17 Pro (iOS 26.5) simülatöründe **6/6 geçti** (~1 dk 23 sn); gerçek cihaz/kullanıcı kabulü açık. Koro modülünün kendisi (davet, ödev, şef paneli) yok.

**2026-10-30 — Personal + Choir planı (plan, kod değil):** Kullanıcı kararı: koro ayrı modül; ses, nefes, kulak eğitimi tüm kullanıcılar için. Plan [PRODUCT_PLAN_PERSONAL_CHOIR.md](./PRODUCT_PLAN_PERSONAL_CHOIR.md)'de: tek uygulama/tek hesap, Personal ana kimlik, davetli Koro modülü + Flutter web şef paneli (ADR-035). Choir C1 (koro, davet, parti, referans ses, ödev, kayıt gönder, şef dinleme kuyruğu) AI/ölçüm gerektirmez ama sunucu/hesap/upload/hukuk ister — repoda hiçbiri yok. C2 MIDI parti çalışması, C3 otomatik değerlendirme BENCH/VAD/CHOIR-01 kapılarına bağlı. 999 TL/koro örneği KDV ve kanal kesintisiyle ≈700–800 TL katkıya düzeltildi. Kullanıcı kararı bekleyenler: şef görüşmeleri, backend, reşit olmayan koristler, ödeme kanalı, pilot koro. Kararsız başlanabilecek kod: IA-01/ONB-03, CHOIR-M1 domain, MIDI-01 okuyucu.

**2026-10-29 — Ürün yönü (plan, kod değil):** Dış LLM rakip/gelir önerisi değerlendirildi; 90 günlük faz planı, kabul/uyarla/ret listesi ve KDV dahil düzeltilmiş gelir hesabı [PRODUCT_ROADMAP_90D.md](./PRODUCT_ROADMAP_90D.md)'de. Önerilen sıradaki kod işleri HOME-02 (süreye göre tek rota) → PREP-01 (ölçümsüz nefes) → RETRY-02 → RESULT-02; kullanıcı kararları §7'de bekliyor.

**2026-10-29 — E2E-01:** `integration_test/app_journeys_test.dart` ile uygulama gerçek kullanıcı gibi, production kablolamasıyla (dosya depolama, gerçek ses çalma, eklentiler) simülatörde uçtan uca test ediliyor: onboarding + sekmeler + soğuk yeniden başlatma, yarım onboarding'e dönüş, bugünkü ders + kalıcılık, 8 soruluk perde pratiği sonuna kadar, Koro aralık girişi + kaç ses, verileri sil. iPhone 17 Pro (iOS 27) simülatöründe **6/6 geçti** (~1 dk 22 sn). Komut: `flutter test integration_test -d <id>`; `quality_check` yalnız formatını kontrol ediyor (1004 kod testi + analyze/format temiz). Mikrofon, bildirim izni sistem penceresi, duyulan ses, gerçek telefon ve insan kullanıcı kapsam dışı; cihaz/pilot kapıları açık.

**2026-10-29 — TRAINER-03 (ADR-034):** Ders yolu, quiz, ders akışı, müfredat sırası/metinleri, oturum sonu ve istatistik ekranları da Harmonia'ya özgü yeniden yazıldı (Basamak/Ara durak/Konser provası; Dinle → Söyle → Ayırt et; dinleme diski). Referans uygulamadan kalan metin/düzen yok; tür ortak.

**2026-10-29 — TRAINER-04a:** Pitch eğitmeninin isteğe bağlı “Söyle” adımı için UI'dan bağımsız, puansız session composition eklendi. Dersin item/bölge/parti/tını hedefi immutable MIDI+Hz referansına bağlanıyor; sentetik referans ayrı player'dan, cevap mevcut kalibrasyon/kalite/worker kapılı tek-ses oturumundan geçiyor. Çıktı yalnız tanısal candidate evidence; ders tamamlama, store, history, mastery veya unlock yazımı yok. 7 yeni testle tam paket 1000 geçti, 1 opt-in ekran turu atlandı; analyze/format/diff temiz. UI wiring, fiziksel cihaz ve insan sesi BENCH/VAD kapıları açık.

**2026-10-29 — TRAINER-04b:** Pitch dersi “Söyle” sayfasına isteğe bağlı ses kontrolü bağlandı. Ekrana giriş izin/mikrofon açmıyor; öğrenci ortam ölçümünü açıkça başlatıyor, referansı dinleyip söylüyor, yalnız kaynak etiketli tanısal sent farkı görüyor ve her an puanlı “Ayırt et” bölümüne geçebiliyor. Arka plan/çıkış denemeyi iptal ediyor, otomatik devam yok; kurulum hatası nötr ve atlanabilir. Diğer eğitmenlerde ve `liveAudio=false` test/preview'da kapalı. 4 widget testiyle tam 1004 test geçti, 1 opt-in ekran turu atlandı; analyze/format/diff temiz. Gerçek telefon, insan sesi, audibility, VAD/BENCH ve eğitimci kabulü açık.

**2026-10-29 — TRAINER-02 (farklılaşma, ADR-033):** Eğitmen modülü artık Harmonia görsel kimliğinde ve koro öncelikli: Bugün / Koro / İlerleme / Ayarlar sekmeleri, 8 adımlı koro onboarding'i (rol, parti, odak), lig/kilit/kullanıcı adı kaldırıldı, seçilen parti dersleri öğrencinin aralığında çalar. Ders/quiz mekaniği hâlâ türün ortak kalıbında; cihaz/insan sesi/yayın kapıları açık.

**2026-10-29 — TRAINER-01 (ana deneyim değişti):** Uygulama artık `lib/trainer/` altındaki kulak eğitimi ikiziyle açılıyor (5 eğitmen, Öğren/Pratik, İstatistik, Sıralama, Ayarlar, kalıcı onboarding) ve **Koro Atölyesi** (ses aralığı testi, dinle-söyle, ezgi, ritim, aksak ritim, kaç ses?) ayrı kategori. Ödeme/hesap/lig sunucusu yok; ekranlar bunu açıkça söylüyor. Tam paket 978 test geçti, analyze/format temiz; iOS arm64 simülatör derlemesi başarılı. **Güncelleme (aynı gün sabah):** simülatör onarıldı, Flutter 3.47.8; `flutter run` iPhone 18 Pro (iOS 27) simülatöründe çalıştı. Ana sayfa, pratik quiz'i, ipucu sayfası, Koro Atölyesi ve mikrofonlu ses aralığı testi (izin → kayıt → çekirdek analiz → “ölçülemedi” kapısı) elle doğrulandı; 992 test geçti. Gerçek iPhone'da, insan sesiyle ve sesi kulakla dinleyerek test yapılmadı. Ayrıntı: IMPLEMENTATION_LOG “TRAINER-01”, ADR-032.

**Son kod doğrulaması (2026-10-29):** TRAINER-04b, TRAINER-04a'nın puansız pitch production session'ını yalnız açık kullanıcı eylemiyle dersin “Söyle” sayfasına bağlıyor. Kalibrasyon/dinleme/cevap/analiz durumları açıklanıyor; fake kaynak microphone'a yükseltilmiyor; sonuç store/history/mastery/completion/unlock'a yazılmıyor. Background/çıkış session'ı kapatıyor, production factory hatası öğrenciyi kilitlemiyor. Tam 1004 test geçti, 1 koşullu ekran-turu testi atlandı; analyze, format ve diff temiz. Gerçek cihaz/insan sesi BENCH-VAD ve öğretim kabulü hâlâ açık kapı.

**CAL-03a:** Ortak gözlenen saat, route/rate bağlamı ve 8–64 trial doğrulanır; medyan/MAD/ham P90–P10, aykırı trial indeksleri ve çekimser durumlar raporlanır. Planlanan playback timestamp'i duyulmuş klik değildir; mixed clock ve inferred route reddedilir. Tap hizalama motor yanlılığını içerir; loopback toplam gecikmesi dokunma pipeline'ına taşınamaz. Bu diagnostic **LatencyCalibration üretmez, ritim düzeltmez ve count-in açmaz**. Gerçek ölçüm adapter'ı/protokolü CAL-03b ve cihaz kapısı açık.

**LEARN-01a (22:05 TRT, ayrı oturum):** taslak beceri grafiği (15 düğüm; önkoşul, döngüsüzlük ve rota kuralları doğrulanır), kanıta dayalı durum merdiveni (ölçülmedi → çalışılıyor → destekle → bağımsız → sonraki gün korundu) ve hedefe göre filtrelenen “Beceri haritası” ekranı. Yalnız ritim düğümleri uygulamada ölçülüyor; diğerleri dürüstçe “henüz ölçülmedi”. 436 test (CAL-03a'nın 21 testi dahil), analyze/format temiz. Eğitimci onayı yok; kilit yok.

**PERC-01 (23:00 TRT):** “Tiz mi, pes mi?” dinleme çalışması — 8 sentetik ton çifti/tur, dengeli (her zaman aynı düğme = %50), tohumlu; cevap dokunmayla, mikrofon/DSP yok; şans düzeyi ekranda. Sonuç `touch` kaynaklı, `dimension: perception`, accuracy ölçülü, timing/stability uygulanamaz. Beceri grafiğinde “Tiz / pes ayırt etme” artık ölçülüyor (200 ve 100 cent seviyeleri, taslak ölçüt: art arda iki tur ≥7/8). Değerlendirici ortak `MeasuredExercise` arayüzüne taşındı. 448 test, analyze/format temiz. **iOS simulator build bu turda araç hatasıyla düştü** (Flutter `debug_unpack_ios` mimari kontrolü; framework doğru mimarileri içeriyor; motor önbelleği derleme sırasında yeniden yazıldı, aynı anda başka ajanın test süreci açık) — kod değişikliğinden kaynaklandığına dair kanıt yok, `flutter clean` diğer ajan bitince denenmeli.

**LEARN-03b (23:10 TRT):** Home “Bugünkü öneri” artık beceri grafiği üzerinden, hedefin rotasındaki **tüm ölçülen egzersizleri** (tiz/pes + ritim) kapsıyor: vadesi gelen kalıcılık kontrolü → rotadaki ilk tamamlanmamış ölçülebilir çalışma (tekrar/yeniden dene/sıradaki) → tamam. Ölçülemeyen önkoşullar engellemez. Algı turunda kalıcılık kontrolü = her çift tek dinleme, sonuç işaretli. 454 test, analyze/format temiz.

**iOS simulator build (2026-10-13 22:10 güncel):** Flutter 3.47.7 + Xcode 27.0 ile `flutter build ios --simulator --debug` başarılı; eski Xcode 26.6/Flutter 3.44.4 lipo engeli kapandı. iOS minimum hedef 15.0. Elle gezinti ve gerçek cihaz testi yapılmadı.

**INT-01a (23:30 TRT, ADR-024 hareketli do):** “Dereceyi bul” dinleme çalışması — her soruda tonik bağlamı (do–mi–sol), sonra do → hedef derece; ton soru başına değişir; cevap hece + aralık adı; seçenekler dengeli; şans düzeyi ve en çok karışan derece çifti gösterilir; 3 taslak seviye. Sonuç `Skill.interval`, `solfege: movable_do`, algı boyutu. Beceri grafiğinde “Tonik ve dereceler” ölçülüyor (ilk iki seviye, ≥7/8 × 2); günlük öneri rotada buraya ulaşır. 466 test, analyze/format temiz. Eğitimci terminoloji/içerik onayı yok; iOS simulator build engeli (Xcode lipo) sürüyor.

**2026-10-14 11:55 TRT — REL-09 / OPS-01a:** Beta kanalı, uygulama adı, release
imzalama yapılandırması, iOS gizlilik manifesti, yerel hata günlüğü. iOS simulator
ve Android debug APK build başarılı; gerçek cihazda çalıştırılmadı. Yayın açıkları:
[RELEASE_READINESS.md](./RELEASE_READINESS.md).

**2026-10-14 — UI-01 A+C:** Seçilen tasarım uygulandı (ayrı dal): alt sekmeli
kabuk, beceri yolu, yeni egzersiz ve rapor ekranları, gerçek veriye bağlı ses
görselleri, ikon ve açılış ekranı. Simulator'da açık/koyu kontrol edildi;
gerçek cihaz ve kullanıcı testi yapılmadı.

## Kalan işler — 2026-10-15 (A+C arayüz birleştirmesi sonrası)

Tür: **K** kodla yapılabilir · **Ka** kullanıcı kararı · **D** dış kaynak/insan/cihaz.
Ayrıntılı yayın açıkları: [RELEASE_READINESS.md](./RELEASE_READINESS.md).

**Arayüz (UI/UX)**
- [x] K — GROW-01a/b/c / F27: son7 gün çalışma dökümü, gönüllü 2/3/4/5 gün
  hedefi (günlük seri ve beceri puanından ayrı), desteklenen geçerli turlardan
  yerel takvim. Hedef yok seçeneği, değiştir/kapat, single-flight hata koruması
  ve v1→v2 yerel tercih migration'ı testli. REM-01c izinli yerel hatırlatmayı
  hedefi ve Gelişim ekranında önceki 7 günle çalışma hacmi/egzersiz kırılımı.
  Karşılaştırma öğrenme veya beceri artışı değildir. REM-01c hatırlatmayı
  kod/build seviyesinde bağladı; fiziksel teslimat cihaz kapısıdır.
  Üç ticari referansın diğer farkları ve sırası [benchmark](./COMMERCIAL_BENCHMARK_2026-10.md)
  tablosunda; aile/lig/ticari katalog çekirdek yayını engellemez.
- [x] K — Tek ses sonuç örnekleri A+C düzene taşındı (UX-02k): açık
  simülasyon shell, örnek puan etiketi, nötr invalid ve tema renkleri;
  yardım/noauto/tek işlem/hata/retry/dispose testli. Gerçek mikrofon/puan
  pipeline'ı değildir; geçmişe veya mastery'ye yazmaz.
- [x] K — Ses laboratuvarı A+C düzene taşındı (UX-02j): puansız shell,
  phase kontrolleri, açılır kayıt/gizlilik rehberi, kalite/diagnostic kartları.
  Gerçek seviye göstergesi yalnız capture fazlarında; human voice/cihaz QA
  sayılmaz. Kayıt/silme/worker/lifecycle sözleşmeleri aynı.
- [x] K — Ayarlar A+C kart düzenine taşındı (UX-02i): kısa görünür
  durumlar/açılır rehberler, erişilebilir bölüm başlıkları ve neutral eylemler.
  Profil silme geçmişi silmez; açık onay/çift işlem kilidi, pano hata/retry
  testli. Gerçek cihaz panosu/ekran okuyucu kabulü açık.
- [x] K — Çalışma geçmişi A+C kart düzenine taşındı (UX-02h): açık ölçüm
  kaynağı, karşılaştırma yardımı, büyük yazıya uygun kartlar. Beceri/sürüm/kaynak
  grupları ayrı; kronolojik son3 ve eksik alanlarda çekimser sunum. Yerel
  liste/silme onayı korunur; gerçek cihaz/ekran okuyucu kabulü açık.
- [x] K — Günlük plan A+C düzenine taşındı (UX-02g): taslak shell, açılır
  kurallar ve contextual blok eylemleri; bütçe/geçerli tur/free minutes
  korunur. Öğretim etkisi ve süre/tekrar ölçütleri gerçek pilot bekliyor.
- [x] K — Tek ses oturumu A+C düzenine taşındı (UX-02f): puansız shell,
  phase tabanlı kontrol ve canlı seviye korunur. Gerçek nota kararı/puan
  hâlâ VAD/BENCH/cihaz kapısına bağlı; yalnız UI kod/widget doğrulaması.
- [x] K — Veri taşıma A+C düzenine taşındı (UX-02e): yerel/puansız shell,
  açık onay ve pano hata/retry; çift işlem kilidi. Gerçek cihazlar arası
  pano doğrulaması açık; DATA-03b toplu sonuçları tek atomik dosya commit'inde
  uygular ve yazma hatasında kısmi önek bırakmaz. DATA-03c günlük süre/haftalık
  hedefi v2 ile taşır; hatırlatma/titreşim cihazda kalır. DATA-03d başarılı
  importu açık Bugün görünümüne yeniden başlatmadan yansıtır ve seçili sekmeyi
  korur. Ses/bulut aktarımı yok.
- [x] K — Piyano yer tutucusu A+C düzenine taşındı (UX-02d): kapalı shell,
  açılır akış ve altı disabled eylem; katalog retry recovery testli. Kayıt,
  hak/nota/kalite QA ve gerçek 2/3/4 modülü hâlâ bekliyor.
- [x] K — Mikroders okuyucu A+C düzenine taşındı (UX-02c): taslak/puansız
  lesson shell, özgün beş faz, açılır ders bilgisi ve geri dön. Okuma
  completion/mastery değildir; içerik/eğitimci ve gerçek cihaz kabulü açık.
- [x] K — Kısa ezgi oturumu A+C düzenine taşındı (UX-02b): kısa yönerge,
  açılır yardım, ChunkyButton, puansız lesson shell. Kod/widget doğrulaması;
  gerçek cihaz ve kullanıcı kabulü değildir.
- [x] K — Bu listede adı belirtilen kalan ekranların A+C migration'ı
  tamamlandı (UX-02b–k). Bu, aşağıdaki ek UX işleri veya cihaz/kullanıcı
  kabulünün tamamlandığı anlamına gelmez. REVIEW-01a/b görsel döküm ve
  karşılaştırmalı sentetik playback kod-test hazır; gerçek playback/cihaz/
  ekran okuyucu/eğitimci kabulü ayrı açık. Sıradaki kod işi GROW-01b.
- [x] K — CORE-04c2b seçili ezgi dinleme ekranı: elle aralık/tekrar, parent
  session close→fresh player→route replacement; child close doğrulanmadan
  geri dönüş yok. Skor/history/mastery'ye bağlanmaz. Cihaz/focus/EDU QA açık.
- [x] K — ONB-01 günlük süre adımı (5/12/15): seçim ve kaydet ayrı;
  süreyi değiştirmeden devam mevcut tercihi korur. Kısmi hata/retry/back/
  pending/dispose testli. Kullanıcı kabulü UXR-01 hâlâ açık.
- [x] K — Tur sonu ekranı: "ne duydun / ne seçtin / doğrusu" yan yana ve
  karşılaştırmalı tekrar dinleme (rakip araştırmasındaki en güçlü fark).
  REVIEW-01a görsel döküm iki algı modülünde hazır: sekiz soru, açık doğru/farklı/
  cevap yok etiketi, çalınan sentetik örnek ve dokunma cevabı. Dar/büyük yazıda
  alt alta, genişte yan yana; ses kaydı/söyleme kanıtı değil. REVIEW-01b:
  açık dinle/durdur kontrolleri, son istek kazanır, pending-load/stop/close
  sıralaması, sonuç/history/retention koruması, lifecycle ve fail-closed route
  çıkışı fake/widget testli. Gerçek cihaz/playback/audio-focus/eğitimci kabulü D.
- [x] K — RETRY-01a: tiz/pes ve derece sonuçlarından yalnız yanlış sorularla
  kısa hedefli tekrar. Açık kullanıcı eylemi, aynı öğe/tonik, normal geri
  bildirim; history/mastery/retention/sınav kanıtından ayrı ve `toResult`
  fail-closed. Ritim/ezgi segment hedefleme F09 genişlemesi olarak açık.
- [x] K — RETRY-01b: ritim zaman çizgisindeki ilk görünür hatayı komşu
  referans vuruşlarıyla kısa kesite çevirir; kullanıcı başlatır, özgün tempo ve
  olaylar korunur. Kesit sonucu açıkça puansızdır; history/mastery/next-step'e
  yazılmaz ve domain kaydı reddeder. Ezgi tarafının güvenli diagnostic alt
  paketi RETRY-01c ile eklendi; gerçek hata/öğrenme kanıtı dış kapıda.
- [x] K — RETRY-01c: kısa ezgi diagnostic frekans adaylarıyla referans sırayı
  sembolik karşılaştırır; ilk farklı referans için iki seslik bağlamı puansız
  dinlemeye ön seçer. Kullanıcı açıkça başlatır; otomatik oynatma, skor,
  history, mastery veya hafıza sonucu yoktur. VAD/benchmark/eğitimci kapısı
  geçilmediği için “hata” değil deneysel aday bölümü olarak gösterilir.
- [x] K — F06a/b hata sonrası kavram tekrarı: hatalı tiz/pes, ritim ve
  tonik/derece sonuçlarından ilgili mevcut metin taslağına isteğe bağlı geçiş.
  Otomatik ses yok; okuma history/skor/mastery/sonraki adımı değiştirmez.
  Eğitimci onaylı örnekler ve öğretim pilotu olmadan F06 tamamlanmış değildir.
- [x] K — HOME-01: ana sayfada durağan yükleme iskeleti; tek semantik
  bildirim, dekoratif şekiller erişilebilirlik ağacından hariç. Yükleme/hata
  sırasında eski seri/beceri yolu/öneri gizli; açık retry ile toparlanır.
  İki tema, büyük yazı ve hareket azaltma widget testli; cihaz kabulü değil.
- [x] K — REM-01a: günlük hatırlatma saatini diğer tercihlerden bağımsız
  saklayan v3 migration, izin/schedule/cancel portu ve fail-closed coordinator.
  Native işlem doğrulanmadan yerel başarı yazılmaz; production fallback açıkça
  unavailable. Plugin, izin metni, ayarlar UI'sı ve cihaz testi hâlâ açık.
- [x] K — REM-01b: ayarlarda saat seç/aç/değiştir/kapat kabuğu ve dürüst
  unavailable durumu. İzin yalnız kullanıcı eyleminden sonra; pending/failure
  durumları açık, sahte başarı yok. Production native adapter/cihaz QA açık.
- [x] K — HAPTIC-01: varsayılan açık dokunuş geri bildirimi tercihi, v3→v4
  migration ve mevcut buton/cevap/yol/ritim titreşim çağrılarında ortak kapı.
  Kaydetme öncesi UI yayınlamaz; hata önceki değeri korur. Fiziksel cihazda
  titreşim davranışı D kapısıdır.
- [x] K — REM-01c: native günlük hatırlatma adapter'ı, cihaz saat dilimi,
  açık kullanıcı eyleminde izin, inexact Android alarmı, reboot receiver,
  iOS delegate ve izin reddinde bildirim ayarlarına geçiş. Unit/widget testleri
  ile Android debug ve iOS simulator build geçti.
- [ ] D — Hatırlatma fiziksel cihaz QA: gerçek iOS/Android izin diyaloğu,
  seçilen saatte teslimat, yeniden başlatma/DST/OEM pil kısıtı ve ayarlardan
  geri dönüş. İncelenmiş ürün metni de bu kapıda son kez onaylanır.
- [x] K / [ ] D — UI-01b iOS koyu ve renklendirilmiş (tinted) 1024 px ikon
  varyantları: modern tek-boyut catalog, saydam koyu ve gri tonlu tinted kaynak,
  asset/test/`actool` doğrulaması hazır. Fiziksel iOS görünümü, profesyonel ikon
  tasarım kabulü ve mağaza ekran görüntüleri hâlâ açık.
- [ ] D — Kullanıcı testi (UXR-01: ≥5 öğrenci + 1 eğitimci); "rakiplerden
  daha kullanışlı" iddiası ancak bununla kanıtlanır.
- [ ] D — VoiceOver/TalkBack ile elle erişilebilirlik testi; gerçek iPhone
  ve Android cihazda gezinti (şimdiye kadar yalnız simulator ve otomatik
  kılavuz testleri).

**Ürün ve ölçüm (değişmedi, dış kapı bekliyor)**
- [ ] D — Gerçek tek ses/ezgi sonucu: etiketli izinli kayıtlar (BENCH-01),
  ses etkinliği doğrulaması (VAD-01), cihaz route matrisi (CAL-02).
- [ ] D — Sayaçlı ritim için fiziksel gecikme ölçümü (CAL-03b).
- [ ] D — Eğitimci içerik/ölçüt onayı (EDU-01); 2/3/4 sesli piyano kayıtları.
- [x] K — SHELL-02 mikrofon ret kurtarma: açık retten sonra üç kayıt ekranında
  OS uygulama ayarları eylemi; otomatik prompt yok, hata ve single-flight testli.
  Gerçek iOS/Android kalıcı ret ve ayarlardan dönüş D cihaz kapısıdır.
- [x] K — SHELL-03a başlangıç kontrolü: yeni öğrenci için isteğe bağlı üç
  güvenilir dokunma turu, yerel geçmişten devam, hata/retry ve açıklamalı pratik
  odağı. Ölçülemeyen beceriler bilinmiyor; toplu seviye/ready skoru yok.
- [x] K — SHELL-04f güvenli devam: desteklenen güncel kohorttaki son yerel
  denemeden aynı çalışmanın yeni turuna döner. Yarım soru/player/mikrofon
  restore edilmez; otomatik ses/kayıt yok; stale/future kanıt fail-closed.
- [x] K — SHELL-04g ana ekran ön plan yenilemesi: yalnız gerçek arka
  plan→ön plan dönüşünde yerel kanıt tekrar okunur. `inactive` kesintisi ve
  yinelenen `resumed` görmezden gelinir; beklemede eski öneri/eylem gizlenir.
  Ses/egzersiz otomatik açılmaz; gerçek cihaz lifecycle kabulü açık.
- [x] K — SHELL-04h ortak consumer sınırı: aynı güvenli yenileme Today,
  günlük plan, beceri haritası ve çalışma geçmişinde tek yardımcıyla uygulanır.
  Yalnız yerel read projection yenilenir; yazma, rota açma ve media resume yok.
- [x] K — SHELL-04i dependency replacement: plan, harita ve geçmişe yeni
  repository/hedef/tercih verilince eski projection hemen gizlenir ve yeni
  kaynak yüklenir. Hesap/sync veya otomatik media davranışı eklenmez.
- [x] K — SHELL-04j Today tercih dependency replacement: repository kimliği
  revision'dan bağımsız izlenir; yeni store günlük süre/haftalık hedefi yeniden
  yükler ve eski store'un geç sonucu generation kapısında elenir.
- [x] K — SHELL-04k bekleyen tercih yazımı izolasyonu: store değişimi eski
  haftalık hedef save durumunu görünümden ayırır; geç başarı/hata yeni store
  hedefini, loading veya hata mesajını değiştiremez.
- [x] K — SHELL-04l tercih projection'ı fail-closed: store kimliği değiştiği
  anda önceki store'un günlük süre/hedefi gizlenir; yeni okumalar beklerken
  12 dakika/hedefsiz güvenli varsayılan gösterilir, geç eski okuma elenir.
- [x] K — SHELL-04m tercih okuma hatası matrisi: yeni store'un günlük süre
  okuması başarılı, haftalık hedef okuması hatalı olduğunda alanlar bağımsız
  sonuçlanır; eski hedef geri gelmez, UI nötr yükleme uyarısı verir ve hedefsiz
  kalır. Eski generation hataları yeni görünümde uyarı da yayınlayamaz.
- [x] K — SHELL-04n tercih retry recovery: güncel read failure için açık
  yeniden yükleme eylemi vardır; otomatik retry yoktur. Eylem yalnız bağlı
  store'u yeniden okur, başarıda yeni hedefi gösterir ve uyarıyı kaldırır.
- [x] K — SHELL-04o tercih yükleme/yazma kapısı: yeni store'un günlük süre ve
  hedef okumaları sonuçlanana kadar hedef seçimleri pasiftir ve “yükleniyor”
  görünür; tamamlanınca seçimler tekrar açılır. Bekleyen okuma ile save yarışmaz.
- [ ] D — SHELL-03b eğitimci onaylı seviye tanımları ve öğrenci kabul testi;
  bunlar olmadan başlangıç kontrolü yerleştirme veya sınav hazır oluşu değildir.
- [ ] Ka — Uygulama kimliği, sunucu/hesap (DATA-01), hata izleme servisi
  (OPS-01), ücretli API (AI-01), mağaza ve ödeme (PAY).

**Süreç**
- [ ] Ka — Otomatik ajan ana dalda commit'siz çalışmaya devam ediyor; büyük
  arayüz değişikliklerinden önce durdurulmalı veya ayrı dalda çalışmalı
  (2026-10-15 birleştirmesinde home_screen ve belge çakışması çıktı).

## Modül envanteri (A–Q) — kanıt durumu

**2026-10-14 15:39 TRT — REL-06b:** Protokol JSON exact fields/types/enums;
integer schema1, both≤256 event preflight, safe format errors/no partial prefix.
10 new tests, 636 suite. Valid round-trip/scorer aynı; REL-06 tüm session/hint/
cohort veya actual audio/etiket/rights/device acceptance değil.

**2026-10-14 10:36 TRT — REL-06a:** Hedef scientific nota/MIDI/frekans/A4
tutarlılığı ExerciseProtocol constructor + JSON reconstruction'da doğrulanır.
İki ondalık metadata rounding payı, öğrenci pitch toleransı değil. 10 yeni
test, 626 full suite. Gerçek sample/audio/tuning/hak/device QA ve REL-06 tüm
session/hint/cohort kabulü hâlâ açık; legacy demo/scorer değiştirilmedi.

**2026-10-14 05:35 TRT — SHELL-04d:** Beceri haritası geçmiş hatasında
“Durum alınamadı” gösterir; notMeasured/boş geçmişe dönüştürmez. Rapor/focus
kapalı, manual retry; draft okuma erişilebilir ve mastery yazmaz. 4 yeni
widget test, 616 full suite. SHELL-04 tüm consumer/resume ve dış kabulü değil.

**2026-10-14 00:13 TRT — SHELL-04c:** Günlük plan ortak loading/error/empty,
manual retry ve korunmuş bütçe. Immediate future failure next-frame gap
giderildi; error UI görünür, fake success plan yok. 3 yeni widget test, 612 full.
Session resume/tüm consumer migration ve gerçek device/pilot kapıları ayrı.

**2026-10-13 21:30 TRT — DATA-03a / LEARN-04a / SHELL-04a:** Ayarlar →
"Verilerini taşı" (ses-siz JSON panoya; strict import, çakışma korunur);
beceri haritasında rapor kartı (sayılar, bilinmeyen ≠ zayıf, tek hedef, yüzde
yok); günlük bütçe cihazda hatırlanır. 22 yeni test, 596 suite.

**2026-10-13 20:45 TRT — LEARN-03c:** Home'da Deneysel "Günlük çalışma
rotası": 5/12/15 dk plan; kalıcılık kontrolü (1/3/7/14 gün kuyruğu) → zayıf
tekrar → yeni; gün içi sabit plan ve tur ilerlemesi; boş süre açıkça yazılır.
19 yeni test, 574 suite. Süreler/aralıklar taslak; eğitimci ve öğrenme pilotu
kapısı açık. Mastery eşikleri değişmedi.

**2026-10-13 19:17 TRT — LEARN-02c:** Sürümlü draft-only JSON codec;
strict fields/types/enums/budgets, graph/phase/held-out ID yeniden doğrulama,
no accepted prefix ve sanitized parser error. 11 yeni test, son full 555.
Automatic file/asset/import UI veya gerçek onay yok. Sonraki LEARN-03 süreli
5/12/15dk günlük plan, taslak süreler/öğretim kapısı ayrı.

**2026-10-13 14:17 TRT — LEARN-02b:** Beceri haritasından iki taslak mikroders
okunuyor; görünür onay/örnek bekleme, beş faz ve algı/üretim. Practice disabled,
audio/mic/history/mastery/completion yok. 6 widget testi, 544 full suite;
okuma pedagojik kazanım değil. Sonraki LEARN-02c versioned strict JSON draft
katalog/import kapısı; EDU-01 gerçek onay ve örnek bankası hâlâ açık.

**2026-10-13 09:15 TRT — LEARN-02a:** Mikroders beş faz ve skill/route/algı-
üretim bağlama sözleşmesi; immutable/bounded, training/control ID leak reddi.
İki yalnız metin taslağı (tiz/pes, puls); boş örnek bankası ve onay/assessment
kapalı. Okuma/mastery bridge yok. 9 yeni test; sonraki LEARN-02b taslak okuma
ekranı/skill-map erişimi. 12 onaylı mikroünite veya öğretim kabulü değil.

**2026-10-13 04:20 TRT — REL-08:** Script-root Harmonia guard, read-only
format→analyze→full suite, fail-fast exit, explicit locked --fetch ve --plan.
10 runner/CLI testi, 529 full suite. Hosted CI/docs taslağı etkin değil;
code checks ses/cihaz/pilot kabulü değil. Sıradaki hazır LEARN-02 mikroders
şeması; gerçek içerik için eğitimci onayı açık tutulur.

**2026-10-12 23:20 TRT — CORE-04b2:** Ana menüde Deneysel kısa ezgi kartı;
üç sentetik ton→bekle→söyle→quality→puansız detail ekranı. Girişte izin/kayıt
yok, kaynak/Hz adayları açık; history/mastery/AI/scorer bağı yok. 8 fake widget
testi (320px/1.8×, lifecycle, izin, kalite, a11y) ve 519 suite. CORE-04 gerçek
voice/device/pedagoji, recall ve hata bölüm loop kapıları açık. Sıradaki güvenli
bağımsız paket REL-08 local QA runner/CI taslağı, sonra LEARN-02 mikroders.

**2026-10-12 18:20 TRT — CORE-04b1:** Typed ezgi reference'inden 3–5 sıralı
sentetik ton WAV'ı ve capture+clip player adapter'ı; varsayılan tek C4 fallback
yok. Stop/close hata halinde iki kaynağı da kapatmayı dener; mock source korunur.
8 yeni regresyon, 511 full test. Gerçek piyano/cihaz/eğitimci kanıtı değil;
CORE-04b2 puansız ekran ve home bağlantısı sırada. Skor/başarı kapalı.

**2026-10-12 13:13 TRT — CORE-04a:** Puansız ezgi application koordinatörü;
3–5 nota reference bağlama sözleşmesi, kalibrasyon/kalite kapısı, tamamlanan
player callback sayımı ve diagnostic segment raporu. Native komutlar sıralı;
iptal, geç worker ve pending-start temizliği testli. Ürün adapter/ekranı henüz
yok (CORE-04b); callback sayısı duyma/hafıza kanıtı değil. Başarı/skor kapalı.

**2026-10-12 07:51 TRT — CORE-03b diagnostic segmentleme:** Recording frame
kanıtından hedef bağımsız periodic pitch adayları çıkaran `PitchSegmenter`
eklendi. Sessizlik/clip/unreliable ve kapsanmayan zaman boşluğu üzerinden
birleştirme yok; kısa run/spike indeksleri açıkça discarded evidence'da.
Ham oktav korunur; sınırlar window-center tahmini, gerçek onset veya VAD değil.
Ürün başarı/memory/timing/skor bağlantısı kapalı; CORE-04 oturum/UI ve gerçek
VAD/ezgi benchmark/cihaz kapıları açık. Son doğrulama IMPLEMENTATION_LOG'da.

**2026-10-12 02:47 TRT heartbeat — CORE-03a:** Mevcut beceri grafiği/günlük
plan/aralık geliştirmeleri korundu; sıradaki bağımsız ezgi altyapısı uygulandı.
Önceden segmentlenmiş monofonik olayları exact-order karşılaştıran bounded
`PitchSequenceAligner`: doğru/yanlış pitch/yanlış oktav/eksik/fazla adımları ve
immutable kaynaklı kanıt. Aynı nota sayısı, ters sıra veya tekrarlanan cevap
başarı sayılmaz. Boş/bozuk cevapta sıra kararı null; timing/memory/skor yok.
**480 test (+14), analyze temiz, format 143/0.** Mobil build/gerçek cihaz testi
yapılmadı. PCM segmentleme, VAD/insan benchmark'ı ve ezgi ekranı açık.

Durum sözlüğü: **Planlandı → Geliştiriliyor → Kod-test tamamlandı → Cihazda doğrulandı → Eğitim pilotunda doğrulandı → Yayında.** Bir modül, alt paketlerinden biri kod-test olduğunda değil, kendi kabul kapılarının hepsi geçtiğinde ilerler. Tamamlanma yüzdesi verilmez. İş ID'leri: [IMPLEMENTATION_ROADMAP.md §11](./IMPLEMENTATION_ROADMAP.md#11-modül-envanteri-iş-idleri-2026-10-11).

| Modül | Durum | Kodda olan (kanıt) | Eksik / sonraki ID | Dış kapı |
|---|---|---|---|---|
| A. Kabuk ve başlangıç | Geliştiriliyor | Misafir hedef seçimi, home, ayarlar/yardım/gizlilik/abonelik/hesap bilgi ekranları, yükleniyor/hata/yeniden dene, yerel profil silme, light/dark, 320px/1.8× testleri (SHELL-01); mikrofon reddi sonrası OS ayarları kurtarma (SHELL-02 kod/build); **Flutter erişilebilirlik kılavuz testleri: dokunma hedefi (Android/iOS), etiketli hedef, metin kontrastı — açık/koyu home/onboarding + oturum/ritim/lab/geçmiş (QA-01a)** | Başlangıç değerlendirmesi (SHELL-03), kaldığı yerden devam/offline (SHELL-04) | Fiziksel izin/ayar dönüşü, ekran okuyucu ve kullanıcı testi (UXR-01) |
| B. Ses motoru ve oturum | Geliştiriliyor | Kayıt/çalma lab, bounded WAV, YIN frame, kayıt diagnostics, native isolate, epoch iptal; **noise-floor kalibrasyonu, kalite kapısı, route politikası, latency sözleşmesi (CAL-01)**; **tek ses ürün oturum koordinatörü (SESSION-01)**; **canlı giriş seviyesi göstergesi (UX-03a; eklenti genliği, yalnız görüntü)**; just_audio tekrar oynatma düzeltmesi; **açılışta yetim geçici ses temizliği + ayarlarda hata uyarısı (SESSION-02)** | Gerçek VAD (VAD-01), latency ölçüm prosedürü (CAL-03), worker hard cancel | Fiziksel iOS/Android route matrisi (CAL-02), etiketli insan benchmark'ı (BENCH-01) |
| C. Tek ses | Geliştiriliyor | Scorer v2, oktav kuralı, nötr geçersiz sonuç; mock senaryo ekranı (Simülasyon); **gerçek kayıtlı “dinle ve söyle” oturum ekranı — puansız, doğru/yanlış kapalı** | Gerçek karar (CORE-01) yalnız VAD/benchmark sonrası | BENCH-01, cihaz QA |
| D. Ses aralığı | Planlandı | — | AUD-DEV-06 | BENCH-01; SATB/sağlık iddiası yok |
| E. Aralık / fonksiyonel duyma | Geliştiriliyor | Tiz/pes algı (PERC-01); **hareketli do derece duyma (INT-01a)**; algı ve üretim ayrı | INT-01 içerik+algı/üretim ayrımı | Eğitimci (fixed/movable-do kararı) |
| F. Ritim | Geliştiriliyor | Event alignment + vuruş bazlı hizalama; **dinle→tekrar et taklit modu (CORE-02a): pointer engine timestamp, ilk dokunuş çapası (zamanlaması ölçülmez), sentetik klik referansı, dinleme kotası, zaman çizelgesi, tempo ipucu**; 3 taslak desen | Eşzamanlı/count-in mod CAL-03'e bağlı (CORE-02b); ritim okuma/dikte | Eğitimci desen onayı ve tolerans kalibrasyonu; fiziksel dokunma örnekleme ölçümü |
| G. Ezgi | Geliştiriliyor | Fail-closed placeholder analyzer; CORE-03a symbolic alignment; CORE-03b diagnostic segmentleme; CORE-04a puansız session; CORE-04b1 sentetik reference; CORE-04b2 puansız ekran/home (8 widget testi) | Güvenilir bölüm döngüsü, gerçek segmentleme kabulü ve timing/hafıza/recall protokolü | İzinli ezgi fixture'ları, VAD/benchmark, cihaz ve eğitimci QA |
| H. 2/3/4 piyano | Geliştiriliyor (içerik bekliyor) | Kapalı placeholder katalog/ekran, renderer alternatifi, **CONS-01a–e reviewed loader/playback/composer + CONS-02a/b matcher + CONS-02c capture + CONS-02d quality/worker diagnostic + CONS-02e kalibrasyon + CONS-02f attempt coordinator** | Gerçek kayıt birlikte QA, production player/UI/result copy ve cihaz benchmark'ı | **Kullanıcının piyano kayıtları** + birlikte QA; BENCH/VAD/cihaz |
| I. Dersler / rotalar | Geliştiriliyor | Taslak graph/merdiven/harita (LEARN-01a), rota önerisi (LEARN-03a/b), süreli günlük plan (LEARN-03c), beceri raporu (LEARN-04a); LEARN-02a/b mikroders sözleşmesi + iki metin/reader; LEARN-02c strict draft JSON codec | Reviewed örnek bankası/ders akışı ve IO adapter, EDU-01 içerik/ölçüt onayı | Eğitimci ölçüt/içerik onayı ve öğrenme etkisi pilotu; okuma mastery değildir |
| J. Sonuçlar / gelişim | Geliştiriliyor | Sonuç v2 + katı `fromJson`; **yerel geçmiş (CORE-05): attempt ID tekilleştirme, çakışmada üzerine yazmama, açık kapasite, seri atomik yazma, bozuk dosyayı koruma; geçmiş ekranı (aynı cohort'ta ≥3 geçerli deneme yoksa “bilinmiyor”), tek/toplu silme**; ritim sonuçları `touch` kaynağıyla kaydediliyor | Upload/consent kısmı (DATA-03, backend) | — |
| K. Offline / hesap / backend | Geliştiriliyor | Atomik yerel JSON store + misafir profil + yerel sonuç geçmişi; DATA-03b tek-commit toplu import, attempt-id dedup/conflict ve kapasite raporu (tamamen offline) | Backend ADR (DATA-01), sync/outbox (DATA-02), sunucu consent/upload | Backend hesabı/maliyet onayı |
| L. AI koç | Geliştiriliyor | **Girdi/çıktı sözleşmesi, katı doğrulayıcı, zaman aşımı + yedek, 12 yerel eval (AI-02a); canlı çağrı yok** | AI-01 sunucu gateway, AI-03 gerçek model eval, UI bağlantısı | Ücretli API onayı, gateway |
| M. Plus eğitimci | Planlandı | HUMAN_REVIEW tasarımı | HUM-01–07 | Gerçek eğitimci kapasitesi, hukuk |
| N. İleri konservatuvar | Planlandı | — | CONS-03–05 | Güncel resmî kaynak, eğitimci rubriği |
| O. Koro | Planlandı | Route politikası: hoparlörde rehberli parti desteklenmez | CHOIR-01–05 | Kulaklıklı cihaz spike, eğitimci |
| P. Abonelik / haklar | Planlandı | Ayarlarda “satın alma yok” bilgisi | PAY-01–03 | Mağaza hesabı, sandbox, canlı ödeme onayı |
| Q. Öğretmen / sosyal | Planlandı | — | TEACH-01, SOC-01 | İzinli sınıf pilotu |

## Üç teslim kapsamı

1. **Kapalı beta Core** — A (izin/kalibrasyon dahil), B (oturum + kalite kapısı + en az 1 iOS ve 1 düşük/orta Android cihaz raporu), C (benchmark kapısı geçerse gerçek tek ses; geçmezse kapalı), F (ölçülmüş gecikmeyle tap ritim), G (3–5 nota, segmentleme benchmark'ı geçerse), J yerel geçmiş, I ilk mikroüniteler (eğitimci onaylı). Ödeme, hesap, AI ve bulut yok; ham ses cihazdan çıkmaz. Internal/TestFlight dağıtımı ayrı onay ister.
2. **İlk ücretli yayın** — Core + D, E, günlük rota ve gecikmeli kontrol (I), hesap/sync/silme/export (K), isteğe bağlı sınırlı AI koç (L), Premium abonelik sandbox senaryoları (P), crash/hata izleme ve destek (OPS-01), hukuk/çocuk güvenliği/mağaza metni (LAUNCH-01). Plus, pilot kapıları geçmeden satılmaz.
3. **Genişleme** — H (kayıtlar gelince; sequence motoru hazırsa daha erken), M Plus, N ileri konservatuvar, O koro, Q öğretmen/sosyal.

## Kritik yol ve bağımlılıklar

```mermaid
flowchart LR
  REL[REL-01–05 ✓ kod] --> LAB[AUD-DEV-02/03/04 ✓ kod]
  LAB --> CAL[CAL-01 ✓ kod]
  CAL --> SES[SESSION-01 oturum]
  CAL --> CAL2[CAL-02 cihaz route matrisi]
  BENCH[BENCH-01 etiketli insan kaydı] --> VAD[VAD-01 ses etkinliği / çekimserlik]
  SES --> CORE1[CORE-01 gerçek tek ses]
  CAL2 --> CORE1
  VAD --> CORE1
  CAL --> CAL3[CAL-03 gecikme ölçümü] --> CORE2[CORE-02 tap ritim]
  CORE1 --> CORE3[CORE-03 segmentleme] --> CORE4[CORE-04 kısa ezgi]
  CORE3 --> H[H: 2/3/4 piyano]
  PIANO[Kullanıcı piyano kayıtları] --> H
  SHELL[SHELL-01 ✓ kod] --> UX[UX-01/03 + UXR-01 kullanıcı testi]
  CORE1 --> HIST[CORE-05 yerel geçmiş]
  CORE2 --> HIST
  HIST --> LEARN[LEARN-01–03 + EDU-01 eğitimci onayı]
  LEARN --> BETA((Kapalı beta Core))
  UX --> BETA
  BETA --> DATA[DATA-01–03 backend/consent] --> AI[AI-01–03]
  DATA --> PAY[PAY-01–03 sandbox] --> PAID((İlk ücretli yayın))
  AI --> PAID
  OPS[OPS-01 + LAUNCH-01] --> PAID
```

Kritik yoldaki insan/dış kapılar: etiketli izinli kayıtlar (BENCH-01), fiziksel cihazlar (CAL-02), eğitimci içerik onayı (EDU-01), kullanıcı testleri (UXR-01), piyano kayıtları (H), backend/AI/mağaza hesapları ve hukuk incelemesi. Kod işleri bu kapıları geçmiş saymaz.

## 30 / 60 / 90 günlük kapasiteye bağlı plan

Tek geliştirici + kullanıcı koordinasyonu varsayımıyla öneridir; tarih garantisi değildir, dış kapılar gecikirse kayar.

| Pencere | Kod (onay gerektirmeyen) | Kullanıcı/dış girdi gerektiren | Çıkış kanıtı |
|---|---|---|---|
| 0–30 gün | SESSION-01/02, CAL-03 prosedür kodu, CORE-02 tap ekranı, CORE-05 yerel geçmiş, SHELL-02/04 | 2 fiziksel cihazda CAL-02 protokolü; BENCH-01 için izinli 100+ kayıt planı ve ilk etiketler; UXR-01 5 kişilik ilk değer testi | Cihaz raporu, ilk etiketli set, kullanıcı testi notları |
| 31–60 gün | VAD-01 (development seti), CORE-01 kapılı bağlantı, CORE-03 segmentleme spike, EDU-01 içerik şeması | Holdout benchmark ölçümü; eğitimci ilk 12 mikroünite onayı; internal build dağıtım onayı | Holdout raporu (yanlış başarı/çekimserlik), onaylı içerik, kapalı beta adayı |
| 61–90 gün | LEARN-01–03, DATA-01 ADR + adapter'lar, AI-03 eval seti (canlı çağrısız), PAY-02 sandbox entegrasyon kodu | Kapalı beta kullanıcıları; backend/AI/mağaza hesabı ve maliyet onayları; hukuk incelemesi | Beta öğrenme/geri dönüş ölçümü, ücretli yayın kapı listesi |

## Kuzey yıldızı

Harmonia, konservatuvar ve müzik sınavlarına hazırlanan öğrencinin her gün kısa bir çalışma yapmasını, hatasını anlamasını ve bir sonraki doğru egzersize yönlendirilmesini sağlamalıdır.

**Ana vaat:** “Her gün 10 dakika: duy, hatırla, tekrar et, sınava hazırlan.”

## Mevcut gerçeklik

- Ayrıntılı iş/sprint/yayın planı: [IMPLEMENTATION_ROADMAP.md](./IMPLEMENTATION_ROADMAP.md). Uygulanmış paket ve doğrulama: [IMPLEMENTATION_LOG.md](./IMPLEMENTATION_LOG.md).
- 2026-10-11 geliştirme başlangıcı: ScoreMetric/sonuç v2, valid-invalid, metrik örnek sayıları ve zorluk/mod/sürüm cohort; ritim event alignment; ezgi placeholder'ın sahte skoru kapatıldı. 58 test geçti; analyze temiz, format kontrolü değişiklik bulmadı. Gerçek ses/pedagoji kapısı geçilmedi.
- Agora Voice içinde çalışan tek sesli ses aralığı testi referans prototip olarak incelendi.
- Referans projede yukarı/aşağı nota taraması, mikrofon kontrolü, pitch analizi, ses kayıtları ve skor tablosu bulunuyor.
- Harmonia'da domain/mock tek ses ekranı ve yerel kayıt→native DSP diagnostic laboratuvarı var; VAD/gerçek başarı ve fiziksel mikrofon doğrulaması bekliyor.
- Ses ölçümü deterministik ses işleme ile yapılacak; AI ölçümün yerine geçmeyecek.
- `gpt-4o-mini`, ölçüm sonuçlarını açıklayan ve egzersiz seçen metin tabanlı koç olarak kullanılacak.

## Fazlar

### 2026-10-11 eğitim ve Plus kapsam güncellemesi

[Derin inceleme](./PRODUCT_AUDIT.md) kodda olan/plandaki özellikleri ayırır. [Öğrenme modeli](./LEARNING_MODEL.md) ortak temel ve konservatuvar/koro rotalarını; [gerçek eğitimci hizmeti](./HUMAN_REVIEW.md) Plus kapsamını tanımlar. Tercih edilen tasarım Aurora marka deneyimi + Konservatuvar açıklayıcı sonuç yaklaşımıdır; kullanıcı testi bekleniyor.

- **Faz 1–2 P0:** AUD-01–07/F26: ölçülmeyen timing/memory 100, melody count=order, extra tap=100 ve koşulsuz progress ortalaması kapatılmadan gerçek eğitim değerlendirmesi yok. Nullable/status + sequence/rhythm/tuning sözleşmeleri.
- **Faz 2:** F22 mikroders/algı-üretim ayrımı/ipucusuz yeni soru; core sadece test bankası olarak çıkmaz.
- **Faz 3:** Mastery ve gecikmeli kontrol; 3 eğitimci/20 başvuruluk F21 pilotu; F23 kulaklıklı parti bağımsızlığı teknik spike. Tam sınıf paneli bu pilotun önkoşulu değil.
- **Faz 4:** Ayrı çıkış kapılarıyla ileri konservatuvar ve koro rotaları, kurum/yıl eşlemesi, Plus'ın gerçek insan teslimi. Kota/fiyat/teslim kapasite pilotundan sonra.
- **Faz 5:** Sınıf/ödev platformu ve isteğe bağlı lig. Makam/usul, enstrüman pedagojisi ve büyük repertuvar ayrı kapsam olarak kalır.

**Yeni doğrulama:** 2026-10-11'de 26 test tekrar geçti; static analysis sorun bulmadı. Bunlar mock/domain/widget testleridir; gerçek ses veya pedagojik etkililik doğrulaması değildir.

### 2026-10-10 kapsam güncellemesi

10 ilgili rakibin resmî ürün özellikleri incelendi: [araştırma](./COMPETITOR_RESEARCH.md). Eksik özellikler [F01–F20 backlog'una](./FEATURE_BACKLOG.md), beş etkileşimli tasarım [tasarım çalışmasına](./DESIGN_STUDIES.md) kaydedildi. Bunlar uygulamaya eklenmiş canlı özellikler değil; önceliklendirilmiş ürün planı ve tasarım prototipleridir.

- **Faz 1:** AUDIO-01/02/03, doğru oktav, invalid measurement, gerçek pitch/enerji görseli. 3/4 sesli sıralı cevap için erken teknik spike; canlı motor kapısı önce.
- **Faz 2:** teori mikrodersi, hata döngüsü/tempo, offline sonuç kuyruğu, beceriden ilgili egzersize geçiş (F06/F09/F14/F05).
- **Faz 3:** başlangıç/ileri düzey ve adaptif tekrar; AI yalnız ölçülen veriyi açıklar (F02/F12).
- **Faz 4:** 2/3/4 sesi birlikte duyup sırayla söyleme, akor çevrimi, fonksiyonel duyma/solfej, deşifre/dikte, kişisel preset, süreli deneme, abonelik (F07/F08/F10/F11/F13/F16).
- **Faz 5:** sınıf programı, normalize opt-in lig, öğretmen grup lisansı (F15/F17). Enstrüman bankası/MIDI/repertuvar/nefes ölçümü daha sonra ve lisans/benchmark şartıyla.

Eşzamanlı mikrofondan çoklu pitch ayırma ayrı AR-GE'dir; mevcut monofonik motoru üç kez çalıştırmak değildir. İlk 3/4 sesli ürünün önkoşulu değil. [Motor planı](./AUDIO_ENGINE_PLAN.md).

Faz süreleri tam zamanlı tek geliştirici ve dar kapsam için eski kaba tahminlerdir; yeni özelliklerin tamamı bu sürelere otomatik sığmaz. Benchmark ve pilot sonrası yeniden tahmin yapılmalı.

### Faz 0 — Keşif ve ölçüm temeli

**Süre:** 1–2 hafta

**Amaç:** Yanlış ürünü hızlıca inşa etmemek.

- 10–15 öğrenci ve 3–5 müzik öğretmeniyle görüş.
- Gerçek sınav egzersizlerini ve kullanılan terminolojiyi listele.
- En az 100 etiketli tek ses kaydı topla: doğru nota, yanlış nota, oktav hatası, gürültü, kararsız ses.
- Pitch motoru için yanlış pozitif/negatif benchmark seti oluştur.
- MVP’de hangi egzersizlerin olacağını kesinleştir.

**Çıkış kriteri:** Kullanıcı problemi, MVP kapsamı ve ölçüm başarı hedefleri yazılı hale gelmiş olmalı.

### Faz 1 — Teknik spike

**Süre:** 1–2 hafta

- Flutter ses yakalama prototipi.
- Canlı RMS ve pitch göstergesi.
- Pitch analizini UI thread’inden ayırma.
- Doğru oktavı yanlış oktavdan ayıran testler.
- Ritim için tap timestamp toplama prototipi.
- Offline modda temel analiz.

**Çıkış kriteri:** Aynı kayıt, desteklenen cihazlarda tutarlı sonuç vermeli; algoritma testleri çalışmalı.

### Faz 2 — MVP: Harmonia Core

**Süre:** 6–8 hafta

Kullanıcıya görünen ilk ürün:

- Misafir başlangıç testi.
- Mikrofon kalibrasyonu.
- Tek ses dinle-söyle.
- Basit interval egzersizi.
- Ritim dinle-tıkla.
- 3–5 notalık ezgi tekrarı.
- Egzersiz sonunda açıklanabilir geri bildirim.
- Mikroders, algı/üretim ayrımı, destekten ipucusuz yeni soruya geçiş.
- Günlük mini çalışma.
- Temel ilerleme geçmişi.

**MVP dışı:** Sosyal ağ, genel chatbot, büyük şarkı kütüphanesi, öğretmen paneli, herkese açık leaderboard.

**Çıkış kriteri:** Yeni kullanıcı 3 dakika içinde ilk egzersizi tamamlayabilmeli ve neden hata yaptığını anlayabilmeli.

### Faz 3 — Adaptif öğrenme ve Harmonia Coach

**Süre:** 4–6 hafta

- `gpt-4o-mini` ile egzersiz sonu koç mesajı.
- Hata türüne göre sonraki egzersiz seçimi.
- Günlük ve haftalık çalışma planı.
- Pitch, ritim, ezgi ve ses aralığı ayrı gelişim skorları.
- Tekrarlanan hatalara göre zorluk ayarı.
- AI cevaplarının JSON schema ile doğrulanması.
- Beceri önkoşulları, zorluk/mod/içerik sürümü, gecikmeli kontrol ve geçerli örnek bazlı mastery.
- Plus gerçek eğitimci pilotu: kayıt + seçili gelişim özeti → eğitimcinin yazılı yorumu → takip ödevi.
- Koro parti bağımsızlığı için kulaklıklı tek-vokal ölçüm spike'ı.

**Çıkış kriteri:** AI önerisi aynı girdide tutarlı, güvenli ve UI tarafından işlenebilir olmalı.

### Faz 4 — Konservatuvar modu ve abonelik

**Süre:** 4–6 hafta

- 2, 3 ve 4 sesli sınavlar.
- Ritim tekrarı ve tempo analizi.
- 7–10 notalık ezgi hafızası.
- Konservatuvar sınav simülasyonu.
- Premium içerik ve abonelik.
- Kişisel raporların dışa aktarımı.
- Ham ses kayıtları için açık rıza, silme ve dışa aktarma.
- Koro alt rotası: rehberi azalt/diğer partilerle söyle, giriş-bitiş ve kısa repertuvar aktarımı.
- Okul/bölüm/yıl gereksinimlerini kaynağa bağlama; çalgı/şan dış kapsamını gösterme.
- Plus: gerçek eğitimci kapasitesi, güvenli kayıt/hak ledger ve teslim/iade kapıları geçildiyse ücretli hizmet.

**Çıkış kriteri:** Kullanıcı doğrulanmış şablonla ipucusuz deneme tamamlayabilmeli; koro rotasında rehbersiz parti çalışması ayrı doğrulanmalı. Plus satılıyorsa gerçek eğitimci teslimi ve gizlilik/hak kapıları geçilmiş olmalı. Tam sınav/prova yerine geçme iddiası yok.

### Faz 5 — Öğretmen ürünü ve kontrollü sosyal sistem

**Süre:** 8–12 hafta

- Öğretmen paneli.
- Sınıf ve öğrenci grupları.
- Ödev gönderme.
- Özel sınav oluşturucu.
- Anonim ve zorluk-normalize ligler.
- Gelişim yüzdesi bazlı ödüller.

**Çıkış kriteri:** En az bir öğretmen gerçek sınıfıyla ürünü kullanmalı ve haftalık raporu faydalı bulmalı.

## Öncelik sırası

1. Oktav doğruluğu ve pitch güvenilirliği.
2. Tek ses deneyimi.
3. Ritim ve kısa ezgi tekrarı.
4. Açıklanabilir geri bildirim.
5. Adaptif çalışma planı.
6. Gerçek eğitimci hizmet pilotu ve koro parti bağımsızlığı spike'ı.
7. 2/3/4 sesli sınavlar, solfej/deşifre ve rota içerikleri.
8. Kapıları geçilmiş Premium/Plus aboneliği.
9. Tam öğretmen/sınıf paneli.
10. Leaderboard ve sosyal özellikler.

## Yapılan iş (2026-08-16)

Faz 0/1 kapsamında kod tabanı ilk kez oluşturuldu (`agoravoiceweb`'e dokunulmadı, AI hiçbir yere bağlanmadı):

- **Flutter iskeleti:** `flutter create` ile proje kuruldu (`pubspec.yaml`, `lib/main.dart`, `android/`, `ios/`).
- **Klasör yapısı** (`ARCHITECTURE.md` katmanlarını yansıtır):
  - `lib/app/` — app shell (`harmonia_app.dart`).
  - `lib/domain/models/` — `User`, `Exercise`, `ExerciseAttempt`, `ExerciseResult`, `SkillProgress`.
  - `lib/domain/audio/` — `PitchAnalyzer`, `RhythmAnalyzer`, `MelodyAnalyzer` arayüzleri ve sonuç tipleri.
  - `lib/domain/scoring/` — `PitchExerciseScorer`: `PitchAnalysisResult`'ı `ExerciseResult` sözleşmesine çevirir (ADR-006 dahil: yanlış oktav asla başarı sayılmaz).
  - `lib/infrastructure/audio/mock/` — `MockPitchAnalyzer` (senaryo seçilebilir: doğru, yanlış nota, yanlış oktav aşağı/yukarı, kararsız, gürültü, sessizlik), `MockRhythmAnalyzer` (gerçek onset eşleştirme mantığı, DSP gerektirmiyor), `MockMelodyAnalyzer` (placeholder).
  - `lib/features/single_tone_exercise/` — ilk egzersiz ekranı.
- **İlk egzersiz ekranı:** Tek ses (C4) dinle-söyle ekranı. Gerçek mikrofon henüz yok; senaryo butonlarıyla mock pitch motoru tetiklenip başarı, yanlış nota, yanlış oktav (aşağı/yukarı), kararsız ses, gürültü ve sessizlik durumları gösteriliyor. Hata metinleri `AI_COACH.md` § Fallback'teki kural tabanlı, AI'siz metinlerle birebir aynı.
- **Testler:** `test/domain/...`, `test/infrastructure/audio/mock/...`, `test/widget_test.dart` — 26 test, hepsi geçiyor (`flutter test`). `flutter analyze` temiz.
- **Dokunulmadı / bağlanmadı:** `agoravoiceweb` projesi; AI Coach canlı sisteme bağlanmadı; pitch/ritim skorları hâlâ tamamen deterministik kodla hesaplanıyor (AI'ye hesaplatılmadı).

## Bir sonraki oturum

**Başka modele devir:** Önce [MODEL_HANDOFF.md](./MODEL_HANDOFF.md) ve [AGENTS.md](./AGENTS.md) oku; kod/akış haritası, gerçek doğrulama sınırları, önerilen ama kaydedilmemiş piyano listesi ve en yakın diagnostic integration dilimi burada özetlenir. Bu teslim kullanıcı isteğiyle ilk yerel commit olarak kaydediliyor; push/yayın yok.

**Yeni kullanıcı yönü (geçerli):** Hazır 2/3/4 sesli piyano kayıtları klasörlerden çalınacak; kayıtlar gelince birlikte incelenecek. O zamana kadar placeholder kapalı. Live multipitch yok. [PIANO_REFERENCES.md](./PIANO_REFERENCES.md).

**Bu oturumda tamamlanan kod paketleri:** CAL-01 (noise-floor kalibrasyonu, kayıt kalite kapısı, route politikası, latency sözleşmesi, laboratuvara bağlantı) ve SHELL-01 (Aurora token'ları, misafir hedef seçimi, home, ayarlar/yardım/gizlilik/abonelik/hesap, yerel profil). Ayrıntı: [IMPLEMENTATION_LOG.md](./IMPLEMENTATION_LOG.md).

**Güncel devir:** DATA-03c pano belgesinde günlük süre ve haftalık hedefi taşır;
hatırlatma/titreşim cihazda kalır, v1 okunur ve cross-store kısmi hata açık
raporlanır. Bunu hesap/bulut senkronu veya gerçek iki cihaz kabulü diye sunma.
SHELL-04i/h stale yerel projection sınırlarını korur; medya otomatik başlamaz.
DATA-03b pano içe aktarmasını tek atomik yerel batch yazımına taşıdı; bunu
hesap, bulut senkronu veya iki cihaz teslimatı diye sunma. Backend
ADR/outbox hâlâ açık. RETRY-01c ezgi frekans adaylarından yalnız puansız ve açıkça
deneysel bölüm dinleme önerisi üretir; bunu hata, nota doğruluğu veya hafıza
kanıtı sayma. SHELL-03a başlangıç kontrolünü yalnız mevcut güvenilir
dokunma turlarıyla bağladı; toplu seviye/ready skoru yok. SHELL-03b eğitimci
seviye tanımı ve öğrenci kabulüne bağlıdır. Sıradaki güvenli bağımsız kod işi
SHELL-04/F14'ün kalan offline consumer/device durum matrisini somutlaştırmak olabilir. Fiziksel
iOS/Android mikrofon izin/ayar dönüşü ve bildirim teslimatı D kapılarıdır.
CAL-03b fiziksel referans saat/pipeline
ölçüm adapter'ı ve protokolünü gerektirir. Count-in yalnız doğru pipeline'ın
bağımsız cihaz ölçümüyle açılır; tap yanlılığı veya loopback toplamını dokunma
düzeltmesi yapma. VAD/benchmark olmadan simülasyon başarı ekranını gerçek motora
bağlama; eşikleri sonuca bakarak değiştirme. Mağaza/ödeme/upload/ücretli API/
push ayrı yetki ister.

- [x] Öncelikli tasarım yönünü kaydet: Aurora + Konservatuvar. Nihai doğrulama değil.
- [ ] Öğrenci ve eğitimciyle hibrit tasarımın sonuç anlama/sonraki eylem testini yap.
- [x] REL-01/02: measurement status ve metrik durumları; tek seste timing/memory 100 kaldırıldı, invalid puanlanmıyor.
- [x] REL-03/04: metrik bazlı gelişim/cohort ve ritim extra/latency/monoton alignment.
- [x] REL-05: ezgi placeholder'da yanlış sıra/hafıza başarısı üretimini kapat; gerçek analiz yok.
- [ ] REL-06/07: tam exercise sequence/tuning/hint sözleşmesi ve provenance/fixture; gerçek melody alignment CORE-03'te.
- [x] REL-06/07 alt paketi: protokol JSON round-trip, mode/skill politikaları, immutable sonuç evidence, mock pitch provenance ve kaynak/analyzer cohort.
- [x] AUD-DEV-01 alt paketi: PCM16 WAV ve sentetik tone testleri; fixture metadata/holdout sızıntı kontrolleri. Gerçek kayıt seti bekliyor.
- [x] AUD-DEV-01 loader alt paketi: metadata/manifest JSON, disk varlığı/hash/header/Hz/count/bütçe ve symlink/path testleri. Gerçek etiketli kayıt seti bekliyor.
- [x] AUD-DEV-02 kod alt paketi: açık kullanıcı eylemiyle yerel kayıt/çalma laboratuvarı ve fake-testli iptal/lifecycle coordinator. Fiziksel cihaz/Android QA bekliyor.
- [x] AUD-DEV-03 frame alt paketi: hedef bağımsız deneysel DSP, bounds/abstention, sentetik nota/oktav ve WAV→frame regresyonları. Tam kayıt analizi, VAD/benchmark/isolate ve cihaz kapısı açık.
- [x] AUD-DEV-03 kayıt/worker alt paketi: bounded overlapping/end-anchor frame diagnostics, tüm denominator'lar, explicit source/version, log dispersion ve native isolate testleri. Lab bağlantısı/hard cancel, VAD ve gerçek benchmark/cihaz kapısı açık.
- [x] AUD-DEV-04 diagnostic bağlantı alt paketi: owned file bütçesi/header, explicit PCM kaynak, isteğe bağlı worker, stale load/result/error ve lifecycle testleri. Tam exercise session/VAD/cihaz ve hard cancel kapıları açık.
- [x] CAL-01 (AUD-DEV-05 kod alt paketi): noise-floor kalibrasyonu, kalite kapısı, route politikası, latency sözleşmesi ve lab bağlantısı. Cihaz eşik doğrulaması (CAL-02) açık.
- [x] SESSION-01: tek ses ürün oturum koordinatörü + ekran; puansız, hoparlörde referans bitmeden kayıt yok, cevap analizden önce silinir. Cihaz QA açık.
- [x] INT-01a: hareketli do derece duyma (tonik bağlamı, ton değişimi, karışma analizi). Aralık söyleme (üretim), harmonik/inen aralıklar ve eğitimci onayı açık.
- [x] LEARN-03b: rota genelinde (algı + ritim) tek günlük öneri; algıda tek dinlemeli kalıcılık kontrolü.
- [x] PERC-01: tiz/pes algı çalışması (dokunma cevaplı, şans düzeyi gösterilir); beceri grafiğine bağlı. Eğitimci içerik onayı ve simülatör/cihaz denemesi açık.
- [x] LEARN-01a: taslak beceri grafiği, kanıta dayalı durum merdiveni, beceri haritası ekranı. Eğitimci onayı, mikroders içeriği (LEARN-02) açık.
- [x] QA-01a: erişilebilirlik kılavuz testleri (dokunma hedefi/etiket/kontrast). Ekran okuyucu ile manuel test açık.
- [x] UX-03a: kayıt/kalibrasyon sırasında canlı giriş seviyesi (yalnız görüntü). Cihazda dBFS doğrulaması açık.
- [x] LEARN-03a: kural tabanlı tek sonraki adım (tekrar → yeni desen → ertesi gün kalıcılık kontrolü). Eşikler taslak; eğitimci onayı ve öğrenme pilotu açık.
- [x] CORE-05: yerel sonuç geçmişi + geçmiş ekranı; aynı attempt iki kez sayılmaz.
- [x] SESSION-02: açılışta yetim geçici ses dizini temizliği; hata ayarlarda görünür.
- [x] CORE-02a: ritim taklit modu (ilk dokunuş çapası, vuruş zaman çizelgesi). Eğitimci desen onayı ve cihaz dokunma ölçümü açık; count-in modu CAL-03'e bağlı.
- [x] SHELL-01: Aurora token'ları, misafir hedef seçimi, home, ayarlar/yardım/gizlilik/abonelik/hesap, yerel profil. Kullanıcı testi (UXR-01) açık.
- [x] AUDIO-01: fixture manifest/hash/header kapısından pitch frame'e kısa buffer ve oktav sözleşmesi; kısa veri Hz uydurmaz, ham oktav korunur. Sentetik kod testi; gerçek insan/cihaz benchmark'ı BENCH-01/CAL-02'de açık.
- [ ] AUDIO-02: gerçek mikrofon + frame pipeline; ölçülmeyen timing/memory değerlerini sonuçta gösterme.
- [ ] AUDIO-03: gerçek VisualFeedbackFrame ile seçili ses efektini Flutter'da bağla.
- [ ] AUDIO-04: 3/4 referans playback + sıralı nota segment/alignment spike; **CONS-02a reviewed-target diagnostic matcher kod-testli**, gerçek fixture/insan sesi/cihaz değerlendirmesi açık.
- [x] AUDIO-04 piyano hazırlama alt paketi: 2/3/4 bilinen MIDI hedefi/protokol + single-clock WAV mix, headroom/key/rate/tuning/runtime testleri. Bank/player/capture ve gerçek sequence benchmark açık.
- [ ] F22: ilk 12 mikroünitenin öğrenme amaçları ve örnek/kontrol seti için eğitimci onayı.
- [ ] F21: eğitimci uzmanlık/QA rubriği, hak/kota/kapasite politikası, kayıt paylaşma-gizlilik akışı ve küçük pilot planı.
- [ ] F23: başka partiler çalarken kulaklıklı vokal kayıt ölçümü; referans sızıntısı fixture'ı.

Önceki eksik temel işler de devam eder:

- [ ] Gerçek mikrofon yakalama (Flutter ses yakalama prototipi) — `PitchAnalyzer` arayüzünü değiştirmeden `MockPitchAnalyzer`'ın yerini alacak gerçek bir implementasyon.
- [ ] Canlı RMS ve pitch göstergesi (UI thread'inden ayrı, isolate/compute ile).
- [ ] Pitch fixture kayıtlarıyla regression test seti (Faz 0'daki 100+ etiketli kayıt toplandıktan sonra).
- [ ] `DECISIONS.md` içindeki ilk kararları onayla.
- [ ] Faz 0 görüşme sorularını yaz, 10–15 öğrenci/3–5 öğretmenle görüş.
- [x] İlk tek ses benchmark formatı: mono PCM16 WAV ve metadata kapısı. Gerçek benchmark seti henüz yok.
- [ ] Ritim için gerçek tap timestamp toplama prototipi (ekran + mikrofon/dokunma girişi).
- [ ] Ham sesin hangi durumda saklanacağını kesinleştir (rıza akışı `ExerciseAttempt.rawAudioStorageRef` alanına bağlanacak).

## Açık sorular

- İlk yayın odağı konservatuvar işitsel hazırlığı; koro ayrı rota olarak planlandı. Hangi okul/bölüm ve ilk koro düzeyi pilotu daraltacak?
- İlk dil yalnızca Türkçe mi olacak?
- İlk MVP’de sesli kullanıcı kaydı zorunlu mu, misafir modunda mı başlanacak?
- Öğretmenlerin içerik oluşturması ne zaman gerekli?
- Abonelikte hangi içerik gerçekten ödeme isteği oluşturuyor?
- Plus hak/fiyat/teslim kapasitesi, eğitimci ücreti ve kayıt saklama süreleri nasıl doğrulanacak?

## Yarım kalırsa devam notu

Kod yazmaya başlamadan önce `PRODUCT_SPEC.md`, `ARCHITECTURE.md` ve `DECISIONS.md` birlikte okunmalı. Yeni kapsam için `FEATURE_BACKLOG.md`, `AUDIO_ENGINE_PLAN.md`, `DESIGN_STUDIES.md`, `PRODUCT_AUDIT.md`, `LEARNING_MODEL.md` ve `HUMAN_REVIEW.md` de okunmalı. Ölçüm benchmark’ı yoksa AI ve leaderboard geliştirmesine geçilmemeli. Beş önizleme simülasyondur; gerçek mikrofon/abonelik/eğitimci servisi eklenmiş sayılmaz. İlk uygulama paketi skor/ölçüm sözleşmesi + gerçek tek ses pipeline; bütün ileri kapsam bir sprint değildir.

## Değişiklik günlüğü

| Tarih | Değişiklik |
|---|---|
| 2026-08-15 | İlk roadmap, mimari, ürün, AI ve karar dokümanları oluşturuldu. |
| 2026-08-16 | Flutter proje iskeleti, domain modelleri (`User`, `Exercise`, `ExerciseAttempt`, `ExerciseResult`, `SkillProgress`), pitch/ritim/ezgi analiz arayüzleri, mock pitch/ritim/ezgi motorları, `PitchExerciseScorer`, ilk tek ses egzersizi ekranı ve 26 unit/widget testi eklendi. |
| 2026-10-10 | 10 rakibin resmî kaynakları; F01–F20 özellik backlog'u; beş uçtan uca etkileşimli tasarım; 3/4 sesli sıralı cevap/multipitch ayrımı ve ses-görsel sözleşmesi. Flutter kaynakları değiştirilmedi; bu oturumda eski 26 test yeniden çalıştırılmadı. |
| 2026-10-11 | Kod/eğitim yeterliliği incelemesi; 26 test ve temiz analiz yeniden doğrulandı. Aurora + Konservatuvar öncelikli yön; öğrenme modeli/iki rota, Plus gerçek eğitimci servisi, F21–F26 ve ADR-013–016 dokümante edildi. Flutter ve Agora kaynakları değiştirilmedi; canlı servis/ödeme/AI bağlanmadı. |
| 2026-10-11 — geliştirme başlangıcı | Kullanıcı uygulama başlangıcını istedi. Ayrıntılı roadmap; REL-01–05 kaynak/test değişiklikleri ve dar ekran/büyük yazı kontrolü. 58 test geçti; önceki yalnız doküman oturumundan farklı olarak Harmonia kaynakları değiştirildi. Agora, gerçek mikrofon, AI, ödeme ve dış servisler değişmedi. |
| 2026-10-11 — modül envanteri | A–Q modül envanteri, üç teslim kapsamı, kritik yol ve 30/60/90 planı. CAL-01 kalibrasyon/kalite kapısı ve SHELL-01 misafir kabuğu kod-test; 299 test, analyze/format temiz, iOS simulator build. Cihaz/pilot/yayın doğrulaması yok. |
| 2026-10-11 — oturum + ritim | SESSION-01 tek ses oturumu (puansız) ve CORE-02a ritim taklit modu; just_audio tekrar oynatma düzeltmesi. 338 test, analyze/format temiz, iOS simulator build ve elle simülatör gezintisi. Cihaz/pilot doğrulaması yok. |
| 2026-10-11 — geçmiş | CORE-05 yerel sonuç geçmişi (katı JSON, tekilleştirme/çakışma/kapasite, bozuk dosya koruma, ekran) ve SESSION-02 yetim ses temizliği. 363 test, analyze/format temiz. |
| 2026-10-11 — sonraki adım | LEARN-03a kural tabanlı sonraki adım + home “Bugünkü öneri”. 377 test, analyze/format temiz. Öğrenme etkisi doğrulanmadı. |
| 2026-10-11 — erişilebilirlik + seviye | QA-01a erişilebilirlik kılavuz testleri ve UX-03a canlı giriş seviyesi. 384 test, analyze/format temiz, iOS simulator build. |
| 2026-10-11 — metrik/ekonomi/UXR | ANALYTICS-01 olay sözleşmesi (gönderim yok), ECON-01 birim ekonomi tablosu, UXR-01 protokolü ve üretim UX akış/durum matrisi. 389 test. |
| 2026-10-11 — AI sözleşmesi | AI-02a koç girdi/çıktı sözleşmesi ve yerel eval (canlı API yok). Oturum sonu: 401 test, analyze/format temiz, iOS simulator build. |
| 2026-10-11 — beceri grafiği | LEARN-01a taslak beceri grafiği, durum merdiveni ve beceri haritası. 436 test (CAL-03a dahil), analyze/format temiz. |
| 2026-10-11 — algı | PERC-01 tiz/pes algı çalışması, ortak ölçülen egzersiz arayüzü. 448 test; iOS simulator build araç hatası (ortam). |
| 2026-10-11 — günlük öneri | LEARN-03b beceri grafiği tabanlı günlük öneri. 454 test. iOS simulator build Xcode lipo uyumsuzluğuyla engelli (ortam). |
| 2026-10-11 — aralık | INT-01a hareketli do derece duyma, ADR-024. 466 test. |
