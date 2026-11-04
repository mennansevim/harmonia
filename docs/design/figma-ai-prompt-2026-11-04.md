# Figma AI tasarım promptu — Vocalart (4 Kasım 2026)

Kaynak: kullanıcı konsepti (Bugün / Egzersiz Kütüphanesi / Gelişim) +
uygulamanın gerçek özellikleri (`lib/trainer`, `lib/choir`). Referans
uygulamanın (Riyaz) görseli, renkleri ve çokgen kartları kopyalanmaz;
yalnız "kategori şeridi + kaldığın yerden" fikri alınır.

---

## Sayfa 1 — Sistem, Bugün, Egzersizler

Vocalart adlı Türkçe bir iOS ses ve kulak eğitimi uygulaması için 390×844 mobil ekranlar tasarla. Ton: sakin, sade, güven veren; tek ekranda tek ana eylem. Açık arka plan #F7F8FA, metin #222539, ana vurgu mor #705CE6, başarı/ilerleme teal #45B4AC, seri ve ödül sıcak sarı #F2B96D. Inter benzeri sans-serif, başlık 28/600, gövde 15/400. Kartlar beyaz, 20px köşe, ince 1px #E6E8EF çizgi, gölge yok. Lucide tarzı ince çizgi ikonlar. 8px ızgara, 20px yan boşluk, dokunma alanı en az 48px. Alt menüde 4 sekme: Bugün, Egzersizler, Koro, Gelişim. Profil ve ayarlar sağ üstteki avatardan açılır.

Ekran 1 · Bugün: Üstte "Merhaba Mennan" ve küçük "Bugün sesini çalıştırmaya hazır mısın?"; sağda sarı seri rozeti "7 gün" ve avatar. Altında haftalık hedef çipi "Bu hafta 3/5 gün". Ekranın ana öğesi tek büyük koyu kart (#222539): etiket "BUGÜNKÜ PLANIN · 12 dk", başlık "Sesini ısıt ve kulağını aç", 4 parçalı ilerleme çubuğu (Nefes, Tekrar kartları, Ders, Ses) ve "1/4 tamamlandı"; kartın içinde tam genişlik mor "Devam et" düğmesi. Altında "Hızlı egzersizler · Tümünü gör" yatay kaydırmalı küçük kartlar: Nefes 2 dk, Aralık 5 dk, Ritim tekrarı 3 dk, Ezgi tekrarı 4 dk. Sonra "Kaldığın yerden" satır kartı: "Aralık Eğitimi · Ders 3/8" ve teal ilerleme çubuğu. Koro üyesiyse en altta tek satır: "Oda Korosu · Kasım 1. hafta · 3 gün kaldı".

Ekran 2 · Egzersizler: Başlık ve arama alanı. Altında kaydırılabilir kategori çipleri: Tümü, Isınma, Kulak, Ses, Ritim, Çok sesli. İki sütunlu kart ızgarası; her kartta ikon, ad, süre, seviye ve ince ilerleme çubuğu: Nefes rehberi, Nota eğitimi, Aralık eğitimi, Akor tanıma, Dizi tanıma, Akor yürüyüşleri, Dinle ve söyle, Ezgi tekrarı, Ritim tekrarı, Alkışla ritim, Aksak ritim, Kaç ses duyuyorsun (2/3/4). Üstte geniş bir kart: "Ses aralığını ölç · 2 dk · mikrofon".

---

## Sayfa 2 — Egzersiz akışı, Koro, Gelişim

Aynı görsel sistemle devam et. Egzersize girildiğinde alt menü kaybolur; tam ekran, dikkat dağıtmayan bir akış başlar.

Ekran 3 · Egzersiz detayı: Sol üstte geri oku. Büyük ikon, "Aralık Eğitimi", "Başlangıç · Ders 3/8 · 5 dk". "Bu derste" başlığı altında 3 maddelik kazanım listesi. "Örneği dinle" ikincil düğmesi (piyano sesi), altta tam genişlik mor "Başla". Küçük not: "Mikrofon isteğe bağlı, kayıtlar cihazdan çıkmaz."

Ekran 4 · Canlı ses çalışması: Üstte ince ilerleme "Soru 4/10" ve kapat ikonu. Ortada büyük, açık bir alan: soldan sağa kayan nota bantları ve kullanıcının sesini gösteren mor canlı çizgi; hedef bandın içindeyken çizgi teal olur. Altında hedef nota "La4" ve durum metni "Biraz pes, hafif yukarı". En altta iki düğme: "Tekrar dinle" ve büyük yuvarlak mikrofon düğmesi. Ses algılanmazsa sade bir uyarı: "Ses duyulmadı, tekrar dene"; puan gösterme.

Ekran 5 · Sonuç: Büyük teal halka içinde "8/10", tek cümle yorum "Küçük üçlüleri büyükten iyi ayırıyorsun." Altında 2 küçük metrik: "İlk denemede doğru %80", "+40 XP". Düğmeler: "Sıradaki adım" (birincil) ve "Tekrar et". Seri artınca üstte küçük sarı "7 gün" kutlaması.

Ekran 6 · Koro: "Korolarım" kartı (Oda Korosu · Alto). "Ödevler" listesi: başlık, eser sayısı, kalan gün çipi. Ödev detayında eser kartı (Gloria · SATB · Ölçü 12–30), şefin zaman damgalı notları ("00:32 Nefes kaçağı"), parti seçici çipler (Tüm koro, Soprano, Alto, Tenor, Bas), "Kendi partin / Diğer sesler / Hız" kaydırıcıları, metronom ve ön sayım anahtarları, koyu oynatıcı ve "Kaydet ve gönder" düğmesi.

Ekran 7 · Gelişim: Seviye kartı "Kalfa · Seviye 3 · 1.820 XP" ve sonraki seviyeye çubuk. "Son 7 gün" çubuk grafik. "Ses aralığı" kartı: klavye üzerinde ölçülen aralık "Sol3–Mi5"; ölçülmediyse "Henüz ölçülmedi · Ölç" boş durumu. "Beceriler · ilk deneme doğruluğu" satırları (Nota, Aralık, Akor, Dizi, Yürüyüş). En altta "Sana önerilen: Akor tanıma, 5 dk".

Tüm ekranlarda Türkçe metin, açık mod, iOS durum çubuğu.
