# REL-08 — Yerel kalite kontrolü ve etkinleştirilmemiş CI taslağı

Repo kökünden `dart tool/quality_check.dart` çalıştırılır. `dart run` kullanılmaz:
bu standalone script package çözümlemesi/build hooks başlatmadan açılır. Script konumu
Harmonia kökünü belirler; çağıranın cwd'si (Agora dahil) kullanılmaz. Sıra:
read-only format (lib/test/tool) → no-pub analyze → no-pub full test.
İlk hata exit code'u korunur, sonrakiler çalışmaz; eksik SDK otomatik kurulmaz.
Bu komut build, cihaz testi, API, upload, push veya deployment yapmaz.

`--plan` yalnız komutları gösterir. Varsayılan bağımlılık fetch yapmaz; hazır
SDK ve `.dart_tool/package_config.json` gerekir. Temiz checkout için açık
`--fetch` seçeneği önce `flutter pub get --enforce-lockfile` çalıştırır; network
ve paket cache erişimi olabilir, lock mismatch başarısız olmalıdır. Paket
sürümlerini değiştirmek veya SDK yükseltmek bu runner'ın işi değildir.

## CI taslağı (sağlayıcıdan bağımsız, etkin değil)

1. İzole, güvenilen checkout; private voice fixture, credentials veya kullanıcı
   seslerini dahil etme. Pinned Flutter/Dart runtime ve committed pubspec.lock
   doğrulansın (mevcut yerel referans Flutter 3.44.4/Dart 3.12.2).
2. `dart tool/quality_check.dart --fetch` tek check adımı olarak kullanılsın.
3. Nonzero exit job'u başarısız kılsın. Ham ses/artifact upload yok; otomatik
   build, signing, mağaza, ödeme/API veya deploy adımı eklenmesin.
4. Çalışanları ve süre/bellek limitlerini sağlayıcı tarafında sınırla. Runner
   bir subprocess için hard timeout uygulamaz; yerelde Ctrl-C, CI'da job timeout
   gerekir. Cihaz acceptance ve insan benchmark ayrı yetkili manuel rapordur.

Bu dosya workflow değildir. `.github/workflows` altında aktif job oluşturulmadı;
CI sağlayıcısı/izinleri/runner/SDK ve gerçek hosted run kullanıcı koordinasyonuyla
belirlenir. Yeşil kod kontrolü fiziksel mikrofon, pedagojik kabul veya yayın
hazırlığı demek değildir. macOS native isolate testleri doğrulanabilir; diğer CI
işletim sistemi matrisi henüz doğrulanmadı. iOS Xcode/lipo engeli ayrı duruyor.
