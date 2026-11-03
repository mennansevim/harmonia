# QA_FINAL_REPORT — Vocalart iOS

**Tarih:** 2026-11-03. **Dal:** `feat/figma-uyumu`, commit yok. **Karar:** üretime hazır değil. Simülatör kapısı geçti; gerçek cihaz, ses ve insan kapıları açık.

## Sonuç özeti

| Kapı | Sonuç |
|---|---|
| `dart format` | Temiz |
| `flutter analyze` | Temiz |
| `flutter test` | 1185 geçti, 0 başarısız, 2 opt-in atlandı (başlangıç 1167) |
| `integration_test` iPhone 17, iOS 27 | 7/7 |
| Maestro, son durum | 27/27 kombinasyon geçti |
| Maestro, tüm koşular | 81 koşu: 60 geçti, 21 başarısız. Başarısızlıkların kök nedenleri aşağıda; hiçbiri açık değil |

27 kombinasyondan 4'ü son düzeltmeden (QA-DEF-010/011, `TrainerScope`) önceki derlemeyle koştu: `02` ve `06` iPhone 17e AX5, `05` ve `08` iPhone 18 Pro Max. Kalan 23 son derlemede. Kod değişikliği son derlemeden sonra yapılmadı.

Kodsal kalite kapısı bir kez çıkış kodu 1 verdi (1181 geçti, 0 başarısız, cihaz matrisi aynı anda koşarken). O koşuda hangi adımın düştüğü kaydedilmedi; yük altında iki sonraki koşu temiz bitti. Neden geriye dönük belirlenemedi. REL-08b ile kapı artık adım exit/süre/ilk hata ve bounded diagnostic kaydediyor; sonraki gerçek koşu 1182/0/2 ve bütün adımlar exit 0 tamamlandı.

## Hatalar

| Önem | Toplam | Doğrulandı | Ertelendi |
|---|---|---|---|
| P0 | 0 | 0 | 0 |
| P1 | 3 | 3 | 0 |
| P2 | 4 | 4 | 0 |
| P3 | 4 | 4 | 0 |

Ayrıntı: [QA_DEFECTS.md](QA_DEFECTS.md). En önemlileri:

- **QA-DEF-010 (P1):** Çalışma sonucu "İlerleme sekmesine eklendi" diyor, İlerleme yeniden başlatılana kadar 0 XP gösteriyordu. Veri diske doğru yazılıyordu, ekran bayattı.
- **QA-DEF-003 (P1):** iPhone yatay tutulduğunda kurulumun son ekranı tamamlanamıyordu.
- **QA-DEF-001 (P1):** Ana CTA VoiceOver için ayrı bir öğe değildi ve etkinleştirme eylemi yoktu.
- **QA-DEF-009 (P2):** İngilizce cihazda arayüz karışıktı. Kullanıcı kararıyla uygulama tam iki dilli: Türkçe cihazda Türkçe, diğer her dilde İngilizce (ayrıntı aşağıda).

## Başarısız koşuların nedenleri

| Neden | Sınıf |
|---|---|
| Ana CTA birleşik semantics | Uygulama, düzeltildi |
| Ready ekranı yatay taşma | Uygulama, düzeltildi |
| AX5 ölçek ve kaydırma | Uygulama + flow, düzeltildi |
| İlerleme bayat | Uygulama, düzeltildi |
| Kırpılan satırlar için kaydırma, metin seçiciler, klavye gecikmesi, "Bitti" dönüşü | Flow, düzeltildi |
| Entegrasyon testinin `Runner.app`'i değiştirmesi | Ortam, yeniden derlendi |
| Koro testi için kapalı mikrofon izni | Ortam, izin verildi |

## Cihaz kapsamı

| Simülatör | Yapılandırma | Senaryo |
|---|---|---|
| iPhone 17, iOS 27.0 | Dikey, TR | 10/10 |
| iPhone 17, iOS 27.0 | Yatay, TR | 3/3 |
| iPhone 17e, iOS 27.0 | AX5 yazı, TR | 5/5 |
| iPhone 18 Pro Max, iOS 27.0 | TR | 4/4 |
| iPhone 17e, iOS 26.5 | TR | 2/2 |
| iPad mini, iOS 27.0 | TR | 2/2 |
| iPhone Air, iOS 27.0 | EN | 2/2 (01 ve 11_english_tour) |

## Erişilebilirlik

Otomatik: 44 pt/48 dp dokunma hedefi, etiket, kontrast ve taşma denetimi 320 px, yatay ve 2× yazıda geçti. Semantics ağacı Maestro ile cihazda okundu. **VoiceOver ile elle tur yapılmadı**; QA-DEF-001 semantics düzeyinde doğrulandı, ekran okuyucuyla değil. Reduced Motion denenmedi.

## Test edilmedi

- Gerçek iPhone, gerçek mikrofon kalitesi, insan sesi, eğitimci ve pilot kapıları.
- iOS 15–26.4: çalışma zamanı kurulu değil.
- Gerçek bildirim teslimi, `.resonia` dosyasını açma/paylaşma sayfası, Veri taşıma ekranı, Dinle ve söyle ile Ezgi oturumları (uçtan uca).
- Bugün ve Ses sekmelerinin bayatlık düzeltmesi cihazda ayrı denenmedi; aynı kök neden İlerleme üzerinden doğrulandı.
- Performans: açılış, bellek ve Instruments ölçümü yapılmadı, sayı yok.
- Golden test: onaylı referans yok. Patrol eklenmedi. CI açılmadı (`docs/ci` taslağı, ayrı yetki gerekiyor).
- Maestro MCP bu oturumda yüklenemedi, CLI kullanıldı. `.mcp.json` hazır; Maestro Studio denenmedi.

## Değişen kod

`lib/trainer/app/scope.dart`, `app/trainer_app.dart`, `ui/kit.dart`, `onboarding/onboarding_flow.dart`, `koro/range_test.dart`, `koro/voice_count.dart`, `quiz/quiz_view.dart`, `settings/settings_tab.dart`, `state/trainer_store.dart`.

Testler: yeni `test/trainer/kit_semantics_test.dart`, `practice_screens_layout_test.dart`; güncellenen `accessibility_audit_test.dart`, `trainer_store_test.dart`.

Davranış değişiklikleri: Türkçe dışı cihazlarda arayüz İngilizce; yazı ölçeği 2× ile sınırlı; yeni kurulumda günlük süre varsayılanı 8 yerine 10 dakika (kayıtlı kullanıcı etkilenmez, rota kademesi aynı).

## İngilizce (QA-DEF-009)

Dil cihazdan gelir: ilk tercih edilen dil Türkçe ise Türkçe, değilse İngilizce (koro modülüyle aynı kural). Uygulama içi dil seçici yok.

- Kapsam: kurulum, dört sekme, beceri/ders/quiz/sonuç/serbest çalışma/nefes, aralık testi, kaç ses, üyelik, müzik sözlüğü (aralık, akor, dizi, yürüyüş adları), müfredat metinleri, Ses Atölyesi'nden açılan eski ekranlar (dinle ve söyle, ezgi, ritim, aksak, piyano yer tutucusu, mikroders taslakları), hatırlatma bildirimi, hata ekranı, iOS mikrofon izni metni (`en.lproj`/`tr.lproj` `InfoPlist.strings`).
- Kanıt: `test/trainer/english_ui_test.dart` İngilizce cihazda gezer ve Türkçe harf/kelime ya da taşma bulursa düşer; Türkçe cihaz testi ve sayı/büyük harf birim testi. Maestro `11_english_tour` iPhone Air (EN) üzerinde geçti, görüntüler `qa/artifacts/evidence/en/`. Türkçe `01`, `05`, `10` aynı derlemeyle yeniden geçti.
- İngilizcede bulunan ve düzeltilen hata: Ayarlar'da uzun değer (ör. "Solfège (Do Re Mi)") satırı 12 px taşırıyordu; değer artık başlıkla satırı paylaşıp sarıyor (iki dilde de).
- Sınırlar: Çeviriler benim; anadili İngilizce bir eğitimci ya da editör okumadı. Ritim/aksak terimleri ("karşılama", "aksak semai") özgün adıyla kaldı. Nota gösterimi varsayılanı İngilizcede de solfej; kullanıcı kurulumda harf seçebilir. Eski, uygulamadan açılmayan `features/` ekranları (eski ana sayfa, beceri haritası) Türkçe kaldı. App Store açıklaması ve mağaza metinleri kapsam dışı.

## Kalan yayın riskleri

- Kullanım koşulları uygulamayı beta, içeriği taslak olarak tanımlıyor; açık mağaza yayını öncesi ele alınmalı.
- Apple Distribution sertifikası ve Android yayın imzası yok (LAUNCH-AUDIT).
- Tek ses, ezgi ve trainer söyleme puanlaması kapalı; canlı perde yok.
- Testlerde mikrofon ve ses simülatör üzerinden çalıştı; akustik doğruluk kanıtı değildir.
