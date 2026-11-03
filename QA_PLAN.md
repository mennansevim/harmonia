# QA_PLAN — Vocalart iOS

**Tarih:** 2026-11-03. Kapsam: `feat/figma-uyumu` çalışma ağacı (commit'lenmemiş kullanıcı işleri dahil).

## Bulunan yapı

- Flutter 3.44.4 / Dart 3.12.2. Açılış `lib/main.dart` → `TrainerApp` (`lib/trainer/`). Eski `lib/features/` kabuğu testlerle korunuyor ama açılışta kullanılmıyor; bir kısmı `Ses` sekmesinden açılıyor.
- Durum: `TrainerStore`, `ChoirStore` (`ChangeNotifier`, JSON dosya) ve `TrainerScope`. Navigasyon: `Navigator` + `MaterialPageRoute`, deep link yok.
- Hesap, backend, API istemcisi, canlı ödeme yok. Veriler cihazda. `.resonia` paketleri dosya ile paylaşılıyor.
- Yerel entegrasyonlar: mikrofon (`record`), ses (`just_audio`), bildirim, dosya seçici, paylaşım sayfası.
- Görünüm: yalnız açık tema (`ThemeMode.light`). Dil: Türkçe; koro modülü TR/EN. Yön: iPhone'da dikey + yatay.

## Özellik envanteri

| Alan | Yüzeyler |
|---|---|
| İlk açılış | Karşılama, 6 adım onboarding, plan özeti, kaldığı adımdan devam |
| Bugün | Günlük rota, nefes rehberi, ders akışı, beceri kartları |
| Kulak eğitimi | Nota, aralık, akor, dizi, yürüyüş: müfredat, serbest çalışma, quiz, sonuç |
| Ses | Aralık testi, dinle ve söyle, ezgi, ritim, aksak ritim, kaç ses |
| Koro | Oluşturma, davet paketi, ödev, kayıt, şef dinleme |
| İlerleme | Seviye, 7 günlük grafik, beceri ayrıntısı |
| Ayarlar | Tercihler, hatırlatma, veri taşıma, üyelik (satış yok), silme |

## Test mimarisi

| Katman | Araç | Yer |
|---|---|---|
| Birim / widget | `flutter_test` | `test/` |
| Düzen ve erişilebilirlik | Flutter kılavuzları, taşma | `test/trainer/accessibility_audit_test.dart`, `practice_screens_layout_test.dart`, `kit_semantics_test.dart` |
| Üretim kablolu yolculuk | `integration_test` | `integration_test/` |
| Kara kutu yolculuk | Maestro 2.12.1 | `.maestro/` |
| Görsel tur | Ekran turu testleri | `test/trainer/screenshot_tour_test.dart`, `test/choir/` |

Patrol eklenmedi: Maestro izin ve sistem Ayarları'nı karşıladı, ikinci bir E2E çerçevesi gerekçesizdi. Golden test eklenmedi: onaylı referans görüntü seti yok, kendi kendine baseline onaylamak kural dışı.

## Çalıştırma

```bash
scripts/qa/run_flows.sh <simulator-udid>
```

```bash
python3 -I scripts/qa/code_gate.py
```

```bash
python3 -I -m http.server 8765 --directory qa
```

Dashboard: `http://localhost:8765/dashboard/index.html`. 5 saniyede bir yenilenir; yalnız `qa/reports/` ve `qa/defects.json` okur.

Adım adım hata ayıklama için `maestro studio`. Ajan erişimi için `.mcp.json` içinde `maestro mcp` tanımlı; bu oturumda CLI kullanıldı, çünkü MCP sunucusu yalnız yeni oturumda yüklenir.

## Cihaz matrisi

| Profil | Simülatör | Amaç |
|---|---|---|
| Küçük + en büyük yazı | iPhone 17e, iOS 27.0 | Dar ekran, AX5 |
| Standart | iPhone 17, iOS 27.0 | Tüm yolculuklar |
| Yatay | iPhone 17, iOS 27.0 | Yatay kurulum |
| Büyük | iPhone 18 Pro Max, iOS 27.0 | Geniş ekran |
| Eski çalışma zamanı | iPhone 17e, iOS 26.5 | Kurulu en eski iOS |
| Tablet | iPad mini, iOS 27.0 | Universal hedef |
| İngilizce | iPhone Air, iOS 27.0 | Dil karışımı |

## Sınırlar

- iOS 15 (dağıtım hedefi) ile 26.4 arası: çalışma zamanı kurulu değil, test edilmedi.
- Gerçek telefon, gerçek mikrofon kalitesi, insan sesi, VoiceOver'ın elle turu, gerçek bildirim teslimi: yapılmadı. Simülatör bunların yerine geçmez.
- Ağ kaybı ve API hatası senaryoları yok: uygulamanın ağ bağımlılığı yok.
