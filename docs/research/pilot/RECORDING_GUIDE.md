# Kayıt rehberi — tek sayfa (TASLAK)

Bu sayfa pilot kayıt oturumu içindir. Hukuk onayı bekleyen taslaktır
([CONSENT_DRAFT.md](./CONSENT_DRAFT.md)); **rıza imzalanmadan kayıt alınmaz.**
Hiçbir ses buluta/e-postaya/mesajlaşmaya gönderilmez.

## Katılımcıya (okunacak)

1. Bu bir **test**: sizi değil uygulamayı ölçüyoruz. Yanlış söylemeniz
   değerli veridir; gizlemeyin.
2. Her denemede önce bir **piyano notası** çalınır. Notayı dinleyin, sonra
   "a" (veya "la") diyerek **aynı notayı** söyleyin, ~2 saniye tutun.
3. Bazı denemelerde **bilerek** başka bir nota, başka bir oktav, hiç ses
   çıkarmama, konuşma veya kısa bir ses istenebilir. Yönetici söyler.
4. İstediğiniz an durabilir ve kaydınızın silinmesini isteyebilirsiniz.
5. Adınız dosya adlarında ve verilerde yer almaz; size bir kod verilir (ör. S07).

## Yöneticiye (oturum akışı)

**Hazırlık**
- [ ] Rıza formu imzalandı, kod (`subjectGroup`) verildi, eşleme tablosu ayrı ve şifreli.
- [ ] Katılımcı kodu **development** veya **holdout**'tan yalnız birine atandı
      (önceden listeden; sonradan değiştirilmez).
- [ ] Cihaz modeli + işletim sistemi sürümü, route (yerleşik / kulaklık kablolu /
      Bluetooth), oda (sessiz / yankılı / TV-klima) not edildi.
- [ ] Kayıt formatı: **mono, 16 bit PCM WAV**, 44,1 veya 48 kHz, ≤120 sn.
- [ ] Telefon sessiz modda değil bildirimler kapalı; otomatik ses işleme
      (varsa) kapatılmadan **olduğu gibi** bırakıldı (AGC dahil gerçek durum).

**Kayıt (her katılımcı, her oda/cihaz koşulu)**
1. 2 deneme ısınma (kaydedilmez).
2. Sınıf başına en az: `correct_note` ×6, `octave_up/down` ×2, `wrong_note` ×2,
   `silence` ×2, `speech_noise` ×2 (konuşma, öksürük), `unstable_vibrato` ×2,
   `short_buffer` ×1, `clipped` ×1 (yakın mesafe, yüksek ses),
   `accompaniment_leak` ×1 (referansı hoparlörden çalarken).
3. İstenen nota (`expectedFrequenciesHz`) ve **yönerge** (ne yaptırıldı) anında
   yazılır; eğitimci etiketi sonra, algoritma çıktısı görülmeden verilir.
4. Alkış oturumu ayrı: mesafe 30 / 60 / 100 cm; konuşma/öksürük/masaya vurma
   yanlış tetikleme olayları; yönergeli kaydırma/eksik/fazla alkış (bkz.
   protokol §3b).

**Dosya adı** (taşınabilir, `[A-Za-z0-9_.-]`):
`<kod>_<nota>_<oda>_<cihaz>_<nn>.wav` → ör. `S07_C4_quiet_phoneA_03.wav`

**Kayıttan sonra**
- [ ] `shasum -a 256 dosya.wav` ile özet; `manifest.json` ve `pilot_meta.json`
      şablonlarından kayıt satırı eklendi ([manifest_template.json](./manifest_template.json),
      [pilot_meta_template.json](./pilot_meta_template.json)).
- [ ] `rightsReference` ve `consentReference` dolu.
- [ ] Dosyalar yalnız şifreli yerel diskte; bulut senkronizasyonu kapalı.
- [ ] İki eğitimci bağımsız etiketledi (A, B); uyuşmazlık çözüldü.

## Yapılmayacaklar

- Rızasız, eksik kodlu veya hakkı belirsiz kayıt alma.
- Aynı kişiyi hem development hem holdout'a koyma.
- Etiketi algoritma çıktısına bakarak verme.
- Kötü çıkan kaydı "temizlik" diye atma (reddedilen kayıt nedeniyle yazılır).
- Eşik/algoritma ayarlama (pilot ölçer, ayarlamaz).
