# Custom Menus — Yazar Kılavuzu

> Further Engine Faz 3: oyuncular/kodcular **kaynak koda dokunmadan** HX ile
> kendi menülerini ekler. Yeni butonlar ana menüde **mevcut butonların altına**
> dizilir.

## Dosya sözleşmesi

```
mods/<modun>/
├── scripts/
│   └── CoolMenu.hxc          ← zorunlu: sınıf burada (dosya adı = sınıf adı)
└── menus/
    └── coolmenu/             ← klasör adı serbest (id ile eşleşmesi şart değil)
        ├── menu.json         ← zorunlu manifest
        └── images/...        ← opsiyonel (Paths ile yüklenir)
```

### `menu.json`

```json
{
  "id": "coolmenu",
  "label": "Cool Menu",
  "class": "CoolMenu",
  "order": 50,
  "icon": "images/icon.png"
}
```

| Alan | Zorunlu | Anlam |
|------|---------|-------|
| `id` | ✔ | Benzersiz kimlik (ana menü `custom_<id>` olarak kullanır) |
| `label` | ✔ | Buton yazısı (atlas yoksa metin buton üretilir) |
| `class` | ✔ | `scripts/` altındaki .hxc'teki sınıf adı |
| `order` | – | Sıra (küçük = üste; varsayılan 50) |
| `icon` | – | (opsiyonel, ileride) |

### `scripts/CoolMenu.hxc`

```haxe
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

class CoolMenu extends funkin.modding.base.ScriptedMusicBeatState
{
    function new()
    {
        super();
    }

    override function create():Void
    {
        super.create();
        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF0A0A0C);
        add(bg);
        var t = new FlxText(0, 300, 0, "MERHABA!", 48);
        t.setFormat("assets/fonts/title.ttf", 48, 0xFFFF2E63);
        t.screenCenter();
        add(t);
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (FlxG.keys.justPressed.ESCAPE)
            FlxG.switchState(new states.MainMenuState());
    }
}
```

## Kurallar

1. **Dosya adı = sınıf adı** (`CoolMenu.hxc` → `class CoolMenu`) — Polymod
   script-class yükleyicisi böyle kaydeder.
2. Sınıf her zaman **`funkin.modding.base.ScriptedMusicBeatState`**'ten türer.
3. Kurucu **argümansız** olmalı: `function new() { super(); }`.
4. Tam `FlxState` gücüsün: `add()`, `FlxTween`, `FlxTimer`, alt state
   (`openSubState`), `Paths`, `Mods`, `ClientPrefs` script'e hazır gelir.
5. Ana menüye dönmek: `FlxG.switchState(new states.MainMenuState());`
   (veya `backend.MenuStyleRouter.goToMainMenu();`).

## Buton görünümü

- Atlas **yoksa** motor `label`'dan modern bir metin buton üretir
  (`objects/MenuTextFrames`) — idle + selected (pembe glow).
- Kendi sanatını istiyorsan mod klasörüne Sparrow atlas koy:
  `images/mainmenu/menu_custom_<id>.png` + `.xml`,
  frame adları: `custom_<id> idle` ve `custom_<id> selected`
  (bkz. `assets/shared/images/mainmenu/menu_mods.xml` formatı).

## Hata ayıklama

Menü açılmazsa motor **kontrol listeli** bir popup gösterir:
`class` alanı eşleşiyor mu, `scripts/` altında `.hxc` var mı, sınıf adı doğru mu.
Ayrıntı konsolda `[CustomMenu]` önekiyle görünür.

Çalışan örnek: `example_mods/ExampleCustomMenu/` — klasörü `mods/`'e kopyala,
ana menüde **Cool Menu** butonu belirir.

## Extension Packs (Faz 4)

Aynı sözleşme `further/extensionpacks/<pack>/menus/` altında da geçerlidir —
`type: "menu"` Menu Pack'leri otomatik taranır.
