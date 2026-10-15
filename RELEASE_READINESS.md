# Harmonia — Yayın hazırlığı (canlıya çıkış açıkları)

**Güncelleme:** 2026-10-14 · Kaynaklar: CURRENT_ROADMAP, IMPLEMENTATION_ROADMAP §5–§11.
Durum sözlüğü roadmap ile aynı; kod-test geçmesi cihaz/pilot/yayın kabulü değildir.

Tür: **K** = kodla kapatılabilir, **Ka** = kullanıcı kararı, **D** = dış kaynak
(cihaz, insan, hesap, hukuk, ödeme).

## 1. Hangi yayın?

1. **İç test / kapalı beta (TestFlight internal, Play internal testing):** en
   yakın hedef. Yalnız dokunmaya dayalı ölçülen çalışmalar (tiz/pes, derece,
   ritim, günlük plan) + puansız deneysel ses modülleri. `HARMONIA_CHANNEL=beta`.
2. **Kapalı beta Core:** gerçek tek ses ve kısa ezgi sonucu, ölçülmüş gecikmeyle
   ritim, eğitimci onaylı ilk mikroüniteler.
3. **İlk ücretli yayın:** hesap/sync, Premium abonelik, isteğe bağlı AI koç,
   hata izleme, hukuk ve mağaza metinleri.

## 2. İç beta için kalan açıklar

| Açık | Tür | Durum / gereken |
|---|---|---|
| Android derleme ortamı | D | Debug APK derlendi (2026-10-14; Gradle CMake 3.22.1'i kendisi kurdu). cmdline-tools eksik, `flutter doctor --android-licenses` onaylanmadı; gerçek Android cihaz/emülatörde çalıştırılmadı |
| Release imzalama | Ka/D | Kod hazır (`android/key.properties`, gitignore). Keystore üretimi ve saklanması kullanıcıda; iOS için Apple Developer hesabı + signing team |
| Uygulama kimliği | Ka | `com.harmonia.harmonia` geçici. Mağazaya ilk yüklemeden sonra değişmez; kendi alan adınızla seçilmeli |
| Uygulama ikonu / açılış ekranı | K/D | Koddan üretilen marka ikonu (iOS alfasız 1024, Android uyarlanabilir + tek renk) ve tema renginde açılış ekranı eklendi. Profesyonel ikon tasarımı ve mağaza ekran görüntüleri hâlâ önerilir |
| Sürüm numarası | K | `1.0.0+1`; her yüklemede build numarası artırılmalı (CI yok) |
| Gerçek cihazda gezinti | D | Simulator build başarılı, elle gezinti/gerçek iPhone/Android testi yok |
| Mikrofon izni kalıcı ret → Ayarlar | Ka | SHELL-02: yeni plugin (ör. permission_handler/app_settings) kararı |
| Gizlilik politikası URL'si | D | Mağaza zorunlu; metin + barındırma + hukuk incelemesi (LAUNCH-01) |
| App Store gizlilik etiketi / Play Data safety | D | Uygulama veri toplamıyor (manifest bunu söylüyor); formlar hesapta doldurulur |
| Yaş/çocuk güvenliği beyanı | D | Hedef kitle öğrenci; hukuk incelemesi |

**Kodda tamam (REL-09/OPS-01a):** beta kanalında geliştirici araçları gizli,
uygulama adı "Harmonia", iOS PrivacyInfo.xcprivacy (izleme yok, veri toplama
yok, dosya zaman damgası C617.1), release imzalama yapılandırması, yerel hata
günlüğü + kopyalanabilir rapor, release'te kırmızı hata ekranı yerine sakin mesaj.

## 3. Kapalı beta Core için açıklar

| Açık | Tür | Gereken |
|---|---|---|
| Gerçek tek ses sonucu (CORE-01) | D | BENCH-01 izinli etiketli insan kayıtları + VAD-01 doğrulaması; o zamana dek puan kapalı |
| Kısa ezgi sonucu (CORE-04) | D | Segmentleme benchmark'ı; bölüm döngüsü/hafıza protokolü eğitimciyle |
| Count-in ritim (CORE-02b) | D | CAL-03b fiziksel gecikme ölçümü (cihaz) |
| Cihaz route matrisi (CAL-02) | D | En az 1 iOS + 1 düşük/orta Android; hoparlör/kablolu/Bluetooth |
| İçerik ve ölçüt onayı (EDU-01) | D | Eğitimci: beceri grafiği, taslak ölçütler, süreler, 12 mikroünite/~120 örnek |
| Kullanıcı testi (UXR-01) | D | ≥5 öğrenci + 1 eğitimci |
| 2/3/4 sesli piyano | D | Kullanıcının kayıtları + birlikte QA |
| Ekran okuyucu manuel testi | D | VoiceOver/TalkBack |

## 4. İlk ücretli yayın için açıklar

| Açık | Tür | Gereken |
|---|---|---|
| Backend / hesap / sync (DATA-01/02) | Ka/D | Teknoloji/bölge/maliyet ADR'si, hesap |
| Upload/consent (DATA-03 sunucu kısmı) | D | Backend + hukuk |
| AI koç (AI-01/03) | Ka/D | Sunucu gateway, ücretli API onayı; mobilde anahtar yok |
| Abonelik (PAY-01–03) | D | Mağaza hesapları, ürünler, sandbox; canlı ödeme ayrı onay |
| Hata izleme servisi (OPS-01) | Ka | Servis seçimi; seçilirse gizlilik manifesti ve etiketler güncellenir |
| Hukuk / mağaza metinleri (LAUNCH-01) | D | KVKK, kullanım koşulları, mağaza açıklama/ekran görüntüleri |
| Plus eğitimci hizmeti (HUM) | D | Gerçek eğitimci kapasitesi |

## 5. Yayın komutları (yetki gerekmeden yerelde)

```sh
dart tool/quality_check.dart
flutter build ios --simulator --debug --dart-define=HARMONIA_CHANNEL=beta
flutter build apk --release --dart-define=HARMONIA_CHANNEL=beta   # key.properties yoksa debug imzalı
```

Mağazaya yükleme, TestFlight dağıtımı, push ve deployment ayrı kullanıcı
yetkisi gerektirir (AGENTS.md).
