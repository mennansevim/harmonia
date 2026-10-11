# Harmonia — Tasarım önizlemesi kontrolü

**Tarih:** 2026-10-10. Üretim Flutter uygulaması için değil, beş etkileşimli tasarım önizlemesi için kontrol kaydıdır.

## Yapılan kontroller

- Beş varyant × 10 ekran × 320/360/736 px: 150 ekran/genişlik durumu.
- Sayfa script sözdizimi ve tarayıcı çalışma hataları: hata görülmedi.
- Telefon yüzeyi ve sayfa genişliği: yatay taşma görülmedi.
- Beş ses ekranının 360/736 px ekran görüntüleri incelendi.
- Aurora: misafir → kalibrasyon demosu → home → 4 ses seçimi → referans → hareketli yanıt → sonuç. 4/4 gösterimi doğrulandı.
- Demo ödeme butonu: gerçek satın alma yok; açık uyarı gösteriliyor.
- Reduced motion altında yanıtı başlat/durdur; koyu host görünümünde çalışma kontrolü.
- Paylaşılan stage yüksekliği küçük ekranda en uzun içeriğe göre ayrıldı; varyant değişimi içeriği kesmez.

## Sınırlar

- Mikrofon, gerçek pitch doğruluğu, DSP gecikmesi, cihaz performansı ve mağaza aboneliği test edilmedi; bu önizlemede bağlı değil.
- Hata senaryoları tasarım kontrollerinde bulunur; tüm hata senaryoları için ayrı otomatik uçtan uca test bu oturumda yapılmadı.
- Ritim tap sayısı yerel etkileşimdir; gerçek referans clock/timing scorer olmadığı için ritim başarı yüzdesi uydurulmaz.
- Rapor/lig profilleri ve fiyatları açıkça örnektir. Gerçek kullanıcı verisi yoktur.
- Ekran okuyucu ve cihaz üzerinde büyük yazı/VoiceOver/TalkBack QA'sı sonraki aşamadadır.
- Host carousel ve tasarım kontrollerini sağlar. Standalone kontrol sırasında yalnız test amacıyla varyant görünürlüğü değiştirildi; teslim edilen önizlemeye ikinci carousel sistemi eklenmedi.

Devam: [DESIGN_STUDIES.md](./DESIGN_STUDIES.md), [AUDIO_ENGINE_PLAN.md](./AUDIO_ENGINE_PLAN.md).
