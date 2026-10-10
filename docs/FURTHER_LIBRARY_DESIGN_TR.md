# Further Library & Texture Pack — Tasarım Dokümanı

> Durum: **Taslak v1** — 2026-09-24
> Kapsam: Further Library (hub menü), Texture Packs, Mod Downloader, Custom Menus, Extension Packs

---

## 0. Kilitlenen Kararlar

| # | Konu | Karar |
|---|------|-------|
| 1 | Öncelik | **Önce Further Library iskeleti + Texture Pack sistemi**, sonra Mod Downloader → Custom Menus → Extension Packs |
| 2 | Referans fork | [Snirozu/Funkin-Psych-Online](https://github.com/Snirozu/Funkin-Psych-Online) ("Built-In Mod Downloader") — **yalnızca UX/akış fikri**; kod kopyalanmayacak, telif sorunu olmayacak. Her şey mevcut `backend/modpack/DownloadManager` üzerine özgün yazılacak |
| 3 | İndirme kaynakları | **GameBanana resmi API + mevcut GitHub Releases / MediaFire katalog sistemi** |
| 4 | Texture Pack kapsamı | **Menü/UI + oyun içi** (note skin, ikon, healthbar vb.) ve paketler **yığılabilir** (katmanlı) |
| 5 | Menü stili | **Sadece Eski (Psych) menüler.** V-Slice ("Yeni") stili bu özelliklerden muaf; `MenuStyleRouter.isOriginalStyle()` hedef |
| 6 | Mevcut mağaza | **Tek merkez:** `ModpackStoreState` işlevi Further Library → "Install Mods" sekmesine taşınır. `ModsMenuState` (yerel mod yönetimi: aç/kapa, öncelik) ana menüdeki `mods` butonunda **kalır** |

---

## 1. Further Library

Her şeyin ana kaynağı: keşfet, indir, kur, yönet. Ana menüye **`library`** butonu eklenir (mevcut `mainmenu/menu_library` atlas'ı ile).

### 1.1 UI Kararı — "Rail + Grid + Slide-over" (Hibrit mağaza/kütüphane)

Seçilen tasarım: **sol dikey rail + üstte arama/filtre + ortada kart grid + sağda detay slide-over + soldan açılan İNDİRİLENLER drawer**.

Gerekçe:
- 3+ içerik türü, arama ve filtre = **kart grid + chip filtreler** en taranabilir düzen.
- **Sağ detay paneli** liste kaybolmadan içerik inceletir (oyun hissi bozulmaz).
- **Sol kenar indirme butonu** (kalıcı FAB) + drawer, "her ekranda kalsın" şartını çözer.
- Mobilde birebir aynı iskelet: rail alt tab bar'a, slide-over tam ekran sheet'e dönüşür (touch hedefleri ≥ 48 dp).

Düzen şeması:

```
┌──┬──────────────────────────────────────────────┬─────────┐
│R │  [Arama....]  (Tümü)(Onaylı)(Topluluk)(Kurulu)│ DETAY   │
│A │                                              │ PANELİ  │
│I │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐            │ (slide- │
│L │  │ ▓▓▓ │ │ ▓▓▓ │ │ ▓▓▓ │ │ ▓▓▓ │  ← kartlar │  over)  │
│  │  └─────┘ └─────┘ └─────┘ └─────┘            │         │
│[⬇]│                                             │         │
└──┴──────────────────────────────────────────────┴─────────┘
 [⬇] = indirme FAB (sol kenar, ilerleme halkalı) → İNDİRİLENLER drawer
```

- **Rail:** Further Library logosu, 3 sekme (Texture Packs / Install Mods / Extension Packs), altta indirme FAB.
- **Kart:** 16:9 küçük resim (kaynak `thumbnail`), başlık, yazar, rozetler (`✔ Onaylı`, `Topluluk`, `Kurulu`, `Güncelleme`), kur butonu.
- **Rozet kaynağı:** depo kataloğundaki `verified: true` alanı → "Onaylı"; yoksa "Topluluk". Fan içerik asla engellenmez, yalnızca rozetlenir.
- **Detay paneli:** büyük görsel, açıklama, meta (sürüm, boyut, tür, yazar), sürümler/changelog, kur / kaldır / öncelik ayarı (texture pack'ler için yığın sırası).
- **İNDİRİLENLER drawer:** aktif (hız, %, duraklat/iptal), tamamlanan, hatalı (yeniden dene). Kuyruk state değişiminden **etkilenmez**.

### 1.2 Kalıcı İndirme Butonu (global overlay)

Flixel state'i her geçişte yıkıldığı için `DownloadHUD`, `FlxG.stage` üzerinde yaşayan bir OpenFL `Sprite` katmanıdır (yalnız buton/drawer input alır). Böylece **Story/Freeplay/Options/Ayarlar/Oyun içi** her yerde görünür ve tıklanır.

### 1.3 Sekmeler

| Sekme | İçerik | Veri kaynağı |
|-------|--------|--------------|
| **Texture Packs** | Katalog + kurulum + **Aktif Yığın** yönetimi | Repo katalog (`texturepacks.json`) |
| **Install Mods** | Mod / Modpack indirme (mevcut mağaza buraya taşınır) | GameBanana API + mevcut katalog (GitHub raw + jsDelivr yedekli) |
| **Extension Packs** | Character Packs, Menu Packs, Misc | Repo katalog (`extensions.json`) + GameBanana |

İleride eklenebilir: "Koleksiyonum" (kurulu her şey tek listede), "Güncellemeler" chip'i şimdilik yeterli.

---

## 2. Texture Pack Sistemi

Psych'in "aktif modun assetleri" kilidini kıran, **modlardan tamamen bağımsız global** bir katman.

### 2.1 Konum

```
<storageRoot>/further/texturepacks/<packId>/     ← mods/ klasöründen BAĞIMSIZ
<storageRoot>/further/texturepacks/texturepacks.json   ← yığın durumu (sıra + açık/kapalı)
```

`ModpackPaths` ile aynı kalıp: `backend/further/TexturePackPaths.hx` → `StorageUtil` sarmalayıcısı. Masaüstünde oyun kökü, Android'de storage root. Kurulum: Library'den indirilen zip güvenli çıkarıcıyla (`backend/modpack/zip/` yeniden kullanılır) buraya açılır; elle klasör atmak da çalışır.

### 2.2 Manifest — `texturepack.json`

```json
{
  "id": "neon-nights",
  "name": "Neon Nights",
  "author": "fanzci",
  "version": "1.2.0",
  "description": "Neon tonlarda menü ve oyun içi görünüm.",
  "thumbnail": "thumb.png",
  "accentColor": "#FF2E63",
  "minFurtherVersion": "0.3.0",
  "sections": ["menu", "ui", "gameplay", "audio", "fonts"],
  "tags": ["neon", "dark"]
}
```

- `sections`: paketin neyi etkilediği (filtre/rozet için; dosya çözümleme zaten dosya-bazlı).
- `accentColor`: paketin önerdiği tema rengi (yüklendiğinde `Theme.accent`'e uygulanabilir).

### 2.3 Klasör yapısı — asset anahtarına birebir ayna

```
<packId>/
├── texturepack.json
├── thumb.png
├── theme.json                 ← renk / font / menü müziği eşlemesi
├── images/...                 ← Paths anahtarlarıyla aynı (ör: images/mainmenu/menu_story_mode.png)
├── music/...                  ← music/freakyMenu.ogg vb.
├── sounds/...
├── fonts/...
└── videos/...
```

`theme.json`:

```json
{
  "colors": { "accent": "#FF2E63", "background": "#0A0A0C", "text": "#FFFFFF" },
  "fonts":  { "default": "fonts/PhantomMuff.ttf", "bold": "fonts/PhantomMuffBold.ttf", "title": "fonts/Title.ttf" },
  "menuMusic": "music/freakyMenu"
}
```

### 2.4 Yığın (stacking) ve öncelik

- Kullanıcı **birden fazla paketi** aynı anda açabilir. `texturepacks.json` içindeki **sıra = öncelik: listede aşağıda/sağda olan kazanır** (son kazanan).
- Çakışma kararı **dosya bazlı**: üst pakette `menu_story_mode.png` varsa yalnız o dosyada kazanır; olmayan dosyalar alt paketten gelir. (Katman maskesi gibi — tam esneklik.)
- Öncelik zinciri (yüksekten düşüğe):

```
Texture Pack yığını (son aktif → ilk aktif)   ← global, kullanıcının seçimi
→ Aktif modlar (currentModDirectory → global modlar; Psych davranışı)
→ Motor varsayılanları (assets/...)
```

- Tam deneyim modları (VS Impostor, Indie Cross tarzı) için kaçış: `pack.json` içine `"ignoreTexturePacks": true` → o mod oynarken yığın askıya alınır (PlayState oturumu boyunca).

### 2.5 Çözümleme katmanı (hook noktaları)

| Katman | Değişiklik |
|--------|------------|
| `Paths.getPath` / `fileExists` | Çözümleme başına `TexturePackManager.resolve(assetKey)` — en üst katman. Mevcut `clearFileExistsCache()` ile birlikte cache yönetimi |
| Fontlar | `TexturePackManager.applyFonts()` → `openfl.text.Font.registerFont` + FlxText default font eşlemesi |
| Tema renkleri | Yeni `backend/further/Theme.hx` singleton (`accent`, `background`, `text`) — menüler renkleri buradan okur |
| Menü müziği | `Paths.music('freakyMenu')` çağrıları resolve katmanından geçtiği için otomatik; `theme.json.menuMusic` ek eşleme sağlar |
| Oyun içi (healthbar, icon, note skin) | Aynı resolve kuralı; `Paths.image/...` zaten `getPath`'ten geçiyor |

Önbellek notu: `Mods.pushGlobalMods`'ta gördüğümüz `Paths.clearFileExistsCache()` deseni yığın değişince de çağrılır.

### 2.6 Yeni sınıflar

```
source/backend/further/TexturePackTypes.hx      ← typedef'ler (manifest, theme, stack config)
source/backend/further/TexturePackPaths.hx      ← dizin sarmalayıcı
source/backend/further/TexturePackManager.hx    ← tara, yığını yönet, resolve(), applyTheme()
source/backend/further/Theme.hx                 ← renk/font singleton
```

---

## 3. Mod Downloader (Faz 2)

Telif notu: Funkin-Psych-Online'dan **hiçbir kod, asset veya varlık kopyalanmayacak**. Alınan tek şey "oyun içi indirme + arka plan kuyruk + kalıcı HUD" fikridir; GameBanana'nın zaten herkese açık resmi API'si ve mevcut kendi `DownloadManager`/`ModpackInstaller` kodumuz üzerine kurulacak.

### 3.1 Kaynaklar

| Kaynak | Nasıl |
|--------|-------|
| **GameBanana resmi API** (apiv11) | Mod arama/liste/profil/dosya → doğrudan indirme URL. Yeni adaptör: `backend/further/GBClient.hx` |
| **Mevcut katalog** | `ModpackCatalogTypes` + GitHub Releases/MediaFire aynen çalışır; Library "Install Mods" sekmesinde görünür |

### 3.2 Arka plan kuyruğu

- `backend/further/DownloadQueue.hx`: **statik singleton**, `sys.thread` tabanlı; state geçişlerinden etkilenmez. İtem durumları: `queued | downloading | paused | done | error`.
- Aynı anda 1-2 eşzamanlı indirme (bant genişliği kibarlığı), kalanı kuyrukta.
- Kurulum sonunda mevcut `ModpackInstaller` / `ModDeltaInstaller` boru hattı devreye girer (zip güvenlik kontrolleri dahil).
- `DownloadHUD` (sol FAB + drawer) tüm bunların tek UI'ıdır — §1.2.

### 3.3 İNDİRİLENLER drawer içeriği

Aktif: başlık, %, hız, boyut, duraklat / iptal. Tamamlanan: "Kuruldu ✓". Hatalı: sebep + "Yeniden dene". Bant/URL hatalarında `DownloadManager`'ın mevcut yedek (raw → jsDelivr, Mediafire resolve) davranışı korunur.

---

## 4. Custom Menus (Faz 3)

Oyuncular/kodcular **kaynak koda dokunmadan** kendi menülerini ekler. Altyapı hazır: `ScriptedMusicBeatState` + CNE-HScript `CUSTOM_CLASSES` (`ClassExtendMacro`).

### 4.1 Dosya sözleşmesi (kesinleşen — docs/CUSTOM_MENUS_TR.md)

```
mods/<mod>/
├── scripts/
│   └── CoolMenu.hxc      ← class CoolMenu extends funkin.modding.base.ScriptedMusicBeatState
└── menus/<menuId>/
    ├── menu.json         ← { "id", "label", "class": "CoolMenu", "order"? }
    └── images/...        (opsiyonel)
```

Sınıf Polymod .hxc script-class yükleyicisiyle kaydedilir (dosya adı = sınıf adı);
`CustomMenuManager.open()` → `ScriptedMusicBeatState.scriptInit('CoolMenu')`
(motorun kendi NoteStyleRegistry deseniyle aynı).

### 4.2 Ana menüye entegrasyon

- `CustomMenuManager` (Faz 3): açık modlar + Menu Pack'lerdeki `menus/` klasörlerini tarar, `order`'a göre sıralar.
- `MainMenuState.optionShit` sonuna eklenir → **yeni butonlar mevcut butonların altında oluşur** (istediğin davranış).
- Sprite atlas'ı olmayan girdiler için **metin tabanlı fallback buton** üretilir (aynı gölge/hover stili); isteyen `menu_library` kalıbında atlas da sağlayabilir.

---

## 5. Extension Packs (Faz 4) ✅

Further'ın orijinalinde olmayan ekstralar. Manifest: `extensionpack.json`:

```json
{
  "id": "extra-chars",
  "name": "Ekstra Karakterler",
  "type": "character",
  "version": "1.0.0",
  "author": "birisi",
  "minFurtherVersion": "0.3.0"
}
```

| Tür | İçerik | Entegrasyon |
|-----|--------|-------------|
| `character` | `registry/players/*.json` + `characters/` + `images/` + `weeks/` | `PlayerRegistry` / `CharSelect` (V-Slice) ve `characters/` (Psych) beslemesi |
| `menu` | §4 Custom Menus paketi | `CustomMenuManager` |
| `misc` | Gallery öğeleri, achievement, pet vb. | ilgili sisteme göre |

Kurulum: `extensionpacks/<packId>/` (yine `mods/`'ten bağımsız) veya pratikte bir mod klasörü olarak da kabul edilir. Katalog verisi repo'dan (`extensions.json`, raw + jsDelivr yedekli) — tıpkı texture pack'lerdeki gibi.

> **UYGULANDI (Faz 4):** `backend/further/ExtensionPackManager.hx` (tarama/kaldırma,
> katalog, `scripts/*.hxc` kayıt) + CharSelect beslemesi (`data/players/` + `characters/`;
> paketler `mods/../further/extensionpacks/<id>` mod-kökü izdizgisiyle motorun mevcut
> mod mekanizmasını kullanır) + Further Library → EXT sekmesi (Kurulu/Katalog,
> indirme `kind: 'extensionpack'`). **Kesinleşen sözleşme ve kılavuz:**
> `docs/EXTENSION_PACKS_TR.md` · Örnek paketler: `example_mods/ExampleCharacterPack`,
> `example_mods/ExampleMenuPack` · Katalog örneği: kök `extensions.json`.

---

## 6. Yol Haritası

| Faz | İçerik | Çıktı |
|-----|--------|-------|
| **1** ✅ | **Further Library iskeleti + Texture Packs** | `FurtherLibraryState` (rail/grid/detay iskeleti), `TexturePackManager` + `Theme` + Paths hook, Aktif Yığın UI, `docs/design/further-library-mockup.html` |
| **2** ✅ | **Mod Downloader** | `GBClient` (GameBanana apiv11), `DownloadQueue` + `QuickModInstaller`, `DownloadHUD` (kalıcı FAB + İNDİRİLENLER), Library → Install Mods sekmesi |
| **3** ✅ | **Custom Menus** | `CustomMenuManager`, `MenuTextFrames` (fallback buton), MainMenu'e alttan buton ekleme + dinamik aralık, `docs/CUSTOM_MENUS_TR.md`, örnek mod |
| **4** ✅ | **Extension Packs** | `ExtensionPackManager`, Character/Menu Pack kurulumu, `extensions.json` kataloğu, `docs/EXTENSION_PACKS_TR.md` |

### Dosya planı (özet)

```
source/backend/further/        ← TexturePack*, Theme, DownloadQueue, GBClient, CustomMenu*, Extension*
source/states/further/         ← FurtherLibraryState, tab substate'leri, detay paneli
source/objects/further/        ← Library kartları, HUD, drawer bileşenleri
docs/design/                   ← mockup + ekran taslakları
```

---

## 7. Karara Bağlanan Küçük Noktalar (2026-09-24)

1. Yığın sırası: **A/Z butonları** (gamepad/touch dostu) — sürükleme sonraki sürümde gelebilir.
2. Çakışma: **`theme.json` yığın bazlı** (en üstteki tema kazanır), dosyalar dosya bazlı.
3. GameBanana apiv11 uç noktaları Faz 2 başlarken resmi dokümandan doğrulanacak (kod içinde tek yerde sabitlenecek).
