# Harmonia — Ayrıntılı uygulama ve yayın roadmap'i

**Başlangıç/güncelleme:** 2026-10-11  
**Ürün yönü:** Aurora marka deneyimi + Konservatuvar açıklayıcı sonuçları; ortak temel, konservatuvar ve koro rotaları; Plus'ta gerçek eğitimci yorumu.  
**Durum:** Güvenilirlik/sözleşme, fixture loader, yerel kayıt laboratuvarı ve deneysel frame DSP çekirdeği uygulandı. Canlı kayıt–DSP bağlantısı, fiziksel mikrofon QA, gerçek ses benchmark, müfredat, backend, AI, abonelik ve insan hizmeti henüz doğrulanmış/canlı değil.

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
| REL-08 | Tekrarlanabilir kalite komutları / CI taslağı | Format, test, analyze; secret olmadan yerel çalışma; CI etkinleştirme ayrı | Bekliyor |

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
