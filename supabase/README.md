# Koro sunucusu (ADR-041)

Supabase: kimlik, üyelik, davet, ödev, durum, geri bildirim ve yetki.
Dosyalar (MIDI, PDF, kayıt, sesli not) koronun Google Drive'ında; uygulama
Drive'a yalnız Edge Function'ın verdiği tek seferlik yükleme adresiyle yazar,
dosyaları yalnız `media` fonksiyonu izin kontrolünden sonra okur.

## Yerelde çalıştırma

```bash
supabase start -x studio,imgproxy,realtime,storage-api,logflare,vector,supavisor,postgres-meta
supabase test db                      # pgTAP: izolasyon ve katılım kuralları
supabase status -o env                # API_URL, PUBLISHABLE_KEY, SECRET_KEY, MAILPIT_URL
```

Uygulama yalnız sunucu adresi verilirse çevrimiçi koroyu açar:

```bash
flutter run --dart-define=SUPABASE_URL=<API_URL> --dart-define=SUPABASE_KEY=<PUBLISHABLE_KEY>
```

Giriş e-postaları yerelde Mailpit'e düşer (`MAILPIT_URL`). Şablon
`templates/sign_in_code.html` 6 haneli kodu gösterir; uzak projeye de aynı
şablon (magic link + confirmation) girilmeli.

Sunucu kodu entegrasyon testi (isteğe bağlı, kullanıcı oluşturur; paylaşılan
projeye bağlamayın):

```bash
RESONIA_SUPABASE_URL=<API_URL> RESONIA_SUPABASE_KEY=<PUBLISHABLE_KEY> \
RESONIA_SUPABASE_SECRET=<SECRET_KEY> RESONIA_MAILPIT_URL=<MAILPIT_URL> \
RESONIA_FUNCTIONS_URL=<API_URL>/functions/v1 \
flutter test --no-pub test/choir/online_backend_integration_test.dart
```

## Edge Functions

- `drive-oauth`: şef tarayıcıda koro hesabıyla Google'a izin verir
  (`drive.file`); refresh token Vault'ta, klasörler `Vocalart · <Koro>` altında.
- `media`: `upload` (izin + Drive yükleme adresi), `finalize` (dosya bu
  medya kaydına mı ait, boyut doğru mu), `GET /media/<id>` (`can_read_media`).

Yerelde Google yerine disk klasörü (yalnız yerel adreste çalışır):

```bash
cat > /tmp/functions.env <<'ENV'
RESONIA_DEV_DRIVE=1
FUNCTIONS_PUBLIC_URL=http://127.0.0.1:54321/functions/v1
DRIVE_STATE_SECRET=local-only
ENV
supabase functions serve --env-file /tmp/functions.env
```

Deno testleri (yerel veritabanı + disk Drive):

```bash
cd supabase/functions && SUPABASE_URL=<API_URL> SUPABASE_ANON_KEY=<ANON_KEY> \
  SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY> deno test -A tests/
```

Uzak projede gereken sırlar: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` (Google
Cloud "Web application" OAuth istemcisi; yönlendirme adresi
`<FUNCTIONS_PUBLIC_URL>/drive-oauth/callback`), `DRIVE_STATE_SECRET`,
`FUNCTIONS_PUBLIC_URL`. OAuth onay ekranı "In production" olmalı (Testing'de
refresh token 7 günde düşer).

## Kurallar

- Tablolara doğrudan yazım policy'si yok; her değişiklik rol kontrollü
  `SECURITY DEFINER` fonksiyonla (`migrations/`).
- Kural kaynağı `lib/choir/domain/choir_access.dart` ile aynı; birini
  değiştiren diğerini ve iki test setini günceller.
