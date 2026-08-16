# Further Engine — Modlama Rehberi

Further Engine, Psych Engine'in `mods/` sistemini korur; Lua/HScript, galeri içeriği ve motor içi mod paketi yönetimiyle genişletir. Bu sayfa yeni bir moda başlamak içindir.

## Hızlı başlangıç

1. Repodaki [`example_mods/FurtherModTemplate.zip`](../example_mods/FurtherModTemplate.zip) zip'ini çıkar.
2. İçindeki `My-Mod` klasörünü oyunun `mods/` klasörüne taşı.
3. Klasörü istediğin gibi yeniden adlandır.
4. `pack.json` dosyasındaki ad, açıklama, sürüm ve diğer bilgileri değiştir.
5. Further Engine'i açıp **Mods** menüsünden modunu etkinleştir. (Kapalıysa)

> [!UYARI]
> Başlangıçta yalnızca ihtiyacın olan klasörleri tutabilirsin. Engine, bir dosyayı yüklerken aktif modu temel oyundan önce kontrol eder.

## Temel klasör yapısı

```text
mods/Benim-Modum/
├── characters/       # Karakter JSONLARI
├── custom_events/    # Özel Eventler
├── custom_notetypes/ # Özel nota tipleri
├── data/             # Şarkı Chartları (chart.json), Ayarlar (settings.json) ve çeviriler (dil.lang)
├── images/           # Resimler ve Sprite'lar
├── music/            # Menü ve galeri müzikleri
├── other/            # gallery.json gibi Further Mod Destekleri için
├── scripts/          # Genel Lua/HScript Kodları
├── shaders/          # shader kodları
├── songs/            # Inst/Vocals
├── sounds/           # Ses efektleri
├── stages/           # Arkaplan JSONLARI ve ARKAPLAN LUA kodları
├── videos/           # Videolar (.mp4)
├── weeks/            # Hafta JSONLARI (week.json)
├── pack.json         # Modun Bilgileri
└── pack.png          # Modun Kapak Resmi
```

Oyunun Modu Görmesi için Tüm klasörlerin bulunması zorunlu değil, Sadece değiştirdiğin veya eklediğin içerikler yeterli.

## Lua ve HScript

Further Engine iki temel script seçeneği sunar:

- **Lua:** Psych Engine modlarıyla uyumluluk ve kolay başlangıç için.
- **HScript/Iris:** Haxe'e yakın sözdizimi ve daha gelişmiş çalışma zamanı davranışları için.

Başlangıç şablonları:

- [`docs/scripts/TemplateScript.lua`](scripts/TemplateScript.lua)
- [`docs/scripts/TemplateScript.hx`](scripts/TemplateScript.hx)

Script dosyalarını `scripts/` (MODDAKİ TÜM ŞARKILAR İÇİN) klasörüne, bir şarkının `data/<şarkı>/` (TEK ŞARKI İÇİN) klasörüne veya ilgili stage/nota/event konumuna koyabilirsin.

## Moda galeri içeriği ekleme

Further Engine galerisi modlar tarafından genişletilebilir. İçerikleri uygun klasörlere koy:

```text
images/gallery/
music/gallery/
sounds/gallery/
videos/gallery/
```

Ardından `other/gallery.json` içinde içerik türünü, dosya yolunu, başlığı ve kategoriyi tanımla. Desteklenen içerikler:

- Resim
- Spritesheet
- Video
- Müzik
- Ses efekti

Şablon arşivinde örnek bir `gallery.json` ve gerekli klasörler bulunur.

## Mod paketi hazırlama

ZIP'te mod klasör yapısını koru. Kullanıcının arşivi çıkardığında anlaşılır görmesi gerek.

Mod Paketlemeden önce:

- `pack.json` sürümünü güncelle. (Gerekli değil ama uyumlu olmasını garantiler)
- Gereksiz dosyaları kaldır.
- Dosya yollarındaki (ÖZELLİKLE RESİM yani resim 1.png gibi ayrı png ler sorun yaratır) büyük/küçük harf uyumunu Linux ve Android için kontrol et.
- Modu temiz bir Further Engine kurulumunda test et.
- Kullandığın müzik, görsel, font ve kodların yapımcılarını koy. (data/credits.txt)

## Diğer Yararlı kaynaklar

- [Psych Engine Wiki](https://github.com/ShadowMario/FNF-PsychEngine/wiki)
- [Psych Engine Lua API](https://shadowmario.github.io/psychengine.lua/)
- [Further Engine hata ve yardım sayfası](https://github.com/SametGkTe/Funky-Further-Engine/issues/new/choose)

## Yardım isterken

Sorununu bildirirken şu bilgileri paylaş:

- Further Engine sürümü
- Modlama türü: Lua, HScript yada kaynak kodu
- Sorunun oluştuğu platform (Windows, Android vb)
- İlgili script ve Log

[← Derleme rehberi](BUILDING_TR.md) · [Ana README →](../README.md)
