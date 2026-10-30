# Resonia çalışma kuralları

Yeni model/ajan önce `MODEL_HANDOFF.md`, `CURRENT_ROADMAP.md`,
`IMPLEMENTATION_ROADMAP.md`, `IMPLEMENTATION_LOG.md`, `AUDIO_TESTING.md` ve
ilgili mimari/ürün kararlarını okusun. Geçmiş log tarihsel; güncel kod, son
kullanıcı açıklaması ve handoff mevcut durumu belirler.

- Bu repo Resonia'dır. Komutları bu repo kökünde çalıştır; komşu
  `agoravoiceweb` kaynaklarını değiştirme. Kullanıcı değişikliklerini koru.
- Son chord yönü: **hazır 2/3/4 sesli piyano kayıtları klasörden çalınır,
  öğrenci sesleri birer birer tekrar eder**. Kullanıcı kayıtları sağlayınca
  birlikte incelenecek. O zamana kadar placeholder'lar kapalı kalsın.
  Live akor transkripsiyonu veya tekil sample mix ana yol değildir.
- Ölçüm/skor deterministik. AI tercihi `gpt-4o-mini`, açıklama/izinli öneri
  içindir; mobilde API anahtarı yok. Plus yorumunu gerçek eğitimci kendi yazar.
- Mock, synthetic, microphone ve unverified kaynaklarını karıştırma.
  Periodicity insan sesi olasılığı, periodicFrameRatio voicedRatio değildir.
  Diagnostic median/dispersion'ı doğrulanmış öğrenci başarısına dönüştürme.
- Ölçülmeyen değer null/status ile kalsın. Invalid ölçüm puan üretmesin;
  yanlış oktav başarı sayılmasın. Öğrenci rubriği/toleransını benchmark veya
  kullanıcı kararı olmadan değiştirme.
- Gerçek cihaz/mikrofon/eğitimci/insan holdout kapılarını fake/sentetik testle
  geçmiş sayma. Lisansı belirsiz sesleri kopyalama/dağıtma.
- Canlı ödeme, ücretli API, kullanıcı kaydı upload, mağaza yayını, satın alma,
  dış mesaj, git push ve deployment ayrı kullanıcı yetkisi gerektirir.
  Yerel commit'i de yalnız kullanıcı talebi varsa oluştur.
- Test/format/analyze çalıştır; `CURRENT_ROADMAP.md` ve `IMPLEMENTATION_LOG.md`
  sonuçlarını ve gerçek sınırları güncelle. Sadece plan tekrar ederek
  geliştirme olmuş gibi raporlama. Tüm kabul kapıları bitmeden ürün bitti deme.

Yerel kontrol: `dart format --output=none --set-exit-if-changed lib test`,
`flutter test --no-pub --reporter expanded`, `flutter analyze --no-pub`.
Yeni checkout'ta önce `flutter pub get` gerekebilir.

REL-08 ortak komut: `dart tool/quality_check.dart` (lib/test/tool read-only
format → analyze → full test; ilk hatada durur). `dart run` kullanma: standalone
giriş implicit package/build-hook çözümlemesini önler. `--plan` dry run;
`--fetch` açık locked dependency fetch, varsayılan indirme yok. CI taslağı
docs/ci/README.md; aktif hosted workflow/deploy yok. Kod kontrolü cihaz/pilot değil.
