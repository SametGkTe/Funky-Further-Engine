# CNE HScript Desteği (Further Engine)

Bu belge, Further Engine'e eklenen **Codename Engine HScript çalışma zamanını** açıklar.
Kaynak: Psych Extended Online'dan (PEXO) port edildi; hscript-improved fork'u
**doğrudan kaynak ağacına gömüldü** (`source/cne/compatibility/codenamecrew/`),
yani **ek haxelib kurulumu gerekmez**. Paket adları yeni konuma göre güncellendi:
`cne.compatibility.codenamecrew.hscript.*` (standart `source/` classpath'iyle
çözülür, ek bayrak gerekmez). Dış `hscript` paketi bağımlılığı yoktur —
`IHScriptCustomClassBehaviour` arayüzü de codenamecrew paketinin içindedir.

> [!WARNING]
> Bu bir v1 portudur — "çalışsın yeter" seviyesinde. Tam CNE script uyumluluğu hedeflenmemiştir.

## Ne çalışıyor?

| Özellik | Durum |
|---|---|
| CNE şarkı scriptleri (`songs/<şarkı>/scripts/*`) | ✅ |
| Uzantılar: `.hx`, `.hscript`, `.hxs`, `.hxc`, `.hsc` | ✅ (hxc dahil!) |
| `data/states/<StateAdı>` state scriptleri (tüm menüler) | ✅ |
| `codenameScripts/` global klasörü | ✅ |
| `import` ifadeleri (CNE import sistemi) | ✅ |
| `#if`/`#else` preprocessor (define'lar script'e aktarılır) | ✅ |
| Abstract sınıflar: `FlxColor`, `FlxPoint`, `FlxAxes`, `BlendMode`, `FlxTextAlign`, `Thread`, `Mutex`, `haxe.xml.Access` | ✅ (AbstractHandler makrosu `_HSC` gölge sınıfları üretir) |
| `class X extends FlxSprite {}` (script içinde sınıf türetme) | ✅ (ClassExtendMacro) |
| `strumLines`, `dad`, `boyfriend`, `gf` kısayolları | ✅ (strumLines uyumluluk sarmalayıcısı: members[0]=dad, [1]=boyfriend, [2]=gf) |
| Script olayları: `create`, `createPost`, `update`, `updatePost`, `beatHit(curBeat)`, `stepHit(curStep)`, `onCountdownTick`, `onStartCountdown`, `onSongStart`, `onEndSong`, `onPause`, `onResume` | ✅ |
| Not olayları: `onNoteHit(event)`, `onNoteMiss(event)`, `onPlayerMiss(event)` (NoteHitEvent) | ✅ |
| `setVar` / `getVar` / `removeVar`, `initSaveData`/`getDataFromSave`/`setDataFromSave`, `debugPrint`, `__script__`, `disableScript` | ✅ |
| Varsayılan değişkenler: `FlxG`, `FlxSprite`, `FlxAnimate`, `FlxTween`, `Paths`, `Mods`, `ClientPrefs`, `FunkinText`, `FunkinSprite`, `PlayState`, `FlxVideo` (hxvlc), vs. | ✅ |
| Hata durumunda ekran üstü debug metni + konsol çıktısı | ✅ |

## Nasıl çalışır?

1. CNE modunu `mods/` altına koy (mevcut CNE data desteğiyle aynı).
2. Şarkı yüklenirken PlayState, modun `songs/<şarkı>/scripts/` klasöründeki tüm
   CNE scriptlerini (uzantı fark etmeksizin) otomatik yükler ve `create()` çağırır.
3. Psych'in `callOnScripts`/`setOnScripts` akışı CNE scriptlerine de yönlendirilir:
   `onBeatHit` → `beatHit`, `onStepHit` → `stepHit`, `onUpdate` → `update` vb.
   otomatik eşlenir; `curStep`, `curBeat`, `curDecStep`, kamera değişkenleri
   `setOnScripts` üzerinden scriptlere anlık aktarılır.
4. Menülerde `data/states/FreeplayState.hx` gibi dosyalar state açılırken yüklenir
   (`MusicBeatState` köprüsü) ve `create`/`update`/`destroy` çağrılır.

Örnek şarkı scripti (`mods/MyMod/songs/bopeebo/scripts/effects.hxc`):

```haxe
function create() {
    var bg = new FlxSprite(0, 0).loadGraphic(Paths.image('mybg'));
    insert(0, bg);
    boyfriend.y -= 100;
}

function beatHit(curBeat) {
    if (curBeat % 2 == 0)
        dad.playAnim('danceLeft', true);
}

function onNoteHit(event) {
    if (event.noteType == 'Special') event.healthGain *= 2;
}
```

## Mimari (eklenen dosyalar)

| Dosya | Görev |
|---|---|
| `source/cne/compatibility/codenamecrew/` | hscript-improved fork'u (vendored; tek paket `cne.compatibility.codenamecrew.hscript.*`, arayüz dahil) |
| `source/funkin/backend/scripting/HScript.hx` | CNE yorumlayıcı sarmalayıcısı + Script/ScriptPack (PEXO'dan uyarlandı) |
| `source/funkin/backend/scripting/ScriptLoader.hx` | Script arama/yükleme yardımcısı (modlar + base assets) |
| `source/funkin/backend/scripting/StrumLineCompat.hx` | `strumLines` uyumluluk sarmalayıcısı |
| `source/funkin/backend/scripting/EventManager.hx` + `events/` | CNE olay sistemi (recycle'lı CancellableEvent) |
| `source/funkin/backend/scripting/DebugText.hx` | Ekran üstü hata/debug metni |
| `source/funkin/backend/FunkinText.hx`, `FunkinSprite.hx` | CNE yardımcı sınıfları (FunkinSprite sadeleştirilmiş: atlas yok) |
| `source/funkin/backend/assets/MultiFramesCollection.hx` | CNE frame koleksiyonu |
| `source/macros/DefineMacro.hx`, `EventMacro.hx` | Define aktarımı + event recycle makrosu |
| `source/backend/FunkinFileSystem.hx` | Dosya sistemi yardımcısı |

Değişen mevcut dosyalar:

- `Project.xml` — `HSC_ALLOWED`, `CUSTOM_CLASSES`, `HSCRIPT_ABSTRACT_SUPPORT`,
  `hscriptPos` ve `--macro` bayrakları (yeni paket yollarıyla)
- `backend/MusicBeatState.hx` — state scriptleri (`stateScripts`), `call`/`event`,
  `update`/`destroy` kancaları
- `states/PlayState.hx` — `cneScripts`, şarkı scripti yükleyici, `callOnScripts`/
  `setOnScripts` yönlendirmesi, `onNoteHit`/`onNoteMiss`/`onPlayerMiss` olayları

## Bilinen sınırlamalar (v1)

- **Shader desteği yok**: `FunkinShader`/`CustomShader` port edilmedi; shader scriptleri çalışmaz.
- **FunkinSprite sadeleştirildi**: FlxAnimate atlas sarmalayıcısı, beat animasyonları
  ve zoomFactor yok; temel `playAnim`/`animOffsets` var.
- `onCameraMove`, `onNoteCreation`, `onNoteUpdate` gibi bazı CNE olayları henüz bağlanmadı.
- CNE script'lerindeki `onEvent` (chart event) çağrısı yok.
- Multi-strumline yok (4k; `strumLines` sarmalayıcısı 3 satır döner).
- Karakter/stage `.hx` scriptleri yüklenmez (sadece şarkı + state scriptleri).
- CNE'nin ModState menüleri (`data/states/<Ad>` script'ten menü açma) desteklenmez.
- State scriptleri `create` sırasında yüklenir; state scriptlerine `onCreatePost`
  vb. Psych kancaları bağlanmadı.

## Derleme notları

- `CUSTOM_CLASSES` define'ı açıkken tüm `flixel`/`funkin` sınıflarına
  ClassExtendMacro uygulanır → **derleme süresi uzar** (PEXO ile aynı davranış).
  Hıza ihtiyacın varsa `Project.xml`'den `<define name="CUSTOM_CLASSES" .../>`
  satırını kaldırabilirsin (script içinde sınıf türetme çalışmaz, gerisi çalışır).
- Desteği tamamen kapatmak için `Project.xml`'deki `HSC_ALLOWED` satırını silmen yeterli.
- Script hataları çökme yapmaz; ekran üstünde kırmızı metin olarak görünür (konsola da yazılır).
