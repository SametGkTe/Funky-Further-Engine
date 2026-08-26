# Codename Engine Mod Desteği (Further Engine)

Bu belge, Further Engine'e eklenen **Codename Engine (CNE) mod çalışma zamanı
desteğini** açıklar. Amaç: `mods/` klasöründeki CNE modlarının, mevcut Psych
Engine mod sistemini **hiç bozmadan** çalışmasıdır.

## Kapsam

| Özellik | Durum |
|---|---|
| Asset override (images, music, sounds, fonts, videos, shaders, data) | ✅ Desteklenir |
| Karakterler (`assets/data/characters/*.xml`, FlxAnimate dahil) | ✅ Çevrilir |
| Sahneler (`assets/data/stages/*.xml`, sprite/animatedSprite) | ✅ Çevrilir |
| Şarkılar (`assets/songs/<şarkı>/charts/*.json` + `meta.json`) | ✅ Çevrilir |
| Haftalar (`assets/data/weeks/weeks/*.xml`) | ✅ Çevrilir |
| Haftasız CNE şarkıları (serbest oynatma) | ✅ Sentetik hafta ile listelenir |
| hscript scriptler (şarkı/sahne/karakter/ModState) | ❌ Kapsam dışı |
| ZIP (.zip/.cba) modlar | ❌ Kapsam dışı (yalnız klasör modlar) |
| CNE addon'ları (`addons/`, addon.json) | ❌ Kapsam dışı |

## Kullanım

1. CNE mod klasörünü `mods/` altına koyun (örn. `mods/MyCNEMod/data/...`,
   `mods/MyCNEMod/songs/...`). CNE'de asset ağacı doğrudan mod kökündedir;
   `<mod>/assets/` altına sarılmış düzenler de desteklenir.
2. Mods menüsünden (veya `modsList.txt` ile) modu etkinleştirin.
3. Mod, `assets/` kökü üzerinden **otomatik olarak CNE modu** diye tespit edilir;
   Mods menüsünde açıklaması `Codename Engine mod` olarak etiketlenir.
4. Şarkılar Freeplay'de, haftalar Story Mode'da görünür. Oynatın.

Ek ayar gerekmez. CNE modu, Psych modlarıyla aynı `modsList.txt` listesinde
birlikte aktif olabilir; öncelik listedeki sıradır.

## Tespit ve öncelik kuralları

- Bir klasörün CNE modu sayılması için Psych modlarıyla çakışmayan marker'lara
  bakılır: `data/config/modpack.ini`, `data/weeks/weeks/` klasörü,
  `songs/<şarkı>/charts/` klasörü veya `data/stages|characters/*.xml` dosyaları.
  Marker'lar mod kökünde ya da `<mod>/assets/` altında aranır. Sonuç önbelleğe alınır.
- Dosya çözümleme sırası (her mod için): **Psych yolu** (`<mod>/<key>`) →
  **CNE kökü** (`<kök>/<key>`; kök = `<mod>` veya `<mod>/assets`) → V-Slice yolu
  (`<mod>/shared/<key>`). Yani hybrid bir modda Psych düzeni her zaman kazanır.
- Arama sırası: aktif mod (`currentModDirectory`) → global modlar → `modsList.txt`
  sırası.

## Format çevirileri

### Karakter (XML → Psych JSON)
`data/characters/<ad>.xml` → Psych karakter JSON'u (bellek içinde):

- `sprite` → `image: "characters/<sprite>"` (PNG/XML ve FlxAnimate atlasları çalışır)
- `x/y` → `position`, `camx/camy` → `camera_position`
- `icon`/`color` → `healthicon`/`healthbar_colors`
- `flipX`, `holdTime`, `scale`, `antialiasing`, `isPlayer` eşlenir
- `<anim name anim fps loop indices x y/>` → `animations[]`

Karakter scriptleri (`.hx`) yok sayılır.

### Sahne (XML → Psych StageFile)
`data/stages/<ad>.xml` → Psych `StageFile` + yeni nesne sistemi:

- `zoom` → `defaultZoom`; `folder` → sprite görüntü ön eki
- `<sprite>` → `{type:'sprite'|'animatedSprite', x, y, image, scroll, ...}`
  (`<anim>` çocukları ve `animated="true"` desteklenir; `name` Lua değişkeni olur)
- `<girlfriend/> <dad/> <boyfriend/>` → karakter konumları + kamera ofsetleri
  (`camxoffset/camyoffset`) ve katman sırası
- `<girlfriend/>` düğümü yoksa GF gizlenir
- `<box>/<solid>`, ratings/combo ve extension düğümleri desteklenmez, güvenle atlanır

### Şarkı (CNE chart → SwagSong)
`songs/<şarkı>/charts/<zorluk>.json` + `meta.json` → Psych chart'ı:

- İstenen zorluk yoksa sırayla `normal > hard > easy > ilk chart` kullanılır
- PLAYER notları lane 0-3, OPPONENT notları lane 4-7'ye maplenir (Psych'in
  psych_v1 semantiği: lane < 4 = oyuncu). ADDITIONAL strumline'lar karşı
  tarafa eklenir; 4k üstü notlar atlanır)
- İkonlar: CNE karakter XML'indeki `icon` attribute'u HealthIcon tarafından
  çözülür (ikon adı karakter adından farklı olabilir)
- `noteTypes[type-1]` → Psych not tipi adı
- `meta.bpm`/`beatsPerMeasure` → bölüm yapısı; **"BPM Change" eventleri
  `changeBPM`'li bölümlere dönüştürülür**
- `scrollSpeed` (sayı veya `{default: n}`) → `speed`
- Karakterler strumline'lardan okunur (`player1`/`player2`/`gfVersion`),
  `stage` alanı korunur
- `events.json` (global eventler) birleştirilir; "Camera Movement",
  "Alt Animation Toggle", "HScript Call" atlanır; diğer eventler isimleriyle
  aktarılır (Psych tarafında aynı isimli custom event varsa çalışır)
- `needsVoices`: meta'dan, yoksa `Voices` dosyasının varlığından belirlenir
- Sesler: `songs/<şarkı>/song/Inst.ogg`, `Voices.ogg` ve meta'daki
  `instSuffix`/`vocalsSuffix` ile zorluk türevleri (`Inst-hard` vb.) desteklenir

### Hafta (XML → WeekFile)
`data/weeks/weeks/<hafta>.xml`:

- `name`, `chars`, `sprite`, `bgColor`, `<song>` ve `<difficulty>` düğümleri eşlenir
- Şarkı ikonları chart'taki karşı karakterden + karakter XML'inin `icon`
  attribute'undan okunur (yoksa `face`)
- Hafta karakter sprite'ları (`data/weeks/characters/*.xml`) kullanılmaz;
  Story menüsü Psych'in kendi menu karakter sistemini kullanır
- Hiçbir haftada olmayan CNE şarkıları için mod başına **freeplay-only sentetik
  hafta** (`cne_<mod>`) üretilir

## Mimari

Yeni paket `source/cne/compatibility/`:

| Dosya | Görev |
|---|---|
| `CNECompat.hx` | CNE mod tespiti, yol/ses/chart/meta bulma yardımcıları |
| `CNECharacterConverter.hx` | Karakter XML → Psych JSON |
| `CNEStageConverter.hx` | Sahne XML → Psych StageFile/objects |
| `CNESongConverter.hx` | CNE chart/meta → Psych SwagSong |
| `CNEWeekConverter.hx` | Hafta XML → WeekFile + sentetik haftalar |

Dokunan mevcut dosyalar (hepsi mevcut V-Slice köprüleriyle aynı desenle):

- `backend/Paths.hx` — `modFolders`, `fileExists`, `inst()`, `voices()`: CNE yolları
- `backend/Mods.hx` — `directoriesWithFile`: CNE kökü; `updateModList`: önbellek tazeleme
- `backend/Song.hx` — `getChart`: CNE chart köprüsü
- `objects/Character.hx` — `changeCharacter`: CNE XML köprüsü
- `backend/StageData.hx` — `getStageFile`: CNE XML köprüsü
- `backend/WeekData.hx` — `reloadWeekFiles` sonu: CNE hafta taraması
  (modül döngüsünü kırmak için **reflection** ile çağrılır)
- `states/ModsMenuState.hx` — CNE mod etiketi

Not: `WeekData`, `Song` vb. ile dönüşümlü modül bağımlılığı oluşmaması için
converter'lar bu sınıfları import etmez; çağrılar reflection/Dynamic üzerinden yapılır.

## Psych Lua kullanımı (CNE modlarında)

Psych düzenindeki konumlar her zaman çalışır: `mods/<Mod>/scripts/*.lua`
(global), `mods/<Mod>/data/<şarkı-adı>/*.lua` (şarkı scripti),
`mods/<Mod>/custom_events/` ve `mods/<Mod>/custom_notetypes/`.

Ayrıca CNE'nin doğal şarkı script konumu da desteklenir:
`mods/<Mod>/songs/<şarkı>/scripts/*.lua` dosyaları şarkı yüklenirken otomatik
push edilir (PlayState köprüsü). CNE chart event isimleri aynen aktarıldığı
için, eş isimli Lua custom event'lerle (`custom_events/<Event>.lua`) CNE
davranışları Lua'da yeniden kurulabilir. CNE'nin kendi `.hx`/`.hscript`
scriptleri çalışmaz.

## Bilinen sınırlamalar

- Script davranışı gerektiren CNE modları (sahne/karakter/şarkı `.hx` scriptleri,
  `use-extension`, ModState menüleri) yalnızca **asset ve veri** düzeyinde çalışır.
- CNE'nin 4k dışı chartları desteklenmez.
- GF görünürlüğü sahne XML'ine göre karar verilir (CNE'de chart'a bağlı olduğu
  durumlar birebir yansımaz).
- Chart editöründe CNE şarkısı açılırsa Psych formatında görünür; kaydetmek
  Psych formatında yazar.

## Ek: bu sürümde düzeltilen mevcut hata

`states/GalleryState.hx` içinde `cycleCategory()` yalnızca `#if mobile` bloğunda
tanımlıydı ama masaüstü kod yolundan çağrılıyordu (masaüstü derlemesini bozan
mevcut repo hatası). Fonksiyon mobile bloğunun dışına taşındı.
