# QA_VISUAL_AUDIT — Vocalart iOS

**Tarih:** 2026-11-03. Kaynak: simülatör ekran görüntüleri ve iki projeli ekran turu (toplam 49 tur görüntüsü, 28 trainer, 21 koro). Onaylı referans görüntü seti olmadığı için golden baseline oluşturulmadı. Tasarım önerileri aşağıda ayrı.

## Düzeltilen görsel hatalar

| Ekran | Cihaz | Tema | Dil | Hata | Önce | Sonra | Çözüm |
|---|---|---|---|---|---|---|---|
| Planın kuruldu | iPhone 17, yatay | Açık | TR | 65 px taşma, alt eylemler erişilemez | [önce](qa/artifacts/evidence/QA-DEF-003_ready_landscape_before.png) | [sonra](qa/artifacts/evidence/QA-DEF-003_ready_landscape_after.png) | `FitOrScroll` |
| Karşılama, tüm metinler | iPhone 17e, AX5 | Açık | TR | "kul/ağını" hece ortasından bölündü, S/A/T/B çubuklara bindi | [önce](qa/artifacts/evidence/QA-DEF-006_ax5_before.png) | 01 akışı AX5 geçti | Ölçek 2× sınırı, süs harfi ölçeklenmez |
| Quiz > Karşılaştır | iPhone 17e, AX5 | Açık | TR | "DOĞRUS / U" bölündü | [önce](qa/artifacts/evidence/QA-DEF-011_compare_before.png) | [sonra](qa/artifacts/evidence/QA-DEF-011_compare_after.png) | Tek satır, `FittedBox` |
| Ayarlar satırları | iPhone 17 | Açık | TR | Alt başlık ile değer neredeyse bitişik | 05 akışı görüntüsü | `settings_notation_sheet` | 8 pt boşluk |
| Aralık testi | 390×844, 2× | Açık | TR | Taşma | Widget testi | Widget testi | `FitOrScroll` |
| Kaç ses | 844×390 | Açık | TR | Taşma | Widget testi | Widget testi | `FitOrScroll` |
| İlerleme | iPhone 17 | Açık | TR | 0 XP, bayat ekran | [önce](qa/artifacts/evidence/QA-DEF-010_progress_before.png) | [sonra](qa/artifacts/evidence/QA-DEF-010_progress_after.png) | `TrainerScope` store'u bildiriyor |

## Hata sayılmayanlar

- Ekran turunda `♯/♭` kutu görünüyordu: test ortamı fontu. Simülatörde doğru.
- Hatırlatma ekranındaki buton çakışması: Maestro kapsayıcı kutusu. Görsel olarak ayrı.
- Koyu sistem modu: uygulama bilerek açık tema; durum çubuğu okunaklı kaldı.
- 2× ile kısıtlanan yazı: bilinçli karar. iOS'un en büyük boyutu (yaklaşık 3×) tam uygulanmıyor.

## Öneriler (hata değil, uygulanmadı)

- Serbest çalışma: büyük yazıda dizi çipleri yatay kayıyor, "Doğal minör" kesik görünüyor. Kaydırma ipucu ya da sarmalama düşünülebilir.
- Serbest çalışmada `Pes/Orta/Tiz` satırı diğer satırlardan 4 pt içeride.
- `♯/♭` Inter'de değil, sistem fontundan geliyor; ince duruyor. Müzik sembol fontu düşünülebilir.
