# Vocalart — farklı yaşlarla kullanılabilirlik ve otomasyon protokolü

9 Kasım 2026 · Durum: öneri / henüz uygulanmadı.
Amaç: ses tespit algoritmasını değiştirmeden, farklı yaş ve deneyimlerde
kullanıcının doğru çalışmayı bulabildiğini, tamamlayabildiğini ve sonucunu
anladığını ölçmek. Otomasyon insan katılımcıyı taklit ederek kabul veremez.

## 1. Tek, ölçülebilir otomasyon hedefi

**Her ürün değişikliğinde kritik kullanıcı yollarını tekrarlanabilir biçimde
kontrol et; gerçek insan gözlemlerini ayrı kaydet; kod, cihaz, kullanılabilirlik
ve eğitimci kapılarından biri eksikse “tamamlandı” üretme.**

Bu bir zamanlanmış uygulama görevi değil, geliştirilecek QA sisteminin hedefidir.
Bu belgede yeni recurring otomasyon kurulmadı, katılımcılara mesaj gönderilmedi.

## 2. Mevcut altyapıyı genişlet

- `dart tool/quality_check.dart`: format → analyze → full test, ilk hatada durur.
- `test/trainer/accessibility_audit_test.dart`: boyut/yazı/dokunma/kontrast/etiket.
- `.maestro/01...11`: kurulum, günlük ders, serbest pratik, çıkış/devam,
  sekmeler, mikrofon ret, silme, koro, sonuç, ritim/ayarlar ve İngilizce turu.
- `integration_test/`: uygulama ve yerel koro yolculukları.
- `scripts/qa/run_flows.sh`: iOS simülatör koşucusu ve video/rapor çıktısı.
- `scripts/qa/code_gate.py`, `build_dashboard.py`: mevcut kalite raporlaması.

İlk genişleme mevcut araçlarda yapılmalı. Yeni test sistemi veya ikinci dashboard
kurmadan gerekli kanıt türlerini mevcut rapor şemasına ekle. iOS simülatör
koşucusunu Android/fiziksel cihaz destekliyormuş gibi sunma; cihaz adapter'ı ayrı iş.

## 3. Beş kanıt katmanı

| Katman | Otomatik mi? | Kanıt | Asla kanıtlamaz |
|---|---|---|---|
| Kod ve motor koruma | Evet | Başlangıç hash farkı, mevcut regresyonlar, kalite çıkışları | İnsan sesi doğruluğu veya kolay kullanım |
| Ekran ve akış | Evet / simülatör | Görev adımları, ekran, hata, semantics | Yaşlı/çocuk kullanıcının anladığı |
| Gerçek cihaz | Kısmen; fiziksel kurulum ve gözlem gerekir | İzin, kesinti, route, mikrofon, performans | Öğrenme ve eğitimci kabulü |
| Gerçek insan kullanılabilirliği | İnsan gözlemi; kayıt/hesaplama otomatik olabilir | Yardımsız görev, anlama, süre, yardım, görüş | Ses kalitesi ve uzun vadeli öğrenme |
| Eğitimci/öğrenme | İnsan + izinli analiz | İçerik onayı, görülmemiş/gecikmeli kontrol | Pazar liderliği veya klinik sonuç |

Durumlar: `not_run`, `blocked`, `passed`, `failed`, `not_applicable`.
Eksik/null kanıt “passed” olamaz. Atlanan testler raporda ayrı görünür.

## 4. Katılımcı planı

İki küçük iyileştirme turu önerisi: her turda **24 yetişkin**, dört yaş
diliminde altışar kişi: 18–29, 30–44, 45–59, 60+. İkinci turda mümkün olduğunca
yeni kişiler; aynı kişilerin deneyimi ayrı işaretlenir. Bu örneklem sorun
bulmak içindir, nüfus geneline istatistiksel üstünlük iddiası için yeterli değildir.

Her yaş diliminde düşük/yüksek telefon deneyimi ve başlangıç/deneyimli müzik
kullanımı bulunmalı; yaşları sadece müzik deneyimiyle karıştırma. Altı hedef
kitlenin her biri toplam örneklemde en az birkaç kişide temsil edilsin; kişi
birden çok role sahip olabilir. iOS ve Android iki tura yayılmalı. Büyük yazı
ve ekran okuyucu kullanan gerçek katılımcılar dahil edilmeli; bunların
örneklemi küçükse sonuç ayrı nitel gözlem olarak raporlanmalı.

Sonraki aşama: 13–17 yaş için altı katılımcılık ayrı tur, uygun veli/katılımcı
izin süreci ve gözetim hazır olunca. 8–12 yaş, çocuklara özel içerik ve görevler
hazırlanmadan mevcut yetişkin testine eklenmemeli. Bu yaşlar için “test edildi”
veya “uygundur” iddiası şu anda yok; hukuki süreç ayrı uzman incelemesi ister.

Katılımcı ses kayıtlarının saklanması varsayılan kapalıdır. Ekran/ses kaydı
ayrı isteğe bağlı araştırma izni gerektirir; kayıtsız gözlem seçeneği olmalı.
Araştırma kimliği rastgele kod; ad, doğum tarihi, iletişim veya ham ses rapora
girmez. Yalnız gönüllü yaş dilimi, rol ve ilgili kullanım tercihleri tutulur.

## 5. Oturum ve görevler

Oturum önerisi 30–40 dakika; ara veya erken bitirme serbest. Moderatör ilk
denemede düğmenin yerini tarif etmez. Katılımcı zorlanırsa yardım verir ve bu
durumu kayıtlar; yardımlı tamamlanma “yardımsız başarı” sayılmaz.

Görev metinleri ürünün düğme adını söylemez:

| ID | Katılımcıya verilen görev | Başarı gözlemi |
|---|---|---|
| U01 | “Beş dakikan var. Amacına uygun ilk çalışmanı başlat.” | Hedefe uygun hazır çalışmaya yardım almadan ulaşır |
| U02 | “Şimdilik mikrofon kullanmak istemiyorsun. Çalışmaya devam et.” | Ret/atlama sonrası mikrofon gerektirmeyen çalışma bulunur |
| U03 | “Bu çalışmada senden ne istendiğini anlat, örneği bul ve dene.” | Örnek ile cevap sırasını anlar; gerektiğinde tekrar dinler |
| U04 | “Uygulama bu denemeyi ölçemedi. Sence ne oldu, şimdi ne yaparsın?” | Bunu düşük yetenek/0 puan sanmaz; tekrar/çıkış yolunu bulur |
| U05 | “Bir süre ara ver; sonra uygulamaya dön.” | İstenmeyen kayıt/çalma başlamaz; devam kararı anlaşılır |
| U06 | “Bu çalışmadan sonra hangi konuyu çalışacağını bul.” | Sonraki adımı bulur ve nedenini açıklayabilir |
| U07 | “Yazıyı rahat okuyacağın boyuta getir; ses olmadan yönergeleri izle.” | Bilgi/eylem kaybı olmadan tamamlar; yalnız renk/animasyona bağımlı değildir |
| U08 | “Bugünkü çalışmanı bul ve bu veriyi cihazdan kaldır.” | Geçmişi bulur, silme kapsamını anlar, yanlış veri silmez |
| U09 | “Konuşma/prova öncesi kısa hazırlık yapmak istiyorsun.” | Kitleye uygun içerik bulunur; hazır değilse neden/kapsam açık |
| U10 | Korist: “Verilen ölçüleri çalış, kaydını dinle ve öğretmen yorumunu bul.” | Yerel koro kapsamı anlaşılır; gönderilmemiş kayıt gönderildi sanılmaz |

U01–U08 ortak çekirdek. U09/U10 yalnız uygun kitlede ve gerçekten hazır ürün
yüzeyinde uygulanır; tasarım prototipiyle yapılan tur `prototype` diye etiketlenir.
Ölçülemeyen sonuç örneği kontrollü testte gösterilebilir ama `mock` kaynağıdır;
gerçek mikrofon arızası veya insan sesi başarısı diye raporlanmaz.

Her görevden sonra “Ne kadar kolaydı?” 1–7 yanıtı ve kısa gerekçe alınır.
Oturum sonunda: “Bu uygulama sana ne sağlıyor?”, “Hangi sonucu ne kadar
güvenilir buldun?”, “Yarın niçin dönersin/dönmezsin?” soruları sorulur.

## 6. Kabul hedefleri: öneri, henüz ölçülmedi

Bu sayılar kullanıcı skorunu veya nota toleransını değiştirmez; UX araştırma
hedefidir. Pilot başlamadan sabitlenir, başarısızlıktan sonra sessizce gevşetilmez.

| Ölçüt | Önerilen kabul | Nasıl hesaplanır |
|---|---|---|
| U01 ilk çalışma | Her yetişkin yaş diliminde en az 5/6 yardımsız; medyan ≤90 sn | İlk amaç ekranından egzersize; isteğe bağlı ses aralığı süresi ayrı |
| Ortak kritik görevler | Her yaş diliminde en az %85 yardımsız tamamlanma | Başarılı görev denemesi / planlanmış geçerli görev denemesi |
| Sonuç anlama U04 | Her dilimde en az 5/6 doğru açıklama | Önceden yazılı rubrik: ölçülmedi ≠ başarısızlık |
| Mikrofon/kayıt güveni | İstenmeyen kayıt, açıklanmayan paylaşım ve yanlış silme: 0 | Her kritik olay tek başına bloklayıcı |
| Algılanan kolaylık | Her dilimde görev medyanı ≥5/7 | Yaş dilimi bazında, boş yanıtlar ayrı |
| Ciddi engel | Açık kritik engel 0 | Çıkmaz, kayıp çalışma, erişilemeyen ana eylem, mahremiyet olayı |
| Ekran okuyucu | U01–U08'in uygulanabilir olanları gerçek okuyucuda tamamlanabilir | Eksik katılımcı/cihaz kanıtı `not_run`; semantics testi yerine geçmez |

Altışar kişilik dilimlerde yüzdelerle birlikte **ham sayıları** yaz; örneğin
“5/6”. Genel ortalama iyi olsa da başarısız yaş dilimini gizleme. Terkler
tamamlanmamış görevdir; teknik test düzeni hatası ayrı dışlama gerekçesiyle
sayılır. Payda ve dışlama nedenleri raporda görünür.

Öğrenme/retention ayrı pilot: 4 hafta, gün 0 ve gün 28'de eşdeğer ama farklı
kontrol soruları; gün 7/28'de ipucusuz hatırlama. Baseline, kullanım dozu ve
eğitimci değerlendirmesi birlikte raporlanır. Kontrol grubu olmadan “uygulama
iyileşmeye neden oldu” denmez; XP artışı öğrenme sonucu değildir.

## 7. Otomatik senaryo matrisi

Tam çapraz çarpım yerine kritik kesişimler seçilir; destek kapsamı açık kalır.

- Çekirdek: dört hedef × TR/EN × mikrofon kabul/ret; yalnız hazır hedefler.
- Görünüm: 320×568, yaygın telefon, yatay, tablet; 1.0/1.3/1.6/2.0 yazı;
  2.0 üstü sistem tercihi için mevcut clamp etkisini ayrıca raporla.
- Erişilebilirlik: azaltılmış hareket, kontrast, etiket, odak sırası,
  dokunma alanı, renk dışında durum işareti. VoiceOver/TalkBack manuel kapı.
- Yaşam döngüsü: uygulama kapatma/açma, arka plan, izin ayarından dönüş,
  yarım oturum, çevrimdışı açılış, yerel geçmiş ve tekrar giriş.
- Ses çevresi: sessiz giriş, gürültü, yanlış oktav, kesinti, kulaklık çıkarma,
  Bluetooth, reddedilmiş ölçüm. Mock test ve fiziksel test ayrı kaynak etiketli.
- Veri: eski onboarding kaydı, birden çok rol, odak değiştirme, bozuk/eksik
  içerik, geçmiş silme. Test uygulaması gerçek kullanıcı verisini kullanmaz.

Fiziksel minimum: bir desteklenen iPhone, düşük/orta sınıf Android; dahili
mikrofon + kablolu kulaklık; Bluetooth ayrı destek kararı/kanıtı. Minimum
desteklenen OS ve yaygın OS kapsamı mevcut proje ayarından çıkarılır.

## 8. Rapor şeması ve otomasyon işi

Geliştirilecek yerel raporun her çalıştırmasında:

- `runId`, `appVersion`, `commit`, `dirtySnapshotHash`, `contentVersion`,
  `scenarioId`, `startedAt`, `durationMs`, `platform`, `deviceClass`, `locale`;
- `evidenceKind`: unit / widget / simulator / physical / human / educator;
- `audioSource`: none / mock / synthetic / microphone / unverified;
- `status`, `failedStep`, `artifactPath`, `skipReason`, `owner`;
- insan kaydında ayrı `participantCode`, gönüllü `ageBand`, `musicExperience`,
  `phoneExperience`, `taskOutcome`, `assistanceCount`, `ease1to7`,
  `comprehension`, `consentReference`;
- ölçülmeyen süre, başarım veya yaş alanı `null`; boş veri sıfır değil.

İnsan görev kayıtları önerilen `qa/research/` altında, uygulama event logundan
ayrı tutulabilir; araştırma verisi ve artifact'ları Git'e ekleme. Açıkça
`synthetic-demo` etiketli örnek kayıt raporun gerçek katılımcı paydasına giremez.
Ham ses/screenshot içeriği varsayılan rapora gömülmez; izin ve saklama/silme
kuralları belirlenmeden bulut sağlayıcı eklenmez.

Önerilen uygulama sırası:

1. Başlangıç dosya hash envanteri; korunan ses dosyasında fark varsa işi durdur.
2. Mevcut kalite runner'ını çalıştır, çıkış kodu ve atlananları kaydet.
3. Mevcut Maestro akışlarına yeni hedef ve toparlanma senaryolarını ekle;
   izin verilmiş test cihazında çalıştır, tekrar denemeyle ilk hatayı gizleme.
4. Gerçek insan sonuçlarının yerel giriş/doğrulama aracını ekle. Gerçek kişiyi
   otomasyon adına üretme; eksik katılımcıda kapı `not_run` kalsın.
5. Yaş/rol/cihaz kırılımları ve açık engellerle tek rapor üret.
6. Hata önceliğini belirle → UI/içerik düzelt → ilgili regresyon → yeni insan
   turu. Ses algoritmasına müdahale gereği ayrı karar olarak kaydedilsin.

Hedef rapor: “Kod geçti; iOS simülatör geçti; fiziksel Android bekliyor;
60+ U04 3/6, sonuç dili revizyon istiyor.” Tek bir genel yeşil işaret yeterli değil.

## 9. Operasyon ve sorumluluk

Ürün sahibi: hedef/kapsam ve kabul eşikleri. Geliştirici: akış/regresyon/rapor.
Araştırma moderatörü: insan görevleri ve önyargısız kayıt. Ses/konuşma eğitimcisi:
içerik ve pedagojik uygunluk. Katılımcı koordinatörü: izin, randevu, silme talepleri.
Küçük ekipte roller aynı kişide birleşebilir; ses eğitimcisi onayı uydurulamaz.

Bu belge otomasyon hedefi ve uygulanabilir test tasarımıdır. Katılımcılar
bulunmadı, oturum yapılmadı, fiziksel cihaz kabulü verilmedi ve yeni runner
yazılmadı. Mevcut kod kalite kontrolü insan testinin yerine geçmez.
