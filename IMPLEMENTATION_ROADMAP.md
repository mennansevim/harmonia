# Resonia — Ayrıntılı uygulama ve yayın roadmap'i

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
| REL-06 | Egzersiz v2: nota/vuruş dizisi, tuning, hint, gecikme, order/set | Geçersiz egzersiz tanımı runtime'da reddedilir; round-trip sözleşme | Kısmi: protocol/binding/round-trip + REL-06a 12TET label/frequency/A4 metadata guard testli; session/katalog ve gerçek audio QA bekliyor |
| REL-07 | Analiz/puan için evidence/provenance; içerik kalite kontrolü | Mock/gerçek ayrımı, session id, puanlama sürümü; mutable veri ve kopya sonuç kontrolleri | Kısmi: deep snapshot, pitch provenance/source cohort ve fixture loader testli; diğer analyzer/dedup/etiket QA bekliyor |
| REL-08 | Tekrarlanabilir kalite komutları / CI taslağı | Format, test, analyze; secret olmadan yerel çalışma; CI etkinleştirme ayrı | Yerel runner + test/sağlayıcı-bağımsız taslak kod-testli; 08a full suite `--concurrency 4` ile kaynak baskısına karşı sabit; hosted run açık |

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

**2026-10-27 — CONS-01a:** Henüz gerçek WAV eklenmeden, incelenmiş hazır
piyano kaydı için strict domain manifesti kod-testli. Yalnız 2/3/4 ses; klasör
ile voice count eşleşmesi, alttan üste farklı MIDI, PCM16 WAV metadata bütçesi,
SHA-256, hak referansı ve bağımsız nota etiketi inceleme referansı zorunlu.
Manifest beyanı dosya/header/hash/nota/hak doğrulaması veya playback izni
değildir. CONS-01b read-only file adapter ve gerçek kayıt QA'sı açık.

**2026-10-27 — CONS-01b:** Manifest entry'sini açıkça seçilmiş yerel kökten
salt-okunur yükleyen adapter kod-testli. Path/root/symlink, byte bütçesi ve
okuma boyunca uzunluk kontrolü; SHA-256; RIFF/WAVE PCM16 mono/stereo header;
sample rate/channel/frame exact eşleşmesi fail-closed. Defensive byte copy
yalnız ilerideki player adapter'ına veri sağlar; bu paket oynatma, remix,
nota/hak doğrulama veya UI açmaz. Gerçek kayıt QA + CONS-01c player açık.

**2026-10-27 — CONS-01c:** Bir reviewed kayıt + doğrulanmış WAV byte snapshot'ı
için dedicated `ChordReferenceSession` kod-testli. Autoplay yok; explicit play
tamamlanıp player stop ve 0–10 sn recall delay bitmeden sıralı cevap kapısı
açılmaz. Cancel/background/route-focus kesintisi epoch'u iptal eder ve otomatik
resume etmez; cleanup failure tekrar oynatmayı fail-closed kapatır; close tekil
ve serialize. Bu katman mikrofon açmaz, skor/history/mastery yazmaz. Gerçek
kayıt QA, production player/UI wiring ve CONS-02 cevap segment/alignment açık.

**2026-10-27 — CONS-02a:** Mevcut target-independent monofonik segment
kanıtını reviewed MIDI/A4 hedefleriyle exact low→high sırada karşılaştıran
domain adapter kod-testli. 2/3/4 hedef; eksik, fazla/mükerrer, yanlış pitch,
yanlış oktav ve aynı mutlak hedef setinin farklı sırası ayrılıyor. Segment
zamanları nominal sıraya çevrilir ve timing/recall puanı üretilmez; provenance
ve discarded/non-pitched frame sayıları korunur. `diagnosticCandidateMatch`
skor/history/mastery değildir. Capture composition, any-order/set seçeneği,
BENCH/VAD ve gerçek cihaz kabulü açık.

**2026-10-28 — CONS-02b:** Aynı matcher protokoldeki `ResponseOrder.anyOrder`
için bounded set özeti üretiyor. En fazla dört hedef nedeniyle 2^N state DP;
her gözlenen aday atlanır veya yalnız bir hedefe atanır. Exact mutlak pitch,
yanlış oktav, eksik hedef ve fazla/mükerrer aday ayrı sayılır; ilgisiz pitch bir
eksik + bir fazla bırakır. Exact-order alignment her durumda korunur ve ters
sıra açıklaması kaybolmaz. Set modu da yalnız diagnostic aday eşleşmesidir;
ExerciseResult/history/mastery açmaz. Gerçek capture/fixture/device kapıları açık.

**2026-10-28 — CONS-02c:** `ChordResponseCaptureSession` reviewed referans ile
tek sürekli monofonik öğrenci kaydını yaşam döngüsü düzeyinde bağlıyor. İzin ilk
referanstan önce; capture yalnız playback+recall hazırsa başlar. Replay kapıyı
yeniden kapatır. Stop sonrası metadata+PCM exact doğrulanır, native kayıt silinir
ve yalnız ephemeral immutable snapshot kalır. Cancel/interruption/pending start
serialize; cleanup failure replay'i kapatır. Worker/quality/matcher, skor,
history/mastery ve UI yok; BENCH/VAD/cihaz kapıları açık.

**2026-10-28 — CONS-02d:** Capture snapshot artık ölçüm anındaki route'u ve
reviewed kayıt metadata'sını taşır. `ChordResponseDiagnosticAnalyzer` mevcut
kalite kapısını zorunlu kullanır; missing/stale/wrong-route calibration veya
silent/invalid kalite worker'ı çalıştırmaz. Usable durumda bounded worker →
target-independent segment → exact/any-order matcher çalışır. Worker metadata
ve provenance capture ile exact eşleşmezse çekimser kalır. Çıktı diagnostic
candidate evidence; skor/history/mastery/AI değildir. BENCH/VAD/cihaz açık.

**2026-10-29 — CONS-02e:** `ChordResponseCaptureSession` içine açık ve tekrar
edilebilir ortam kalibrasyonu bağlandı. Oturum izin→route snapshot→1.5–5 sn
sessizlik capture→metadata/PCM doğrulama→native discard→noise-floor sırasını
aynı serialized kaynak kuyruğunda yürütür. Gürültü/aktivite tarafsız retry'dır;
başarılı kalibrasyon referans boyunca kalır, cancel/interruption/close ile
geçersizleşir. Üretim UI sonucu ve gerçek kayıt availability hâlâ kapalıdır.

**2026-10-29 — CONS-02f:** `ChordResponseAttemptCoordinator` kalibrasyon,
reviewed referans, tek sürekli sıralı cevap ve quality→worker→segment→matcher
zincirini tek UI-ready application state machine'de birleştirir. Ürün kapısı
kalibrasyon olmadan referans/cevap başlatmaz. Pending analiz sırasında
cancel/replay/close eski sonucu yayımlayamaz; quality retry ile worker
unavailable ayrıdır. Candidate evidence hâlâ skor/history/mastery/AI değildir.

**2026-10-29 — TRAINER-04a:** Pitch eğitmeni “Söyle” adımının ilk güvenli
composition dilimi eklendi. `TrainerPitchSingTarget` yalnız pitch lesson içindeki
item ve izinli register'ı kabul eder; seçilen alt koro partisini sounding
register'a uygular ve tını sürümlü sentetik hedef üretir. Ayrı reference player
ile mevcut SESSION-01 kalibrasyon/kalite/isolate zinciri tek sahipli session'da
buluşur. Puan, node completion, store/history/mastery/unlock yazımı yoktur.
UI bağlantısı ve gerçek BENCH/VAD/cihaz kabulü TRAINER-04b/dış kapıdır.

**2026-10-29 — TRAINER-04b:** Pitch lesson “Söyle” sayfası 04a session'ını
production mobile factory veya test injection ile compose eder. Girişte izin,
playback veya capture yoktur; ortam ölçümü ve deneme ayrı açık eylemlerdir.
Durumlar dinle/hazırlan/söyle/kalite/analiz olarak görünür; sonuç yalnız kaynak
etiketli sent diagnostic'idir ve “puan değil” der. Skip her zaman açıktır.
Background/route/çıkış cancel eder, resume autoplay yapmaz; factory unavailable
nötr ve atlanabilir. Store/history/mastery/completion/unlock bağlantısı yoktur.
TRAINER-04c ancak BENCH/VAD/cihaz kanıtıyla skor politikasını değerlendirebilir.

**2026-10-28 — CONS-01d:** `ChordReferenceSession` öğrenme/recall modunu ve
1–10 completed-play kotasını taşır. Sayaç native completion sonrası artar;
cancel/route/background/start failure tüketmez. Replay response-ready kapısını
hemen kapatır ve yeniden tam playback+recall ister. Learning kotası açıkça
verilir; recall exam tek dinleme, hedef görünmez. `PianoChordReference` da recall
exam için tek dinlemeyi fail-closed doğrular. Bu sayaç duyma veya öğrenme kanıtı
değildir; production UI/history/cihaz bağlantısı hâlâ açık.

**2026-10-28 — CONS-01e:** App composition sınırı reviewed loader çıktısının
recording metadata'sı ile defensive WAV snapshot'ını tek işlemde fresh player
ve `ChordReferenceSession` ile bağlıyor. Invalid mode/quota player tahsisinden
önce fail-closed; her create bağımsız player ister ve başarılı session kaynağın
sahibidir. Create autoplay, mikrofon, skor/history/mastery veya placeholder
availability açmaz. Production `JustAudioClipPlayer`/UI/capture wiring, gerçek
kayıt QA ve cihaz route kabulü açık.
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

Devam talimatı: “Resonia'da CURRENT_ROADMAP ve IMPLEMENTATION_ROADMAP'i oku. Bir sonraki tamamlanmamış öncelikli paketi uygula; testlerini çalıştır, yapılan işi ve kalan sınırları belgele. Ölçümü AI'ye yaptırma ve insan yorumunu AI ile taklit etme.”

## 11. Modül envanteri iş ID'leri (2026-10-11)

Kullanıcının A–Q modül listesi mevcut ID'lerle eşlendi; eksik kalanlar için yeni ID açıldı. Paralel plan değildir: önceki R0–R6 dilimleri ve ID'ler geçerli. Efor tek geliştirici için kaba aralıktır (S ≤3 gün, M 1–2 hafta, L 2–4 hafta). Dilim: B = kapalı beta Core, Ü = ilk ücretli yayın, G = genişleme. Kanıt: P planlandı, D geliştiriliyor, K kod-test, C cihaz, E eğitim pilotu, Y yayında.

| ID | Öncelik | Kapsam / somut çıktı | Bağımlılık | Kabul kriteri ve test | Cihaz/insan/dış ihtiyaç | Risk | Efor | Dilim | Kanıt |
|---|---|---|---|---|---|---|---|---|---|
| SHELL-01 | P0 | Aurora token'ları (sonuç renkleri: yanlış oktav ≠ başarı, geçersiz = nötr), misafir hedef seçimi, home, ayarlar/yardım/gizlilik/abonelik/hesap, yerel profil + silme, startup hata/yeniden dene | — | Widget: ilk açılış → hedef → home, ayar akışları, silme onayı, bozuk profil, 320px/1.8×, dark; kontrast ≥4.5:1 birim testi | UXR-01 kullanıcı testi, ekran okuyucu manuel | Tasarım kabulü testsiz | M | B | K |
| SHELL-02 | P0 | **Kod/build tamam:** açık ret sonrası tek ses/ezgi/lab ekranlarında OS uygulama ayarları; girişte prompt yok, izinsiz çıkış/referans yolu korunur | SHELL-01 | 4 yeni fake/widget + üç ekran regresyonu; 824 full | Fiziksel iOS/Android kalıcı ret ve ayarlardan dönüş | Android pasif status kalıcı reddi ayıramaz; eylem yalnız gerçek ret sonrası görünür | S–M | B | K/D |
| SHELL-03 | P1 | **03a kod tamam:** isteğe bağlı 3 dokunma turu, yerel devam ve açıklamalı pratik odağı; toplu seviye yok. **03b açık:** eğitimci onaylı hedef bazlı seviye tanımı | PERC-01, CORE-02; gerçek yerleştirme için CORE-01/EDU-01 | 4 domain + 4 widget/integration; ölçülmeyen beceri “bilinmiyor” | Eğitimci seviye tanımı + öğrenci kabulü | Erken yanlış seviye; bu nedenle readiness skoru kapalı | M | B | K/D |
| QA-01a | P0 | Flutter erişilebilirlik kılavuz testleri (Android/iOS dokunma hedefi, etiketli hedef, metin kontrastı) | SHELL-01 | 5 widget testi; açık/koyu onboarding+home, oturum/ritim/lab/geçmiş | Ekran okuyucu manuel testi (VoiceOver/TalkBack) | Otomatik kılavuz ≠ tam erişilebilirlik | S | B | K |
| UI-01b | P1 | Mevcut marka işaretinden iOS varsayılan/koyu/renklendirilmiş tek-boyut AppIcon kaynakları | UI-01, REL-09 | 4 asset testi; 1024 px, default opak, dark saydam, tinted gri tonlu; Xcode 27 actool uyarısız | Fiziksel iOS görünümü + profesyonel tasarım/mağaza QA | Sistem tint/maske görünümü cihazda farklılaşabilir | S | B | K/D |
| UX-03a | P1 | Canlı giriş seviyesi göstergesi (record eklenti genliği, 100 ms, yalnız görüntü; tepe-tutma azalması sadece çizimde) | AUD-DEV-02 | 2 widget testi: etiketler, nota iddiası yok, yalnız mikrofon açıkken görünür | Cihazda dBFS doğrulaması | Platform genlik farkı | S | B | K |
| SHELL-04 | P1 | **04a–o kısmi kod tamam:** tercihler, ortak durumlar, consumer recovery, güvenli yeni tur, Today/plan/harita/geçmiş ön plan yenilemesi ve dependency replacement. Today tercih store kimliğini revision'dan ayrı izler; eski store'daki bekleyen save yeni UI'a yayın yapamaz, store değişince eski tercihler yeni okuma boyunca görünmez; alan-bazlı read failure eski veriyi diriltmeden nötr uyarı/açık retry verir ve pending read sırasında hedef yazımı kapalıdır. Yarım ses/mikrofon oturumu restore edilmez. Kalan: gerçek cihaz/offline kabul matrisi | CORE-05 | Domain + widget durum matrisi; SHELL-04f 6, 04g 2, 04h 3, 04i 3, 04j 1, 04k 1, 04l 1, 04m 1, 04n 1, 04o güçlendirilmiş test | Gerçek cihaz/offline kabulü | Sessiz stale state veya unsafe media restore | S | B | K/D |
| UXR-01 | P0 | Kullanıcı testi protokolü: ilk değer süresi, hata anlama, doğru sonraki eylem; düşük cihaz performansı | SHELL-01, SESSION-01 | Protokol ve önceden kayıtlı eşikler DESIGN_QA.md'de; ≥5 öğrenci + 1 eğitimci | Katılımcılar (kullanıcı koordinasyonu), cihazlar | Küçük örneklem | S hazırlık | B | Protokol hazır, yürütülmedi |
| CAL-01 | P0 | Noise-floor kalibrasyonu, kayıt kalite kapısı (sessizlik/kırpılma/düşük SNR/yetersiz etkinlik/referans kuyruğu), route politikası, latency sözleşmesi (ölçülmedi varsayılanı), lab bağlantısı | AUD-DEV-02/04 | 31 birim/controller/widget testi; route/rate/yaş değişiminde kalibrasyon geçersiz; ölçülmemiş latency düzeltme üretmez | — | Eşikler hipotez | M | B | K |
| CAL-02 | P0 | Cihaz route matrisi ve eşik doğrulaması: hoparlör/kablolu/Bluetooth/USB; iOS route raporu, Android çıkarımı | CAL-01 | Önceden kayıtlı eşiklerle sessiz/gürültülü oda, konuşma, sızıntı kayıtları; sonuçlara bakıp eşik gevşetme yok | ≥1 iOS + ≥1 düşük/orta Android, kulaklıklar | Android route belirsizliği | M | B | P |
| CAL-03 | P0 | Gecikme ölçüm prosedürü: duyulur klik + tap hizalama (≥8 örnek), mümkünse loopback | CAL-01 | Sentetik: dağılım/aykırı değer reddi; cihazda tekrar ölçüm tutarlılığı | Fiziksel cihaz | Tap ölçümü motor gecikmesini de içerir | M | B | P |
| CAL-03a | P0 | Bounded diagnostic medyan/MAD/P90–P10; aykırı trial indeksleri, clock/route/rate ve provenance | CAL-01 | 21 sentetik test; 8–64 trial, invalid tail/mixed clock/scheduled timestamp/inferred route reddi; correctionEnabled=false | CAL-03b gerçek ölçüm | Tap bias/loopback toplamı hardware/touch correction değildir | S | B | K (kod) |
| CAL-03b | P0 | Pipeline'a özel fiziksel gecikme ölçümü ve ortak gözlenen saat adapter'ı | CAL-03a | Ölçüm kimliği/clock/reset/route değişimi, bağımsız tekrar ve belirsizlik; loopback toplamı dokunma gecikmesi olarak aktarılmaz | Cihaz/ölçüm düzeneği, kullanıcı koordinasyonu | Gecikme bileşenleri ayrı tanımlanamayabilir | M | B | P |
| SESSION-01 | P0 | Tek ses ürün oturumu: referans → bekleme → otomatik cevap penceresi → kalite kapısı → diagnostics/nötr yeniden deneme; puansız | CAL-01 | 15 controller + 2 widget testi: referans bitmeden kayıt yok, cevap analizden önce silinir, oktav korunur, kalite reddinde worker çalışmaz, kesinti/iptal/eski sonuç, route/yaş/rate kalibrasyon kontrolü | Cihazda oturum QA | Oturum yarışları | M | B | K |
| SESSION-02 | P1 | Açılışta yetim geçici kayıt temizliği; hata görünürlüğü | AUD-DEV-02 | 4 birim + 2 widget testi: yalnız `resonia-audio-lab-*`/`resonia-clip-*`, yalnız bilinen dosya adları, symlink izlenmez, beklenmeyen içerik korunur/raporlanır; ayarlarda uyarı | Cihaz kill testi | Yanlış dosya silme | S | B | K |
| VAD-01 | P0 | İnsan sesi etkinliği/çekimserlik modeli (konuşma, öksürük, enstrüman, sızıntı ayrımı) | BENCH-01 | Kişi bazlı holdout: yanlış başarı ve çekimserlik oranları önceden kayıtlı eşiklerle | Etiketli kayıt | Veri azlığı | L | B | P |
| BENCH-01 | P0 | Etiketli izinli kayıt protokolü: doğru/yanlış nota, oktav, sessizlik, gürültü, konuşma, kararsızlık, sızıntı; development/holdout kişi ayrımı | AUD-DEV-01 loader | Manifest/consent/holdout sızıntı kontrolleri (kodda var); ≥100 kayıt | Katılımcılar, eğitimci etiketleme, rıza | Rıza/etiket kalitesi | L (insan) | B | P |
| CORE-01 | P0 | Gerçek tek ses sonucu (nota/oktav/tiz-pes açıklaması, öğrenme/sınav) | SESSION-01, VAD-01, CAL-02 | Holdout kabul eşikleri; yanlış oktav asla başarı | Cihaz + benchmark | Yanlış başarı | M | B | P |
| CORE-02a | P0 | Dinle → tekrar et ritim taklidi: pointer engine timestamp, ilk dokunuş çapası (zamanlaması ölçülmez/puanlanmaz), sentetik klik, dinleme kotası, vuruş zaman çizelgesi, tempo ipucu, `ExerciseResult` | REL-04 | 21 domain/controller/widget/click testi: aynı vuruş sayısı başarı değil; eksik/fazla/erken/geç; geri giden timestamp düşer; referans sırasında dokunuşlar değerlendirilmez | Eğitimci desen/tolerans onayı; fiziksel dokunma örnekleme ölçümü | Dokunma örnekleme gecikmesi | M | B | K |
| CORE-02b | P1 | Eşzamanlı (count-in) ritim: referansla birlikte vuruş | CAL-03 | Ölçülmüş gecikme yoksa mod kapalı; otomatik kaydırma yok | Cihaz gecikmesi | Çıkış gecikmesi | M | Ü | P |
| CORE-05 / HIST-01 | P1 | Yerel sonuç geçmişi, attempt dedup, silme, kaynak ayrımı, cohort içi gelişim | REL-01 | 19 test: katı round-trip (7 mock senaryo + ritim), aynı attempt duplicate/conflict, kapasite, seri yazma, bozuk dosya korunur, ekran boş/bilinmiyor/trend/silme | Export (DATA-03) | Migration | M | B | K |
| INT-01a | P1 | Hareketli do derece duyma (tonik bağlamı, soru başına ton, hece + aralık adı, karışma çifti) | ADR-024, PERC-01 | 12 test: dengeli seçenek, ton değişimi, tam yarım ton, tohumlu, sonuç/round-trip, eksik tur, beceri durumu, etiketler, ton dizisi, seçenek dışı cevap, kalıcılık, seviye kilidi/iptal, ekran + geçmiş, planlayıcı rotası | Eğitimci terminoloji/içerik onayı | Terminoloji karışması | M | B | K |
| DATA-03a | P1 | Yerel ses-siz sürümlü dışa/içe aktarma (pano), strict doğrulama, geçmiş kurallarıyla import | CORE-05 | 7 birim + 4 widget testi | Gerçek cihazlar arası deneme | Bozuk belge | S | B | K |
| DATA-03b | P1 | Toplu yerel sonuç importu: mevcut dedup/conflict/kapasite kurallarını planla, dosyaya tek atomik commit; yazma hatasında görünür prefix yok | DATA-03a, CORE-05 | 2 memory/file batch +1 file failure +1 widget failure; mevcut import sonucu regresyonu | Gerçek cihazlar arası pano denemesi; bulut için DATA-01/02 | Batch'i bulut sync sanma; kapasite sonucu açık kalmalı | S | B | K/D |
| DATA-03c | P1 | Export v2: günlük bütçe + haftalık hedefi strict taşır; v1 uyumlu. Hatırlatma/titreşim cihazda kalır; preference dosyasına atomik uygulanır | DATA-03a/b, SHELL-04a, GROW-01b | 1 codec migration +1 file preservation +1 widget import; full863 | Gerçek iki cihaz pano denemesi | History+preference iki ayrı store; kısmi sonuç açık raporlanmalı | S | B | K/D |
| DATA-03d | P1 | Başarılı taşınabilir tercih importunu çalışan Bugün görünümüne revision ile uygula; sekme/rota durumu korunur, geç kalan eski okuma elenir | DATA-03c, SHELL-04i | 1 callback regresyonu +1 widget revision/sekme testi; full864 | Gerçek cihazda açık rota + import kabulü | Global reset veya eski async read ile yeni tercihi ezme | S | B | K/D |
| LEARN-04a | P1 | Beceri raporu: durum sayıları, bilinmeyen beceriler, tek hedef + eylem; yüzde yok | LEARN-01a, LEARN-03b | 5 birim + 2 widget testi | Eğitimci rapor dili onayı | Yanlış yorum | S | B | K |
| F06a/b | P1 | Hatalı tiz/pes, ritim ve tonik/derece sonucundan ilgili taslak mikroderse isteğe bağlı geçiş; otomatik medya ve ilerleme yazımı yok | LEARN-02a/b, RETRY-01 | 3 uçtan uca widget akışı + 3 ders catalog/codec regresyonu; history/player değişmez | Eğitimci metin/ses onayı + öğretim pilotu | Okumayı öğrenme kanıtı sanma | S | B | K/D |
| RETRY-01c | P1 | Ezgi diagnostic adaylarını referansla sembolik sırada karşılaştır; ilk farklı referans için iki seslik puansız dinleme bağlamı | CORE-03a/b, CORE-04b/c | 2 suggestion +2 widget/route testi ve mevcut session alignment regresyonu; clean/extra-only abstention, no autoplay/score | VAD/insan sesi benchmark'ı, cihaz playback ve eğitimci kabulü | Adayı doğrulanmış hata/hafıza sonucu sanma | S | B | K/D |
| GROW-01c | P1 | Gelişim ekranında rolling-7 çalışma özeti, önceki 7 gün hacim karşılaştırması, egzersiz kırılımı ve geçersiz ölçüm sayısı; başarı yüzdesi yok | CORE-05, GROW-01a | 5 domain + 1 widget; current cohort/rota, stale/future, local calendar sınırları | Kullanıcı rapor dili kabulü | Hacmi öğrenme artışı sanma | S | B | K/D |
| SHELL-04a | P1 | Günlük bütçe tercihinin cihazda saklanması (bozuk → varsayılan) | REL-09 | P0 | Dağıtım kanalı (dev/beta), uygulama adı, release imzalama yapılandırması, iOS gizlilik manifesti, RELEASE_READINESS | SHELL-01 | 3 test + iOS/Android build | Keystore, Apple hesabı, uygulama kimliği kararı | Yanlış imza/ID | S | B | K |
| OPS-01a | P1 | Yerel hata günlüğü (kişisel metin yok), global handler, kopyalanabilir rapor; servis yok | SHELL-01 | 4 test | Servis seçimi (OPS-01) | Eksik görünürlük | S | B | K |
| LEARN-03c | 3 birim + 1 widget testi | — | — | S | B | K |
| LEARN-03c | P1 | Süreli günlük plan 5/12/15 dk: kontrol kuyruğu (1/3/7/14), zayıf tekrar, günlük yeni sınırı, gün içi sabit plan + ilerleme; plan ekranı/home | LEARN-03b | 13 domain + 6 widget testi; bütçe aşılmaz, boş süre açık, kontrol yalnız retention turuyla tamamlanır | Eğitimci süre/aralık onayı, öğrenme pilotu | Yanlış yük/aralık | S | B | K |
| LEARN-03b | P1 | Beceri grafiği tabanlı günlük öneri (rota + tüm ölçülen egzersizler), algı kalıcılık kontrolü | LEARN-01a, PERC-01 | 6 planlayıcı + 1 controller testi; home kartı egzersiz türüne göre doğru ekranı açar | Eğitimci rota/ölçüt onayı | Yanlış sıralama | S | B | K |
| PERC-01 | P1 | Tiz/pes algı turu (8 dengeli sentetik çift, dokunma cevabı, öğrenme geri bildirimi, şans düzeyi), geçmiş + beceri grafiği bağlantısı | LEARN-01a, CORE-05 | 12 test: dengeli/tohumlu/tam cent, sabit cevap = şans, sonuç sözleşmesi/round-trip, eksik tur geçersiz, beceri merdiveni, ton çifti sessizliği, dinlemeden cevap yok, tekrar sayımı, tur ortasında seviye kilidi, iptal kaydetmez, ekran + geçmiş metni | Eğitimci seviye/ölçüt onayı | Algı ≠ üretim karışması | S | B | K |
| LEARN-01a | P1 | Taslak beceri grafiği (önkoşul/rota/ölçüm desteği), kanıta dayalı durum merdiveni, hedefe göre beceri haritası | CORE-05, LEARN-03a | 14 test: tekrar/bilinmeyen/rota-arası önkoşul ve döngü reddi, ölçülen düğüm ↔ egzersiz bağı, sıra, rota filtresi, merdiven geçişleri, kötü sonraki deneme geri düşürür, denenmemiş egzersiz tavanı, farklı sürüm dışlanır, ekran durumları ve kılavuzlar | Eğitimci grafik/ölçüt onayı | Yanlış önkoşul | M | B | K |
| LEARN-03a | P1 | Sonuçtan tek somut sonraki çalışma (kural tabanlı; hedefli tekrar → yeni desen → gecikmeli kontrol) | CORE-05, CORE-02a | 14 test: başla/ölçülemeyen/baskın hata/tek temiz ≠ ustalık/yeni desen/ertesi gün kontrol önceliği/kalıcı/başarısız kontrol/farklı sürüm-kaynak dışlama/mevcut desen önceliği; kalıcılık kontrolünde tek dinleme ve `retentionCheck` işareti; AI yok | Eğitimci eşik onayı, öğrenme pilotu | Yanlış ilerleme önerisi | M | B | K |
| SHELL-02 karar | P0 | **Tamam:** MIT `permission_handler` 12.0.3; mevcut compileSdk36/AGP ve iOS SPM ile build edildi | — | Bağımlılık ve platform build kontrolü geçti | Fiziksel cihaz kabulü açık | Supply-chain sürüm takibi | S | B | K/D |
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

Standalone `dart tool/quality_check.dart`: script konumuna bağlı Resonia root
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

## 2026-10-13 devam — SHELL-04b ortak durum görünümü

ContentStatusPanel loading/empty/error, explicit retry; history/chord consumer.
LocalOnlyNotice history veri politikasıdır, connectivity/sync değil. 6 widget
test; son runner 609 test, 181/0 format, analyze temiz. Büyük-yazı aralık/algı
history testleri yeni notice sonrası kartı scroll ile bulur; assertions aynı.
SHELL-04 session resume/tüm ekran migration hâlâ ayrı; dış kapılar açık.

## 2026-10-14 00:13 TRT — SHELL-04c günlük plan recovery

DailyPlanScreen shared loading/error/empty panel; manual retry retains budget,
no stale plan while waiting, no auto data reset. Rapid load failure observer
immediately attaches before next FutureBuilder frame, returning original future
so error still renders (no fake plan). Mounted reload guard. 3 new widget
tests: failure/budget/retry, pending retry/no duplicate action, dispose/late
response. Planner timing/mastery/score thresholds unchanged. Full SHELL-04
session resume and all-consumer migration/device acceptance remain open.

## 2026-10-14 05:35 TRT — SHELL-04d skill-map recovery

Shared loading/error + manual retry. History unavailable now has a separate
view state (Durum alınamadı), not MasteryState.notMeasured; no report/focus
recommendation until load succeeds. Text drafts remain accessible without
completion/history write. Immediate Future failure observed before next frame;
mounted reload. 4 regressions: unavailable vs empty, explicit retry recovery,
draft navigation, pending/dispose. Mastery/scorer criteria unchanged; full
SHELL-04 session resume/consumer matrix and external acceptance remain open.

## 2026-10-14 10:36 TRT — REL-06a hedef tuning tutarlılığı

TargetNoteTuning strict scientific notation/MIDI0–127 + 12TET frequency; note
label/frequency/A4 guard ExerciseProtocol constructor'ında, JSON reconstruction
da aynı kapıdan geçer. 0.005000001Hz yalnız iki ondalık metadata yuvarlama payı;
öğrenci/acoustic skor toleransı değil. Enharmonic octave carry korunur, yanlış
oktav hedefi kabul edilmez. Legacy Exercise/scorer/fixtures/player değişmedi;
gerçek waveform/etiket/hak/device QA hâlâ açık. REL-06 tüm session/hint/cohort
kapsamı tamamlanmadı. Ayrıntı ADR-025/testing/log'da.

## 2026-10-14 15:39 TRT — REL-06b protokol JSON sınırı

ExerciseProtocol.fromJson exact required root/tuning/event/note fields, schema
integer1, strict enums/numbers/integers/bools. Both event budgets≤256 before
walking first note; unknown/missing/malformed fields safe FormatException.
Semantic constructor failures (tuning/recall aids) existing ArgumentError kalır.
10 new regressions, 636 full suite; schema1 valid output unchanged. Raw text
JSON parsing/duplicate-key canonicalization/IO veya actual content review değil.
Session hint/tuning cohort, reviewed audio ve dış acceptance kapıları açık.

### 2026-10-14 20:42 TRT — REL-06c ritim saat preflight

Playback ve değerlendirme ortak RhythmReferenceClock kullanır. Uç tempo/
overflow, ms çakışması ve mevcut 30 s click-renderer bütçesi dışındaki referans
çekimser reddedilir; negatif/unsafe/backwards dokunma ve dinleme kota ihlali
puan üretmez. İlk tap anchor, eşit tap extra ve rubrik aynı. 10 yeni regresyon;
gerçek ritim cihaz/latency ve eğitimci doğrulaması açık, modül tamamlandı değil.

### 2026-10-15 02:06 TRT — REL-06d öğrenme evidence cohort

ResultCohort sekiz alanı eşler: ID, skill, mode, difficulty, content/scoring
version, source/analyzer. Shared measured catalog + rhythm next-step bağlandı;
skill map/rapor/today/daily planner farklı koşullardaki denemeyi ilerleme saymaz.
Aynı cohort invalid deneme retry için korunur. Sonuç JSON/puan/eşik değişmedi,
geçmiş yeniden yazılmaz. 12 yeni regresyon; protocol/tuning fingerprint, hint
kanıtı ve session binding tamamlanmış değil. Cihaz/EDU/pilot kapıları ayrı.

### 2026-10-15 08:44 TRT — SHELL-04e ana ekran önerisi recovery

Home TodayCard ortak loading/error panel + manual retry. Hızlı Future hatası
sonraki frame öncesi gözlenir ama UI'dan gizlenmez. Pending stale action yok;
exercise dönüşü/dispose ve repository değişimi güvenli. Hata boş geçmişe veya
fake öneriye dönüştürülmez; read-only. 6 widget regresyonu (320px/1.8× dahil).
Session resume ve tüm SHELL-04/device/UXR kabulü tamamlanmış değil.

### 2026-10-15 13:47 TRT — CORE-04c1 seçili ezgi bölümünü hazırlama

DiagnosticMelodyPractice + renderDiagnosticMelodyPractice: orijinal referansta
1–5 ardışık ses, explicit range, 1–3 tekrar; Hz/oktav/sıra korunur. İç sesler
arası200ms, tekrarlar arası1000ms, son tail400ms; bounded max13.8s. Tam ezgi
renderer aynı örnekleri üretir. 8 yeni test; player/capture/UI/score bağlantısı
yok. “Hatalı bölüm” otomatik seçilmez; öğrenci başarısı/öğretim etkisi değil.

**Sıradaki hazır CORE-04c2:** yalnız dinlemeye yönelik seçili bölüm ekranı ve
exclusive player coordinator; play/stop/close/pending-start/background race
fake testleri, büyük yazı ve sentetik/manual açıklaması. Mevcut mikrofon
oturumuyla eşzamanlı kaynak paylaşımı yok; recall/history/mastery bağı yok.
CORE-04 bütünü ve gerçek voice/device/EDU kapıları hâlâ açık.

### 2026-10-15 18:45 TRT — UX-02b ezgi ekranı A+C migration

Birleştirme sonrası CURRENT_ROADMAP yeni önceliğine uyuldu: CORE-04c2
player yerine eski ezgi ekranı LessonScaffold/ChunkyButton/StatusPill'e taşındı.
Kısa ana yönerge + açık sentetik/puansız durum; privacy/kayıt süreleri açılır
yardımda. Diagnostic lesson progress:null, percentage yok, doğal kaydırma;
numeric progress kullanan mevcut dersler aynı. Session callback/kalite/skor
eşikleri değişmedi. 4 yeni widget + mevcut8 ezgi testleri; dış cihaz/UXR açık.
Kalan UI migration listesi CURRENT_ROADMAP'te; CORE-04c2 hâlâ ayrı açık iş.

### 2026-10-15 23:45 TRT — UX-02c mikroders okuyucu migration

LessonScaffold progress:null + StatusPill/ChunkyButton; kısa görünür no-mastery
uyarısı, açılır içerik bilgisi, alt geri dön eylemi. Beş faz ve özgün öğretim
metinleri aynı; practice kapalı, okuma başarı/completion/history değildir.
4 yeni widget + mevcut6 reader testi; close navigation kullanan map recovery
testi yeni lesson_close'a taşındı, durum/veri assertions korunur. Kalan migration
tek listede sürer; gerçek içerik/EDU/cihaz/pilot kapıları geçilmedi.

### 2026-10-16 05:23 TRT — UX-02d piyano placeholder migration

Null-progress A+C lesson shell, kısa kapalı açıklaması + açılır ürün akışı,
2/3/4 kartlarda neutral disabled ChunkyButton. Prerecorded yönü/yer tutucular
korundu; player/mic/scorer açılmaz. Katalog fast error eager observer; manual
retry pending durumda eski hata/düğme gizli; mounted/dispose regression.
5 yeni + mevcut5 hedefli test. Kayıt/hak/nota/cihaz QA ve gerçek chord modülü
açık; kalan UI migration CURRENT_ROADMAP listesinde devam eder.

### 2026-10-16 10:24 TRT — UX-02e veri taşıma migration/reliability

Yerel null-progress lesson shell + ChunkyButton/StatusPill, live status. Onay
dahil busy guard, kilitli input/iki eylem; pano Platform/MissingPlugin hatası
safe retry, eski success yok; load sonrası disposed ise clipboard yazılmaz.
Non-string exportedAt decoder cast yerine safe date format error. Schema1,
onay, conflict/dedup/capacity ve profile semantics aynı. 6 yeni widget+1 codec
regresyonu; gerçek cihazlar arası pano ve kullanıcı/cihaz kabulü hâlâ açık.

### 2026-10-16 16:07 TRT — UX-02f tek ses oturumu migration

Null-progress A+C lesson shell; görünür sentetik/puansız hedef ve phase,
açılır kayıt/4sn/privacy yönergesi. Kalibrasyon→dinle/söyle contextual kontrol,
response finish ve aktif cancel; gerçek InputLevelMeter aynı fazlarda kalır.
Yeni attempt detail expansion sıfırlanır. Controller/quality/scorer kapıları
aynı, verdict/score/history yok. 4 yeni widget; izin ret, close sırasında pending
permission, dark/reduced-motion/büyük yazı ve mevcut akış/meter/a11y doğrulanır.
Gerçek voice/device/BENCH/EDU ve kalan UI migration kapıları açık.

### 2026-10-16 21:07 TRT — UX-02g günlük plan migration

A+C null-progress lesson shell; görünür taslak uyarısı, açılır plan kuralları,
bloklarda StatusPill/ChunkyButton. Budget seçimi/saklama, actual round counts,
free minutes, retention flag, error/retry aynı. Completed blok optional neutral
Bir tur daha; mastery/criteria/plan algorithm değişmez. Yeni4 + mevcut10
plan/recovery testleri, shell navigation lesson_close'a taşındı. Gerçek süre/
interval/öğretim kabulü ve kalan UI migration hâlâ açık.

### 2026-10-17 02:18 TRT — UX-02h çalışma geçmişi migration

A+C StatusPill/DataLabel/kartlar + geri dön; lazy ListView/AppBar korundu.
Açılır karşılaştırma kuralları, yerel uyarı/silme onayı. Çakışmasız cohort'a
skill eklendi; son3 tarihe göre. Eksik/bozuk ölçüm sıfır hata değildir;
desteklenmeyen beceride sayısal trend yok. Rubrik/depo şeması aynı. Yeni6
fake widget, hedefli16/full719, analyze/format temiz. Sıradaki UI: Ayarlar, Ses laboratuvarı, Tek ses sonuç
örnekleri; CORE-04c2 ve gerçek cihaz/voice/eğitimci/yayın kapıları açık.

### 2026-10-17 13:10 TRT — UX-02i ayarlar migration

A+C kartlar/StatusPill/ChunkyButton ve semantic başlıklar; lazy liste/AppBar
korundu. Kısa durumlar + açılır mikrofon/gizlilik rehberi; cleanup uyarısı
gizlenmez. Profil silme kapsamı açık, onay dahil single-flight; hata retry.
Hata raporunda required platform acknowledgement (aynı JSON codec), güvenli
pano hata/retry ve busy/dispose koruması; sanitized format aynı. Yeni7,
hedefli24/full726, analyze/format temiz. Kalan UI: Ses laboratuvarı, Tek ses sonuç örnekleri; ardından
CORE-04c2. Fiziksel pano/cihaz/voice/eğitimci/yayın kapıları hâlâ açık.

### 2026-10-18 19:10 TRT — UX-02j ses laboratuvarı migration

Null-progress A+C lesson shell, görünür sentetik/deneysel/puansız açıklama,
phase'e göre ChunkyButton eylemleri; açılır kayıt/privacy rehberi. Kalite ve
diagnostic ayrı kartlar, metadata DataLabel; mikrofon meter koşulları aynı.
Kalibrasyon mevcut kayıt silme uyarısı her durumda görünür. A11y kontrolü
sonrası record/finish primary tone (shared palette değişmez). Controller,
DSP/quality/route/skorer ve lifecycle aynı. Yeni5 + mevcut12 hedefli17/full731
geçti; analyze temiz7.8sn, format203/0, diff check temiz.
Kalan UI Tek ses sonuç örnekleri; ardından CORE-04c2. Fiziksel voice/cihaz/
eğitimci/yayın kapıları hâlâ açık.

### 2026-10-18 19:13 TRT — UX-02k tek ses sonuç örnekleri migration

A+C null-progress shell, görünür simülasyon/mikrofon kapalı/kişisel puan
değil; örnek hedef ve açılır yardım. Neutral ChunkyButton; geri bildirim
tema token'larında (invalid nötr, octave başarı değil). Single-flight, stale
result reset, safe error/retry/dispose; skorer/depo/gerçek oturum değişmez.
Yeni5 + mevcut19 hedefli24, tüm senaryolar dark/reduced-motion320px1.8× ve
iki tema a11y. Son runner exit0 full736 (+5), analyze temiz4.3sn, format203/0,
diff check temiz. Listelenen migration ekranları tamam; sıradaki CORE-04c2.
Diğer UX backlog'u ve gerçek cihaz/voice/eğitimci/yayın kapıları açık.

### 2026-10-19 10:12 TRT — CORE-04c2a exclusive rehearsal player

DiagnosticMelodyPracticePlayer + MelodyPracticePlayback: tek reference bound,
noauto/single-flight, native mutation queue, stop/close epoch/wake, stale
handle error observer ve cleanup fail-closed. SyntheticMelodyPracticePlayer
exact c1 WAV'ını ayrı ReferenceClipPlayer'da oynatır; capture API'si/depo/skor
bağı yok. Yeni12 + mevcut26 hedefli38/full748, runner exit0, analyze temiz11.3sn,
format205/0 ve diff check temiz. UI bağlı değil; CORE-04c2 bütünü açık.
Sıradaki c2b: explicit bölüm/1–3 tekrar seçimi, ayrı owned player ekranı;
parent mikrofon oturumu idle/kapalı olmadan route açılmaz, playback/capture
resource paylaşılmaz. Background/close/focus handler, pending start exit ve
dar ekran/sentetik/manual açıklaması widget testli bağlanmalı. Dinleme
tamamlandı sayacı öğretim/recall/history/mastery kanıtına dönüştürülmez.

### 2026-10-19 15:15 TRT — CORE-04c2b rehearsal screen/navigation

MelodyPracticeScreen explicit contiguous range/1–3 repeats, no mic/auto play/
score/history; A+C null-progress, original Hz/manual synthetic notice. Parent
canStart + handoff guard; await session.close before fresh player factory,
pushReplacement removes capture route. Child PopScope awaits close before
system/lesson back; failed cleanup locks route and requests app restart.
Lifecycle + mobile AudioSession interruption/noisy/device handlers stop, no
auto-resume; monitoring failure disables play. Yeni11 + mevcut17 hedefli28,
dark/reduced-motion/büyük yazı ve iki tema a11y. Son runner exit0 full759 (+11),
analyze temiz3.6sn, format207/0, diff check temiz. c2 kod bağlantısı hazır;
gerçek focus/playback/route/device/EDU kabulü açık. Sıradaki bağımlılığı hazır
iş CURRENT_ROADMAP onboarding 5/12/15 süre seçimi.

### 2026-10-20 — ONB-01 guest duration step

Goal draft→5/12/15 budget→home; save before profile, skip preserves existing/
default budget. Busy/back/dispose, partial-write message/retry/no redundant
budget save. Settings goal-only/returning profile/schema1 contracts unchanged.
Selected AnswerOption opaque theme fill fixes contrast. Yeni9 + mevcut18
shell/a11y; full768, analyze temiz3.7sn, format209/0, diff check temiz.
Sıradaki kod işi ana sayfa yükleme iskeleti; süre bir eğitim başarısı ölçüsü
değil. Gerçek kullanıcı/cihaz/voice/EDU/yayın kapıları açık.

### 2026-10-20 — HOME-01 static loading/current-evidence guard

Durağan home skeleton, tek semantic announcement, theme tokens; no progress/
measurement/action fabrication. FutureBuilder retained data only done/no-error:
refresh/replacement pending/error hides stale streak/path/recommendation.
Explicit safe retry retained; repositories/planner/scoring unchanged. Yeni4,
targeted15 passed; full772, analyze temiz5.2sn, format209/0, diff check temiz.
Sonraki hazır kod işi tur sonu cevap karşılaştırması ve tekrar dinleme.
Gerçek device/VoiceOver/BENCH/EDU/yayın kabulü değildir.

### 2026-10-20 — REVIEW-01a perception answer breakdown

Interval/high-low summaries show eight optional read-only comparison cards:
known synthetic reference / selected touch answer / correct answer, explicit
correct/different/unanswered text. Wide side-by-side, narrow/large-text stacked;
no playback, writes, new scoring or persistence. Empty-bottom LessonScaffold
uses natural scrolling to avoid intrinsic overflow on disclosure. Yeni5 +
extended2 screen tests targeted7; full777, analyze temiz3.5sn, format211/0,
diff check temiz. REVIEW-01b audio replay remains open: serialize load/stop/close,
preserve completed outcome and retention evidence, explicit controls, lifecycle
and failure tests before enablement. Real device/VoiceOver/EDU gates open.

### 2026-10-20 — GROW-01a and commercial gap reconciliation

Simply ecosystem, Yousician and Duolingo Music desk research with dated
financial scope/source caveats; see COMMERCIAL_BENCHMARK_2026-10.md. Feature
revenue ranking unknown. Existing F02/F05/F09/F12/F15/F16/F17/F19/F21 expanded,
not duplicated. F27 habit/optional goal and F28 family-account plan added.
GROW-01a implemented local rolling7 calendar-day activity, one valid supported
cohort result/day; low score counts, mock/invalid/unknown/future excluded.
No mastery/streak/scorer/planner change, no store/permission/backend. New4 data
+2 theme widgets; full783, analyze clean12.8s, format213/0, diff check clean.
Next audio priority remains REVIEW-01b. Then GROW-01b voluntary target/reminder
with permission/plugin/device gates; F28/social after DATA/PAY/privacy pilots.
Safety and real-audio acceptance are not displaced by monetization features.

### 2026-10-20 — REVIEW-01b comparative result playback

Interval/high-low result cards now expose explicit, optional playback; there
is no autoplay. Shared ReviewPlaybackCoordinator serializes stop→load→play,
invalidates stale pending starts, makes the latest request win and supports
an explicit stop. Interval can compare reference with the selected touch
answer; high/low replays its reference pair. Review uses immutable finished
items and never changes outcome, plays/retention counters, score or history.
Background stops review but preserves the finished result. PopScope waits for
review/player close before route release; close failure stays on-screen with
recovery copy. apple-design agency/readability guidance informed the controls.

New4 coordinator +2 route-gate tests; controller and two screen flows extended.
Targeted24 passed; full791 (+8), analyze clean3.2s, format216/0, diff clean.
Fakes and synthetic WAV only: no physical speaker/audio-focus/screen-reader or
educator acceptance. REVIEW-01 code scope is complete; external gates remain.
Next dependency-ready item is GROW-01b local voluntary weekly goal. Notification
permission/plugin/device work remains a separate gate; no live service enabled.

### 2026-10-20 — GROW-01b voluntary rolling-seven-day goal

RecentPracticeCard now offers an optional local goal: none or 2/3/4/5 active
days in the same rolling seven-day evidence window. Progress reuses GROW-01a's
valid/current-cohort days, so wrong attempts count as practice while demo,
invalid, future and unsupported evidence stays excluded. Copy explicitly says
this is not mastery, an exam score or a punitive streak. Users can change or
disable it at any time; no reward, paywall, shame or automatic notification.

Practice preferences schema v2 stores daily budget and nullable weekly goal.
Strict v1 daily-budget migration is retained; serialized read-modify-write
prevents concurrent independent saves from losing either field. Pending saves
are single-flight and a failure preserves the prior visible/stored goal. New2
storage +2 widget tests; targeted24 and full795 (+4), analyze clean2.9s,
format217/0, diff clean. Local/fake evidence only. Notification permission,
native scheduling/plugin and physical-device QA remain open and were not added.

### 2026-10-20 — RETRY-01a exact-mistake guided rounds

Pitch high/low and movable-do interval summaries now offer a user-initiated
short round containing only the exact missed items from the completed round.
The same frequencies/tonics and normal immediate feedback are reused; no item
is invented or generalized. UI marks the round as “Tekrar”, explains that it
is practice-only and omits the normal full-round criterion. A fresh full round
remains separately available.

Guided rounds disable retention mode and never call history. Domain rounds carry
an explicit guided flag and `toResult` throws, so a future caller cannot silently
turn the practice loop into mastery/exam evidence. Two controller tests cover
exact subset/order, completion, no second history entry and fail-closed result;
both 320px/1.8× screen flows cover the action/label, and pitch completes the
loop with no threshold/history mutation. Targeted15; full797 (+2), analyze and
format clean, diff clean. Synthetic/fake only; educator/device acceptance open.

### 2026-10-20 — RETRY-01b rhythm error-segment repetition

Measured rhythm timelines now derive one deterministic excerpt around the first
early/late/missed/extra event. The excerpt reuses adjacent source onsets,
rebases only its local clock and is started explicitly from the result. It is
visibly marked as guided and unscored; controller skips history/next-step and
domain conversion to `ExerciseResult` throws. New2 domain +1 controller tests;
the existing 320px/1.8× screen flow covers entry/layout. Full800, analyze clean,
format217/0. Melody segmentation remains open; device/educator gates unchanged.

### 2026-10-20 — REM-01a reminder boundary and local migration

Added a validated daily reminder time, independent local persistence and exact
v1/v2→v3 migration. `PracticeReminderCoordinator` requests permission only on
explicit enable, serializes updates, changes the saved preference only after
native schedule/cancel succeeds and attempts rollback if storage fails. The
production adapter is deliberately unavailable: no plugin, alarm or permission
prompt is claimed. New7 coordinator +1 storage test; full808, analyze clean,
format219/0. Next gate is native adapter/product copy/settings UI/device QA.

### 2026-10-21 — REM-01b reminder settings shell

Settings now hosts a future-ready reminder card with explicit time selection,
enable/change/disable, permission-denied and pending/failure copy. It calls the
REM-01a coordinator only after user action. The shipping unavailable adapter
shows a disabled honest state with no permission prompt or fake alarm. Injected
adapter tests cover enable/disable/denied plus dark 320px/1.8× layout. New4;
full812, analyze clean, format221/0. Native plugin and device delivery remain.

### 2026-10-21 — HAPTIC-01 persisted haptic preference

Settings now exposes a default-on haptic feedback switch backed by preferences
schema4 and exact v3 migration. A shared inherited notifier gates every current
direct `HapticFeedback` path; persistence completes before the app-wide value is
published, and failure retains the previous state. Platform-channel tests prove
that disabled suppresses the vibration request and enabled restores it. New3;
full815, analyze clean, format222/0. Physical-device vibration and native
reminder delivery remain separate gates.

### 2026-10-21 — REM-01c native local-notification adapter

The app now ships a Flutter local-notification adapter for Android/iOS with
device IANA timezone lookup, daily wall-clock matching, inexact Android alarms
that require no exact-alarm permission, reboot rescheduling receivers and an
iOS notification delegate. Initialization never prompts; permission is
requested only after the existing explicit settings action. Denial exposes a
direct OS notification-settings recovery action. Driver tests cover unknown →
denied, initialization failure, schedule/cancel/settings delegation and
next-day wall-clock preservation. Full820, analyze clean, format224/0; Android
debug APK and iOS simulator debug builds pass. Physical permission/delivery,
reboot/DST/OEM behavior remain device gates.

### 2026-10-21 — SHELL-02 microphone permission recovery

After a real microphone denial, single-tone, melody and audio-lab screens now
show one explicit app-settings action. Entry never requests permission or opens
settings. The shared boundary serializes launches and reports false/exception
results without claiming recovery. `permission_handler`12.0.3 is pinned because
13.x requires compileSdk37 beyond the current AGP9.0.1 recommendation; Android
debug and iOS simulator builds pass. New4 tests; full824, analysis clean,
format228/0. Physical permanent-denial and settings-return behavior remain D.

### 2026-10-22 — SHELL-03a honest starting check

Today exposes an optional three-round starting check using only existing
touch-proven pitch direction, steady pulse and movable-do exercises. The model
reloads local history after each round, retries invalid evidence before moving
on and suggests the first valid weak area after completion. It counts every
engine/content/educator-gated route skill as unknown and never emits an
aggregate level, admissions score or readiness claim. New4 domain +4 widget/
integration tests; full832, analysis clean, format233/0. Educator-defined level
bands and learner acceptance remain SHELL-03b external gates.

### 2026-10-22 — SHELL-04f safe local continuation

The latest completed result matching a supported current exercise cohort now
offers a fresh round from Today. Invalid current evidence is retryable; future,
retired-content and unknown-analyzer evidence fail closed. This is deliberately
not mid-question/media-session persistence: no player, audio or microphone is
restored or auto-started. New4 domain +2 integration tests; full838, analysis
clean, format236/0. The remaining SHELL-04 offline/consumer and real-device
acceptance matrix stays open.

### 2026-10-30 — IA-01b Personal dil ve iddia tutarlılığı

ADR-035'in Personal ana kimliği kalan öğrenci metinlerine uygulandı. Ders
müfredatı koro üyeliği veya parti seçimi varsaymaz; SATB seçimi, uygulamanın
ölçmediği bir “ses tipi” iddiası yerine yalnız çalışma aralığı olarak görünür.
İlerleme unvanları rol bağımsızdır ve gelecekteki çok ses içeriği piyano
kayıtları olarak adlandırılır. Domain regresyonu Personal ders metninde
`koro/parti` varsayımını; widget regresyonu İlerleme/Ayarlar dilini korur.
Full1041 + 1 koşullu skip, analyze/format temiz. Eğitimci içerik kabulü,
gerçek ses sınıflandırması ve cihaz QA kapsam dışıdır.

### 2026-10-30 — AUDIO-01 referans motor fixture sözleşmesi

Manifest/hash/header/sample-clock kapısından geçen sentetik PCM16 fixture,
hedef bağımsız pitch frame çekirdeğine bağlandı. Kısa buffer açıkça yetersiz
kalır; aynı pitch class'ın C4/C5 örnekleri mutlak oktavı korur ve hedefe
katlanmaz. İki entegrasyon regresyonu; full1043 + 1 koşullu skip,
analyze/format temiz. Bu kod kapısı BENCH-01 insan holdout'u, VAD-01 veya
CAL-02 fiziksel cihaz kabulünün yerine geçmez.
