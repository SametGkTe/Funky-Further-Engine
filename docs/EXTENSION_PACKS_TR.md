# Extension Packs — Paket Yazar Kılavuzu

**Extension Pack**, Further motoruna **karakter, menü veya misc içerik** ekleyen,
mod klasörü dışında duran (`further/extensionpacks/`) pakettir. Modlardan bağımsızdır;
oyun içi **Extension Packs** sekmesinden (veya elle) kurulur/kaldırılır.

## 1. Kurulum yeri

```
<oyun>/further/extensionpacks/<pack>/
```

- **Further Library → EXT sekmesi**: kurulu paketleri listeler/kaldırır; `extensions.json`
  katalogundan tek dokunuşla indirir (arka planda, İNDİRİLENLER çekmecesi).
- **Elle**: paket klasörünü yukarıdaki konuma kopyalaman yeterli.

## 2. Zorunlu dosya: `extensionpack.json`

```json
{
  "id": "cool-pack",
  "name": "Cool Pack",
  "description": "Ne kattığını yaz.",
  "author": "sen",
  "type": "character",
  "version": "1.0.0"
}
```

`type`: `character` | `menu` | `misc` (UI'da etiket gösterir; paket aynı anda
hem karakter hem menü içerebilir — tip yalnızca kategoridir).

## 3. Character Pack (Character Select'e karakter)

```
<pack>/
├── extensionpack.json
├── data/players/cool-guy.json    ← V-Slice oynanabilir girişi (ZORUNLU)
└── characters/cool-guy.json      ← Psych karakter tanımı (ZORUNLU)
    (+ images/... veya mevcut bir atlas'ı image alanıyla kullanabilirsin)
```

### `data/players/cool-guy.json` (oyun/seçim ekranı girişi)

```json
{
  "version": "1.0.0",
  "name": "Cool Guy",
  "ownedChars": ["cool-guy"],
  "showUnownedChars": false,
  "unlocked": true,
  "freeplayStyle": "bf",
  "charSelect": {
    "position": 6,
    "gf": { "assetPath": "charSelect/gfChill", "animInfoPath": "charSelect/gfAnimInfo", "visualizer": false }
  }
}
```

- `ownedChars`: bu oyuncuya ait **sahne karakteri id'leri** (aşağıdaki `characters/<id>.json`).
- `charSelect.position`: seçim ızgarasındaki slot (mevcut karakterlerle çakışmasın;
  0,1,2... slotlara bak, serbest seç). `gf`: seçim ekranındaki DJ görseli — şimdilik
  taban `charSelect/gfChill` kullan.
- `freeplayStyle`: taban stillerden biri (`bf`, `pico`).

### `characters/cool-guy.json` (oyun içi sprite tanımı)

Standart **Psych karakter JSON'u** (`animations`, `image`, `healthicon`, ...).
Görsel yüklemesi mod mekanizmasıyla yapılır: `"image": "characters/BOYFRIEND"`
gibi **taban bir atlas'ı gösterebilirsin** (hazır sanatla denemek için) ya da

```
<pack>/images/characters/cool-guy.png + .xml
```

koyup `"image": "characters/cool-guy"` yazabilirsin.

> **Nasıl çalışır?** Motor, paketi `mods/../further/extensionpacks/<pack>` yoluyla
> "mod kökü" gibi gezer; `PlayerRegistry` + Character Select mevcut mod tarama
> mantığıyla paketin `data/players/` klasörünü otomatik görür. Ana menüdeki
> **Characters** butonundan (Char Select) doğrudan listelenir.

## 4. Menu Pack (ana menüye buton)

```
<pack>/
├── extensionpack.json
├── menus/packmenu/menu.json      ← { "id", "label", "class", "order"? }
└── scripts/PackMenu.hxc          ← class PackMenu extends ...ScriptedMusicBeatState
```

Sözleşme **Custom Menus ile birebir aynı** (bkz. `docs/CUSTOM_MENUS_TR.md`):
dosya adı = sınıf adı, sınıf `funkin.modding.base.ScriptedMusicBeatState`'ten türer.
Paket açılırken `scripts/*.hxc` dosyaları otomatik kaydedilir — ayrıca bir şey yapman gerekmez.

## 5. Misc Pack

`extensionpack.json` + istediğini. (Şimdilik yalnızca listelenir/kaldırılır;
gelecekte stage/song pack'leri bu tip altında gelecek.)

## 6. Katalog: `extensions.json`

Further Library → EXT → **KATALOG** sekmesi, repodaki kurucu listeyi çeker:

```json
{
  "version": 1,
  "packs": [
    {
      "id": "example-character-pack",
      "name": "Ornek Karakter Pack",
      "type": "character",
      "author": "FNF-Further",
      "description": "...",
      "url": "https://github.com/.../example-character-pack.zip",
      "version": "1.0.0"
    }
  ]
}
```

- Kaynak: `ExtensionPackManager.CATALOG_URL` (varsayılan
  `https://raw.githubusercontent.com/FNF-Further/Funky-Further-Engine/main/extensions.json`).
  Fork'un kendi reposuna taşıdıysan bu sabiti güncellemen yeterli.
- İnternet yoksa gömülü kopya (`assets/shared/data/further/extensions.json`) kullanılır.
- `url`, **zip kökünde `extensionpack.json` bulunan** paket zip'idir.
- Listeye paket eklemek = repoda `extensions.json`'a satır ekleyip zip'i barındırmak
  (bkz. `docs/extensionpacks/*.zip` hazır örnekler).

## 7. Yaygın hatalar

| Belirti | Neden / Çözüm |
|---|---|
| Karakter Character Select'te yok | `data/players/<id>.json` yok veya `unlocked: false`. `extensionpack.json` kökte mi? |
| Karter eksik grafikle açılıyor | `characters/<id>.json` içindeki `image` yolu yok; taban atlas'ı ya da `images/characters/...` kullan |
| Menü butonu açılıyor ama beyaz/hata popup | `scripts/<Sinif>.hxc` adı ile `menu.json`'daki `class` alanı eşleşmiyor (bkz. CUSTOM_MENUS_TR hata tablosu) |
| Slot çakışması | `charSelect.position` başka bir karakterle aynı; serbest slot seç |
| İndirme bitti ama paket yok | Zip kökünde `extensionpack.json` olmalı (tek üst klasör kabul edilir) |

## 8. Bilinen sınırlar

- Paket `scripts/` klasöründen yalnızca **menü sınıfları** kaydedilir; karakter
  davranış scriptleri (`characters/<id>.hx`) şimdilik modlara özeldir.
- `ownedChars` içindeki karakter id'leri `characters/` altında tanımlı olmalı.
- Katalog `url`'leri depoya push edilene kadar 404 verir (offline kurulum: elle kopyala).
