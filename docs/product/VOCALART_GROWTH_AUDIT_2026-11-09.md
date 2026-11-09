# Vocalart — geniş kitle, kullanılabilirlik ve büyüme incelemesi

Tarih: 9 Kasım 2026. Kapsam: mevcut çalışma ağacının ürün/kod incelemesi,
resmî ürün sayfalarıyla sınırlı rekabet taraması ve yeni geliştirme önerileri.
Bu bir ürün geliştirme teslimi veya gerçek kullanıcı testi sonucu değildir.
Kullanıcının mevcut ses tespit algoritması korunacaktır. Kaynak kod değiştirilmedi.

## 1. Temel karar

Vocalart'ın en değerli büyüme fırsatı, aynı ses ve kulak altyapısını farklı
amaçlara göre anlaşılır günlük çalışmalara dönüştürmektir. Bugün güçlü bir
egzersiz temeli var; ancak tiyatro sanatçısı, yeni başlayan ve sınava hazırlanan
öğrenci büyük ölçüde aynı başlangıç ve günlük rota mantığıyla karşılaşıyor.

Önerilen ürün vaadi: **“Sesini, kulağını ve sahne hazırlığını kendi hedefine
uygun kısa çalışmalarla geliştir.”** Bu bir konumlandırma önerisidir; başarı,
sağlık, sınav kazanma veya pazar liderliği garantisi değildir.

Geniş hedef kitleyi destekleyen mimariyi şimdi kur; içerikleri sırayla doğrula.
İlk pilotta yetişkin amatör şarkıcı/korist ve müziğe yeni başlayanları odak al.
Konservatuvar ve konuşma/sahne rotalarını ayrı içerik kabul kapısıyla genişlet.
Bu öncelik, diğer kitlelerin üründen dışlanması anlamına gelmez.

## 2. Bugün gerçekten ne var?

Aktif açılış `lib/main.dart → TrainerApp → HomeShell` zinciridir. Eski
`lib/features/` ekranlarının tamamı ana ürün değildir; bazıları Egzersizler
üzerinden yeniden kullanılır. Eski roadmap maddelerini doğrudan eksik listesi
olarak almak yanıltıcı olur.

| Alan | Güncel kod kanıtı | Açık ihtiyaç |
|---|---|---|
| Kulak eğitimi | `lib/trainer/domain/trainers.dart`: nota, aralık, akor, dizi, yürüyüş | Başlangıç seviyesine uygun açıklama ve hedefe göre ders seçimi |
| İlk kullanım | `lib/trainer/onboarding/onboarding_flow.dart`: sekiz durum; rol, mikrofon, aralık, odak, süre, hatırlatma | İlk değerden önce çok karar; konuşmacı/oyuncu/sınav hedefleri açık değil |
| Günlük çalışma | `lib/trainer/home/daily_route.dart`: süreye göre nefes + kulak + opsiyonel ses | Hedefe ve hazır içeriğe göre farklı program; toplam süreyi gerçek içerikle eşleştirme |
| Egzersiz bulma | `lib/trainer/koro/koro_hub.dart`: arama, kategori ve durum etiketleri var | Yeni katalog icat etmek yerine mevcut katalogda amaç/süre/seviye filtreleri |
| Nefes | `lib/trainer/prepare/breath_screen.dart`: 4/2/6 taslak rehber, duraklatma, atlama, mikrofonsuz | Uzman onaylı alternatifler ve ses ısınma dizileri; tamamlamak beceri ölçümü değil |
| Ses tespiti ve aralık | `live_pitch_tracker.dart`, `range_test.dart`, `range_ladder.dart`, `range_score.dart` | Algoritma değişikliği önerilmiyor; anlaşılır yönergeler ve mevcut davranışı koruyan regresyon |
| Gerçek zamanlı görsel | `range_test.dart` içinde `LivePitchTracker` kullanılıyor | “Canlı perde hiç yok” şeklindeki eski QA ifadesi güncel kodu açıklamıyor; görsel iz ve deneme kararı ayrılmalı |
| Ezgi/ritim | Egzersizler üzerinden dinle-söyle, ezgi, ritim, alkış, aksak akışları | Deneysel/taslak durumlarını koruyarak günlük rotaya anlamlı bağlama |
| Nota okuma | Nota adı tanıma mevcut; `skill_graph.dart` dikte/deşifreyi `awaitingContent` tutuyor | Porte okuma, süre/sus, deşifre ve dikteyi ayrı kazanımlar olarak geliştirme |
| Koro | `lib/choir/`: yerel ödev, MIDI, kayıt, inceleme, paket aktarımı | Gerçek koro pilotu, kolay dosya alışverişi; hesap/sunucu/davet/panel ayrıca planlanmalı |
| Eğitimci yorumu | `human_review_preview_screen.dart` ve `domain/human_review/` | Canlı servis değil; gerçek eğitimci, kapasite ve yetkili teslim altyapısı |
| İlerleme | `stats_tab.dart`: XP ve pratik seviyesi, aralık ve öneriler | Pratik miktarı, dinleme doğruluğu, ses üretimi, eğitimci yorumu ayrı açıklanmalı |
| Erişilebilirlik | `accessibility_audit_test.dart`: küçük/yatay ekran, 1–2× yazı, hedef/etiket/kontrast | Gerçek VoiceOver/TalkBack, farklı yaşlarda anlama ve sistemin 2× üzeri yazı ihtiyacı |
| Otomasyon | 11 numaralı Maestro akışı, integration testler, kalite komutu ve QA raporlama | Yeni hedef rotaları, Android cihaz turu ve gerçek insan pilot verisinin ayrı raporu |
| Analitik | `product_event.dart`: sınırlı olay şeması, geçici bellek kaydı | Kalıcı ve izinli araştırma ölçümü yok; mevcut session kimliğiyle D7 kişisel geri dönüş ölçülmez |

### İncelemede öne çıkan somut uyumsuzluklar

1. `DailyRoute.forMinutes` yalnız süreyi bilir; kullanıcının “konuşma/sahne”
   hedefini bilen bir program seçimi değildir.
2. `_finish` seçilen odaklar arasında TrainerKind bulamazsa aralık eğitimine
   döner. Yalnız “ses” hedefi seçen kişinin ilk dersiyle beklentisi arasındaki
   uyum gerçek kullanıcı testinde incelenmeli; bunu kanıtlanmış terk nedeni sayma.
3. “Isınma” kategorisinde nefes rehberi var; bağımsız, eğitimci onaylı ses
   ısınma müfredatı saptanmadı. Nefes rehberini tam ses eğitimi diye pazarlama.
4. Tiyatro/diksiyon/artikülasyon için aktif trainer kataloğunda ayrı bir rota
   saptanmadı. Bu kullanıcıların ihtiyacını mevcut kulak sınavıyla eşitleme.
5. `TrainerApp` yazıyı 2× ile sınırlıyor. 2× testinin geçmesi, daha büyük sistem
   yazısı isteyen bir kişinin erişimini doğrulamaz; yeniden akış tasarımı gerekir.
6. “Usta/Üstat/Maestro” XP seviyeleri pratik motivasyonudur. Kullanıcı bunları
   doğrulanmış ses yetkinliği sanıyor mu test et; gerekirse “pratik seviyesi”
   ifadesini belirginleştir, kazanım iddiasına dönüştürme.

## 3. Altı hedef kitle, ortak altyapı

| Kitle | Asıl iş | Önerilen ilk deneyim | Başarı kanıtı |
|---|---|---|---|
| Müziğe meraklı/yeni başlayan | Ne yapacağını bilerek başlamak | Kısa dinle-ayır + örnekli nota tanıma | Yardımsız ilk görev ve sonucu kendi cümlesiyle açıklama |
| Korist | Prova öncesi hazırlanmak, partisini korumak | Isınma + aralık/ritim; mevcut koro ödevine köprü | Ödeve erişim, prova rutini, gerçek şef gözlemi |
| Şarkıcı/ses sanatçısı | Düzenli ısınmak ve belirli pasajı çalışmak | Onaylı ısınma + dinle/tekrar + öz dinleme | Rutinin uygulanması ve eğitimci değerlendirmesi |
| Tiyatro/müzikal sanatçısı | Metni anlaşılır, niyetli ve rahat söylemek | Artikülasyon, vurgu/durak, örnekli kısa metin | Öz karşılaştırma ve insan değerlendirmesi; otomatik diksiyon puanı yok |
| Seslendirmeci/konuşmacı | Konuşma öncesi hazırlık | Kısa nefes farkındalığı + artikülasyon + metin provası | Görev tamamlama ve karşılaştırmalı insan dinlemesi |
| Konservatuvar adayı | Sınav becerilerine çalışmak | Kulak + ritim + porte; sonra doğrulanmış sınav protokolü | Görülmemiş/ipucusuz kontrol; okul kapsamı güncel kaynakla doğrulanır |

Yaş, müzik seviyesi ve teknoloji deneyimi ayrı eksenlerdir. Yaştan ses tipi,
nota toleransı veya zorunlu kolay mod türetme. “Daha büyük yazı”, “örneği
göster”, “süre baskısı olmasın” tercihleri herkes için erişilebilir olsun.

## 4. Kullanım kolaylığı tasarımı

Mevcut Bugün / Egzersizler / Gelişim yapısını koru; koro ayrı bağlamda kalsın.
Ana navigasyonu yeniden büyütmek yerine içerik ve yönlendirmeyi iyileştir.

- İlk giriş: “Bugün ne için çalışıyorsun?” → süre → uygun ilk çalışma.
  Hedef: ilk çalışmaya en fazla üç karar. Mikrofon yalnız gerektiğinde;
  aralık ölçümü, ayrıntılı rol ve hatırlatma ilk değerden sonraya taşınabilir.
- Hedefler: “Sesimi hazırlamak”, “Kulağımı geliştirmek”, “Konuşma/sahne”,
  “Sınava hazırlanmak”. Koro üyeliği, bu hedeflerden bağımsız bir kullanım bağlamı.
- Bugün: tek ana “Çalışmaya başla” düğmesi, gerçek içerik sürelerinin toplamı,
  adım sayısı ve anlaşılır amaç. Hazır olmayan içerik günlük rotaya girmesin.
- Her egzersiz: ne yapacağım → örneği dinle/gör → dene → ne oldu → tek sonraki
  adım. Teknik sent/Hz ayrıntısı açılabilir, ilk sonuç sade olmalı.
- Sonuç dili: “Bu denemede ses ölçülemedi; tekrar deneyebilirsin” ile
  “yanlış yanıt” ayrı. Algı sorusunun puanı ses üretim puanına dönüşmesin.
- Konuşma rotasında nota bilme önkoşulu olmasın. Porte ile nota adı tanıma
  ayrı egzersizler olarak görünür olsun.
- Eğitimci örnekleri kısa ses + metin + gerektiğinde altyazılı video; yalnız
  videoyla öğrenmeye veya yalnız renkle durum anlamaya zorlamasın.
- Arama zaten mevcut: amaç, süre, seviye ve çevrimdışı kullanılabilirlik
  bilgisiyle geliştirilmesi yeterli. Favoriler ve kaldığın yere dön sonraki dilim.
- TR/EN metinler aynı anda tasarlansın; profesyonel terminoloji editörü ve
  hedef kullanıcılarca anlaşılabilirlik doğrulansın.

## 5. Nefes, ses açma ve “diyafram” kapsamı

Ürün başlığı önerisi: **“Nefes ve ses hazırlığı”**. Kullanıcının “diyafram
açma” dediği ihtiyacı nefes farkındalığı ve konuşma/şarkı sırasında nefes desteği
içeriği olarak ele al. Telefondan diyafram kapasitesi, akciğer kapasitesi,
ses sağlığı veya doğru kas kullanımı ölçülmüş gibi sonuç üretme.

İçerik paketi önerisi: rahat hazırlık, nefes farkındalığı, eğitimci gösterimli
ses ısınma, artikülasyon, kısa uygulama ve bitiriş. Süre/desen/tekrar sayısını
bu inceleme reçetelemez; içerik uzmanı belirler. Mevcut 4/2/6 düzeni herkese
uygun standart diye genişletme. Tutmasız alternatif de uzman incelemesine girsin.

Zorlanma halinde kolayca durma/atlama, kullanıcıya uygun rahat aralık ve
ses yorgunluğu halinde dinlenme yönlendirmesi içerikte yer almalı. Ses bakımını
ürün tasarımına katma gerekçesi için [NIDCD ses bakımı rehberi](https://www.nidcd.nih.gov/health/taking-care-your-voice).
Bu kaynak belirli bir Vocalart egzersizinin etkinliğini doğrulamaz.

## 6. Rekabette fark yaratacak yön

9 Kasım 2026'da erişilen resmî sayfalarda [EarMaster](https://www.earmaster.com/)
kulak, deşifre, ritim ve eğitimci/kurum kullanımını birlikte sunuyor.
[Vocal Tools Academy](https://vocaltools.app/en/academy) ses temeli, nefes,
ısınma, nota okuma ve armoniyi öğrenme rotalarında topluyor. Bunlar üreticilerin
özellik beyanlarıdır; bağımsız kalite veya pazar sıralaması ölçümü değildir.

Dolayısıyla sadece daha çok egzersiz eklemek güçlü bir farklılaşma olmaz.
Vocalart için test edilecek avantaj hipotezleri:

1. **Türkçe yönerge ve gerçek sahne/prova bağlamı:** aynı beceriyi günlük
   kullanımına bağlama; Türkçe artikülasyon ve aksak ritim uzman içeriği.
2. **Anlaşılır ve dürüst sonuç:** neyin ölçüldüğü, neyin çalışıldığı ve bir
   sonraki adım belli; her şeyi tek “ses skoru”na indirmeme.
3. **Eğitimciyle kapanan öğrenme döngüsü:** gerçek yorum → tek çalışma hedefi
   → uygun egzersiz → sonraki derste kontrol. Plus teslimini AI yazmaz.
4. **Prova ile bireysel çalışma köprüsü:** şefin seçtiği zorluktan kişisel
   egzersize gitme. İlk sürümde şef etiketi yeterli; otomatik teşhis gerekmiyor.
5. **Her yaşta kolay ilk değer:** izin ve kurulum engeline takılmadan kısa,
   anlaşılır bir çalışma; gerçek kullanıcı testinde kanıtlanmalı.

“Alanında 1 numara” için önce karşılaştırılabilir kategori tanımı gerekir:
örneğin Türkiye'de Türkçe ses/kulak günlük çalışma deneyimi. Pazar liderliği
indirme, gelir, etkin kullanıcı veya öğrenme etkisi olarak ayrı tanımlanmalı.
Bu inceleme liderlik iddiasını doğrulamıyor.

Ürün ana metriği önerisi: **haftada en az üç ayrı gün, hedefine uygun bir
çalışmayı tamamlayan gönüllü aktif kullanıcı oranı**. Çalışma bitirmek öğrenme
kanıtı değildir; bunu gecikmeli/görülmemiş kontrol ve eğitimci değerlendirmesiyle
ayrı izle. İlk pilotta anonim araştırma kodu + ayrı katılım onayıyla ölç;
mevcut geçici session kayıtlarından kişi bazlı D7/D30 uydurma.

Dağıtım denemesi: önce bir yetişkin koro ve bir eğitmen grubu; ardından bir
tiyatro/seslendirme atölyesi. Her kanalda ilk göreve ulaşım, ikinci haftaya
geri dönüş ve eğitmenin hazırlık yükü ölçülsün. İletişim, davet gönderimi,
ücretli reklam veya satış bu inceleme kapsamında yapılmadı.

Paketleme: ücretsiz ilk değer ve temel rutin; Premium'da doğrulanmış içerik
derinliği; Plus'ta kapasitesi belli gerçek insan hizmeti; Koro ayrı ürün.
Erişilebilirliği, durdurmayı ve veri silmeyi ücret duvarının arkasına koyma.
Fiyatı ve ödeme isteğini gerçek pilotla araştır; burada fiyat icat edilmedi.

## 7. Öncelikli backlog ve kabul koşulları

Eforlar keşif sonrası güncellenecek planlama bantlarıdır; tek geliştirici ve
erişilebilir eğitimci varsayımıyla, taahhüt değildir. P0 önce, P1 sonra.

| ID | Öncelik / iş | Efor / bağımlılık | Kabul |
|---|---|---|---|
| WIDE-01 | P0: hedef → süre → ilk çalışma | 3–5 gün; mevcut onboarding/veri uyumu | Eski kullanıcı tercihi korunur; izin ilk ihtiyaçta; görev testinde ölçülür |
| WIDE-02 | P0: amaç bazlı günlük rota | 4–7 gün; WIDE-01, içerik statüsü | Ses odaklı kullanıcı sessizce yalnız aralık rotasına düşmez; kapalı içerik önerilmez |
| WIDE-03 | P0: sade sonuç ve sonraki adım | 3–5 gün; mevcut sonuç sözleşmeleri | Ölçülmedi ≠ yanlış; XP ≠ beceri; skor/eşik değişmez |
| WIDE-04 | P0: erişilebilirlik ve yaş pilotu | 1–2 hafta + katılımcı bulunması | Protokoldeki yaş dilimlerinde engel görünür; VoiceOver/TalkBack elle denenir |
| WIDE-05 | P0: üç örnekli hazırlık rutini | 1–2 hafta + eğitimci kayıt/onayı | İçerik sürümlü/onaylı; nefes başarısı uydurulmaz; durdurma her adımda |
| WIDE-06 | P1: porte, süre/sus ve nota okuma | 2–4 hafta + eğitimci | Görsel tanıma ile işitsel tanıma ayrı; doğrulanmış doğru cevaplar |
| WIDE-07 | P1: konuşma/sahne pilot paketi | 2–3 hafta + uzman içerik | Bir kısa metin provası uçtan uca; otomatik diksiyon/sağlık puanı yok |
| WIDE-08 | P1: konservatuvar beceri paketi | 2–4 hafta + okul/içerik doğrulama | Protokol ve yardım kayıtlı; sınav garantisi yok; 2/3/4 kayıtları gelmeden açılmaz |
| WIDE-09 | P1: şef etiketi → kişisel çalışma | 1–2 hafta + gerçek koro pilotu | Şefin seçtiği hazır egzersize gider; otomatik başarı üretmez |
| WIDE-10 | P1: izinli pilot raporu ve regresyon | 4–7 gün; araştırma şeması | Gerçek/sentetik veriler ayrı; eksik veri bilinmiyor; ham ses dışarı çıkmaz |
| WIDE-11 | P2: hesap/sync, canlı Plus ve koro servisi | Ayrı keşif ve yetki | Auth, saklama/silme, kapasite, ödeme ve pilot kapıları tamamlanmadan canlı sayılmaz |

## 8. Aşamalı uygulama sırası

- **İlk 2 hafta:** WIDE-01–03'ün dar prototipi; ses motoru koruma kontrolü;
  araştırma görevleri ve içerik envanteri. Mevcut akışla başlangıç ölçümü al.
- **3–4. haftalar:** 18 yaş üstü ilk kullanılabilirlik turu; üç onaylı rutin;
  erişilebilirlik düzeltmeleri. Başlangıç ve yeni akış sırasını katılımcılar
  arasında dengele; öğrenilmiş ekranın sonucu şişirmesini önle.
- **5–8. haftalar:** ikinci insan turu, porte veya konuşma rotasından pilotta
  daha güçlü ihtiyaç göstereni genişlet; gerçek cihaz matrisi ve koro köprüsü.
- **9–12. haftalar:** 4 haftalık tekrar kullanım/öğrenme pilotunu değerlendir;
  içerik ve paketleme kararını ver. Yaş, cihaz ve müzik deneyimi bazında
  başarısızlıkları kapatmadan genel yayın iddiası üretme.

Çocuk/ergen grubu, uygun katılım/veli süreci ve eğitimci gözetimi hazır olunca
ayrı aşamaya alınır. Zaman çizelgesi dış kapılar nedeniyle uzayabilir.

## 9. Ses algoritmasını koruma sözleşmesi

Korunan kapsam sadece YIN dosyası değildir: `lib/domain/audio/`,
`lib/domain/scoring/`, `lib/infrastructure/audio/`, ilgili application session
ve calibration akışları, `lib/trainer/sing/`, `lib/trainer/audio/`,
`range_ladder.dart`, `range_score.dart`, `range_test.dart` içindeki yakalama/
karar bağları, izin/native audio yapılandırması, fixture ve scorer beklentileri.

- Frekans tespiti, örnekleme, smoothing, pencere, eşik, kalibrasyon, oktav,
  tolerans, kalite kararı ve puan formülü bu ürün iyileştirmesinin dışında.
- Başlangıç **mevcut kirli çalışma ağacıdır**; yalnız HEAD karşılaştırması
  kullanıcı değişikliklerini yanlışlıkla geri alabilir. İş öncesi dosya hash
  envanteri ve diff al, iş sonunda o envanterle karşılaştır.
- UI testi geçsin diye mevcut ses testinin beklenen sonucunu değiştirme.
  Ses hatası görülürse ayrı bulgu yaz; bu pakette algoritmayı “düzeltme”.
- UI metni/hizası ses dosyasına gömülüyse metni ayrı sunum bileşenine taşıma
  gereğini ayrı iş olarak değerlendir; motor davranışına dokunmadan kanıtla.
- Mevcut sentetik regresyonlar aynı girişte aynı karar/sonuçları korumalı.
  Gerçek cihaz ve insan benchmark'ı ayrıca toplanır; kötü sonuç algoritmayı
  izinsiz değiştirme yetkisi doğurmaz.
- Hazır 2/3/4 sesli piyano kaydı → öğrencinin tek tek tekrarı ana yol.
  Dosyalar ve gerekli kabul gelmeden placeholder kapalı kalır. Mevcut sentez
  akor tanıma quiz'i ile bu kayıt temelli tekrar özelliğini karıştırma.

## 10. Teslim ve doğrulama sınırı

Bu pakette ürün raporu, [test/otomasyon protokolü](VOCALART_USABILITY_PROTOCOL_2026-11-09.md)
ve [uygulama promptu](VOCALART_IMPLEMENTATION_PROMPT_2026-11-09.md) hazırlandı.
Gerçek insan testi, cihaz turu, yeni otomasyon koşucusu, içerik kaydı, hosted CI,
upload, ödeme, mesaj, commit, push veya deployment yapılmadı.

Güncel kalite çalıştırmasının sonucu CURRENT_ROADMAP.md ve IMPLEMENTATION_LOG.md
WIDE-AUDIT-01 kaydında tutulur. Önceki loglardaki test sayıları bu incelemenin
çalıştırma sonucu diye sunulmaz.
