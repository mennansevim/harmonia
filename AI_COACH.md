# Resonia Coach

## Amaç

Resonia Coach, öğrencinin sonuçlarını anlaşılır müzik öğretmeni diline çevirir ve sonraki egzersizi seçer.

AI’nin görevi ölçmek değildir. Ölçümü pitch/ritim motoru yapar; AI sonucu açıklar, motive eder ve kişiselleştirir.

## Model kararı

İlk AI koçu için `gpt-4o-mini` kullanılacak.

Model; metin ve görsel girdiler, metin çıktıları, Structured Outputs ve function calling için uygundur. Ham sesin doğrudan pitch analizi için kullanılmayacaktır. Güncel model yetenekleri için [OpenAI Docs — GPT-4o mini](https://developers.openai.com/api/docs/models/gpt-4o-mini) referans alınır.

## Kullanım alanları

1. Egzersiz sonrası hata açıklaması.
2. Bir sonraki egzersiz seçimi.
3. Günlük çalışma planı.
4. Haftalık gelişim raporu.
5. Sınav simülasyonu geri bildirimi.
6. Kullanıcının müzik sorularına bağlamlı cevap.
7. Öğretmen için sınıf özeti.

## AI’ye giden veri

Ham ses yerine:

```json
{
  "skill": "pitch",
  "target": {
    "note": "C4",
    "frequency": 261.63
  },
  "detected": {
    "frequency": 246.94,
    "centsDifference": -100,
    "octaveOffset": -1,
    "voicedRatio": 0.91,
    "stabilityCents": 18
  },
  "scores": {
    "accuracy": 72,
    "stability": 84
  },
  "recentErrors": ["wrong_octave", "low_intervals"],
  "userLevel": "beginner"
}
```

## Zorunlu çıktı

```json
{
  "coachMessage": "Notayı duydun fakat bir oktav aşağı söyledin.",
  "errorType": "wrong_octave",
  "severity": "medium",
  "explanation": "Sesin aynı nota ailesine yakın ancak hedef oktavın altında.",
  "nextExercise": {
    "type": "octave_matching",
    "difficulty": 2,
    "count": 5
  },
  "encouragement": "Kulağın doğru nota ailesini yakalamış.",
  "shouldRepeat": true
}
```

## Prompt kuralları

AI:

- Ölçüm sonucunu değiştiremez.
- Kullanıcıya kesin tıbbi veya vokal sağlık iddiası sunamaz.
- “Sesin kötü” gibi kişiliğe dönük ifade kullanamaz.
- En fazla bir ana hata ve bir sonraki egzersiz önermelidir.
- Önce kanıta, sonra öneriye geçmelidir.
- Türkçe ve kısa cevap vermelidir.
- Skor uydurmamalıdır.
- Yetersiz veri varsa bunu belirtmelidir.

## Fallback

AI çağrısı başarısız olursa uygulama çalışmaya devam eder:

```text
wrong_octave -> "Bir oktav fark var. Aynı notayı hedef oktavda tekrar dene."
unstable -> "Sesin hedefe yaklaştı fakat sabit kalmadı. Daha uzun ve rahat söyle."
late -> "Doğru söyledin; başlangıç biraz geç geldi."
noise -> "Ortam sesi sonucu etkiliyor. Kulaklık ve sessiz ortam dene."
```

## Çağrı politikası

- Her frame için AI çağrısı yok.
- Egzersiz sonunda en fazla bir çağrı.
- Günlük plan için oturum başına bir çağrı.
- Aynı hata imzası cache’lenebilir.
- Free kullanıcıya günlük limit.
- Premium kullanıcıda da kötüye kullanım limiti.

## Function calling adayları

```text
get_user_progress()
get_recent_errors()
recommend_exercise(skill, difficulty)
create_daily_plan(minutes)
start_exam_simulation(level)
```

AI’nin bu fonksiyonlarla gerçek veriyi alması sağlanmalı; veritabanı sorgusu uydurmasına izin verilmemeli.

## Değerlendirme seti

İlk release öncesinde en az şu örnekler hazırlanmalı:

- Doğru nota.
- Yanlış nota.
- Bir oktav aşağı.
- Bir oktav yukarı.
- Kararsız vibrato.
- Gürültülü kayıt.
- Çok kısa kayıt.
- Düşük ses seviyesi.
- İkinci denemede başarı.
- Tekrarlanan aynı hata.

Her örnek için öğretmen tarafından beklenen hata türü ve öneri yazılmalı. AI çıktısı bu referansla karşılaştırılmalı.

## AI’nin ürün içindeki sınırı

AI şu kararları veremez:

- Kullanıcı geçti/kaldı.
- Nota kesinlikle doğrudur.
- Ses tipi kesin olarak şudur.
- Kullanıcı tıbbi olarak şarkı söylemeye uygundur.
- Leaderboard sırası.

Bu kararlar kural tabanlı ve ölçüm temelli kalır.

## AI-02a — kodda olan sözleşme (2026-10-11)

`lib/domain/coach/coach_contract.dart` ve `lib/application/coach_service.dart`. **Canlı API çağrısı, sunucu gateway'i ve mobil anahtar yok.**

- `CoachInput.fromResult`: yalnız `touch`/`microphone` kaynaklı sonuçlar; mock/sentetik/doğrulanmamış sonuç koça gitmez. Yük: beceri, mod, ölçüm durumu, metrik durumları (ölçülmüş değer yuvarlanmış), izinli sayaçlar (eşleşme/eksik/fazla/erken/geç), hata kodları, izinli sonraki egzersiz listesi, `promptVersion = coach-prompt-1`, `model = gpt-4o-mini`. Serbest metin ve ölçüm dışı alanlar taşınmaz.
- `CoachReplyValidator`: şema `{schemaVersion:1, summary ≤280, nextExerciseId?}`; skor/puan alanı, izinsiz anahtar, olmayan egzersiz, yüzde/hazırlık/garanti iddiası, eğitimci taklidi, sağlık/teşhis ifadesi, geçersiz ölçümde övgü reddedilir.
- `CoachService`: 6 sn zaman aşımı; her hata/ret deterministik yedek metne düşer; çıktı `ai`/`fallback` etiketli; skor değiştirmez.
- Yerel eval: 12 test (9 simüle model yanıtı + zaman aşımı/gateway hatası/gateway yok + kaynak kapısı + yük içeriği).

Model durumu: OpenAI deprecations sayfasının 2026-10-11 tarihli arama indeksine göre temel `gpt-4o-mini` sohbet modeli için duyurulmuş kapanış görülmedi; audio/realtime/transcribe varyantları 2026–2027'de kapanıyor. Canlı entegrasyondan önce resmî sayfa ve fiyat yeniden doğrulanmalı. Sonraki: AI-01 sunucu gateway'i (hesap/maliyet onayı), AI-03 Türkçe eval setinin gerçek modelde koşulması (ücretli API onayı).
