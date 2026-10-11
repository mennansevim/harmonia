# Harmonia

Konservatuvar hazırlığı için kişisel kulak, ritim, ezgi ve ses koçu.

Flutter iskeleti, mock tek ses egzersizi ve yerel kayıt→deneysel DSP laboratuvarı hazırdır. Sonuç v2/ölçüm geçerliliği, metrik bazlı gelişim ve ritim event eşleştirme uygulandı; gerçek öğrenci başarı ölçümü doğrulanmadı. Proje yarım kalırsa önce [`CURRENT_ROADMAP.md`](./CURRENT_ROADMAP.md), ardından ayrıntılı [`IMPLEMENTATION_ROADMAP.md`](./IMPLEMENTATION_ROADMAP.md) okunur.

**Yerel prototip:** Tek ses ekranının sağ üst mikrofon düğmesi “Ses laboratuvarı”nı açar. Sentetik C4 dinle → açık izinle kısa kayıt → dinle/sil veya açık eylemle deneysel analiz et. Native worker frekans/periodic pencere kanıtı gösterir; ses kimliği veya doğru nota/başarı puanı değildir. Kayıt yüklenmez. iOS/Android adapter'ları var; fiziksel mikrofon/route/VAD QA bekliyor. Puanlama ekranı hâlâ mock. Önceki iOS simulator build fiziksel cihaz testi değildir.

## Doküman haritası

- [`MODEL_HANDOFF.md`](./MODEL_HANDOFF.md) — başka model için genel işleyiş, kod haritası, doğrulama sınırları ve doğrudan devam adımı.
- [`AGENTS.md`](./AGENTS.md) — repo içinde çalışan model/ajan için kalıcı çalışma kuralları.
- [`PIANO_REFERENCES.md`](./PIANO_REFERENCES.md) — hazır 2/3/4 sesli piyano klasörleri, placeholder ve kayıtların sonraki incelemesi.
- [`CURRENT_ROADMAP.md`](./CURRENT_ROADMAP.md) — mevcut durum, fazlar ve bir sonraki iş.
- [`IMPLEMENTATION_ROADMAP.md`](./IMPLEMENTATION_ROADMAP.md) — iş ID'leri, bağımlılıklar, kabul kapıları, yakın sprintler ve yayın sırası.
- [`IMPLEMENTATION_LOG.md`](./IMPLEMENTATION_LOG.md) — uygulanmış paket, doğrulama ve kalan teknik sınırlar.
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — Flutter, ses analiz motoru, backend ve AI sınırları.
- [`PRODUCT_SPEC.md`](./PRODUCT_SPEC.md) — ürün kapsamı, kullanıcı akışları ve MVP.
- [`AI_COACH.md`](./AI_COACH.md) — Harmonia Coach, model kullanımı ve değerlendirme planı.
- [`DECISIONS.md`](./DECISIONS.md) — geri dönülmesi pahalı teknik ve ürün kararları.
- [`COMPETITOR_RESEARCH.md`](./COMPETITOR_RESEARCH.md) — 10 ilgili rakip, resmî kaynaklar ve ürün çıkarımları.
- [`FEATURE_BACKLOG.md`](./FEATURE_BACKLOG.md) — eksik özellikler, fazlar ve kabul kriterleri.
- [`DESIGN_STUDIES.md`](./DESIGN_STUDIES.md) — beş uçtan uca tasarım, UX diyagramı ve seçim kriterleri.
- [`AUDIO_ENGINE_PLAN.md`](./AUDIO_ENGINE_PLAN.md) — gerçek ses motoru, 3/4 sesli genişleme ve ölçüm/görsel sınırları.
- [`AUDIO_TESTING.md`](./AUDIO_TESTING.md) — uygulanmış protokol/evidence/WAV/fixture altyapısı, sınırları ve kayıt laboratuvarının devam adımları.
- [`DESIGN_QA.md`](./DESIGN_QA.md) — tasarım önizlemesinin kontrolleri ve test edilmeyen sınırlar.
- [`PRODUCT_AUDIT.md`](./PRODUCT_AUDIT.md) — kodda olan/plandaki özellikler; konservatuvar ve koro yeterliliği; ölçüm açıkları.
- [`LEARNING_MODEL.md`](./LEARNING_MODEL.md) — öğretim döngüsü, ortak temel, iki hazırlık rotası ve öğrenme kanıtları.
- [`HUMAN_REVIEW.md`](./HUMAN_REVIEW.md) — Plus'ta gerçek eğitimci yorumu, kota, teslim, gizlilik ve operasyon.

## Devam etme kuralı

Yeni model önce `MODEL_HANDOFF.md` ve `AGENTS.md` okusun. Ana ekran mock,
mikrofon düğmesi yerel laboratuvar, müzik-kitaplığı düğmesi 2/3/4 sesli
placeholder bölümüdür. Gerçek piyano dosyaları gelene kadar bu bölüm dinleme,
kayıt ve skor başlatmaz. En son suite 248 test; bunlar gerçek cihaz/öğrenme
doğrulaması değildir.

Her çalışma oturumunda:

1. `CURRENT_ROADMAP.md` içindeki “Bir sonraki oturum” bölümünü oku.
2. Yapılan işi ve engeli aynı dosyada güncelle.
3. Büyük bir yön değişikliğini `DECISIONS.md` içine ekle.
4. Fazın çıkış kriterleri tamamlanmadan yeni faza geçme.
