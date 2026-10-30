# Resonia — Ticari başarıdan ürüne aktarım

İnceleme: 20 Ekim 2026. Üç referans: Simply Piano/Simply, Yousician,
Duolingo Music. Bu bir mağaza gelir sıralaması veya yatırım/getiri önerisi
değildir. Aynı dönem/ülke/platform için uygulama bazlı gelir ve maliyet verisi
yok; en çok kâr eden üç uygulama oldukları doğrulanmadı. Simply ve Duolingo
ekosistem toplamları tek uygulamaya/müzik modülüne atfedilemez. Ücretli hesapla
uygulamalı kullanım veya tüm onboarding/paywall ekranlarının denetimi yapılmadı.

## 1. Ticari kanıt ve sınırları

| Referans | Kamuya açık kanıt | Güven/sınır |
|---|---|---|
| Simply Piano + Simply ekosistemi | CTech, 21 Haziran 2021 haberinde JoyTunes'un 2020 gelirini yaklaşık 100 milyon USD bildirdi. | İkincil basın kaynağı, tarihsel şirket toplamı; bugünkü Simply Piano/Sing geliri veya kârı değil. Aynı haber kârlılığın henüz gerçekleşmediğini belirtiyor. |
| Yousician | Suomen Asiakastieto'nun Yousician Oy 2025 kaydı: 52,981 milyon EUR ciro, 3,513 milyon EUR faaliyet kârı. | Finansal veri sağlayıcısı; şirket kapsamı, Singing modülü değil. Platform/platform dışı dağılım yok. Faaliyet kârı net kâr veya yatırım getirisi değildir. |
| Duolingo Music'in içinde bulunduğu Duolingo | FY2025 hissedar mektubu: 1.037,6 milyon USD gelir ve yıl sonunda 12,2 milyon ücretli abone. | Birincil SEC belgesi; dil/diğer dersler toplamı. Music için ayrı gelir veya kârlılık açıklanmıyor. Doğrudan konservatuvar rakibi değil, alışkanlık/abonelik referansı. |

Kaynaklar: [CTech](https://www.calcalistech.com/ctech/articles/0,7340,L-3910571,00.html),
[Asiakastieto](https://www.asiakastieto.fi/yritykset/fi/yousician-oy/23743640/taloustiedot),
[Duolingo FY2025](https://www.sec.gov/Archives/edgar/data/1562088/000162828026012246/q4fy25duolingo12-31x25shar.htm).

## 2. En güçlü örüntüler: gözlem ile çıkarım ayrı

**Simply:** Kısa çalışma ve kişiselleştirme. Yardım merkezi beş dakikalık
alıştırmaları tanımlıyor; aynı belge yeni çalışma biçimlerine geçişte bu
özelliğin bazı sürümlerde görünmediğini söylüyor. Simply Sing, şarkıların
ses aralığına uyarlanmasını sunuyor. Aile planı beş kişisel profil içeriyor.
Bunlar resmî ürün özellikleri; hangi özelliğin en çok gelir ürettiği veya
öğrenmeyi ne kadar artırdığı açıklanmıyor.
[Kısa çalışma](https://piano-help.hellosimply.com/en/articles/7939170-what-are-5-minute-workouts),
[Simply Sing](https://www.hellosimply.com/simply-sing),
[aile planı](https://piano-help.hellosimply.com/en/articles/6816433-learn-with-your-family-multiple-profiles).

**Yousician:** Söyleme rehberinde yavaşlatma, zor parçayı bölümlere ayırma,
seçili kısmı döngüleme ve sonradan geri dönme var. Aile ürünü dört ayrı
Premium+ hesabı sunuyor. Hata sonrası hedefli çalışma ve ilerleme için anlamlı
bir tekrar nedeni bizim çıkarımımız; bunların gelir katkısı ayrı ölçülmemiş.
[Söyleme rehberi](https://support.yousician.com/hc/en-us/articles/360000555665-The-best-way-to-practice-singing),
[aile planı](https://yousician.com/family?bx=true).

**Duolingo:** Şirketin yayımladığı eski streak A/B deneyinde günlük hedefi
seriden ayırmak D14 geri dönüşünde %3,3 artışla raporlanmış. Bu dil ürünü
bağlamındaki şirket deneyidir; müzik/Resonia için nedensel etki veya aynı
artış garantisi değildir. Music'te beceriye bağlı popüler şarkı çalışmaları
ve Super için daha geniş tekrar erişimi bulunuyor. Arkadaş görevleri ortak
çalışmayı destekliyor; sosyal özelliklerle tamamlama korelasyonu tek başına
nedensellik değildir.
[Deney](https://blog.duolingo.com/improving-the-streak/),
[Music şarkıları](https://blog.duolingo.com/popular-songs-music-course/),
[arkadaş görevleri](https://blog.duolingo.com/de/freundesmissionen/).

“En tutan” ifadesi burada üç üründeki güçlü örüntüler anlamında kullanılır.
Özellik bazlı gelir/retention sıralaması mevcut değil. Resonia seçimleri
test edilecek hipotezlerdir; görseller, içerikler, sesler veya marka kopyalanmaz.

## 3. Mevcut ürünle fark analizi ve uygulama işleri

| İş | Resonia'da bugün | Eklenecek / kabul kapısı | Öncelik |
|---|---|---|---|
| GROW-01a / F27: çalışma düzeni | Günlük seri var; son yedi gün dökümü bu pakette eklendi. | Yerel takvimde son7 gün, desteklenen cohort'ta geçerli tur; aynı gün tek sayılır; düşük doğru da çalışmadır. Mock/unknown/future hariç; başarı puanına karışmaz. | Kod-test |
| GROW-01b / F27: gönüllü hedef | 5/12/15 dakika ve günlük plan var. | İsteğe bağlı haftalık gün hedefi, değiştir/atla; izinli hatırlatma. Hedef kaçınca ücretli kurtarma veya utandırma yok. Streak/ustalık ayrı. Yeni izin/plugin kararı ve cihaz testi gerekir. | P1, GROW-01a sonrası |
| REVIEW-01b + F09: hatayı dinle/çalış | Soru-cevap dökümü var; ezgide manuel aralık/tekrar hazır. | Bitmiş turda gerçek örnek ve seçilen derecenin sentetik örneği, açık kaynak etiketi; serialize load/stop/close/lifecycle. İnceleme score/plays/retention/history'yi değiştirmez. Sonra zor bölüme geçiş; otomatik hata bölgesi yalnız kanıtla. | P1, sıradaki ses işi |
| F02/F05/F12: kısa adaptif oturum | Günlük öneri, beceri yolu, geçmiş mevcut; tüm ses becerileri ölçülmüyor. | Tek dokunuşla mevcut 5dk planına giriş, açıklanabilir zayıf-alan önerisi ve cohort içi haftalık beceri raporu. Demo sonuçlarından kişisel gelişim uydurma. | P1; önce güvenilir ölçüm |
| F19: anlamlı mini repertuvar | Büyük ticari katalog MVP dışında; karar korunuyor. | Önce özgün/lisansı belgelenmiş kısa ezgiler; öğrenilen derece/ritimle eşleştirme. Rahat aralığa uyarlama ancak doğrulanmış aralık ve eğitimci onayıyla; kullanıcı sınırı değiştirebilir/durdurabilir. Sınavda transpoze yardım yok. | P2; içerik/BENCH/EDU |
| F15/F17: haftalık görev ve sosyal bağlılık | Lig/öğretmen işi planda; gerçek sosyal servis yok. | Önce özel sınıf ortak hedefi veya bireysel görev; opt-in, takma ad, çıkış/silme; aynı test zorluğu/sürümü. Ses genişliği yarışması ve sahte kullanıcı yok. | P3; hesap/gizlilik/backend |
| F16/F21: ödeme karşılığı süreklilik | Premium/Plus planda; ödeme bağlı değil. | İlk anlamlı çalışma/sonuç ücretsiz. Premium: daha derin rapor, yapılandırılmış program, deneme; restore/iptal/süre/fiyat açık. Plus: kotası ve kapasitesi doğrulanmış gerçek eğitimci yazısı. Güvenlik/ölçüm kalitesi ücretle açılmaz. | P2; PAY ve HUM kapıları |
| F28: aile/çoklu öğrenci paketi | Yok; bu araştırmayla değerlendirmeye eklendi. | Bireysel plan doğrulanınca hesap/entitlement/ayrı sonuç/özel kayıt yetkisi; aile üyesi diğerinin sesini otomatik göremez. Ücretsiz pilot ve kapasite araştırması; fiyat/kontenjan henüz seçilmedi. | P3; kullanıcı kararı, DATA/PAY |

F02/F05/F09/F12/F15/F16/F17/F19/F21 yeniden oluşturulmayacak; mevcut işleri
bu kabul kriterleriyle genişlet. Önce güvenilir çekirdek ve REVIEW-01b; büyük
katalog/aile/lig için yayını geciktiren kapsam artışı yapma. Aile planı yeni
onaylanmış satış ürünü değil, geliştirme backlog'udur.

## 4. Ticari deneyler ve karar kuralları

1. Alışkanlık: son7 gün kartı → yedi gün içinde geçerli çalışma günü ve D7/D30.
   Açılış, demo oynatma veya kalitesiz kaydı “başarılı gün” sayma. Aynı zaman
   dilimi/pencereyle kontrol grubu; gelir artışı iddiası için örneklem gerekli.
2. Hedefli tekrar: hata dökümünden çalışma başlatma → farklı yeni soruda ve
   sonraki gün aynı beceri başarısı. Kolay soruyu ezberlemek ana metrik değil.
3. Premium: ilk değer sonrası teklif → deneme/ödeme/restore/iptal/iade. Fiyatı
   mağazadan al; sahte indirim/geri sayım yok. Canlı ödeme ayrı yetki ister.
4. Plus: eğitimci teslim süresi, yorum kalitesi, tekrar kullanım ve katkı marjı.
   Öğretmen ücreti, vergi, mağaza kesintisi, iade, içerik ve edinim maliyetleri
   dahil edilmeden “yüksek getiri” sonucu verme. AI insan yorumunun yerini almaz.

Analitik şu an yerel/gönderimsiz; canlı rıza/servis kurulmadan bu deneyler
yapılmış sayılmaz. D7/D30 için katılımcı pilotu ve ölçüm planı gerekir.

Önerilen konum: **Kısa günlük işitsel çalışma + açıklayıcı hata tekrarı +
konservatuvar/koro rotası + isteğe bağlı gerçek eğitimci.** Genel piyano/şarkı
uygulamasını yeniden yazmak değil; bu ürünlerin devam etme nedenlerini kendi
uzmanlık alanımıza uyarlamak. Başarı/gelir garantisi yok.
