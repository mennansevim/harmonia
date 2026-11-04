# Figma Make prototipi — inceleme ve uygulama planı (4 Kasım 2026)

Kaynak: <https://outer-cane-45483491.figma.site/> (yayınlanmış Make
prototipi; Figma MCP dosyaya düzenleme yetkisi olmadığı için kodu
okuyamadı, ekranlar tarayıcıda gezildi). Prompt:
[figma-ai-prompt-2026-11-04.md](./figma-ai-prompt-2026-11-04.md).

## Gezilen ekranlar

| Ekran | Prototipte | Flutter karşılığı |
|---|---|---|
| Bugün | Selam + seri + haftalık hedef çipi; koyu plan kartı (4 parçalı çubuk, %25, "Devam et"); hızlı egzersizler (yatay); kaldığın yerden; koro satırı | `lib/trainer/home/home_shell.dart` `PlayTab` |
| Egzersizler | Arama, kategori çipleri, "Ses aralığını ölç" geniş kartı, 12 kartlık 2 sütun ızgara (ikon, süre, seviye, ilerleme) | Yok; dağınık: `KoroHub` (Ses sekmesi) + Bugün'deki beceri ızgarası |
| Egzersiz detayı | İkon, başlık, "Bu derste" 3 madde, "Örneği dinle", "Başla" | `lib/trainer/learn/skill_screen.dart`, `lesson_flow.dart` girişi |
| Canlı çalışma | Soru 4/10, kayan nota bantları + canlı çizgi, hedef nota, durum cümlesi, "Tekrar dinle" + mikrofon | `lib/trainer/sing/trainer_pitch_sing_session.dart` |
| Sonuç | Halka içinde 8/10, tek cümle, %80 ilk deneme + 40 XP, "Sıradaki adım" / "Tekrar et" | `lib/trainer/learn/session_end.dart` |
| Koro | Korolarım, ödev, eser, şef notu, parti çipleri, karıştırıcı, metronom, oynatıcı, "Kaydet ve gönder" | `lib/choir/app/*` |
| Gelişim | Seviye + XP, son 7 gün çubuk, ses aralığı klavyesi, beceri doğrulukları, öneri | `lib/trainer/stats/stats_tab.dart` |

## Tasarım değerleri (prototipten)

- Renkler: zemin `#F7F8FA`, metin/koyu kart `#222539`, ana `#705CE6`,
  açık mor `#DDD9FA`/`#F0EDFF`, ilerleme/başarı `#45B4AC` (açık `#E4F5F2`),
  sıcak `#F2B96D`, çizgi `#ECEEF2`.
- Yazı: tamamen Inter (şu an başlıklar Lora serif).
- Köşe: kart 20px, küçük kutu 14–16px, çubuk 4px.
- Not: prototip telefon çerçevesi küçültülmüş; 7–10px yazı boyutları
  ölçek kaynaklı. Flutter'da mevcut `TT` ölçekleri ve 2.0 metin ölçeği
  sınırı korunur.

## Prototipteki hatalar / ürün kurallarıyla çelişenler

1. **Canlı ekranda nota sırası ters:** Sol4 üstte, Si4 altta. Tiz nota
   yukarıda olmalı.
2. **Canlı ses ekranı "Aralık Eğitimi"ne bağlanmış.** Uygulamada aralık
   eğitimi dinle-seç sorusudur; canlı pitch çizgisi "Dinle ve söyle" ve
   "Ezgi tekrarı"na aittir. Kulak dersleri için sonuç ekranı aynı, canlı
   ekran soru kartı olmalı.
3. **"Tam hedefte" anlık başarı:** Ölçüm geçersizse (ses yok, yanlış
   oktav) başarı rengi/puan gösterilmemeli; "Ses duyulmadı" durumu
   tasarımda yok, eklenmeli.
4. **Gelişim "42 dk çalışma":** Uygulama soru sayısı tutuyor; dakika
   ölçülmüyorsa "soru" gösterilir.
5. **Ses aralığı "Ölçülen rahat ses aralığın":** Aralık testi deneysel;
   "taslak ölçüm" etiketi ve ölçülmemiş boş durumu korunmalı.
6. **Plan çubuğu hep 4 parça:** Gerçek rota dinamik (tekrar kartı yalnız
   vadesi gelince, ses adımı süreye bağlı); parça sayısı rotadan gelmeli.
7. **"Alto · 12 üye", "John Rutter":** Koro verisinde üye sayısı/besteci
   yoksa gösterilmez.

## Uygulama planı (önerilen sıra)

1. **Tema** — `lib/trainer/ui/kit.dart` `TC`/`TT`: yeni palet, Inter
   başlıklar, kart köşesi 20. Tek dosya, tüm ekranlara yayılır.
2. **Gezinme** — 4 sekme: Bugün · Egzersizler · (Koro, role göre) ·
   Gelişim. Ayarlar sağ üst avatara.
3. **Bugün** — prototip yerleşimi; beceri ızgarası Egzersizler'e.
4. **Egzersizler** — yeni kütüphane ekranı: kategori çipleri, 2 sütun;
   `KoroHub` içeriği buraya. DENEYSEL/TASLAK olanlar ayrı ve etiketli.
5. **Detay → Canlı → Sonuç** — mevcut akış yeniden giydirilir, hatalar
   1–3 düzeltilmiş haliyle.
6. **Gelişim ve Koro** — aynı görsel sistemle; 4, 5, 7 dikkate alınır.

Her adımdan sonra `dart tool/quality_check.dart`; widget testlerindeki
anahtarlar (`today_begin`, `daily_plan`, `tab_*` …) korunur ya da test
birlikte güncellenir.

## Uygulama durumu (4 Kasım 2026)

Adım 1–5 kodda (DESIGN-09…12, NAV-02). Hata 1–3 canlı panelde ele alındı:
tiz üstte ölçek, ses yok/yanlış oktav nötr ve açık metinli. Prototipteki
kayan canlı çizgi uygulanmadı; ses analizi kayıt sonrası yapılıyor. Adım 6
(Gelişim, Koro) DESIGN-13 ile tamamlandı; hata 4, 5, 7 korundu. Plan kodda
bitti; simülatör, cihaz ve kullanıcı kontrolü açık.
