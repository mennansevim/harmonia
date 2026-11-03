# Legato karşılaştırması ve koro/ses adı araştırması

Tarih: 31 Ekim 2026. İncelenen yerel proje: `/Users/sevimm/Documents/Projects/resonia` (sohbetin eski harmonia yolu artık yok).

## Kapsam ve kanıt sınırı

Legato incelemesi App Store açıklaması, sürüm notları ve geliştiricinin resmi ürün sayfasına dayanır. Uygulama kurulup gerçek cihazda denenmedi; satıcının özellik beyanı bağımsız doğruluk testi değildir. Bizdeki durum güncel `lib/trainer`, `lib/choir`, ses domain/application kodu ve son roadmap ile karşılaştırıldı. Kodda var olması cihazda doğrulanmış olduğu anlamına gelmez. Eski README ve eski `features` kabuğu tek başına güncel ürün envanteri değildir; giriş `TrainerApp`.

## Ana sonuç

En büyük açık özellik sayısı değil, vokal ölçümün güvenilir ürün deneyimine dönüşmesi. Kulak eğitimi, nefes rehberi, günlük rota, soru istatistikleri ve koro ödev/geri bildirim akışı zaten var. Canlı perde ölçümü, zaman içinde karşılaştırılabilir vokal gelişim, eser bazlı çalışma günlüğü ve sunuculu devamlılık henüz aynı olgunlukta değil.

## Karşılaştırma

| Alan | Legato'nun beyanı | Mevcut projedeki kanıt | Öneri |
|---|---|---|---|
| Kulak eğitimi | 12 bölüm, 232 ders; dinle-hatırla-söyle | Nota, aralık, akor, dizi, yürüyüş için basamaklı ders/quiz var; içerik eğitimci onayı bekliyor | Yeni katalogdan önce mevcut içeriği onaylat; algı cevabını sesle üretimden ayır |
| Perde geri bildirimi | Canlı perde grafiği | `live_visual_feedback.dart` yalnız enerji üretir; signedCents/confidence/stability null. Tek ses kaydı sonrası deneysel frekans/sent sonucu var | Önce insan sesi ve cihaz doğrulaması; sonra canlı hedef çizgisi ve nötr ölçülemedi durumu |
| Entonasyon | Kayıt sonrası nota bazlı değerlendirme | Tek ses ve ezgi oturumlarında scoringEnabled=false | Hedef-gerçek nota, oktav farkı ve ölçülemeyen bölümleri göster; doğrulanmadan puan açma |
| Ritim | 65 ritim, 58 poliritim seviyesi | Dokunmalı ritim taklidi ve aksak desenler var; kademeli poliritim kursu bulunmadı | Temel vuruş/sus/senkop yolu ve ritim geçmişini ana ilerlemeye bağla |
| Çalışma günlüğü | Eser/aktivite bazında süre, not, rutin | Günlük rota, soru/seans sayıları, doğruluk, seri ve XP var; eser bazlı gerçek süre günlüğü yok | Eser + bölüm + aktif süre + tempo + not + kayıt sürümü |
| Araçlar | Metronom, drone, tuner, vibrato | Koro çalışmasında metronom, ön sayım, döngü, parti dengesi ve hız var | Var olan mikseri yeniden yapma; önce ihtiyaç duyulan kişisel pratik araçlarını aç |
| Nota | PDF içe aktarma, tarama ve işaretleme | Koro kaynak arşivi dosya tutuyor/açıyor; uygulama içi PDF çizim katmanı bulunmadı | Prova ekranında nota + işaret + ölçü bağlantısı, ikinci aşama |
| Süreklilik | Cihazlar arası eşitleme | TrainerStore ve ChoirStore yerel; koro paket paylaşımı var | Koro pilotundan sonra hesap/eşitleme ve teslim durumu |
| Üyelik | Ücretsiz başlangıç + Plus | Üyelik ekranı önizleme; satın alma düğmesi kapalı | Değer kanıtından sonra satın alma/geri yükleme/erişim sonlandırma akışı |

Legato bilgileri: https://www.proximitylabs.dev/ ve https://apps.apple.com/us/app/legato-music-practice-journal/id6752220169 . ABD mağazasında inceleme sırasında Plus aylık $6.99, yıllık $34.99 listeleniyor; Türkiye fiyatı değildir. Liste fiyatından gelir veya abone sayısı çıkarılamaz.

## Bizde korunacak farklılaşma

Koro modülünde şef ödev/eser/bölüm/son tarih tanımlar. Korist MIDI parti miksini çalışır, eşlikli kayıt alır veya dosya ekler. Şef zaman işareti, metin ve sesli yorum ile kabul/tekrar iste kararı verir. Bunlar kodda mevcut; ayrı bir ürün önerisi gibi yeniden geliştirilmemeli. Gerçek telefon/kulaklık, Android, gerçek koro MIDI ve şef pilotu açık kapılardır. Sunucu bulunmadığından paket aktarımı otomatik bulut teslimi değildir.

Konumlandırma önerisi: günlük bireysel kulak/ses çalışmasını gerçek koro ödevine ve şef geri bildirimine bağlamak. Legato'nun kamuya açık sayfalarında aynı koro teslim/onay akışını doğrulamadım; bu mutlak yokluk iddiası değildir. Daha doğrudan koro rakibi olarak cori de sonraki karşılaştırmaya alınmalı: https://apps.apple.com/it/app/cori-studiare-in-coro/id6670766994 .

## Öncelikli işler ve kabul ölçütleri

1. **Ses ölçümünün doğrulanması.** Desteklenen cihaz/route listesi, etiketli ve izinli insan sesi örnekleri, sessizlik/gürültü/eşlik sızıntısı/yanlış oktav kontrolü. Eşikler sonuçlara göre gevşetilmez. Geçersiz deneme puan ve başarı üretmez. Mevcut kalibrasyon altyapısı gerçek donanım gecikmesi ölçümü yerine geçmez.
2. **Tek egzersizin tam öğrenme döngüsü.** Dinle → söyle → açıklayıcı geri bildirim → aynı hedefi yeniden dene. Önce tek nota, sonra kısa ezgi. Kullanıcıya sonuçtan sonra tek somut çalışma önerisi. Eğitimci onayı ve cihaz kapısı tamamlanmadan otomatik başarı ilan edilmez.
3. **Çalışma günlüğü.** Kullanıcının seçtiği 8 dakika hedefi gerçek çalışma süresi değildir. Pause/background zamanı dışarıda; eser/bölüm/tempo/not/kayıt ayrı saklanır. XP ile vokal yetkinlik ayrı gösterilir. Aynı koşullardaki kayıtlar A/B dinlenebilir.
4. **Koro pilotu.** Davet/paket → ödev → parti çalışması → kulaklıkla kayıt → şefe gönderim → işaretli geri bildirim → yeniden kayıt akışı gerçek şef ve koristlerle tamamlanır. Elle hizalama otomatik gecikme düzeltmesi diye adlandırılmaz.
5. **Gelir altyapısı.** Bireysel gelişim paketi ve koro başına paket ayrı fiyat deneyi olabilir. İnsan eğitimci yorumu sınırlı kontenjanlı olmalı; her öğrenciye sınırsız insan hizmeti temel aboneliğe konmamalı. Satın alma, yenileme, geri yükleme ve erişim durumu test edilmeden satış açılmaz.
6. **Daha sonra:** PDF çizim/tarama, widget, tatil modu, gelişmiş poliritim ve vibrato. Bunlar temel ölçüm ve koro pilotunun önüne geçmemeli.

Kod dayanakları:
- `lib/trainer/domain/trainers.dart`, `curriculum.dart`: beş eğitim alanı ve taslak müfredat.
- `lib/trainer/learn/lesson_flow.dart`, `sing/trainer_pitch_sing_session.dart`: isteğe bağlı, puansız söyleme.
- `lib/domain/audio/live_visual_feedback.dart`: canlı enerji, perde yok.
- `lib/application/single_tone_session.dart`, `melody_session.dart`: puanlama kapalı.
- `lib/trainer/state/trainer_store.dart`, `stats/stats_tab.dart`: yerel soru/doğruluk/seri/XP; aktif süre günlüğü yok.
- `lib/trainer/home/daily_route.dart`, `prepare/breath_screen.dart`: günlük rota ve ölçülmeyen nefes rehberi.
- `lib/trainer/koro/koro_hub.dart`, `aksak_patterns.dart`: ritim/ezgi yolları ve aksak desenler.
- `lib/choir/app/practice_screen.dart`, `review_screen.dart`, `assignment_editor.dart`: prova/ödev/şef iş akışı.
- `lib/choir/data/choir_store.dart`: yerel depolama; sunucu yok.
- `lib/trainer/settings/membership_screen.dart`: satış kapalı.

## İsim taraması

Yöntem: Resmi App Store sayfalarını web üzerinden araştırma; seçili adayları Apple Search API software kataloğunda Türkiye/ABD için tekrar sorgulama. Altı aday için limit 200 ve aksan duyarsız ad eşleşmesi. Ham sonuçlar `2026-10-31-appstore-name-check.json` dosyasında. Arama katalog eksiklikleri, bölge farkları ve henüz yayımlanmamış ad rezervasyonlarını göstermez. Eşleşme bulunmaması alan adı/tescil/App Store Connect uygunluğu değildir.

| Ad | Anlam | Sonuç |
|---|---|---|
| Vocalita | İtalyanca vocalità: vokal nitelik, şarkıcının teknik/ifade özellikleri | TR/US sorgularında adı içeren uygulama eşleşmesi bulunmadı |
| Sonante | İtalyanca ses veren/çınlayan; sesle ilgili sıfat, özel bir koro tekniği değil | TR/US sorgularında adı içeren uygulama eşleşmesi bulunmadı |
| Cantilena | Vokal/lirik melodi | TR/US sorgularında adı içeren uygulama eşleşmesi bulunmadı; mevcut koro adları var |
| Appoggio | Şan terminolojisinde nefes desteği yaklaşımı | TR/US iOS sorgularında eşleşme yok; Google Play'de doğrudan Appoggio: Breath for Singers var |
| Corale | Koroya ilişkin; koro/toplu söyleme bağlamı | Tam tek kelimelik eşleşme bulunmadı; TR/US'ta Corale Santa Cecilia Bernate var |
| Intonare | Sesi doğru perdeye getirmek, akort etmek | TR/US'ta tam Intonare adlı Music uygulaması var |
| Cantabile | Şarkı söyler gibi | Aynı adla metronom var |
| Vocalise | Sözcüksüz vokal egzersizi | Vocalise – Smart Singing doğrudan ses eğitimi rakibi |
| Tessitura | Eserin ağırlıklı ses bölgesi; tam ses aralığıyla aynı şey değil | Tessitura Pro Scales var |
| Cantus | Latince şarkı/söyleyiş | Cantus ve Cantus+ mevcut |
| Divisi | Bir partinin alt gruplara ayrılması | DIVISI adlı Music uygulaması var |
| Tutti | Topluluğun tümünün birlikte icrası | Tutti adlı ve Tutti önekli çeşitli müzik/koro uygulamaları var |
| Unison | Aynı perdede birlikte icra | Unison ve UNISON Music Journal dahil eşleşmeler var |
| Leggiero | Hafif icra | Tam adla yiyecek/içecek uygulaması var; müzik rakibi diye sınıflanmadı |

İsim önerim: ürünün ses eğitimi yönü için **Vocalita**, daha geniş ses/müzik markası için **Sonante**. **Cantilena** üçüncü aday; daha uzun ve mevcut koro kullanımları daha belirgin. Sonorita geliştirici adıyla karşılaşıldı; geliştirici adı tam uygulama adı değildir. Bu isimleri yasal olarak kullanılabilir ilan etmiyorum.

Anlam kaynakları:
- https://www.treccani.it/vocabolario/vocalita/
- https://www.treccani.it/vocabolario/sonante1/
- https://www.treccani.it/vocabolario/cantilena/
- https://www.treccani.it/vocabolario/intonare1/
- https://www.treccani.it/vocabolario/ricerca/CORALE/
- https://www.treccani.it/enciclopedia/tessitura_res-c83ae136-8bb7-11dc-8e9d-0016357eee51_%28Enciclopedia-Italiana%29/

Mağaza kanıtları:
- https://apps.apple.com/us/app/cantabile/id1638467627
- https://apps.apple.com/pl/app/vocalise-smart-singing/id6468425084
- https://apps.apple.com/us/app/tessitura-pro-scales/id6745803127
- https://apps.apple.com/ca/app/cantus/id6758154981
- https://apps.apple.com/es/app/divisi/id6449466657
- https://apps.apple.com/tr/app/intonare/id6790028334
- https://apps.apple.com/tr/app/corale-santa-cecilia-bernate/id6479448157
- https://apps.apple.com/tr/app/tutti-self-harmony-choir/id6794339509
- https://apps.apple.com/tr/app/unison-music-journal/id6802885345
- https://apps.apple.com/ie/app/leggiero/id1330614047
- https://play.google.com/store/apps/details?id=com.vicinolabs.appoggio

Bu çalışma araştırma ve kaynak kod incelemesidir. Uygulama davranışı değiştirilmedi, test paketi yeniden çalıştırılmadı, önceki test sonuçları yeni doğrulama gibi sunulmadı. Kodda yeni özellik uygulanmadı; öneriler kullanıcı kararı bekleyen ürün öncelikleridir.
