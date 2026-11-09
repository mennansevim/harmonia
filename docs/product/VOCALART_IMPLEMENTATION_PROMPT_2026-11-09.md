# Vocalart geliştirme ajanı için uygulama promptu

Aşağıdaki metin, uygulama çalışması başlatılmak istendiğinde kullanılmak üzere
hazırlanmıştır. Bu inceleme oturumunda uygulama değişikliği yapılması talimatı
olarak yürütülmedi.

---

Vocalart'ın ürün deneyimini geniş bir kitleye uygun hale getir. Kullanıcılar:
müzikle ilgilenenler, koristler, şarkıcılar, tiyatro/müzikal sanatçıları,
seslendirmeciler/konuşmacılar ve konservatuvara hazırlanan öğrenciler.
İç kod adı Resonia; görünen marka Vocalart. Repo kökü
`/Users/sevimm/Documents/Projects/vocalart`. Komşu agoravoiceweb'e dokunma.

Önce AGENTS.md, MODEL_HANDOFF.md, CURRENT_ROADMAP.md,
IMPLEMENTATION_ROADMAP.md, IMPLEMENTATION_LOG.md, AUDIO_TESTING.md ve ilgili
ARCHITECTURE.md / DECISIONS.md kararlarını oku. Sonra şu üç belgeyi oku:

- docs/product/VOCALART_GROWTH_AUDIT_2026-11-09.md
- docs/product/VOCALART_USABILITY_PROTOCOL_2026-11-09.md
- docs/product/VOCALART_IMPLEMENTATION_PROMPT_2026-11-09.md

Tarihsel planı güncel kod yerine koyma. `lib/main.dart` üzerinden aktif
TrainerApp/HomeShell akışını izle. `features/` içindeki eski veya yeniden
kullanılan ekranların erişilebilirliğini ayrıca kontrol et. Kullanıcının
commit edilmemiş değişikliklerini koru; başlangıç diff'ini ve dosya hash'lerini
kaydet. Mevcut kullanıcı değişikliklerini sana aitmiş gibi raporlama.

## Değişmez sınır: ses algoritması

Ses tespit algoritması kullanıcının korunmasını istediği çalışan çekirdektir.
DSP, YIN, live pitch, sample-rate dönüşümü, smoothing, frame/hop, eşik,
kalibrasyon, capture quality, segmentleme, oktav, scoring, range ladder,
range score, mikrofon session ve native audio yapılandırmasını değiştirme.
İlgili testlerin beklenen çıktılarını değiştirme; bağımlılık yükseltmesiyle
dolaylı ses davranışı değişikliği de yapma.

Başlangıç çalışma ağacına göre korunan kapsamı hash ile denetle:
lib/domain/audio, lib/domain/scoring, lib/infrastructure/audio,
lib/trainer/audio, lib/trainer/sing, ilgili application/session/composition,
range_ladder.dart, range_score.dart, range_test.dart'ın ses bağlantıları,
native izin/audio ayarları ve audio fixture/testleri. Kapsamı keşfederek genişlet.
Değiştirilmesi gereken UI motor dosyasına gömülüyse dar sunum ayrımını öner;
bu pakette algoritmayı refactor etme. Bir ses sorunu bulursan rapora yaz,
izinsiz düzeltme veya benchmark sonucuna göre tolerans değiştirme.

Mock/synthetic/microphone/unverified ayrı kalır. Ölçülmeyen null/status,
invalid ölçüm puansız; yanlış oktav başarı değildir. Nefes süresi veya XP,
diyafram/sağlık/ses yetkinliği skoru değildir. Canlı görsel iz deneme kararını
değiştirmez. Mevcut kullanıcı rubriğine dokunma.

Hazır 2/3/4 sesli piyano kayıtları klasörden çalınır; öğrenci sesleri tek tek
tekrar eder. Kullanıcı dosyaları ve kabul gelmeden kapalı özelliği açma.
Canlı akor transkripsiyonu veya tek sample karıştırmayı ana yol yapma.

## Bu çalışmanın ilk uygulama dilimi

Önce yalnız WIDE-01 ve WIDE-02'nin küçük, kullanılabilir ilk dilimini yap:

1. Hedef → süre → ilk hazır çalışma akışını sadeleştir. Mikrofon ve ses aralığı
   ilk ihtiyaç anında, atlanabilir; hatırlatma ilk değer sonrasında olsun.
2. Günlük rota seçimine hedefi ekle. Katalog durumunu doğrula; yalnız hazır ve
   izin verilen içerik öner. Konuşma rotası hazır değilse varmış gibi gösterme.
   Ses hedefini sessizce varsayılan aralık quiz'ine yönlendirme.
3. Bugün / Egzersizler / Gelişim yapısını ve Koro'nun ayrı kapsamını koru.
   Mevcut arama/kategori bileşenlerini yeniden kullan; yeni sekme çoğaltma.
4. Var olan rol, odak, süre, onboarding adımı ve ilerlemeyi kaybetmeden sürümlü
   veri uyumu sağla. Eski kurulumdan devam ve çoklu rolü test et.
5. Her adımın amacı ve tek ana eylemi anlaşılır olsun. TR/EN birlikte;
   yeni metinleri mevcut `tr()` yaklaşımıyla yaz. TC/TT ve mevcut tasarım dili.
6. 320 px, yatay, büyük yazı ve azaltılmış hareketi gözet. Sistem yazısını
   bastırarak test geçirme; mevcut 2× sınırını bu paketle rastgele değiştirme,
   daha geniş destek ayrı layout işi olarak raporlansın.

Yeni ses/nefes/konuşma egzersizi içeriklerini eğitimci onayı olmadan hazır
göstermeme sınırı korunur. İlk dilimde içerik şeması/placeholder gerekiyorsa
kapalı kalsın; sahte video, eğitimci, örnek kayıt veya başarı üretme.

## Test ve insan doğrulaması

Mevcut kalite, widget, integration, Maestro ve QA raporlama araçlarını kullan.
Yeni mimari kurma. Değişikliğin anlamlı davranışlarını test et:

- eski kullanıcı tercihinin korunması ve yarım onboarding devamı;
- hedefin uygun ilk çalışmaya gitmesi;
- hazır olmayan içeriğin seçilmemesi;
- mikrofon izni olmadan uygun çalışma ve ret sonrası çıkış;
- izin/çalma/kaydın kendiliğinden başlamaması;
- yazı/kontrast/semantics ve TR/EN temel görevleri;
- mevcut ses regresyonlarının aynı sonuçla kalması.

`dart tool/quality_check.dart` çalıştır; `dart run` kullanma. Gerekli bağımlılık
fetch'i dışında varsayılan indirme yapma. Hata çıkarsa sana ait mi başlangıçta
var mı ayır; ilgisiz kullanıcı dosyasını düzeltip geçme. Mevcut full suite
geçmesini yeni insan/cihaz kanıtı sayma.

İnsan protokolünü uygulanabilir görev kayıtları ve ayrı rapor alanlarıyla
destekle. İlk yetişkin pilotu 18–29 / 30–44 / 45–59 / 60+ yaş dilimlerinde
planla; küçük örneklemi temsilî araştırma diye sunma. Çocuk/ergen testini uygun
izin ve içerik hazırlığına bağlı ayrı kapı tut. Yaş üzerinden nota toleransı
veya ses tipi seçme. Gerçek katılımcı yoksa `not_run` yaz; persona simülasyonuna
“60+ kullanıcı testi geçti” deme.

## Sonraki dilimler

WIDE-03 sade sonuç → WIDE-04 insan/erişilebilirlik pilotu → WIDE-05 onaylı
hazırlık rutinleri. Pilot bulgusuna göre porte veya konuşma/sahne paketini
genişlet. Eğitimci yorumunu insan kendi yazar; AI onun adına yazmaz.
AI yalnız izinli açıklama/öneri içindir; deterministik ölçüm ve puanı değiştirmez.
Mevcut `gpt-4o-mini` tercihini ve mobilde API anahtarı bulunmamasını koru.

## Yetki ve teslim

Yerel, geri alınabilir UI/rota/test işleri bu promptun ilk dilimidir. Canlı
ödeme, ücretli API, kayıt upload, mağaza yayını, dış mesaj, push/deployment
ayrı kullanıcı yetkisi gerektirir. Yerel commit yalnız açık talep varsa.
Kendiliğinden zamanlanmış görev veya hosted CI açma.

Teslimde gerçek kod değişikliğini, kullanıcıya etkisini, test sonuçlarını,
ses koruma kontrolünü ve açık insan/cihaz kapılarını yaz. CURRENT_ROADMAP.md
ve IMPLEMENTATION_LOG.md'ye yalnız gerçekten yapılan işi ekle. Sadece plan
yazdıysan uygulama geliştirildi deme. İlk dilimi bitir; tüm yol haritasını
bitmiş veya ürünü alanında birinci ilan etme.
