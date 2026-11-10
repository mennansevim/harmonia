# Koro (ADR-041) — devam prompt'u

Aşağıdaki metni yeni bir oturuma olduğu gibi ver.

---

Resonia/Vocalart reposundayız (`/Users/sevimm/Documents/Projects/vocalart`). Önce `AGENTS.md`,
`MODEL_HANDOFF.md` (en üstteki CHOIR-B girdileri), `DECISIONS.md` ADR-041, `CURRENT_ROADMAP.md`
(en üst 4 girdi) ve `supabase/README.md`'yi oku. Commit, push, deploy ve hesap ayarı değişikliği
yalnız benim açık onayımla yapılır.

## Şu ana kadar yapılan (hepsi commit'siz, çalışma ağacında)

- **Çevrimiçi koro (Faz 1–3)**: Supabase (Auth + Postgres RLS + Edge Functions) + koronun Google
  Drive'ı. Kod: `lib/choir/online/`, `lib/choir/data/choir_remote.dart`, `ChoirStore` aynası
  (`remote`, `onlineChoirIds`, `syncOnline`, `ensureMedia`, `leaderDecide`, `partTakes`, rol bilen
  `reviewQueue`), `lib/choir/domain/choir_access.dart` (yetki kuralı), `supabase/migrations/` (3
  dosya), `supabase/functions/` (`media`, `drive-oauth`, `_shared/`), testler `supabase/tests/`,
  `supabase/functions/tests/`, `test/choir/online_*`.
- Kararlar: Drive ana dosya deposu (koro hesabı `agoravoiceschoir@gmail.com`), kaydı aynı parti +
  partisyon şefi dinler, şef yalnız partisyon şefinin "Şefe gönder" dediğini görür, tek şef,
  giriş e-posta kodu (Apple/Google girişi sonra), pilot 35 kişilik kendi koromuz.
- **Gerçek Google Drive yerelde doğrulandı**: Google Cloud projesi koro hesabında ("My First
  Project", `coral-environs-514320-a8`), Web OAuth istemcisi `Vocalart Supabase`, yönlendirme
  `http://127.0.0.1:54321/functions/v1/drive-oauth/callback`, kapsamlar `openid`,
  `userinfo.email`, `drive.file` (hassas/kısıtlı yok), uygulama **Testing** durumunda, koro hesabı
  test kullanıcısı. Sırlar yalnız `supabase/functions/.env.local` (git yok sayıyor).
- **Son iş — Drive klasör yerleşimi (kod bitti, gerçek Drive'da henüz denenmedi)**:
  `supabase/functions/_shared/layout.ts`:
  ```
  Vocalart/<Koro>/                      (koro klasörü choirId app property ile bulunur)
    Eserler/<Eser>/MIDI ve nota/
    Eserler/<Eser>/Kayıtlar/<Parti>/    "2026-11-10 · Ad · Ödev · deneme N.wav",
                                         sesli not yanında "… · Ad notu · Korist.wav"
    Kaynaklar/Notalar | Prova kayıtları | Diğer
  ```
  Uygulama yüklemede `work` (eser = parça başlığı), `shelf`, `part` gönderiyor
  (`ChoirRemote.upload`, `ChoirStore._uploadLocal/_uploadVoice/_sendOnline`, `addMidi(work:)`).
  Deno 5/5 ve `test/choir` 118 test geçti.

## Sıradaki işler (sırayla)

1. **Doğrula**: `dart tool/quality_check.dart`, `supabase test db`, Deno testleri
   (`supabase/README.md`'deki komut). Yerel stack kapalıysa `supabase start -x
   studio,imgproxy,realtime,storage-api,logflare,vector,supavisor,postgres-meta`, fonksiyonlar
   gerçek Google ile: `supabase functions serve --env-file supabase/functions/.env.local`.
2. **Gerçek Drive'da yeni yerleşimi dene**: yerel bir test şefi + koro oluştur,
   `drive-oauth/start` ile izin adresini al, tarayıcı panesinde aç; izni **ben** veririm (koro
   hesabı). Sonra `media/upload`'a `work`, `shelf`, `part` vererek MIDI, nota ve (bir korist
   kullanıcısıyla) kayıt yükle; Drive'da `Vocalart/<Koro>/Eserler/...` yapısını panede göster.
   Eski deneme klasörü `Vocalart · Drive Deneme` koro Drive'ında duruyor; silmeyi bana sor.
   Yardımcı betik örneği: scratchpad'deki `google_drive_check.ts` (start/check) — yoksa aynısını
   yaz (supabase-js ile sign-in, `create_choir`, `drive-oauth/start`, upload → Google'a PUT →
   finalize → GET).
3. **Dokümanlar**: `CURRENT_ROADMAP.md`, `IMPLEMENTATION_LOG.md`, `MODEL_HANDOFF.md`,
   `supabase/README.md` ve ADR-041 "Sınırlar"a klasör yerleşimini ve sonucu ekle (gerçek sınırlarla).
4. **Simülatörde uygulama akışı** (gerçek Drive): `flutter build ios --simulator --debug
   --dart-define=SUPABASE_URL=<yerel API_URL> --dart-define=SUPABASE_KEY=<PUBLISHABLE_KEY>`;
   giriş kodu Mailpit'ten (`MAILPIT_URL`). Şef: koro kur → Drive'ı bağla → ödev + MIDI;
   korist: katıl → kayıt gönder; partisyon şefi: Şefe gönder; şef: dinle/geri dön.
5. **Benim tarafımda bekleyenler (hatırlat, zorlama)**: uzak Supabase projesi (AB) + `db push` +
   `functions deploy` + sırlar (onayımla); Resend SMTP + 6 haneli kod şablonları (ertelendi);
   Google uygulamasını yayına almak için ana sayfa + gizlilik politikası (KVKK metniyle birlikte);
   uzak yönlendirme adresini OAuth istemcisine eklemek;
   `rotori-app/design/vocalartdata/client_secret_*.json` dosyasını repo dışına almak.
6. **Faz 4 adayları**: kayıt ekranında PDF nota (şef ölçü aralığına sayfa atar); AAC sıkıştırma
   (2 dk WAV ≈ 10 MB); kaldığı yerden yükleme + çevrimdışı kuyruk; push bildirim; koro/üye
   silinince Drive temizliği; davet universal link; Apple/Google girişi; gizlilik manifesti ve
   mağaza veri etiketleri (sunuculu derleme e-posta/kimlik/ad/ses topluyor).
7. **Commit**: istersem yalnız koro dosyalarını commit'le (`lib/choir`, `supabase/`,
   `test/choir`, ilgili dokümanlar, `pubspec*`, iOS/Android izin değişiklikleri,
   `scripts/release/verify_android_apk.py`); `lib/trainer/koro/*` vb. başka değişikliklere dokunma.
