# Texture Pack Yazar Kılavuzu

> Further Engine — global, modlardan bağımsız görünüm paketleri.
> Tasarım: `docs/FURTHER_LIBRARY_DESIGN_TR.md` (§2) · UI: Further Library → Texture Packs

## Paket nasıl kurulur?

```
<storageRoot>/further/texturepacks/<paketId>/
├── texturepack.json      ← zorunlu manifest
├── theme.json            ← isteğe bağlı: renk / font / menü müziği
├── thumb.png             ← isteğe bağlı: katalog küçük resmi
├── images/...            ← motorla AYNI anahtarlar (mods/ düzeni gibi)
├── music/...
├── sounds/...
├── fonts/...
├── data/...
└── videos/...
```

Masaüstünde `<storageRoot>` oyun klasörü, Android'de oyunun storage root'u.
Klasörü elle atabilir veya Further Library'den kurabilirsin (Faz 2).

## `texturepack.json`

```json
{
  "id": "neon-nights",
  "name": "Neon Nights",
  "author": "fanzci",
  "version": "1.2.0",
  "description": "Neon tonlarda menü ve oyun içi görünüm.",
  "thumbnail": "thumb.png",
  "accentColor": "#FF2E63",
  "sections": ["menu", "ui", "gameplay", "audio", "fonts"],
  "tags": ["neon", "dark"]
}
```

Alanlar: `id` ve `name` zorunlu; `thumbnail` dosya adı (`"thumbnail": "thumb.png"`);
diğerleri isteğe bağlı.

## `theme.json`

```json
{
  "colors": { "accent": "#FF2E63", "background": "#0A0A0C", "text": "#FFFFFF" },
  "fonts":  { "default": "fonts/Ozel.ttf", "vcr.ttf": "fonts/Ozel.ttf" },
  "menuMusic": "music/freakyMenu"
}
```

- `colors` → Further UI tema renkleri (yığının **en üstündeki** paket kazanır).
- `fonts` → `"vcr.ttf": "..."` motor fontunu değiştirir; `"default"` = `vcr.ttf` kısayolu.
- `menuMusic` → `music/freakyMenu` yerine bu dosya çalar (uzantı yazılmasa da olur).

## Öncelik kuralları (özet)

1. **Dosyalar dosya bazlı:** iki pakette aynı dosya varsa **yığında üstteki** kazanır; olmayan dosyalar alt paketten gelir.
2. **Tema yığın bazlı:** renk/font/müzik eşlemesi her zaman yığının **en üstteki** `theme.json`'undan.
3. Zincir: `Texture Pack yığını → aktif modlar → motor varsayılanları`.
4. Tam deneyim modları `pack.json`'a `"ignoreTexturePacks": true` yazarak o mod oynarken yığını askıya alır.

## Anahtar eşleme (dosyalar nereye koyulur?)

Paket yapısı **mod klasörüyle aynıdır**:

| Motorun aradığı | Paketteki dosya |
|---|---|
| `images/mainmenu/menu_story_mode.png` | `images/mainmenu/menu_story_mode.png` |
| `shared/images/menuBG.png` | `images/menuBG.png` (veya `shared/images/menuBG.png`) |
| `week1/images/week1BG.png` | `images/week1BG.png` (veya `week1/images/week1BG.png`) |
| `fonts/vcr.ttf` | `fonts/vcr.ttf` |
| `music/freakyMenu.ogg` | `music/freakyMenu.ogg` |

Sparrow atlas'ları **PNG + XML ikilisiyle** paketlemeniz gerekir
(ikisi ayrı ayrı çözümlenir; yalnız PNG koymak kırık frame verir).

## Yığın (stacking)

Further Library → Texture Packs sekmesi:
- **AKTIF YIGIN** şeridi: `A` = öncelik yukarı, `Z` = aşağı. En üstteki kazanan.
- Kart üzerindeki **AC / KAPAT** paketi açıp kapatır.
- Yeni kurulan paket otomatik olarak **en üste ve etkin** gelir.
- Durum `further/texturepacks/texturepacks.json` dosyasında saklanır.
