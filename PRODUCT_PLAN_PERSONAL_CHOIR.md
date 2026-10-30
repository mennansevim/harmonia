# Resonia — Personal + Choir geliştirme planı

**Tarih:** 2026-10-30 · **Girdi:** kullanıcının yapıştırdığı dış LLM önerisi
(Resonia Personal / Resonia Choir ayrımı, koro başına abonelik, 3 fazlı koro
planı) ve kullanıcı kararı: *“koro modülü ayrı; ses, nefes eğitimi vs. tüm
kullanıcılar için olacak.”*
**Yöntem:** Öneri güncel kodla (`lib/trainer/`, `lib/trainer/koro/`,
`lib/trainer/prepare/`), [ARCHITECTURE](./ARCHITECTURE.md) `choir_practice`
kuralları, [PRODUCT_ROADMAP_90D](./PRODUCT_ROADMAP_90D.md),
[HUMAN_REVIEW](./HUMAN_REVIEW.md) ve
[IMPLEMENTATION_ROADMAP](./IMPLEMENTATION_ROADMAP.md) CHOIR-01–05 ile
karşılaştırıldı.

Bu belge plandır; kod değişikliği değildir. Fiyat ve müşteri sayıları hipotezdir,
gelir garantisi yoktur. 90 günlük plan Personal için geçerliliğini korur; bu
belge onu Choir koluyla genişletir.

---

## 1. Kısa hüküm

**Yön doğru, ama Choir Faz 1 sanıldığı kadar “küçük” değil.** Bugün repoda
sunucu, hesap, davet, dosya yükleme ve web paneli yok; Faz 1'in tamamı bunlara
dayanır. Buna karşılık değer önerisi (WhatsApp ses kayıtları yerine tek panel)
AI veya ölçüm gerektirmez — ses motorunun açık kapılarını (BENCH/VAD, cihaz)
beklemeden satılabilir.

| Konu | Karar / öneri |
|---|---|
| Ürün yapısı | Tek uygulama, tek hesap. **Personal** herkes için ana kimlik; **Choir** ayrı, davetle açılan modül. Şef için web paneli. |
| Ses, nefes, kulak, ritim | Personal'a aittir, korist olsun olmasın herkes kullanır. Koro onboarding'i ana akış olmaktan çıkar (ADR-035 taslağı, §8). |
| Choir ilk sürümü | Koro → davet → parti → referans ses → ödev → kayıt gönder → şef dinler, yazılı geri bildirim. MIDI ve otomatik değerlendirme yok. |
| MIDI eşlikli çalışma | Choir Faz 2. Kulaklık zorunlu (ARCHITECTURE `choir_practice`). |
| Otomatik değerlendirme | Choir Faz 3; BENCH-01/VAD-01 ve CHOIR-01 bleed testi geçmeden puan yok. |
| Sıralama | Personal'ın günlük değeri önce (90D Faz 1–2), Choir Faz 1 paralel *keşif + domain* ile başlar, sunucu işi kullanıcı kararlarından sonra. |

## 2. Önerideki iddialar — repo ile karşılaştırma

| İddia | Repo gerçeği | Sonuç |
|---|---|---|
| “Mevcut `choir_practice` yaklaşımı iyi bir başlangıç” | `choir_practice` yalnız `ExerciseMode` değeri ve ARCHITECTURE'da route/bleed kuralı. Oynatıcı, mixer, parti track'i, MIDI okuyucu yok | **Kısmen.** Kurallar hazır, kod yok |
| Koristler partilerini çalışır | `VoicePart` (SATB register) ve ses aralığı testi var; parti yalnız ders sesinin oktavını taşır | Personal tarafında temel var; eser/parti dosyası yok |
| Şef kayıtları dinler | Kayıt yalnız cihazda (lab/tek ses), analizden sonra silinir; upload/sunucu yok | Sıfırdan |
| Nefes eğitimi yeni geliştirilecek | PREP-01 `BreathScreen` var: görsel/haptik, mikrofonsuz, ölçümsüz | Var (taslak, eğitimci onayı yok) |
| 999 TL × koro = brüt gelir | KDV ve kanal kesintisi yok | Düzeltildi, §6 |
| Faz 1 AI'sız satılabilir | Doğru; ölçüm motoruna bağlı değil | Kabul |

## 3. Ürün yapısı

```
Resonia (tek uygulama, tek hesap)
├── Personal — herkes
│   Bugün rotası · Nefes (Hazırla) · Kulak (nota/aralık/akor/dizi)
│   Ritim · Ezgi · Ses aralığı · İlerleme · Free / Pro
└── Koro — yalnız bir koroya katılınca görünür
    Korolarım · Ödevler · Parti çalışması · Kayıt gönder · Geri bildirim
Şef web paneli (ayrı giriş noktası, aynı hesap)
    Koro · Üyeler/partiler · Kaynak dosyalar · Ödevler · Dinleme kuyruğu · Takip
```

- Koro sekmesi bugünkü haliyle (Koro Atölyesi: ses aralığı, aksak ritim,
  kaç ses) **Personal'ın “Ses” bölümüne** taşınır; “Koro” adı davetli koro
  modülüne bırakılır. Böylece koro üyesi olmayan kullanıcı “koro
  uygulaması” görmez.
- Onboarding: rol sorusu “Kendim çalışacağım / Bir koroya üyeyim / Koro
  şefiyim” olur; parti seçimi yalnız ses aralığı için kullanılır ve
  atlanabilir.
- Köprü (asıl farklılaşma): korist ödevinde şefin işaretlediği zorluk
  (ör. “aralık atlaması”, “giriş zamanı”) Personal'da ilgili beceriyi önerir.
  Faz 1'de bu **şefin etiketi** ile çalışır, otomatik tespit değil.

## 4. Kullanıcı kararları (Faz 0)

Bunlar kilitlenmeden sunucu kodu yazılmaz (AGENTS: kullanıcı kaydı upload,
ücretli servis, deployment ayrı yetki).

| # | Karar | Neden önemli | Öneri |
|---|---|---|---|
| K1 | Şefin bugünkü yöntemi (WhatsApp'tan MIDI mi, MP3 mü, nota PDF'i mi; kayıtlar nasıl toplanıyor?) | İlk sürümün çözeceği asıl sorunu belirler | 3–5 şefle 30 dk görüşme; senin korondan başla |
| K2 | Backend | Hesap, davet, dosya, yetki | Supabase (Postgres + Auth + Storage, AB bölgesi) veya Firebase; tek ADR |
| K3 | Şef paneli teknolojisi | Kod tekrarı | Aynı repodan **Flutter web** (domain/model paylaşılır) |
| K4 | Reşit olmayan koristler | KVKK, veli onayı, ses kaydı | İlk pilot yalnız yetişkin koro; çocuk korosu ayrı hukuk kapısı |
| K5 | Koro ödemesi kanalı | Mağaza komisyonu ve kuralları | Web panelinden kurumsal abonelik; iOS'ta korist erişimi ücretsiz (Apple 3.1.3 kurumsal hizmet maddesi hukuken doğrulanmalı) |
| K6 | Pilot koro | Gerçek kabul | Senin koron, ücretsiz 4–6 hafta |

## 5. Yol haritası

**K** kod · **Ka** kullanıcı kararı · **D** dış iş (insan, cihaz, hesap, hukuk).
Personal kolu [PRODUCT_ROADMAP_90D](./PRODUCT_ROADMAP_90D.md) fazlarını izler;
burada yalnız değişen/eklenen işler var.

### Kol P — Personal (herkes için)

| ID | İş | Tür | Kabul / sınır |
|---|---|---|---|
| IA-01 ✅ 2026-10-30 | Bilgi mimarisi: Koro Atölyesi → “Ses” bölümü; Koro sekmesi koro üyeliği yoksa gizli | K | Mevcut testler yeni sekme düzeniyle güncellenir; ses aralığı/aksak ritim/kaç ses kaybolmaz |
| ONB-03 ✅ 2026-10-30 | Rol sorusu (bireysel / korist / şef), parti atlanabilir | K | Eski `trainer_store` kayıtları migration ile korunur |
| PREP-02 | Nefes rotası herkes için: 3 egzersiz çeşidi, süre seçimi | K (metin D) | Ölçüm yok; seri/mastery'ye yazmaz (PREP-01 sınırları) |
| — | 90D Faz 1–3 (RETRY-02 ertesi gün kontrolü, BETA-01, PAY-01–04 Free/Pro) | K/D | 90D'deki kapılar |

### Kol C — Choir

#### C0 — Keşif ve temel (Kasım, 1–2 hafta)

| ID | İş | Tür | Çıkış |
|---|---|---|---|
| CHOIR-D0 | Şef görüşmeleri (K1), mevcut iş akışı haritası, “bir ödevde kaç kayıt dinleyebilirsin” sorusu | D | Görüşme notu; ilk sürüm kapsamı onaylı |
| CHOIR-ADR | Backend, web paneli, veri bölgesi, saklama süresi, silme | Ka | ADR-036 |
| CHOIR-M1 ✅ 2026-10-30 | Saf Dart domain: `Choir`, `ChoirMember` (rol + `VoicePart`), `Invite`, `ReferenceAsset` (kaynak/hak beyanı), `Assignment` (parti hedefi, son tarih), `Submission` (durum makinesi: taslak → gönderildi → dinlendi → geri bildirildi / tekrar istendi), `Feedback` (yazılı + hazır etiketler) | K | Backend'den bağımsız, JSON round-trip ve durum geçişleri testli; sunucu olmadan yazılabilir |

> **2026-10-30 güncellemesi (ADR-036):** Sunucu beklemeden cihazda çalışan sürüm yapıldı (CHOIR-A0): ödev, çoklu eser, MIDI çalışma, tek telefonda eşlikli kayıt, şef dinleme/işaret/sesli not, kaynaklar; aktarım `.resonia` paketleriyle. Aşağıdaki sunucu, davet linki ve web paneli işleri K2 kararını bekliyor. MIDI-02–05'in kod kısmı bu sürümde var, gerçek koro MIDI'siyle doğrulanmadı.

#### C1 — Koro ve ödev yönetimi (Aralık–Ocak, ~6 hafta, ilk pilot)

| ID | İş | Tür | Kabul / sınır |
|---|---|---|---|
| CHOIR-B1 | Hesap + koro verisi + satır düzeyi yetki (şef yalnız kendi korosunu, korist yalnız kendi kaydını görür) | K (hesap açma Ka) | Yetki kuralları testli; canlı ortam ayrı yetki |
| CHOIR-B2 | Davet: link/kod, süreli, tek kullanımlık veya koro kodu | K | Süresi geçmiş/iptal davet reddedilir |
| CHOIR-W1 | Şef paneli: koro oluştur, üye listesi, parti ata, referans yükle (MP3/WAV/M4A, parti başına) | K | Dosya türü/boyut sınırı; hak beyanı kutusu |
| CHOIR-W2 | Ödev: eser + parti(ler) + ölçü/zaman aralığı notu + son tarih | K | Parti bazlı atama |
| CHOIR-A1 | Korist uygulaması: Korolarım, ödev listesi, referansı dinle (döngü, A–B tekrar) | K | `just_audio`; çevrimdışı önbellek |
| CHOIR-A2 | Kayıt + kendini dinle + gönder | K | Açık rıza ekranı; kayıt **puanlanmaz**; yükleme yeniden denenebilir; gönderilmeden silinebilir |
| CHOIR-W3 | Dinleme kuyruğu: parti bazlı sırayla çal, tek tuşla “tamam / tekrar çalış / not yaz”, hazır etiketler | K | Şefin dinleme süresi ölçülür (yerel olay, içerik değil) |
| CHOIR-W4 | Takip tablosu: üye × ödev durumu, parti özetleri | K | Teslim yok ≠ başarısız; durum metni nötr |
| CHOIR-N1 | Bildirim: önce uygulama içi + e-posta; push sonra | K | Push için APNs/FCM ayrı karar |
| LEGAL-C1 | Aydınlatma metni, ses kaydı rızası, saklama/silme, şefin veri sorumluluğu | D | Pilot öncesi zorunlu |

**Şef iş yükü (pilotta ölçülecek):** 30 korist × ~1,5 dk kayıt ≈ 45 dk saf
dinleme / ödev. Tasarım bunu azaltmalı: kayıt süresi sınırı, parti bazlı
ardışık çalma, 1,25× hız, “örneklem dinle” (her partiden birkaç kişi), hazır
etiketler. Pilotta haftalık dinleme dakikası ve “dinlenmeden kalan kayıt” oranı
izlenir.

**C1 çıkış kapısı (D):** 1 gerçek koro 4 hafta kullandı; teslim oranı,
şefin dinleme süresi, “WhatsApp'a göre daha iyi mi” anketi; gerçek iPhone +
Android'de kayıt/yükleme; hukuk metinleri yayında.

#### C2 — MIDI ile parti çalışması (Şubat–Mart, ~6 hafta)

| ID | İş | Tür | Kabul / sınır |
|---|---|---|---|
| MIDI-01 ✅ 2026-10-30 | Saf Dart SMF (tip 0/1) okuyucu: track/kanal, tempo haritası, ölçü işareti, nota olayları | K | Bozuk/çok büyük dosya güvenli reddedilir; fixture testleri |
| MIDI-02 | Parti eşleme: şef track/kanalı S/A/T/B'ye atar (otomatik tahmin yalnız öneri) | K | Yanlış eşleme şef düzeltir |
| MIDI-03 | Seslendirme: önce mevcut additive sentez; SoundFont yalnız lisansı net bir SF2 ile (ADR) | K/Ka | Lisansı belirsiz ses dağıtılmaz |
| MIDI-04 | Mixer: kendi parti öne, diğerleri kıs/sustur, solo, metronom | K | Tek saatli render (piyano mix altyapısındaki yaklaşım) |
| MIDI-05 | Ölçü döngüsü, tempo %50–120 (MIDI'de kayıpsız), count-in | K | MP3 referansta tempo değişimi bu fazda yok (time-stretch ayrı spike) |
| CHOIR-01 | Eşlik üstüne kayıt spike'ı: kulaklık zorunlu, bleed ve gecikme ölçümü | K + D | Hoparlörde rehberli kayıt kapalı (ARCHITECTURE kuralı) |
| CAL-03b | Gerçek gecikme ölçümü ve kayıt hizalama | K + D | Ölçülmeden zamanlama yorumu yok |

**C2 çıkış:** pilot korosunda MIDI'li ödev; gerçek cihazda kulaklık + Bluetooth
gecikme turu; şef “parti dengesi doğru” onayı.

#### C3 — Akıllı değerlendirme (Nisan+, kapılara bağlı)

| ID | İş | Önkoşul |
|---|---|---|
| CHOIR-E1 | Kendi partisi hedef olaylarıyla nota/ritim karşılaştırması (tanısal, kaynak etiketli) | BENCH-01, VAD-01, CHOIR-01 |
| CHOIR-E2 | Zorlanılan ölçü ısı haritası — şef için | E1 + insan holdout |
| BRIDGE-02 | Ödevdeki zorluktan Personal egzersiz önerisi (otomatik) | E1; Faz 1'de şef etiketiyle (BRIDGE-01) zaten var |

Yanlış oktav başarı sayılmaz; bleed/hoparlör kaydı puanlanmaz; şef her
otomatik bulguyu geçersiz kılabilir.

## 6. Ticari model — düzeltilmiş hesap

Önerideki tablo KDV dahil brütü gelir sayıyor. 999 TL/ay koro paketi
(KDV dahil varsayımı):

| Kalem | Web/kurumsal satış | Mağaza içi satış |
|---|---:|---:|
| Fiyat | 999 TL | 999 TL |
| KDV %20 hariç | 832 TL | 832 TL |
| Ödeme kesintisi (≈%3 / %15) | −25 TL | −125 TL |
| Depolama + bant (aşağıdaki tahmin) | ≈ −10 TL | ≈ −10 TL |
| **Koro başı aylık katkı** | **≈ 797 TL** | **≈ 697 TL** |
| 50 koro | ≈ 39.900 TL | ≈ 34.900 TL |
| 100 koro | ≈ 79.700 TL | ≈ 69.700 TL |

Depolama tahmini: 40 korist × 4 ödev × 2 dk × AAC 64 kbps ≈ 155 MB/ay/koro +
referans dosyaları; dinleme bant genişliği benzer. Destek, gelir vergisi,
edinim maliyeti dahil değil. Oranlar vergi danışmanı ve mağaza kurallarıyla
doğrulanmalı.

Paketleme önerisi (hipotez):

- Şef paneli ücretli, koristin ödev deneyimi koro paketine dahil.
- Kademe üye sayısıyla (ör. ≤25 / ≤50 / ≤80); tek fiyat ilk pilotta.
- Korist isterse Personal Pro'ya kendi geçer; koro paketi Pro'yu açmaz.
- İlk pilot ücretsiz; fiyat pilot sonrası şef görüşmeleriyle (ödeme isteği
  sorusu) belirlenir. Sahte indirim/kontenjan baskısı yok.

Büyüme: Choir, Personal için dağıtım kanalıdır (şef davetiyle gelen korist
Personal'ı keşfeder). Ölçülecek: davetle gelen koristlerin Personal'da 7 gün
içinde en az bir ders yapma oranı.

## 7. Takvim özeti

| Hafta | Personal | Choir |
|---|---|---|
| Kas 2 – Kas 16 | IA-01, ONB-03, RETRY-02, BETA-01 | CHOIR-D0 görüşmeler, CHOIR-ADR, CHOIR-M1 |
| Kas 16 – Ara 14 | 90D Faz 1 çıkış kapısı (gerçek cihaz) | CHOIR-B1/B2, W1/W2, A1/A2 |
| Ara 14 – Oca 25 | Kapalı beta, EDU-01, PREP-02 | W3/W4, N1, LEGAL-C1, **pilot koro** |
| Şub – Mar | PAY-01–04 Free/Pro | MIDI-01–05, CHOIR-01, CAL-03b |
| Nis+ | Ücretli erken erişim | Koro fiyatı; C3 yalnız kapılar kapanınca |

Kod işleri (K) tek geliştiriciyle bu takvime sığmayabilir; D işleri (şef,
hukuk, cihaz) takvimi belirler.

## 8. Mimari notlar

- **ADR-035 (taslak, bu plana bağlı):** Personal ana kimlik; Koro davetli ayrı
  modül; nefes/ses/kulak herkes için. ADR-033'ün “koro öncelikli” sekme ve
  onboarding kararını kısmen yerine geçer.
- Kod düzeni: `lib/choir/domain` (saf Dart, test önce), `lib/choir/data`
  (backend adapter arayüzü + bellek içi sahte), `lib/choir/app` (korist
  ekranları), `web/` veya ayrı `lib/choir_panel/` (Flutter web). Personal
  `lib/trainer/` olarak kalır.
- Backend bağımlılığı arayüz arkasında: domain ve korist ekranları bellek içi
  adapter ile testli; sahte veri gerçek koro verisi gibi sunulmaz.
- Kayıt: cihazda AAC/M4A sıkıştır, yükleme sonrası yerel kopya silinir;
  sunucuda saklama süresi koro ayarı (öneri 90 gün), korist silebilir.
- Mevcut `choir_practice`, `VoicePart`, tek saatli piyano mix, kalite kapısı
  ve kalibrasyon C2'de yeniden kullanılır.

## 9. Hemen başlanabilecek işler (kullanıcı kararı gerektirmeyen)

1. ✅ **IA-01 + ONB-03** — Personal'ı herkes için ana kimlik yapan sekme ve
   onboarding değişikliği.
2. ✅ **CHOIR-M1** — `lib/choir/domain/` (koro, üye, davet, referans + hak
   beyanı, ödev, teslim durum makinesi, geri bildirim etiketleri, parti
   takibi), 16 test.
3. ✅ **MIDI-01** — `lib/choir/midi/smf_reader.dart` (tip 0/1, tempo
   haritası, ölçü başları, sınırlı güvensiz girdi), 10 test.

Kararsız yapılabilecek kod işleri bitti. Sıradakiler kullanıcı kararı veya
dış iş ister: şef görüşmeleri (K1), backend ADR'si (K2/CHOIR-ADR), web
paneli (K3), reşit olmayan koristler (K4), ödeme kanalı (K5), pilot koro
(K6). MIDI-02–05 (parti eşleme, seslendirme, mixer, döngü/tempo) kod olarak
yazılabilir ama gerçek bir koro MIDI'si ve SF2 lisans kararı (MIDI-03)
olmadan doğrulanamaz.
