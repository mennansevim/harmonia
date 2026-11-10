# Harmonia tasarım devri

Bu paket, konuşmada hazırlanan etkileşimli mobil tasarım örneğidir. Üretimdeki Flutter uygulamasının ekran görüntüsü veya uygulanmış yeni sürümü değildir.

## Dosyalar

- `harmonia-preview.html`: tarayıcıda açılabilen, gömülü önizleme kabuğu içeren sürüm.
- `harmonia-source.txt`: başka bir LLM'ye yüklemek veya metin olarak kopyalamak için sade HTML/CSS/JavaScript kaynak parçası. Asıl tasarım burada; büyük önizleme kabuğunu düzenlemek yerine bu kaynaktan çalışın.
- `LLM-DEVIR.md`: amaç, kapsam ve uygulama sınırları.

## Tasarım amacı

Türkçe koro ve konservatuvar işitsel hazırlığı için günlük, anlaşılır bir çalışma rotası. Harmonia'nın mor/lavanta kimliği korunur: vurgu #5B46F5, koyu vurgu #3825BF, açık zemin #F7F7FC. Tek büyük birincil eylem, okunaklı metin, yuvarlatılmış yüzeyler ve açıklayıcı sonuçlar.

## Örnek ekranlar

1. Bugün: 12 dakikalık tenor rotası; Nefes → Dinle → Söyle adımları.
2. Çalış: mikrofonsuz nefes yönlendirmesi için örnek sayaç ve duraklat düğmesi.
3. Sonuç: 7/8 dokunma yanıtı, tekrar önerisi, ölçülmemiş nefes desteği ve deneysel tek ses adayı ayrı sunulur.
4. Üyelik: Premium/Plus seçimi ve örnek fiyatlar.

Alt gezinti taslak ekranları dolaşmak içindir. Mevcut uygulamanın Bugün/Koro/İlerleme/Ayarlar sekmelerini değiştirme kararı olarak yorumlamayın.

## Çalışan etkileşimler ve sınırlar

Ekranlar arası geçiş, Premium/Plus seçimi ve duraklat/devam et düğmesinin görünümü çalışır. Nefes sayacı gerçek zamanlı çalışmaz. Profil, yanlış tekrarı, deneme satın alma ve pilot başvurusu bağlı değildir. Mikrofon, ses oynatma, kayıt, ödeme, hesap veya dış ağ servisi yoktur. İkonlar ve önizleme yardımcıları için dış kaynak gerekebilir; tam çevrimdışı çalışma doğrulanmadı.

Tüm seri, sonuç, süre, kullanıcı ve fiyat verileri temsili tasarım verisidir. 249 TL ve 799 TL onaylanmış satış fiyatları değildir. Nefes süreleri (4/2/6) eğitimci tarafından onaylanmış egzersiz reçetesi değildir; yalnız yerleşim örneğidir. Ürünleştirmeden önce onaylı içerik kullanılmalıdır. Üyelik ekranındaki yedi günlük deneme öneridir; gerçek mağaza koşulları, yenileme tarihi ve toplam ödeme ayrıca bağlanmalıdır.

## Uygulama sınırları

- Ölçüm ve puan deterministiktir; AI yalnız açıklama ve izinli öneri sunabilir.
- Geçersiz/ölçülmemiş sonuçlara puan verilmez; yanlış oktav başarı sayılmaz.
- Deneysel frekans farkı, öğrencinin doğrulanmış başarısı veya nefes desteği ölçümü değildir.
- Plus yorumu gerçek eğitimci tarafından yazılır. AI metni eğitimci yorumu gibi sunulmaz.
- Hazır 2/3/4 sesli piyano kayıtları klasörden çalınır; öğrenci notaları tek tek tekrar eder. Kullanıcı kayıtları gelmeden placeholder açılmaz.
- Repo uygulaması yapılacaksa AGENTS.md, MODEL_HANDOFF.md ve güncel yol haritası okunmalı; görsel taslak güncel kodun veya kabul kapılarının yerine geçmez.

## Başka LLM'ye verilecek istek

Ekli harmonia-source.txt dosyasını tasarım referansı, LLM-DEVIR.md dosyasını bağlam olarak kullan. Dört ekranı ve etkileşimleri incele. Harmonia'nın mor/lavanta kimliğini, Türkçe metinlerini, tek ana eylemini ve ölçülen/ölçülmeyen sonuç ayrımını koru. Temsili fiyat ve skorları gerçek veri gibi sunma. Önce tasarımın güçlü ve eksik yanlarını değerlendir; değişiklik istendiğinde bunları belirtilen hedef platforma uygula. HTML sarmalayıcısını ürün kodu sanma; Flutter uygulaması için mevcut bileşen ve tasarım sistemini kullan.
