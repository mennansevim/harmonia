# Harmonia — Ayrıntılı uygulama ve yayın roadmap'i

**Başlangıç/güncelleme:** 2026-10-11  
**Ürün yönü:** Aurora marka deneyimi + Konservatuvar açıklayıcı sonuçları; ortak temel, konservatuvar ve koro rotaları; Plus'ta gerçek eğitimci yorumu.  
**Durum:** Güvenilirlik/sözleşme, fixture loader, yerel kayıt laboratuvarı, deneysel frame DSP çekirdeği, kalibrasyon/kalite kapısı (CAL-01) ve misafir uygulama kabuğu (SHELL-01) kod-test seviyesinde. Modül envanteri: [CURRENT_ROADMAP.md](./CURRENT_ROADMAP.md#modül-envanteri-aq--kanıt-durumu). Canlı kayıt–DSP bağlantısı, fiziksel mikrofon QA, gerçek ses benchmark, müfredat, backend, AI, abonelik ve insan hizmeti henüz doğrulanmış/canlı değil.

## 1. Hedef ve kapsam yönetimi

İlk yayın: Türkçe, iOS/Android, konservatuvar işitsel hazırlığı. Koro ayrı alt rotadır. Core evde kısa ve açıklanabilir çalışmayı sağlar; tam çalgı/şan eğitimi, resmî sınav eşdeğerliği, kesin SATB ataması, sağlık teşhisi ve kabul garantisi vaat etmez.

Mükemmellik tamamlanmış bir özellik listesi değil: güvenilir ölçüm, anlaşılır sonuç, gerçek öğrenme, akıcı/erişilebilir deneyim, güvenli veri ve sürdürülebilir hizmet kapılarından geçmek. Yeni özellik, bu kapıları bozuyorsa sonraya bırakılır.

Durum sözlüğü: **bekliyor / geliştiriliyor / kod tamamlandı / doğrulandı / pilotta / yayında**. Kod testini geçmek cihaz veya öğretim pilotunu geçmiş olmak değildir. Bu dosyanın iş ID'leri geliştirmeyi; F01–F26 ürün kapsamını; AUDIO-01–05 motor tasarımını izler. [Anlık durum](./CURRENT_ROADMAP.md), [ürün backlog'u](./FEATURE_BACKLOG.md).

## 2. Yayın dilimleri ve bağımlılıkları

| Dilim | Teslim | Önkoşul | Planlama eforu* | Geçiş kapısı |
|---|---|---|---|---|
| R0 — Güvenilir temel | Sonuç v2, geçerli kanıt, ritim event eşleştirme | Mevcut demo | 1–2 hafta; ilk kod alt paketi tamamlandı | Regresyonlar, sözleşme ve yanlış başarı engeli |
| R1 — Gerçek tek ses | Kayıt/çalma, frame motoru, ortam ve oktav | R0 | 2–4 hafta | Gerçek fixture + iOS/Android cihaz raporu |
| R2 — Kullanılabilir Core | Hibrit tasarım, onboarding, tek/aralık/ritim/kısa ezgi | R1; içerik hazırlığı paralel | 4–6 hafta | İlk egzersiz, erişilebilirlik, offline ve öğretmen içerik QA |
| R3 — Öğrenme ve güvenli bulut | Müfredat/tekrar/gelişim, hesap/sync, sınırlandırılmış AI | R2 | 3–5 hafta | Yeni/gecikmeli soru pilotu, veri ve AI güvenlik testleri |
| R4A — Plus pilotu | Gerçek eğitimci kaydı dinler/yazılı teslim eder | R2; kayıt gizliliği ve R3 yetki altyapısı | 2–4 hafta; eğitimci hazırlığı paralel | 20 başvuru/3 eğitimci önerisi; kalite, kapasite, hak akışı |
| R4B — Konservatuvar ileri | 2/3/4 ses, deşifre/dikte, okul denemeleri | R2 sequence + R3 müfredat | 4–6 hafta | Öğretmen onaylı ipucusuz sınav ve sıra/set benchmark |
| R4C — Koro | Parti bağımsızlığı, giriş-bitiş, repertuvar | R2; track/latency spike erken | 3–5 hafta | Kulaklıklı rehbersiz çalışma ve gerçek prova pilotu |
| R5 — Ücretli yayın | Premium/Plus, mağaza satın alma, restore/iptal | Satılan her ürünün ilgili R3/R4 kapısı | 2–4 hafta | Entitlement, hizmet kapasitesi, gizlilik, mağaza QA |
| R6 — Ölçek | Teacher/sınıf/ödev ve opt-in beceri ligi | R5 + ölçülmüş kullanım | Ayrı tahmin | İzinli sınıf pilotu, normalize/denetlenebilir sonuçlar |

*Tek geliştirici, küçük beta ve hazır eğitimci desteği varsayımıyla kaba efor aralıklarıdır; teslim tarihi/teklif değildir. Paralel işleri körlemesine toplama. Core için yaklaşık 8–12 haftalık planlama penceresi değerlendirilebilir; ilk cihaz spike'ı sonrası tekrar tahmin edilir. İleri rotalar ve ücretli Plus daha sonra kendi kapısıyla çıkar; hepsini ilk yayına sıkıştırma.

## 3. R0 — Sonuç ve değerlendirme güvenilirliği

| ID | İş / somut çıktı | Kabul kriteri | Durum |
|---|---|---|---|
| REL-01 | `ScoreMetric`, sonuç v2 JSON, valid/invalid, mode/difficulty/version | Ölçülmedi ve uygulanamaz null; measured zero farklı; geçersiz sonuç sayısal skor taşıyamaz | Kod/test doğrulandı |
| REL-02 | Tek ses scorer ve nötr sonuç görünümü | Gürültü/sessizlik puanlanmaz; timing/memory uygulanmaz; oktav kuralı korunur; non-finite veri güvenli | Kod/test doğrulandı |
| REL-03 | Metrik örnek sayısı ve karşılaştırılabilir cohort | Invalid/eksik sonuç ortalamaya girmez; farklı zorluk/mod/sürüm reddedilir | Kod/test doğrulandı |
| REL-04 | Monoton ritim event alignment, extra/missed, latency ve mutlak sapma | Greedy tuzak testi; ekstra tap 100 olmaz; karşıt sapmalar gizlenmez; boş referans reddedilir | Kod/test doğrulandı; eğitimci kalibrasyonu bekliyor |
| REL-05 | Ezgi placeholder fail-closed | Aynı nota sayısı sıra/timing/memory başarısı üretmez; ölçüm yoksa null/status | Kod/test doğrulandı; gerçek analyzer değil |
| REL-06 | Egzersiz v2: nota/vuruş dizisi, tuning, hint, gecikme, order/set | Geçersiz egzersiz tanımı runtime'da reddedilir; round-trip sözleşme | Kısmi: protocol/binding/round-trip testli; session/katalog ve tuning frekans tutarlılığı bekliyor |
| REL-07 | Analiz/puan için evidence/provenance; içerik kalite kontrolü | Mock/gerçek ayrımı, session id, puanlama sürümü; mutable veri ve kopya sonuç kontrolleri | Kısmi: deep snapshot, pitch provenance/source cohort ve fixture loader testli; diğer analyzer/dedup/etiket QA bekliyor |
| REL-08 | Tekrarlanabilir kalite komutları / CI taslağı | Format, test, analyze; secret olmadan yerel çalışma; CI etkinleştirme ayrı | Yerel runner + test/sağlayıcı-bağımsız taslak kod-testli; hosted run açık |

R0 kod doğrulaması ses motorunun doğru duyduğunu kanıtlamaz. Pitch toleransları değiştirilmedi. Ritim coverage × timing fidelity formülü ilk deterministik implementasyondur, resmî sınav rubriği değildir. Gelişimde persistence/dedup/tuning/hint cohort ayrıntıları R2/R3'te genişletilir.

## 4. R1 — Gerçek ses motoru ve ilk uçtan uca dilim

| ID | İş | Bağımlılık | Kabul / test |
|---|---|---|---|
| AUD-DEV-01 | Audio fixture formatı, nota kayıt envanteri/telif, sample-rate/tuning metaverisi | REL-06 | Sentetik/gerçek ayrı; okul/kişiye göre holdout; etik izin; eksik dosya sessiz geçilmez |
| AUD-DEV-02 | Capture/playback adaptör seçimi ve dar prototip | REL-01; bağımlılık/lisans incelemesi | PCM/sample rate; izin reddi/kalıcı ret; cancel; pause/resume; kulaklık/route değişimi |
| AUD-DEV-03 | Deterministik monofonik frame analyzer | AUD-DEV-01/02 | Boş/kısa buffer sonlanır; NaN/clip/noise; gerçek oktav korunur; frame confidence anlamı açık |
| AUD-DEV-04 | Session coordinator: hazırlan → dinle → cevap → sonuç | AUD-DEV-02/03 | Yeni soruya eski frame sızmaz; arka plan/çağrı/cancel tüm kaynakları kapatır |
| AUD-DEV-05 | Noise-floor/VAD/latency kalibrasyonu | AUD-DEV-02 | Desteklenmeyen route açık; konuşma/eşlik sızıntısı yanlış başarı yaratmaz |
| AUD-DEV-06 | Ses aralığı makinesi ve uç tekrar doğrulaması | AUD-DEV-03/05 | Yanlış oktav uç sayılmaz; rahat bölge/uç ayrımı; kullanıcı durdurabilir; otomatik SATB kesinliği yok |
| AUD-DEV-07 | Gerçek kayıt benchmark ve cihaz raporu | 01–06 | Aynı fixture tekrarlanabilir; false positive/abstention/oktav hatası ve cihaz performansı raporlu |

100+ etiketli tek ses hedefi; kayıt toplama kullanıcı/eğitimci koordinasyonuyla yapılır. Önerilen kalite hedefleri [AUDIO_ENGINE_PLAN.md](./AUDIO_ENGINE_PLAN.md) içindedir; sonuçlara bakıp tanım değiştirilmez. Sentetik test tek başına canlı motor kapısını açmaz. Desteklenen cihazlar pilotta açıkça belirlenir; en az gerçek iOS ve düşük/orta Android denenir.

2026-10-11 devam: AUD-DEV-01 için PCM16 codec, deterministik sentetik tone ve fixture metadata/partition kapısı testli; dosya loader ve gerçek kayıt seti yok. AUD-DEV-02 için resmî record/just_audio belgeleri araştırıldı; bağımlılık/kayıt prototipi henüz eklenmedi. [Uygulama sınırları ve bir sonraki dilim](./AUDIO_TESTING.md).

2026-10-11 “şimdi başlat” paketi: AUD-DEV-02 bağımlılıkları/yerel kayıt laboratuvarı, capture/playback coordinator ve fake regresyonlar eklendi. iOS simulator build geçti; fiziksel cihaz QA, Android build ve tam pause/route kabul kapısı bekliyor. Kesintide iptal edilir, otomatik resume yok. Sonraki iş fixture loader + AUD-DEV-03; canlı pitch ve benchmark tamamlanmış değildir.

2026-10-11 ilk heartbeat: AUD-DEV-01 metadata/manifest v1 JSON + disk loader varlık/hash/header/Hz/count/path/bütçe kod kapısı testli. 123 test/analyze; gerçek fixture veri seti, etiket QA ve device benchmark yok. Sonraki iş AUD-DEV-03 frame analyzer; loader başarısı pitch başarısı değildir. [Kabul sınırları](./AUDIO_TESTING.md).

2026-10-11 08:41 UTC heartbeat: AUD-DEV-03 **frame kod alt paketi** testli; `YinPitchFrameAnalyzer`, finite evidence, kısa/boş/invalid/clip/sessizlik/unreliable durumları; hedef bağımsız Hz + ayrı `PitchDeviation`. Toplam 184 test (+61)/analyze/format geçti. YIN-style çekirdek deneysel alternatif; Agora McLeod port'u veya tam YIN implementasyonu değil. Yalnız sentetik sesler: gerçek VAD, kayıt aggregation/segment, isolate/capture ve cihaz benchmark yok. AUD-DEV-03/R1 bütünü tamamlanmış sayılmaz; sıradaki bağımsız iş bounded kayıt analiz adapter'ı, ardından güvenli laboratuvar PCM/cancel/isolate bağlantısı.

2026-10-11 kullanıcı devam paketi: AUD-DEV-03 bounded `RecordingPitchAnalyzer` diagnostic evidence + native `IsolateRecordingPitchWorker`; 205 test (+21), analyze/format temiz. Periodic ratio/dispersion human voice veya başarı skoru değil; mevcut `PitchAnalyzer`/scorer otomatik değiştirilmedi. Kayıt tamamını preflight, regular half-hop + tek tail anchor, kaynak/version, immutable PCM-free sonuç. Worker tek active iş/snapshot; hard cancel ve lab-owned PCM/load/epoch entegrasyonu sonraki AUD-DEV-04 alt paketi. Gerçek VAD/benchmark/performance/cihaz kapıları açık.

## 5. R2 — Aurora × Konservatuvar Core

2026-10-11 13:44 UTC: AUD-DEV-04 diagnostic alt paketi: owned WAV→immutable
PCM/source→native worker→ayrı lab görünümü; 248 test (+18), analyze/format temiz.
Load bütçe/metadata, duplicate analysis, cancel/new recording epoch, geç hata,
close/background/route, dar ekran ve sentetik WAV→gerçek worker testli.
Hard cancel yok; worker bitişi cleanup kuyruğunu tutmaz, eski iş sırasında yeni
analiz kapalı. Gerçek exercise session/VAD/benchmark/cihaz kabulü değil.
Sonraki bağımsız AUD-DEV-05 kalibrasyon sözleşmesi; fiziksel ölçüm uydurulmaz.

2026-10-11 son kullanıcı açıklaması: AUDIO-04 ana yol hazır 2/3/4 sesli piyano WAV kayıtlarını klasörden oynatmak, öğrenci sırayla tekrar eder. Kullanıcı sesler gelene kadar placeholder istedi: klasör/strict null-metadata katalog + disabled-action UI testli (230 test/+9). Mix renderer alternatif; live chord transcription yok. Gerçek kayıtlar gelince birlikte asset/etiket/hak QA, reviewed manifest/player/session açılır. Sadece dosya eklemek veya placeholder status'u değiştirmek başarı/oynatmayı açmaz.

2026-10-11 kullanıcı piyano isteği: AUDIO-04/R4B için `PianoChordReference` + `PianoChordRenderer` kod alt paketi testli, 221 test (+16). Gerçek sample bankası/rights ve format seçimi, player/session/capture, öğrenci segment/alignment ve cihaz/öğretmen kapıları açık. Bu hazırlama işi R1/VAD/tek ses doğrulaması bağımlılığını kaldırmaz. [Sözleşme](./PIANO_REFERENCES.md).

| ID | Teslim | Kabul |
|---|---|---|
| UX-01 | Renk/tipografi/spacing ve sade–detaylı sonuç sistemi | Aurora marka alanı, nota/vuruş kanıtı, tek sonraki eylem; tasarım kullanıcı testi |
| UX-02 | Onboarding/hedef/misafir/izin ve home | 3 dk ilk egzersiz hedefi; izin reddi çıkmaz değil; hesap mecburiyeti yok |
| UX-03 | Gerçek `VisualFeedbackFrame` ve ses alanı | Enerji/cents/confidence ayrı; reduced motion; yanlış oktav başarı gibi görünmez; UI skoru etkilemez |
| CORE-01 | Tek ses/aralık ve hedefli bölüm tekrarı | Tiz/pes/oktav açıklaması; öğrenmede rehber, recall sınavında gizli |
| CORE-02 | Tap ekranı ve ritim sesi/reference clock | Monoton timestamp; latency açık; eksik/fazla/sapma timeline; clap ayrı spike |
| CORE-03 | Nota segmentleme + ezgi sequence alignment | Ters sıra, ekstra/eksik/tekrar/oktav/süre; null ölçüm; memory için gecikme/ipuçları |
| CORE-04 | 3–5 notalık ezgi ekranı ve hatalı bölüm döngüsü | Dinle → bekle → söyle; replay/hint kaydı; sınavla karışmaz |
| CORE-05 | Yerel sonuç repository ve offline içerik | Sonuç v2 round-trip, aynı attempt iki kez sayılmaz, yerel silme; raw varsayılan saklanmaz |
| EDU-01 | İlk 12 mikroünite / yaklaşık 120 çekirdek örnek önerisi | Eğitimci onayı; doğru/yanlış örnek; yeni kontrol seti; algı/üretim ayrı |
| QA-01 | Widget/integration ve erişilebilirlik matrisi | 320px, büyük yazı, ekran okuyucu; light/dark; izin/noise/empty/error/loading; Türkçe metin |

Çıkış: gerçek mikrofonla tamamlanan tek ses + tap + kısa ezgi; geçersiz ölçümde yeniden deneme; offline geçmiş; açıklama ve sonraki eylem. Animasyon profili gerçek düşük cihazda ölçülür; yalnız emülatör videosuyla kabul edilmez.

## 6. R3 — Öğrenme, veri ve AI koç

- **LEARN-01:** `SkillNode`/önkoşul/katalog; hangi dersten hangi beceriye gidildiği test edilir.
- **LEARN-02:** Algı/üretim, destekli/bağımsız, zorluk/tuning ve içerik sürümlü öğrenme kanıtı. Mevcut cohort modeli başlangıçtır, tam mastery değildir.
- **LEARN-03:** Günlük 5/12/15 dk plan; zayıf alan ve tekrar kuyruğu; yeni/görülmemiş/gecikmeli kontrol. 1/3/7/14 gün ve %80 gibi eşikler pilot hipotezidir.
- **LEARN-04:** Beceri raporu → tek hedef → uygun çalışma; veri yoksa bilinmiyor; evrensel hazırlık yüzdesi yok.
- **DATA-01:** Backend teknolojisi ve bölge için ADR; auth/guest migration, minimum veri, deletion/export, role authorization.
- **DATA-02:** Result sync/outbox/idempotency/çatışma; iki cihazın aynı attempt'i kopyalamaması.
- **DATA-03:** Amaç bazlı consent ve private recording lifecycle; süre, storage, upload doğrulama, signed URL, erişim audit.
- **AI-01:** `gpt-4o-mini` koç, sunucu gateway; API anahtarı mobilde yok. Uygulama aşamasında güncel resmî model/API belgeleri doğrulanır.
- **AI-02:** Yalnız ölçülen özet + izinli egzersiz kataloğu; schema/limit/fallback; skor değiştirme, sağlık teşhisi, uydurma eğitimci yorumu yok.
- **AI-03:** Türkçe sabit eval seti; invalid ölçüm, oktav, yanlış sıra, prompt injection ve olmayan exercise ID testleri. Kullanım/maliyet ve sürüm izlenir.
- **EDU-02:** Öğrenci/öğretmen kapalı beta: başlangıç → yeni soru → gecikmeli kontrol. Kullanım metriği ile öğrenme kanıtı ayrı.

İnsan/eğitimci bulma, hukuki metin, mağaza hesabı veya dış sistem kurulumu gerektiğinde kullanıcıyla koordinasyon gerekir. Geliştirme isteği otomatik dışarıya mesaj, yayın, satın alma veya ödeme yetkisi değildir.

## 7. R4 — Üç ayrı ileri rota

### R4A — Plus gerçek eğitimci

- **HUM-01:** Uzmanlığı doğrulanmış havuz, ücret/kapsam/rubrik; eğitimci pilotu için davetler kullanıcı koordinasyonuyla.
- **HUM-02:** Öğrenci formu: hedef/soru, 30–120 sn kayıt önerisi, seçilmiş 7/30 günlük özet, paylaşım onayı.
- **HUM-03:** Hak ledger: grant/reserve/consume/restore; kapasite ve deadline; upload/iptal/queue hatalarında çift tüketim yok.
- **HUM-04:** Güvenli eğitimci paneli: atama kapsamlı dinleme, zaman notu, kendi yazdığı yorum, üç ödev ve takip hedefi.
- **HUM-05:** Öğrenci yorum/ödev/açıklama akışı; push'a hassas içerik koyma; AI etiketi ayrı.
- **HUM-06:** İlk 20 başvuru kalite kontrolü; yeniden kayıt, eğitmen değişimi, silme/erişim iptali, gecikme ve itiraz.
- **HUM-07:** Kapasite/maliyet; öneri 1 hak/ay, 3 iş günü. Fiyat ve süre pilotla; sınırsız insan hizmeti yok.

Hukuk/çocuk güvenliği, kayıt amaçları/saklama/aktarım ve hizmet/iade şartları doğrulanmadan ücretli Plus açılmaz. AI yazısı insan teslimi yerine geçmez. [Tam hizmet tanımı](./HUMAN_REVIEW.md).

### R4B — Konservatuvar

- **CONS-01:** 2/3/4 hedefin aynı audio clock'ta referansı; gain/clipping/telif.
- **CONS-02:** Sıralı tek vokal segment/set eşleştirme; eksik/fazla/çevrim/oktav sonuçları. Eşzamanlı mikrofondan multipitch ayrı AR-GE.
- **CONS-03:** Fonksiyonel duyma, major/minor, solfej, ritim/ezgi dikte ve deşifre. Eğitimci onaylı notation/audio senkronu.
- **CONS-04:** Okul/bölüm/yıl, kaynak URL/son kontrol, süre/hint/transpozisyon kuralları; bilinmeyen format genel deneme.
- **CONS-05:** Süreli ipucusuz deneme ve rapor; çalgı/şan performansı ayrı uzman desteği/dış çalışma olarak görünür.

Çıkış: görülmemiş referanslarda nota/oktav/sequence benchmark ve eğitimci rubriği. Makam/usul veya tüm konservatuvarlar için eşdeğerlik iddiası yok.

### R4C — Koro

- **CHOIR-01:** İki parti spike'ı; kulaklık + tek vokal, reference bleed ve latency testleri.
- **CHOIR-02:** Parti mixer/rehber gain; solo → rehberli → rehber kapalı. Ses grubu eğitimciyle, otomatik kesin SATB değil.
- **CHOIR-03:** Kanon → 3/4 parti; karşı yön/sus/tonal merkez/kendi hat çizgisini koruma.
- **CHOIR-04:** Giriş/cutoff ve temel şef işareti; ölçülen zamanlama ayrı, diksiyon/ifade eğitimci gözlemi.
- **CHOIR-05:** Lisanslı kısa repertuvar, notalı söz, cümle/dinamik ve gerçek prova ödevi.

Çıkış: rehber kapalı yeni parçada parti bağımsızlığı ve eğitimci gözlemi. Blend/nefes tekniği/tını için otomatik kesin skor yok; gerçek topluluk provası gerekli.

## 8. R5/R6 — Abonelik ve büyüme

- **PAY-01:** Free/Premium/Plus hak matrisi ve ödeme isteği pilotu; eski mock fiyatlar gerçek teklif değil.
- **PAY-02:** Mağaza ürünü/entitlement server doğrulaması; satın alma, pending, restore, cancel, refund, süre bitişi, iki cihaz ve ağ hatası sandbox testleri. Sağlayıcının güncel kuralları uygulama aşamasında doğrulanır.
- **PAY-03:** İnsan hizmeti kapasitesi ve net katkı; yüksek kullanım senaryosu ve QA/destek maliyeti.
- **OPS-01:** Crash/hata metriği, analiz/öğrenme sürümü, raw audio'suz log, rate limits, deletion/export, yedek geri dönme/incident akışı.
- **LAUNCH-01:** Privacy/çocuk güvenliği/hukuk onayı, öğretmen içerik onayı, gerçek cihaz QA ve mağaza metadata incelemesi.
- **LAUNCH-02:** Internal → küçük kapalı beta → daha geniş beta → kullanıcı onayıyla mağaza yayını. Backend ücretli kullanım/AI anahtarı ve dış yayın açık koordinasyon ister.
- **TEACH-01:** İzinli sınıf kodu, ödev/haftalık rapor; öğretmen yalnız bağlı öğrencisini görür.
- **SOC-01:** Takma ad/opt-in, aynı sürüm-zorluk/mod, minimum örnek, sahte/demo kullanıcı hariç; ses aralığı genişliği yarışması yok.

Full katalog, MIDI, marketplace, gerçek zamanlı topluluk analizi ve makam/usul rotası yeni ADR/tahmin gerektirir; ilk gelirin önkoşulu değildir.

## 9. Yakın çalışma kuyruğu

İki haftalık sprintler planlama önerisidir, takvim taahhüdü değildir. Aynı anda en fazla bir ana uygulama paketi ve bir bağımsız içerik/keşif işi.

| Sıra | Kod odağı | Paralel hazırlık | Demo / kanıt |
|---|---|---|---|
| Şimdi | REL-01–05 tamamlandı; REL-06/07 sözleşme ve fixture | Eğitimci görüşme/rubrik taslağı | 58 geçen test, invalid UI, event alignment; mikrofon yok |
| Sonraki paket | AUD-DEV-01/02: fixture + capture/playback prototipi | Nota kayıt hakları ve cihaz envanteri | Gerçek sample rate ile kısa kaydı al/çal; izin/cancel |
| Sonraki sprint | AUD-DEV-03/04/05, tek ses gerçek sonuç | İlk üç mikroünite + hibrit sonuç testi | Gerçek seste doğru/yanlış oktav/noise ve ölçüm izi |
| Sonraki sprint | UX-01/02/03, CORE-01/02/05 | Ezgi fixture ve ders içerikleri | Home → dinle → söyle/tıkla → sonuç → geçmiş |
| Sonraki sprint | CORE-03/04, EDU-01 ve QA-01 | Kapalı beta katılımcıları | Gerçek kısa ezgi; yeni soruda öğrenme kontrolü |

Capture bağımlılığı veya gerçek cihaz eksikse fixture, domain, içerik tanımı ve UI mock/test işlerine devam edilebilir; mock asla gerçek ölçüm diye etiketlenmez. Cihaz kapısı geçmeden R1 tamamlanmış sayılmaz.

## 10. Tamamlandı tanımı ve yarım kalırsa devam

Her işin kanıtı: değişen kaynak, test senaryosu/komut sonucu, manuel cihaz gereksinimi, açık sınırlılık ve sonraki ID. Format/analyze/test temiz olmalı; yalnız test sayısı kalite kararı değildir. Ağ/izin/iptal/empty/invalid hallerini normal akış kadar tasarla.

Oturum sonunda `CURRENT_ROADMAP.md` güncellenir; karar değişirse `DECISIONS.md`; sözleşme değişirse `ARCHITECTURE.md`. İnceleme bulguları tarihi korunarak kapanış kaydıyla izlenir. Dış sistem açılmadıysa yayında yazılmaz. Mevcut kullanıcı dosyaları korunur; git commit/push/PR/yayın otomatik yapılmaz.

Devam talimatı: “Harmonia'da CURRENT_ROADMAP ve IMPLEMENTATION_ROADMAP'i oku. Bir sonraki tamamlanmamış öncelikli paketi uygula; testlerini çalıştır, yapılan işi ve kalan sınırları belgele. Ölçümü AI'ye yaptırma ve insan yorumunu AI ile taklit etme.”

## 11. Modül envanteri iş ID'leri (2026-10-11)

Kullanıcının A–Q modül listesi mevcut ID'lerle eşlendi; eksik kalanlar için yeni ID açıldı. Paralel plan değildir: önceki R0–R6 dilimleri ve ID'ler geçerli. Efor tek geliştirici için kaba aralıktır (S ≤3 gün, M 1–2 hafta, L 2–4 hafta). Dilim: B = kapalı beta Core, Ü = ilk ücretli yayın, G = genişleme. Kanıt: P planlandı, D geliştiriliyor, K kod-test, C cihaz, E eğitim pilotu, Y yayında.

| ID | Öncelik | Kapsam / somut çıktı | Bağımlılık | Kabul kriteri ve test | Cihaz/insan/dış ihtiyaç | Risk | Efor | Dilim | Kanıt |
|---|---|---|---|---|---|---|---|---|---|
| SHELL-01 | P0 | Aurora token'ları (sonuç renkleri: yanlış oktav ≠ başarı, geçersiz = nötr), misafir hedef seçimi, home, ayarlar/yardım/gizlilik/abonelik/hesap, yerel profil + silme, startup hata/yeniden dene | — | Widget: ilk açılış → hedef → home, ayar akışları, silme onayı, bozuk profil, 320px/1.8×, dark; kontrast ≥4.5:1 birim testi | UXR-01 kullanıcı testi, ekran okuyucu manuel | Tasarım kabulü testsiz | M | B | K |
| SHELL-02 | P0 | Mikrofon izni: önceden açıklama, ret, kalıcı ret → OS ayarlarına yönlendirme; izinsiz kullanılabilir yol | SHELL-01 | Fake platform: üç izin durumu; çıkmaz yok | Fiziksel iOS/Android izin diyalogları | Plugin seçimi/izin API farkları | S–M | B | P |
| SHELL-03 | P1 | Başlangıç değerlendirmesi + seviye önerisi (hedef bazlı kısa set) | CORE-01/02, EDU-01 | Ölçülmeyen beceri “bilinmiyor”; seviye önerisi açıklamalı | Eğitimci seviye tanımı | Erken yanlış seviye | M | B | P |
| QA-01a | P0 | Flutter erişilebilirlik kılavuz testleri (Android/iOS dokunma hedefi, etiketli hedef, metin kontrastı) | SHELL-01 | 5 widget testi; açık/koyu onboarding+home, oturum/ritim/lab/geçmiş | Ekran okuyucu manuel testi (VoiceOver/TalkBack) | Otomatik kılavuz ≠ tam erişilebilirlik | S | B | K |
| UX-03a | P1 | Canlı giriş seviyesi göstergesi (record eklenti genliği, 100 ms, yalnız görüntü; tepe-tutma azalması sadece çizimde) | AUD-DEV-02 | 2 widget testi: etiketler, nota iddiası yok, yalnız mikrofon açıkken görünür | Cihazda dBFS doğrulaması | Platform genlik farkı | S | B | K |
| SHELL-04 | P1 | Kaldığı yerden devam, ortak yükleniyor/boş/hata/offline bileşenleri | CORE-05 | Widget durum matrisi | — | — | S | B | P |
| UXR-01 | P0 | Kullanıcı testi protokolü: ilk değer süresi, hata anlama, doğru sonraki eylem; düşük cihaz performansı | SHELL-01, SESSION-01 | Protokol ve önceden kayıtlı eşikler DESIGN_QA.md'de; ≥5 öğrenci + 1 eğitimci | Katılımcılar (kullanıcı koordinasyonu), cihazlar | Küçük örneklem | S hazırlık | B | Protokol hazır, yürütülmedi |
| CAL-01 | P0 | Noise-floor kalibrasyonu, kayıt kalite kapısı (sessizlik/kırpılma/düşük SNR/yetersiz etkinlik/referans kuyruğu), route politikası, latency sözleşmesi (ölçülmedi varsayılanı), lab bağlantısı | AUD-DEV-02/04 | 31 birim/controller/widget testi; route/rate/yaş değişiminde kalibrasyon geçersiz; ölçülmemiş latency düzeltme üretmez | — | Eşikler hipotez | M | B | K |
| CAL-02 | P0 | Cihaz route matrisi ve eşik doğrulaması: hoparlör/kablolu/Bluetooth/USB; iOS route raporu, Android çıkarımı | CAL-01 | Önceden kayıtlı eşiklerle sessiz/gürültülü oda, konuşma, sızıntı kayıtları; sonuçlara bakıp eşik gevşetme yok | ≥1 iOS + ≥1 düşük/orta Android, kulaklıklar | Android route belirsizliği | M | B | P |
| CAL-03 | P0 | Gecikme ölçüm prosedürü: duyulur klik + tap hizalama (≥8 örnek), mümkünse loopback | CAL-01 | Sentetik: dağılım/aykırı değer reddi; cihazda tekrar ölçüm tutarlılığı | Fiziksel cihaz | Tap ölçümü motor gecikmesini de içerir | M | B | P |
| CAL-03a | P0 | Bounded diagnostic medyan/MAD/P90–P10; aykırı trial indeksleri, clock/route/rate ve provenance | CAL-01 | 21 sentetik test; 8–64 trial, invalid tail/mixed clock/scheduled timestamp/inferred route reddi; correctionEnabled=false | CAL-03b gerçek ölçüm | Tap bias/loopback toplamı hardware/touch correction değildir | S | B | K (kod) |
| CAL-03b | P0 | Pipeline'a özel fiziksel gecikme ölçümü ve ortak gözlenen saat adapter'ı | CAL-03a | Ölçüm kimliği/clock/reset/route değişimi, bağımsız tekrar ve belirsizlik; loopback toplamı dokunma gecikmesi olarak aktarılmaz | Cihaz/ölçüm düzeneği, kullanıcı koordinasyonu | Gecikme bileşenleri ayrı tanımlanamayabilir | M | B | P |
| SESSION-01 | P0 | Tek ses ürün oturumu: referans → bekleme → otomatik cevap penceresi → kalite kapısı → diagnostics/nötr yeniden deneme; puansız | CAL-01 | 15 controller + 2 widget testi: referans bitmeden kayıt yok, cevap analizden önce silinir, oktav korunur, kalite reddinde worker çalışmaz, kesinti/iptal/eski sonuç, route/yaş/rate kalibrasyon kontrolü | Cihazda oturum QA | Oturum yarışları | M | B | K |
| SESSION-02 | P1 | Açılışta yetim geçici kayıt temizliği; hata görünürlüğü | AUD-DEV-02 | 4 birim + 2 widget testi: yalnız `harmonia-audio-lab-*`/`harmonia-clip-*`, yalnız bilinen dosya adları, symlink izlenmez, beklenmeyen içerik korunur/raporlanır; ayarlarda uyarı | Cihaz kill testi | Yanlış dosya silme | S | B | K |
| VAD-01 | P0 | İnsan sesi etkinliği/çekimserlik modeli (konuşma, öksürük, enstrüman, sızıntı ayrımı) | BENCH-01 | Kişi bazlı holdout: yanlış başarı ve çekimserlik oranları önceden kayıtlı eşiklerle | Etiketli kayıt | Veri azlığı | L | B | P |
| BENCH-01 | P0 | Etiketli izinli kayıt protokolü: doğru/yanlış nota, oktav, sessizlik, gürültü, konuşma, kararsızlık, sızıntı; development/holdout kişi ayrımı | AUD-DEV-01 loader | Manifest/consent/holdout sızıntı kontrolleri (kodda var); ≥100 kayıt | Katılımcılar, eğitimci etiketleme, rıza | Rıza/etiket kalitesi | L (insan) | B | P |
| CORE-01 | P0 | Gerçek tek ses sonucu (nota/oktav/tiz-pes açıklaması, öğrenme/sınav) | SESSION-01, VAD-01, CAL-02 | Holdout kabul eşikleri; yanlış oktav asla başarı | Cihaz + benchmark | Yanlış başarı | M | B | P |
| CORE-02a | P0 | Dinle → tekrar et ritim taklidi: pointer engine timestamp, ilk dokunuş çapası (zamanlaması ölçülmez/puanlanmaz), sentetik klik, dinleme kotası, vuruş zaman çizelgesi, tempo ipucu, `ExerciseResult` | REL-04 | 21 domain/controller/widget/click testi: aynı vuruş sayısı başarı değil; eksik/fazla/erken/geç; geri giden timestamp düşer; referans sırasında dokunuşlar değerlendirilmez | Eğitimci desen/tolerans onayı; fiziksel dokunma örnekleme ölçümü | Dokunma örnekleme gecikmesi | M | B | K |
| CORE-02b | P1 | Eşzamanlı (count-in) ritim: referansla birlikte vuruş | CAL-03 | Ölçülmüş gecikme yoksa mod kapalı; otomatik kaydırma yok | Cihaz gecikmesi | Çıkış gecikmesi | M | Ü | P |
| CORE-05 / HIST-01 | P1 | Yerel sonuç geçmişi, attempt dedup, silme, kaynak ayrımı, cohort içi gelişim | REL-01 | 19 test: katı round-trip (7 mock senaryo + ritim), aynı attempt duplicate/conflict, kapasite, seri yazma, bozuk dosya korunur, ekran boş/bilinmiyor/trend/silme | Export (DATA-03) | Migration | M | B | K |
| INT-01a | P1 | Hareketli do derece duyma (tonik bağlamı, soru başına ton, hece + aralık adı, karışma çifti) | ADR-024, PERC-01 | 12 test: dengeli seçenek, ton değişimi, tam yarım ton, tohumlu, sonuç/round-trip, eksik tur, beceri durumu, etiketler, ton dizisi, seçenek dışı cevap, kalıcılık, seviye kilidi/iptal, ekran + geçmiş, planlayıcı rotası | Eğitimci terminoloji/içerik onayı | Terminoloji karışması | M | B | K |
| DATA-03a | P1 | Yerel ses-siz sürümlü dışa/içe aktarma (pano), strict doğrulama, geçmiş kurallarıyla import | CORE-05 | 7 birim + 4 widget testi | Gerçek cihazlar arası deneme | Bozuk belge | S | B | K |
| LEARN-04a | P1 | Beceri raporu: durum sayıları, bilinmeyen beceriler, tek hedef + eylem; yüzde yok | LEARN-01a, LEARN-03b | 5 birim + 2 widget testi | Eğitimci rapor dili onayı | Yanlış yorum | S | B | K |
| SHELL-04a | P1 | Günlük bütçe tercihinin cihazda saklanması (bozuk → varsayılan) | LEARN-03c | 3 birim + 1 widget testi | — | — | S | B | K |
| LEARN-03c | P1 | Süreli günlük plan 5/12/15 dk: kontrol kuyruğu (1/3/7/14), zayıf tekrar, günlük yeni sınırı, gün içi sabit plan + ilerleme; plan ekranı/home | LEARN-03b | 13 domain + 6 widget testi; bütçe aşılmaz, boş süre açık, kontrol yalnız retention turuyla tamamlanır | Eğitimci süre/aralık onayı, öğrenme pilotu | Yanlış yük/aralık | S | B | K |
| LEARN-03b | P1 | Beceri grafiği tabanlı günlük öneri (rota + tüm ölçülen egzersizler), algı kalıcılık kontrolü | LEARN-01a, PERC-01 | 6 planlayıcı + 1 controller testi; home kartı egzersiz türüne göre doğru ekranı açar | Eğitimci rota/ölçüt onayı | Yanlış sıralama | S | B | K |
| PERC-01 | P1 | Tiz/pes algı turu (8 dengeli sentetik çift, dokunma cevabı, öğrenme geri bildirimi, şans düzeyi), geçmiş + beceri grafiği bağlantısı | LEARN-01a, CORE-05 | 12 test: dengeli/tohumlu/tam cent, sabit cevap = şans, sonuç sözleşmesi/round-trip, eksik tur geçersiz, beceri merdiveni, ton çifti sessizliği, dinlemeden cevap yok, tekrar sayımı, tur ortasında seviye kilidi, iptal kaydetmez, ekran + geçmiş metni | Eğitimci seviye/ölçüt onayı | Algı ≠ üretim karışması | S | B | K |
| LEARN-01a | P1 | Taslak beceri grafiği (önkoşul/rota/ölçüm desteği), kanıta dayalı durum merdiveni, hedefe göre beceri haritası | CORE-05, LEARN-03a | 14 test: tekrar/bilinmeyen/rota-arası önkoşul ve döngü reddi, ölçülen düğüm ↔ egzersiz bağı, sıra, rota filtresi, merdiven geçişleri, kötü sonraki deneme geri düşürür, denenmemiş egzersiz tavanı, farklı sürüm dışlanır, ekran durumları ve kılavuzlar | Eğitimci grafik/ölçüt onayı | Yanlış önkoşul | M | B | K |
| LEARN-03a | P1 | Sonuçtan tek somut sonraki çalışma (kural tabanlı; hedefli tekrar → yeni desen → gecikmeli kontrol) | CORE-05, CORE-02a | 14 test: başla/ölçülemeyen/baskın hata/tek temiz ≠ ustalık/yeni desen/ertesi gün kontrol önceliği/kalıcı/başarısız kontrol/farklı sürüm-kaynak dışlama/mevcut desen önceliği; kalıcılık kontrolünde tek dinleme ve `retentionCheck` işareti; AI yok | Eğitimci eşik onayı, öğrenme pilotu | Yanlış ilerleme önerisi | M | B | K |
| SHELL-02 karar | P0 | Kalıcı izin reddinde OS ayarlarına derin bağlantı için plugin seçimi (ör. permission_handler / app_settings) | — | Bağımlılık lisans/bakım incelemesi | **Kullanıcı kararı**: yeni bağımlılık | Supply-chain | S | B | P |
| RANGE-01 (AUD-DEV-06) | P1 | Ses aralığı taraması | CORE-01 | Uç tekrar doğrulaması; belirsiz ≠ başarısız | BENCH-01 | Sağlık/SATB iddiası | M | Ü | P |
| INT-01 | P1 | Aralık/fonksiyonel duyma içerik + algı/üretim ayrı ölçüm | EDU-01, CORE-01 | Melodik/harmonik ayrımı; eğitimci onaylı solfej yaklaşımı | Eğitimci | İçerik hakları | L | Ü | P |
| AI-02a | P1 | Koç girdi/çıktı sözleşmesi, doğrulayıcı, zaman aşımı + yedek, yerel eval | REL-01, CORE-05 | 12 test: kaynak kapısı, metinsiz yük, skor/olmayan egzersiz/hazırlık %/eğitimci taklidi/teşhis/geçersizde övgü/uzunluk/bozuk metin reddi | Gateway + ücretli API onayı (AI-01/03) | Model davranışı | S | Ü | K (kod) |
| ANALYTICS-01 | P1 | Olay sözleşmesi (hassas kayıt/ham ses yok), sınırlı bellek içi kayıt; gönderim yok; metrik eşlemesi PRODUCT_SPEC'te | SHELL-01 | 5 test: serbest metin/bilinmeyen anahtar/ses dizisi/kişisel kimlik reddi, dakika hassasiyeti, sınırlı kayıt | Sağlayıcı seçimi, rıza, mağaza gizlilik beyanı (onay) | Gizlilik | S | Ü | K (kod) |
| ECON-01 | P1 | Birim ekonomi modeli: net gelir − komisyon − vergi − iade − edinim − AI/altyapı − içerik − destek − eğitimci | PAY-01 | Düşük/orta/yüksek × %15/%30 komisyon tablosu PRODUCT_SPEC'te; tüm girdiler varsayım | Güncel mağaza/vergi/AI fiyatı, eğitimci ücreti, ödeme isteği | Varsayım hatası | S | Ü | Model hazır, veri yok |

Mevcut ID'ler bu tabloya taşınmadan geçerlidir: UX-01/02/03, CORE-03/04, EDU-01/02, LEARN-01–04, DATA-01–03, AI-01–03, HUM-01–07, CONS-01–05, CHOIR-01–05, PAY-01–03, OPS-01, LAUNCH-01/02, TEACH-01, SOC-01. Kapsamları §5–§8'de.

**Uygulama sırası (kullanıcı talimatı):** güvenilir ses/kalibrasyon → gerçek tek ses/oturum → kullanılabilir tasarım → ritim/kısa ezgi → offline/geçmiş → müfredat/günlük rota → kapılarıyla bulut/AI → piyano/ileri hazırlık → Plus/koro → abonelik ve yayın. Bağımsız işler paralel ilerleyebilir; kapılar atlanmaz.

## 2026-10-12 — CORE-03a sıralı pitch alignment alt paketi

Bağımlılığı hazır bağımsız kod işi: bilinen reference ve önceden segmentlenmiş
response olayları (frequency/onset/duration) arasında bounded monotonic
alignment. 1:1 Levenshtein edit maliyeti; tie önce daha çok correct, sonra daha
az mutlak cents. Exact sıra; missing/extra/wrongPitch/wrongOctave kaybolmaz.
50 cent varsayılanı mevcut tek ses sınırını değiştirmez; öğrenci skoru üretilmez.

**Kod-test:** 480 test (+14), analyze temiz, format 143/0. 64 event/60 sn
bütçe; finite Hz, süre ve overlap kontrolü; invalid response null karar.
Timing, memory, anyOrder chord eşleştirme veya PCM segmentleme yok. Mock melody
adapter açılmadı; gerçek motor/başarı bağlantısı yapılmadı.

**Sonraki CORE-03b:** recording frame evidence→monofonik segmentleme adapter'ı
(sentetik trace regresyonları); voice/VAD/gerçek etiketli ezgi benchmark kapısı
korunur. CORE-04 dinle→hatırla→söyle oturumu/ekranı ayrıca gerekir. Piyano
placeholder kullanıcı dosyaları gelmeden değişmez. Cihaz/öğretim kabulü değil.

## 2026-10-12 07:51 TRT — CORE-03b diagnostic frame→segment alt paketi

`PitchSegmenter.fromRecording` immutable frame evidence'ı hedef bağımsız run
adaylarına dönüştürür. Bütçe 8–48 kHz/10 sn/512 frame, hipotetik 35 cent
anchor sapması, en az 3 frame ve 200 ms merkez-tabanlı span. Ham octave fold
yok; uncertain/silence/gap hard boundary. Kısa run'lar discarded frame
indeksleriyle korunur; başarıya sessizce dönüştürülmez. Skor/voice/memory yok.

Bu CORE-03'ün kod alt paketidir, gerçek segmentation kabulü değil. Sonraki
CORE-04 puansız dinle→hatırla→cevap session ve fake lifecycle/epoch; VAD/etiketli
ezgi benchmark/cihaz kapısı geçmeden öğrenci başarısı açılmaz. Timing ve anyOrder
chord matcher ayrı kapsam; kullanıcı piyano dosyaları gelmeden placeholder aynı.

## 2026-10-12 13:13 TRT — CORE-04a puansız ezgi session alt paketi

`MelodySessionController` SESSION-01 kalibrasyon/kayıt/kalite/epoch hattını
kompozisyonla kullanır; tek ses representative deviation dışarı verilmez.
`MelodyReferenceBackend` 3–5 nota immutable reference kimliği/sürümüne bağlanır;
standart C4 backend yanlışlıkla ezgi olarak takılamaz. Gerçek dosya/etiket/hak
doğrulaması bu declaration'dan çıkarılmaz. Player completed callback sayısı
yalnız bu denemenin dinleme kaydıdır; fiziksel duyma veya hafıza ölçümü değil.

Native mutation/read komutları serialized; playback completion ve DSP queue
dışında. Cancel pending-start bitişinden sonra discard eder; başarısız komut
cleanup kuyruğunu zehirlemez. Pending permission/read/worker bitmeden restart
yok, hard cancel yok. Diagnostic segment sonucu var; sequence başarı kararı,
memory/timing skoru, history/AI/upload yok. 10 fake/sentetik test; tüm suite 503.

**Sonraki CORE-04b:** Bu reference sözleşmesine bağlı yerel sentetik 3–5 nota
player adapter + puansız ekran/home bağlantısı, hata/izin/iptal/büyük yazı testleri.
Yanlış bölüm loop'u ancak güvenilir karar/içerik protokolüyle açılır. VAD/insan
benchmark ve cihaz kapıları geçmeden skor/başarı yok; 2/3/4 piano placeholder aynı.

## 2026-10-12 18:20 TRT — CORE-04b1 bağlı sentetik reference adapter

`SyntheticMelodyBackend` typed reference'i deterministik mono PCM16 sinüs WAV'a
çevirir: 3–5 sıralı ton, 600 ms ton/200 ms ara/sonda 400 ms sessizlik; 8–48 kHz.
`playReference` ayrı clip player'dadır, capture backend'in varsayılan C4 yoluna
düşmez. Capture/reader/route/interruptions orijinal kaynağı korur; stop ve close
bir kaynak hata verse de ikisini kapatmayı dener. Close idempotent; yeniden
play/capture reddedilir. Mobile factory mevcut plugin adapter'larını birleştirir,
tek başına kayıt/izin başlatmaz. Sentetik reference gerçek piyano değildir.

Bu CORE-04b'nin yalnız infrastructure alt paketidir. Sonraki CORE-04b2 puansız
ezgi ekranı/home: açık başlat/kalibrasyon, permission/noise/error/cancel/close,
320 px ve büyük yazı; source/segment/onset sınırları açık. Gerçek VAD/benchmark/
cihaz/öğretim ve bölüm döngüsü kabul kapıları açık; skor veya mastery açılmaz.

## 2026-10-12 23:20 TRT — CORE-04b2 puansız ezgi ekranı/home

MelodySessionScreen: açık kalibrasyon/başlat/bitir/iptal, üç sentetik ton,
native worker. Girişte izin/kayıt yok; piyano olmadığı, doğru/yanlış/sıra/hafıza
puanının kapalı olduğu açık. Nötr retry, completed reference sayısı, isteğe
bağlı source/raw Hz aday ayrıntıları. Background iptal, permission inactive
istisna, dispose close. Home Deneysel kart; chord placeholder aynı.
8 fake widget testi: giriş, izin reddi, 320px/1.8× akış/source, sessizlik,
playback cancel/background, pending permission dispose, home route, a11y.
CORE-04 tümü tamamlanmadı: güvenilir bölüm döngüsü/recall ve gerçek voice/device/
eğitimci kapıları açık. Bağımsız sıradaki iş REL-08 local QA runner/CI taslağı;
dış CI etkinleştirme/push yetkisi değil. LEARN-02 mikroders şeması da hazır iş.

## 2026-10-13 04:20 TRT — REL-08 yerel kalite runner

Standalone `dart tool/quality_check.dart`: script konumuna bağlı Harmonia root
guard, read-only lib/test/tool format → no-pub analyze → no-pub full tests.
İlk hata exit code korunur, spawn error 127; otomatik SDK kurulumu yok.
`--plan` komut envanteri, `--fetch` explicit pub get --enforce-lockfile.
Default fetch/deploy/build/ücretli API/upload yok; `dart run` yerine standalone
giriş implicit pub/build-hook başlangıcını önler. CI docs/ci/README.md taslak,
aktif workflow yok. Hard subprocess timeout yok; hosted job timeout onayla
belirlenir. CI/başka OS/cihaz kabulü değil. Sonraki LEARN-02 mikroders şeması,
taslak ile eğitimci onaylı içeriği ayırarak; gerçek benchmark kapıları açık.

## 2026-10-13 09:15 TRT — LEARN-02a draft mikroders sözleşmesi

MicroLesson/LessonStep/Catalog immutable, bounded; tam sıralı beş faz:
açıklama → karşılaştırma → destekli pratik → yeni örnek kontrolü → gecikmeli
kontrol. Tek skillId/route/dimension graph'a doğrulanır. Training/independent/
delayed example ID partition sızıntısı ve unknown skill reddi; örnek ID bağlamak
hak/etiket/acoustic novelty veya çalıştırılabilir egzersiz doğrulaması değildir.

İki developer text draft: tiz/pes algı ve puls üretim. Örnek slotları boş/pending;
educatorApproved ve assessmentEnabled her zaman false. Okuma/completion→mastery
veya ExerciseResult bridge yok. Bu 12 onaylı ünite/120 kayıt teslimi değil;
JSON/asset/importer/onay akışı ve UI henüz yok. Sonraki LEARN-02b draft lesson
okuma ekranı + skill-map/home erişimi, görünen onay/örnek bekleme etiketi ve
yanlış beceri kazanımı yaratmayan widget testleri. EDU-01/pilot ayrı kapılar.

## 2026-10-13 14:17 TRT — LEARN-02b taslak mikroders okuma ekranı

MicroLessonScreen salt metin, beş faz, algı/üretim ve içerik sürümü, görünür
eğitimci onayı/örnek bekleme; çalıştırma kontrolü kapalı. Beceri haritasında
ilgili düğümden iki taslağa erişim; custom graph default ders almaz, injectable
lesson catalog skill route/dimension filtrelenir. Ses/mic/API/history/mastery
ve tamamlandı marker yok. 6 widget test: etiket/disabled, history/status unchanged,
puls route, custom graph, 320px/1.8×, tap/label/contrast kılavuzları.
Bu gerçek eğitimci onayı, ses bankası veya pedagojik sonuç değil. Sonraki
LEARN-02c strict versioned JSON draft katalog round-trip/import kapısı; alanları
onaylanmış ses veya öğrenci mastery'sine sessizce çevirmeme. EDU-01 açık.

## 2026-10-13 19:17 TRT — LEARN-02c draft katalog JSON codec

MicroLessonCodec schemaVersion=1/kind=draft_micro_lessons; exact keys/types/
enums, yalnız draft review. Graph binding, phase order ve training/control
partition tekrar uygulanır; invalid tail tüm catalog'u reddeder. 1MiB UTF8,
128 lesson/5 step/24 ids ve bounded text; parser errors source metni taşımaz.
Deterministic round-trip/immutable restore; pure domain, otomatik file/asset/
network import yok. Standard JSON duplicate-key semantics, signed/canonical
belge doğrulaması veya waveform novelty/hak/onay kabulü değil. Sonraki LEARN-03
süreli günlük 5/12/15dk plan (taslak süreler); EDU-01/pilot ayrı açık.

## 2026-10-13 20:45 TRT — LEARN-03c süreli günlük plan

DailyPlanner + DailyPlanScreen: 5/12/15 dk bütçe, kontrol → tekrar → yeni
sırası, 1/3/7/14 gün kuyruğu, beceri başına tek yeni seviye, günde ≤1/2 yeni.
Plan gece yarısı sabitlenir; bugünkü turlar ilerleme. Taslak süreler ve
aralıklar pilot hipotezi; mastery eşikleri aynı. 19 yeni test, 574 suite.
Sonraki kod işleri: LEARN-04 beceri raporu → tek hedef, SHELL-04 ortak durum
bileşenleri, DATA-03 yerel export; dış kapılar (cihaz, BENCH, EDU-01, piyano) açık.
