# Vocalart — Yayın hazırlığı (canlıya çıkış açıkları)

**Güncelleme:** 2026-11-06 · Kaynaklar: CURRENT_ROADMAP, IMPLEMENTATION_ROADMAP §5–§11.
Durum sözlüğü roadmap ile aynı; kod-test geçmesi cihaz/pilot/yayın kabulü değildir.

Tür: **K** = kodla kapatılabilir, **Ka** = kullanıcı kararı, **D** = dış kaynak
(cihaz, insan, hesap, hukuk, ödeme).

## 1. Hangi yayın?

1. **İç test / kapalı beta (TestFlight internal, Play internal testing):** en
   yakın hedef. Yalnız dokunmaya dayalı ölçülen çalışmalar (tiz/pes, derece,
   ritim, günlük plan) + puansız deneysel ses modülleri. `RESONIA_CHANNEL=beta`.
2. **Kapalı beta Core:** gerçek tek ses ve kısa ezgi sonucu, ölçülmüş gecikmeyle
   ritim, eğitimci onaylı ilk mikroüniteler.
3. **İlk ücretli yayın:** hesap/sync, Premium abonelik, isteğe bağlı AI koç,
   hata izleme, hukuk ve mağaza metinleri.

## 2. İç beta için kalan açıklar

| Açık | Tür | Durum / gereken |
|---|---|---|
| Android derleme ortamı | D | `RESONIA_CHANNEL=beta` 1.0.0+12 yerel APK ve Play teslim formatı AAB üretildi. REL-21/22 doğrulayıcıları artifact sözleşmesini denetliyor; REL-23 AAB'den geçici universal APK üretip identity/version/SDK/izin/imza/launch parity'sini doğruluyor. Kurulum yok; gerçek Android cihaz/emülatör kabulü açık |
| Release imzalama | Ka/D | Android release görevi geçerli dört alanlı `key.properties` + var olan keystore olmadan fail-closed. REL-21/22 yalnız explicit yerel override ve `--allow-debug-signing` ile `Android Debug` sertifikalıdır; mağazaya yüklenemez. Production doğrulaması beklenen sertifika SHA-256 ister; gerçek keystore kullanıcıda. iOS App Store IPA, Apple Distribution sertifikası ve `com.mennansevim.vocalart` App Store profiliyle üretildi; profil 2027-09-25'e kadar geçerli |
| TestFlight yüklemesi (REL-10–20) | D | Güncel imzalı `Vocalart.ipa` 1.0.0 build 12. Yerel doğrulayıcı bundle/ad/sürüm, executable, CodeResources, şifreleme, Apple Team/Profile + entitlement, tüm privacy manifestleri, device arm64/IOS/minimum OS ve paketlenmiş izin/ürün beyanı kapılarını geçti; codesign deep/strict temiz. Upload yapılmadı; kullanıcı yetkisi gerekir. Gerçek ses ve güncel ikon/açılış yüzeyi fiziksel cihazda değerlendirilmedi; dış test için gizlilik politikası URL'si + Beta App Review gerekir |
| Uygulama kimliği | K/D | `com.mennansevim.vocalart` iOS ve Android'de uygulandı; platform tutarlılığı otomatik testli. İlk mağaza kaydı/Team ID ve imzalı arşiv dış kapı |
| Uygulama ikonu / açılış ekranı | K/D | Fotogerçekçi marka ikonu iOS varsayılan/koyu/renklendirilmiş ve Android uyarlanabilir/tek renk kaynaklarda paketli. iOS native storyboard krem/patlıcan/lime Vocalart açılışını; Android legacy ve 12+ markalı splash'i kullanıyor. Güncel IPA, yerel APK ve AAB +12 bu kaynakları içeriyor; fiziksel açık/koyu görünüm, profesyonel tasarım kabulü ve mağaza ekran görüntüleri açık |
| Sürüm numarası | K | Pubspec, güncel imzalı IPA ve yerel Android beta APK/AAB `1.0.0+12`; iOS ve Android doğrulayıcıları artifact sürümünü pubspec ile exact-match denetler |
| Android izin sözleşmesi | K/D | REL-21/22 beta APK ve AAB yalnız `RECORD_AUDIO`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `POST_NOTIFICATIONS` ve signature receiver izni taşıyor; exact allow-list otomatik artifact kapısıdır. Plugin kaynaklı READ_EXTERNAL/READ_MEDIA_* ve ACCESS_NETWORK_STATE merge'de fail-closed kaldırıldı. Fiziksel dosya seç/aç, bildirim, reboot ve mikrofon akışı açık |
| Gerçek cihazda gezinti | D | Simulator build başarılı, elle gezinti/gerçek iPhone/Android testi yok |
| Mikrofon izni kalıcı ret → Ayarlar | D | SHELL-02 kod/build tamam (`permission_handler` 12.0.3); fiziksel iOS/Android ret, ayar açma ve uygulamaya dönüş QA bekliyor |
| Gizlilik politikası URL'si | D | Mağaza zorunlu; metin + barındırma + hukuk incelemesi (LAUNCH-01) |
| App Store gizlilik etiketi / Play Data safety | D | Uygulama veri toplamıyor (manifest bunu söylüyor); formlar hesapta doldurulur |
| Yaş/çocuk güvenliği beyanı | D | Hedef kitle öğrenci; hukuk incelemesi |

**Kodda tamam (REL-09/OPS-01a):** beta kanalında geliştirici araçları gizli,
uygulama adı "Vocalart", iOS PrivacyInfo.xcprivacy (izleme yok, veri toplama
yok, dosya zaman damgası C617.1), release imzalama yapılandırması, yerel hata
günlüğü + kopyalanabilir rapor, release'te kırmızı hata ekranı yerine sakin mesaj.

**Arayüz (2026-10-25):** Bugün/Pratik/Gelişim/Profil; tiz/pes, derece, ritim,
ayarlar, geçmiş, günlük plan, tek ses/ezgi oturumları, ses laboratuvarı ve veri
taşıma A+C düzenine geçirildi ve widget testleri mevcut. Bu kod kapsamıdır;
gerçek cihaz, ekran okuyucu ve kullanıcı testi yapılmadı. Ayrıntılı liste:
CURRENT_ROADMAP › "Kalan işler — 2026-10-15".

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
| Günlük hatırlatma teslimatı | D | Fiziksel iOS/Android izin, seçilen saat, reboot/DST ve OEM pil davranışı; kod/build REM-01c hazır |
| Başlangıç yerleştirmesi | D | SHELL-03a üç dokunma turu kod-test hazır; eğitimci seviye bantları ve öğrenci kabulü olmadan yalnız pratik başlangıcı önerir |

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
python3 -I scripts/release/test_verify_ios_ipa.py
python3 -I scripts/release/verify_ios_ipa.py build/ios/ipa/Vocalart.ipa
python3 -I scripts/release/test_verify_android_apk.py
# Yalnız yerel debug-imzalı beta kanıtı:
python3 -I scripts/release/verify_android_apk.py build/app/outputs/flutter-apk/app-release.apk --pubspec pubspec.yaml --allow-debug-signing
python3 -I scripts/release/test_verify_android_aab.py
python3 -I scripts/release/verify_android_aab.py build/app/outputs/bundle/release/app-release.aab --pubspec pubspec.yaml --allow-debug-signing
python3 -I scripts/release/test_verify_android_delivery.py
python3 -I scripts/release/verify_android_delivery.py build/app/outputs/bundle/release/app-release.aab --pubspec pubspec.yaml --allow-debug-signing
flutter build ios --simulator --debug --dart-define=RESONIA_CHANNEL=beta
flutter build apk --release --dart-define=RESONIA_CHANNEL=beta   # geçerli key.properties yoksa bilerek durur
# Yalnız yerel release derleme kanıtı; oluşan debug-imzalı çıktı mağazaya yüklenmez:
cd android && ./gradlew app:assembleRelease -PallowDebugReleaseSigning=true
```

Mağazaya yükleme, TestFlight dağıtımı, push ve deployment ayrı kullanıcı
yetkisi gerektirir (AGENTS.md).
