# V-Slice Mod Desteği (Further Engine)

V-Slice (FunkinCrew/Funkin 0.8+) modlarının Further Engine'de çalışmasını
sağlayan katmanın durum belgesi. Psych modları bu destekten etkilenmez.

## Tespit ve çalışma modeli

- V-Slice modları `_polymod_meta.json` dosyasıyla tanınır (`backend/VSliceMeta`).
  Bu modlar Psych tarafında otomatik **global** sayılır (`runsGlobally = true`),
  yani menülerde de asset çözümlemesine katılırlar.
- Polymod kütüphanesi kullanılmaz (`POLYMOD_ALLOWED` tanımlı değildir); tüm
  çözümleme FFE'nin kendi köprüleriyle yapılır.

## Veri köprüleri

| V-Slice | Psych karşılığı | Dosya |
|---|---|---|
| `data/songs/<id>/<id>-chart.json` | SwagSong (sections) | `vslice/compatibility/VSliceSongConverter` + `Song.tryVSlicelside` |
| `data/songs/<id>/<id>-metadata.json` | bpm/karakter/sahne/vokaller | aynı |
| `data/characters/<id>.json` | karakter JSON | `VSliceCharacterConverter` + `Character.changeCharacter` |
| `data/stages/<id>.json` | StageFile | `VSliceStageConverter` + `StageData.getStageFile` |
| `data/levels/*.json` | Psych hafta | `WeekData.addVSliceWeek` |
| level'sız şarkılar | sentetik freeplay haftası | `VSliceLooseSongs` (reflection hook) |
| `songs/<Şarkı>/Inst.ogg`, `Voices-<karakter>.ogg` | `Paths.inst/voices` | `Paths.findVSliceAudio` |

## Chart dönüşüm detayları

- Notlar `{t, d, l, k}`: **d 0-3 = oyuncu, 4-7 = rakip** (Funkin kaynağıyla
  doğrulandı) — Psych'in psych_v1 semantiğiyle birebir uyumlu.
- Zorluk seçimi: chart'ın `notes` map'inden istenen zorluk (case-insensitive),
  yoksa ilk zorluk.
- **Eventler** `{t, e: "İsim", v: veri}` → Psych `[time, [[isim, v1, v2]]]`
  olarak aktarılır. `v` nesne ise JSON string olarak v1'e konur. Eş isimli
  Psych custom event (Lua/HScript) varsa çalışır; yoksa zararsızca yok sayılır
  (script tabanlı event sistemi çökmez).
- **BPM değişimleri** metadata `timeChanges` üzerinden section'lara
  `changeBPM`/`bpm` olarak işlenir.
- `needsVoices` şarkı klasöründeki `Voices*` dosyalarının varlığından belirlenir.
- Vokal dosyası önceliği: `Voices.ogg` → `Voices-Bf.ogg` → `Voices-<ilk bulunan>`.
- Chart varyasyonları (`-pico` gibi) yüklenmez; temel chart kullanılır.

## Sınırlamalar

- `.hxc` scriptler (ScriptedStage/ScriptedCharacter/song/event scriptleri)
  çalışmaz — şarkı, dönüştürülmüş sahne/karakter verisiyle oynanır.
- V-Slice dialogue, stickerpack, notestyle ve album/freeplay-card görselleri
  kullanılmaz (Psych kendi menü sistemini kullanır).
- Sprite'lar `shared/images/` altında olabilir; `Paths.modFolders` içindeki
  `shared/` köprüsü bunları çözer.

## Psych Lua kullanımı (V-Slice modlarında)

V-Slice modları Psych Lua ile **birlikte** çalışabilir — iki mod desteği
birbirinden bağımsızdır ve aynı mod klasöründe bir arada durabilir.

### Hazır çalışan konumlar (Psych düzeni, mod kökünde)
| Konum | İşlev |
|---|---|
| `mods/<Mod>/scripts/*.lua` | Global script (menü + oyun) |
| `mods/<Mod>/data/<şarkı-adı>/*.lua` | Şarkı scripti (ad formatlı: `bi-nb`) |
| `mods/<Mod>/custom_events/*.lua` (+ `.txt`) | Lua custom event |
| `mods/<Mod>/custom_notetypes/*.lua` | Lua not tipi |
| `mods/<Mod>/shaders/` | Shader dosyaları |

### V-Slice doğal konumları (köprü ile desteklenir)
| Konum | İşlev |
|---|---|
| `mods/<Mod>/scripts/songs/<şarkı>.lua` | Şarkı scripti (V-Slice `scripts/songs/*.hxc` yerine Lua) |
| `mods/<Mod>/scripts/events/<Event>.lua` | Chart event'i için Lua handler — `custom_events/` altında yoksa buraya bakılır |

### Chart event → Lua sinerjisi
V-Slice chart eventleri (`FocusCamera`, `NoteSwapEvent`, `PlayAnimation`, ...)
dönüştürücü tarafından **isimleriyle** Psych event listesine aktarılır. Yani
`scripts/events/NoteSwapEvent.lua` yazarak (parametreler `value1`/`value2`
içinde; nesne değerler JSON string olarak `value1`'e konur) V-Slice modunun
davranışlarını Lua ile yeniden kurabilirsiniz. `.hxc` scriptler çalışmaz;
Lua karşılıkları bu boşluğu doldurur.
