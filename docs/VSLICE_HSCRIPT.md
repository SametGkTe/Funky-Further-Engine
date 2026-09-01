# V-Slice HScript (.hxc) Desteği — Further Engine

Bu doküman, Further Engine'e eklenen **V-Slice (FunkinCrew/funkin) tarzı
class-tabanlı `.hxc` script desteğini** anlatır. Motorun daha önceki CNE
hscript desteğinden (bkz. `CNE_HSCRIPT_SUPPORT.md`) farklıdır: o sistem
"flat-function" script çalıştırır; bu sistem **gerçek sınıf türetme**
(script içinde `class X extends ...`) yapar — tıpkı resmî FNF 0.7.x gibi.

## Destek durumu (dürüst özet)

Further'daki "V-Slice desteği" üç katmandır. Bu doküman yalnızca
**scripting (.hxc)** katmanını anlatır; diğer iki katman motorun önceden
sahip olduğu V-Slice uyumluluk işidir (menüler, sahneler, veri
dönüştürücüler — `vslice/` klasörü).

| Alan | Durum | Not |
|---|---|---|
| Oyun tarafı: yeni Freeplay/Results/albümler/sticker'lar/editörler | ✅ (önceden vardı) | `vslice/menus/`, `vslice/editors/` |
| Resmî sahneler + cutscene'ler + erect zorluklar | ✅ (önceden vardı) | `vslice/stages/` |
| V-Slice veri dönüşümü (song/character/stage) | ✅ (önceden vardı) | `vslice/compatibility/*Converter` |
| Polymod mod yükleme (asset override, `_polymod_meta.json`) | ✅ | `backend/PolymodHandler` |
| **Karakter script'leri** (`.hxc`, 2 sözdizimi) | ✅ v6 | `extends objects.Character` veya FNF shim'leri |
| **Sahne script'leri** | ✅ v6 | sınıf adı = sahne adı |
| **Sprite script'leri** | ✅ v6 | `extends flixel.FlxSprite` |
| **Script olayları** (17 olay) | ✅ v9 | `event.cancelled` onPause'u durdurur; nota olaylarında `event.note` || FNF `ScriptEvent` sınıfları | 🔶 v13 | `SongEvent`/`ScriptedSongEvent`/`ScriptEvent`/`CountdownScriptEvent`/`StateChangeScriptEvent` shim'leri; alan seti hâlâ sadeleştirilmiş |
| Şarkı script'i (ScriptedSong) | ✅ v3 | sınıf adı = şarkı id'si; `onSongLoaded` ile chart mutasyonu, `isSongNew` ile NEW rozeti |
| Module sistemi (ScriptedModule) | ✅ v9 | state'ler arası yaşar; `active = false` olan olay almaz; menülerde de onCreate/onUpdate/onDestroy (v12) |
| FunkinSprite script'leri | 🔶 v9 | temel shim; atlas/filtre sistemi yok |
| State/SubState script'leri | 🔶 v12/v13 | `funkin.ui.MusicBeatState` + `ScriptedMusicBeatState` şimleri; OTOMATİK state yükleme yok (manuel scriptInit) |
| Runtime sınıf çözümü (DCE) | ✅ v13.2 | `-dce no` + `include('funkin', true)` + `include('vslice.scripting', true)` + override'lar init'ten önce + `@:noCustomClass` CNE koruması |
| Strumline / NoteKind / NoteStyle script'leri | ❌ | |
| Freeplay style / Albüm / Level / BackingCard / Sticker script'leri | ❌ | |
| Diyalog / Speaker / StageProp / Bopper / SongEvent script'leri | 🔶 v13 | SongEvent ailesi var; diğerleri yok |
| `funkin.*` import yüzeyi | 🔶 v14 | 6 karakter shim'i + 9 importOverride (Paths/Conductor/Highscore/TitleState/FunkinCamera/HealthIcon/Note ailesi) + 17 MINIMAL stub shim (Preferences, Constants, ModuleHandler, NoteStyle, Strumline, ...) |
| `event.cancelled` motoru durdurur mu? | ❌ | şimdilik bilgi taşır |

**Sonuç:** Tam destek DEĞİL. Karakter + sahne + sprite script'i kullanan
modlar çoğunlukla çalışır; şarkı/module/freeplay script'lerine dayanan
modlar çalışmaz.

## Nasıl çalışır?

Resmî FNF'nin script sistemi **Polymod** haxelib'inin içinde gömülü gelir:
- `polymod.hscript.HScriptedClass` arayüzü + `@:autoBuild` makrosu
  (`HScriptedClassMacro`), `@:hscriptClass` işaretli her sınıfa
  `scriptInit()`, `scriptCall()`, `scriptGet()`, `scriptSet()`,
  `listScriptClasses()` gibi statik araçlar üretir.
- Bir `.hxc` dosyası `class X extends OyunSinifi { ... }` içerdiğinde,
  Polymod bunu parse eder, **scripted sarmalayıcı** üzerinden kurar ve
  script'teki `override`'lar gerçek metod çağrılarını yakalar.
  `super.foo()` çağrıları da çalışır (gerçek Haxe sınıfına düşer).

GEREKSİNİM: `haxelib install polymod 1.7.0` (Project.xml'e sabitlendi).

## Kurulum / Derleme

1. `haxelib install polymod 1.7.0` komutunu bir kez çalıştır.
2. `lime test windows -clean` — POLYMOD_ALLOWED artık otomatik tanımlı.
3. Scriptler startup'ta (`StartupState`) kaydedilir; karakterler şarkı
   yüklenirken çözümlenir.

## Script nereye konur?

| Konum | Ne için |
|---|---|
| `mods/<mod>/scripts/*.hxc` | Psych tarzı mod scriptleri (otomatik taranır) |
| `mods/<mod>/data/scripts/*.hxc` | alternatif klasör |
| `mods/<mod>/data/characters/*.hxc` | karakter scriptleri |
| `mods/<mod>/data/stages/*.hxc` | sahne scriptleri |
| `assets/scripts/*.hxc` | temel oyun (modsuz) — demo burada |
| Polymod modu (`_polymod_meta.json` içeren) herhangi bir `.hxc` | polymod kendisi tarar (useScriptedClasses: true) |

> Düz fonksiyon (flat-function) `.hxc`/`.hx` dosyaları eski sistemle
> (Iris / VSliceScriptLoader) çalışmaya devam eder; `class ` içeren
> dosyalar otomatik olarak bu yeni köprüye yönlendirilir.

## Desteklenen scripted sınıflar (v1)

### 1. ScriptedCharacter — `objects.Character` tabanlı (Further-native)

```haxe
import objects.Character;

class CilginBf extends objects.Character
{
	function new(x:Float, y:Float, char:String, isPlayer:Bool)
	{
		super(x, y, char, isPlayer);
	}

	override function dance():Void
	{
		super.dance();
		this.angle = 6;
	}

	override function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		super.playAnim(AnimName, Force, Reversed, Frame);
		// özel davranış...
	}
}
```

Script, **indexleme anında kurulduğu karakter id'sine** bağlanır
(örnek: 'bf' ile indexlenirse yalnızca `SONG.player1 == 'bf'` olduğunda
devreye girer).

### 2. FNF tarzı id-tabanlı shim'ler (gerçek FNF script sözdizimi)

Gerçek FNF mod script'leri şöyle yazar:

```haxe
import funkin.play.character.SparrowCharacter;

class Whitty extends SparrowCharacter
{
	public function new()
	{
		super('whitty');
	}

	override function dance():Void
	{
		super.dance();
		// ...
	}
}
```

Bunun için Further'a şu **shim sınıflar** eklendi (paket
`funkin.play.character`): `BaseCharacter`, `SparrowCharacter`,
`PackerCharacter`, `AnimateAtlasCharacter`, `MultiSparrowCharacter`,
`MultiAnimateAtlasCharacter`. Hepsi `objects.Character`'a köprü kurar;
kurucuları id alır (`new(id)`), `characterId`/`characterName` alanları
sağlar. Her birinin `vslice.scripting.Scripted*` sarmalayıcısı vardır,
yani `extends` yönlendirmesi çalışır.

### 3. ScriptedFlxSprite — genel sprite

```haxe
class OzellikliSprite extends flixel.FlxSprite
{
	function new(x:Float, y:Float, ?Graphic)
	{
		super(x, y, Graphic);
	}
}
```

### 4. ScriptedStage — sahne scripti

```haxe
import backend.BaseStage;

class Mall extends backend.BaseStage
{
	function new()
	{
		super();
	}

	override function create():Void
	{
		super.create();
		// sahne objeleri...
	}
}
```

SÖZLEŞME: script sınıfının ADI sahne adıyla eşleşmelidir
(`stage: "mall"` → `class Mall`).

### 5. ScriptedSong — şarkı script'i (v3)

```haxe
import funkin.play.song.Song;

class Milf extends funkin.play.song.Song
{
	function new()
	{
		super('milf');
	}

	// Chart hazırken; chart'ı DEĞİŞTİREBİLİRSİN (notalar, hız, bpm...)
	function onSongLoaded(event:Dynamic):Void
	{
		states.PlayState.SONG.speed *= 1.05;
	}

	// Freeplay "NEW" rozeti kararı
	override function isSongNew():Bool
	{
		return false;
	}

	function onBeatHit(event:Dynamic):Void
	{
		// her beat...
	}
}
```

SÖZLEŞME: script sınıfının ADI şarkı id'sine eşit olmalı ("milf" -> class Milf).
Eşleşen script `generateSong` başında kurulur ve `onSongLoaded` chart okunmadan
ÖNCE çağrılır; `states.PlayState.SONG` üzerinden yapılan değişiklikler (hız, bpm,
notalar) şarkıya anında yansır. Diğer olaylar (onBeatHit, onNoteHit, onSongStart...)
şarkı script'ine de yayılır.

### 6. Module script'leri (v9)

```haxe
import funkin.modding.module.Module;

class DemoModule extends funkin.modding.module.Module
{
	function new() { super('DemoModule'); }

	function onSongStart(event:Dynamic):Void { /* ... */ }
	function onBeatHit(event:Dynamic):Void { /* event.data = curBeat */ }
}
```

Module'ler startup'ta kurulur, state'ler arası yaşar ve PlayState'in
TÜM olaylarını alır. `this.active = false` yapılırsa olay almaz (FNF ile
aynı). Kurucu FNF imzasındadır: `new(moduleId, priority = 1000)`.

### 7. FunkinSprite script'leri (v9, temel)

```haxe
import funkin.graphics.FunkinSprite;

class OzellikliSprite extends funkin.graphics.FunkinSprite
{
	function new(x:Float, y:Float) { super(x, y); }
}
```

FNF'nin orijinal FunkinSprite'ı atlas/filtre/framebuffer sistemine
derinden bağlıdır; burada TEMEL shim var (FlxSprite + loadGraphicSimple,
loadSparrow, makeSolidColor, playAnim, getAnimName). Gelişmiş atlas
özellikleri yok. Örnekleme: `ScriptedFunkinSprite.scriptInit(cls, x, y)`.

### 8. FNF karakter JSON'u `scriptClass` alanı (v12)
V-Slice karakter JSON'unda `"scriptClass": "SinifAdi"` varsa, o karakter
kurulurken script DOĞRUDAN yüklenir (FNF birebir davranış):

```json
{ "assetPath": "shared:characters/whitty",
  "scale": 1.0,
  "scriptClass": "WhittyCharacter", ... }
```

Motor, `new Character('whitty')` anında önce id-index'ine bakar, yoksa
aktif modun JSON'undaki `scriptClass` ile script'i kurar. Script:

```haxe
import objects.Character;

class WhittyCharacter extends objects.Character
{
	function new(x:Float, y:Float, char:String, isPlayer:Bool)
	{
		super(x, y, char, isPlayer);
	}
	// override dance() / playAnim() / onBeatHit(event) ...
}
```

### 9. State/SubState script shim'leri (v12)

`funkin.ui.MusicBeatState` ve `funkin.ui.MusicBeatSubState` shim'leri +
`ScriptedMusicBeatState`/`ScriptedMusicBeatSubState` sarmalayıcıları hazır.
Script'ler `class X extends funkin.ui.MusicBeatState { ... }` yazabilir ve
`ScriptedMusicBeatState.scriptInit('X')` ile manuel kurulabilir. OTOMATİK
state script'i yükleme (FNF'deki MusicBeatState-instantiate) yol haritasında.

### 10. Module olayları tüm state'lerde (v12)

Module script'leri artık MENÜ state'lerinde de `onCreate`/`onUpdate`/
`onDestroy` alır (MusicBeatState üzerinden). Şarkı olayları
(onBeatHit/onNoteHit...) yalnızca PlayState'te anlamlıdır.

### 11. Cancelable onPause + event.note (v9)

- `onPause` olayında script `event.cancelled = true` yaparsa pause menüsü
  AÇILMAZ.
- Nota olaylarında (`onNoteHit`, `onNoteMiss`) `event.note` alanı da var
  (`event.data` ile aynı nota).
- Diğer olaylar bilgi taşır; iptal yalnızca onPause'da işlenir.

### 12. Import yönlendirmeleri (importOverrides)

Sık kullanılan FNF adları Further karşılıklarına otomatik yönlenir:
- `funkin.play.PlayState` / `funkin.PlayState` → `states.PlayState`
- `funkin.audio.FunkinSound` → `vslice.funkin.FunkinSound`
- `funkin.util.MathUtil` → `vslice.funkin.utils.MathUtil`

Başka adlar gerektiğinde `VSScriptRegistry.registerImportOverrides()`
genişletilir.

### 13. DCE kapatma + runtime sınıf çözümü (v13 — KRİTİK)

Polymod script sınıflarını **string adla** `Type.resolveClass` ile bulur.
Haxe'ın DCE'si (dead code elimination) motorun statik olarak kullanmadığı
her sınıfı ikiliden siler; sonuç: `Could not import funkin.modding.module.Module`
gibi "mevcut ama silinmiş" hataları. FNF aynı sorunu `project.hxp`'te şöyle
çözer (satır 1062-1066) — Further da birebir uygular:

```xml
<haxeflag name="-dce" value="no" />
<haxeflag name="--macro" value="include('funkin', true)" />
<haxeflag name="--macro" value="include('vslice.scripting', true)" />
```

- `-dce no` → HScript'in runtime'da çağırabileceği FONKSİYONLAR da kalır.
- `include('funkin', true)` → `funkin.*` shim'lerinin tamamı ikiliye girer.
- `include('vslice.scripting', true)` → Scripted* sarmalayıcıları ikiliye girer
  (bunlar resource+string ile çözülür, statik referansları yoktur).

⚠️ v13.1 DERSİ: `include('vslice', true)` KULLANMA — vslice/menus ve
vslice/stages altında hiç derlenmemiş ölü dosyalar var (`CrashState`,
`AttractState` — olmayan bir `vslice.menus.ui.title.TitleState` import eder;
`stages/standard/Template.hx` — `states.stages` package'ı ile yanlış yerde).
Tüm ağacı zorlamak "Type not found" ve "Invalid commandline class"
hataları tetikler. Menus/stages zaten statik referanslıdır, include istemez.

⚠️ v13.2 DERSİ (CNE makro çakışması): CNE'nin `ClassExtendMacro`'su
`Config.ALLOWED_CUSTOM_CLASSES = ["flixel", "funkin"]` yüzünden TÜM
funkin.* sınıflarına `_HSX` gölge sınıfı üretir. Yeni shim'lerimizde
polymod'un `HScriptedClass` arayüzüyle alan adları çakışıyordu
(`_asc`, `scriptCall`, `scriptGet`, ... — "Redefinition of variable _asc",
"Duplicate class field declaration" hataları). ÇÖZÜM: funkin.* shim'lerinin
hepsine `@:noCustomClass` eklendi (PEXO'nun CancellableEvent'te kullandığı
resmi kaçış anahtarı). Ayrıca `EventMacro` artık super zincirinde `recycle`
varsa `AOverride` + `super.recycle()` üretiyor (ScriptEvent →
CountdownScriptEvent gibi ara zincirler için).

SIRALAMA DÜZELTMESİ (v13): `importOverrides` artık `Polymod.init()`'ten
ÖNCE kaydedilir (`VSScriptRegistry.prepare()` — PolymodHandler.init'ten).
Önceki sürümde override'lar init'ten sonra geliyordu; mod script'leri
import'larını init sırasında çözdürdüğü için harita boş kalıyordu.

### 14. FNF event/stage shim'leri (v13)

FNF mod script'lerinin türetebildiği ek sınıflar:
- `funkin.play.stage.Stage` → `backend.BaseStage` shim'i
  (örn. Sunday'ın `garage` sahne script'i artık yüklenir)
- `funkin.play.event.SongEvent` + `funkin.play.event.ScriptedSongEvent`
  (özel şarkı olayları: `class X extends ScriptedSongEvent { ... }`)
- `funkin.modding.events.ScriptEvent` / `CountdownScriptEvent` /
  `StateChangeScriptEvent`
- `funkin.modding.base.ScriptedMusicBeatState`
  (FNF'nin `class X extends ScriptedMusicBeatState` sözdizimi)

### 15. Tam-yol extend + MINIMAL FNF shim kütüphanesi (v14)

**(a) Tam-yol extend düzeltmesi (polymod patch):** Port modlar (örn. Sunday
V-Slice Port) script'lerinde `class X extends funkin.play.event.SongEvent`
gibi TAM YOL yazar. `validateImports` yalnızca kısa-ada bakıyordu ve yanlış
"Could not extend" üretiyordu. Artık son bölümle kısa-ad import'una bakılıp
`fullPath` birebir eşleşiyorsa kabul edilir.

**(b) MINIMAL shim kütüphanesi:** 9 importOverride (funkin.Paths →
backend.Paths, funkin.Conductor → backend.Conductor, funkin.Highscore →
backend.Highscore, funkin.ui.title.TitleState → states.TitleState,
funkin.graphics.FunkinCamera → flixel.FlxCamera, HealthIcon →
objects.HealthIcon, NoteSprite → objects.Note, StrumlineNote →
objects.StrumNote, NoteSplash → objects.NoteSplash) + 17 MINIMAL stub
(`funkin.Preferences`, `funkin.util.Constants`/`WindowUtil`, `ModuleHandler`,
`PlayStatePlaylist`, `PopUpStuff`, `Scoring`, `CharacterDataParser`,
`CharacterType`/`CutsceneType` enum abstract'ları, `VideoCutscene`,
`NoteHoldCover`, `Strumline`, `NoteStyle`, `NoteKindManager`,
`NoteStyleRegistry`, `ScriptedFlxRuntimeShader`).

⚠️ Stub'lar MINIMAL'dir: import/tip çözümü tam, FNF API davranışı yoktur.
Script'ler stub metodlarını çağırırsa null/no-op alır (v1 kabulü).
Shader script'leri (`ScriptedFlxRuntimeShader` extend edenler) kapsam dışı.

## Script olayları (v2 — event dispatch)

FNF tarzı olay metodları script'lerde tanımlanabilir; motor bunları
otomatik çağırır. Olay objesi `{ type, cancelled, data }` yapısındadır;
`event.data` olaya özel veriyi taşır.

| Script fonksiyonu | Ne zaman | event.data |
|---|---|---|
| `onCreate(event)` | Karakterler/sahne kurulunca (create sonu) | — |
| `onCreatePost(event)` | createPost | — |
| `onUpdate(event)` / `onUpdatePost(event)` | her kare | elapsed |
| `onCountdownStart(event)` | geri sayım başlangıcı | — |
| `onCountdownStep(event)` | her geri sayım adımı | swagCounter |
| `onCountdownEnd(event)` | geri sayım bitti (startSong anı) | — |
| `onSongStart(event)` | şarkı başladı | — |
| `onSongEnd(event)` | şarkı bitti | — |
| `onBeatHit(event)` | her beat | curBeat |
| `onStepHit(event)` | her step | curStep |
| `onNoteHit(event)` | nota vuruldu (oyuncu veya CPU) | Note |
| `onNoteMiss(event)` | nota kaçtı | Note |
| `onNoteGhostMiss(event)` | ghost tap | key |
| `onPause(event)` / `onResume(event)` | duraklatma/açma | — |

Örnek (karakter script'i):

```haxe
function onBeatHit(event:Dynamic):Void
{
	this.scale.set(1.05, 1.05);
	flixel.tweens.FlxTween.tween(this.scale, {x: 1, y: 1}, 0.15, {ease: flixel.tweens.FlxEase.quadOut});
}
```

Olaylar şu hedeflere yayılır: dad, boyfriend, gf + tüm sahneler
(scripted karakter/stage'ler `scriptHas` yoklamasıyla yalnızca
tanımladıkları olayları alır; normal nesneler sessizce geçilir).

## Motor entegrasyonu

- `backend/PolymodHandler.init()` — `useScriptedClasses: true` +
  `VSScriptRegistry.initialize()` (script kaydı + importOverrides).
- `states/PlayState` — dad/bf/gf ve `changeCharacter` noktaları önce
  `VSScriptRegistry.resolveCharacter(...)` dener, scripted yoksa normal
  `new Character(...)` ile devam eder. Sahne seçimi de önce
  `resolveStage(curStage)` dener.
- `vslice/compatibility/script/VSliceScriptLoader` — class-tabanlı
  dosyaları Iris'e vermez (Polymod köprüsü yönetir).

## Demo

- `assets/scripts/DemoBf.hxc` — 'bf' karakterine bağlanan örnek script
  (dans tilti + onBeatHit ölçek vuruşu).
- `assets/scripts/DemoMilf.hxc` — 'milf' şarkısına bağlı scripted şarkı
  (hız +5%, HUD beat nabzı, onSongStart trace'i).
- `assets/scripts/DemoModule.hxc` — state'ler arası yaşayan module
  (şarkı başlangıcı/4. beat/şarkı sonu trace'leri).
Hepsini silersen etkiler kalkar.

## Bilinen sınırlamalar (v2)

- **Şarkı script'i sınırlı**: `onSongLoaded` ile chart mutasyonu çalışır,
  ama FNF'nin şarkı-metadata API'si (difficulty, variation, SongRegistry
  sorguları) yok — script yalnızca `states.PlayState.SONG` üzerinden çalışır.
- Olaylar **karakter, şarkı ve sahnelere** yayılır; scripted state/strumline
  hedefleri yok (ScriptedFlxState/ScriptedStrumline port edilmedi).
- Olay iptali yalnızca `onPause`'da motoru etkiler; diğer olaylarda
  `event.cancelled` bilgi taşır (FNF'deki tüm cancelable olaylar gibi değil).
- Module'ler PlayState olaylarını alır; diğer state'lerdeki (menü vb.)
  olaylar henüz yayılmaz.
- `funkin.graphics.FunkinSprite` TEMEL shim'dir; FNF'nin atlas/filtre
  API'sine bağımlı script'ler çalışmaz.
- **Karakter-script eşleşmesi id bazlı ve tektir**: bir script yalnızca
  indexleme anında kurulduğu tek bir karakter id'sine bağlanır.
- `funkin.graphics.FunkinSprite` shim'i yok (FNF sprite scriptleri
  animasyon verisi API'sine bağımlıdır; sonraki adım).
- Gerçek FNF modlarının scriptleri ek `funkin.*` shim'leri gerektirebilir;
  her mod için gereken adlar çalışma anında trace ile görülür.
- Android: `POLYMOD_ALLOWED` tanımlıdır; dosya taraması `sys` gerektirir
  (mobile build'lerde sorun çıkarsa `desktop`'a kısılabilir).

## Yol haritası

1. ~~ScriptEvent dispatch (onCreate/onNoteHit/... köprüsü)~~ ✅ v2
2. ~~ScriptedSong + şarkı verisi köprüsü~~ ✅ v3
3. ~~`funkin.graphics.FunkinSprite` + `funkin.modding.module.ScriptedModule` shim'leri~~ ✅ v9 (FunkinSprite temel seviyede)
4. ~~FNF karakter JSON'u `scriptClass` alanı~~ ✅ v12
5. ~~Menü state'lerine module olayları (onCreate/onUpdate/onDestroy)~~ ✅ v12
6. State/SubState shim'leri hazır (v12); OTOMATİK state script'i yükleme kaldı.
7. Karakter script'lerinde çoklu-id eşleşmesi (script kendini birden çok
   id için ilan edebilsin).
8. ScriptedStrumline + tüm olaylarda cancelable destek.
9. 🔶 Geniş `funkin.*` shim kütüphanesi — v14'te MINIMAL temel atıldı
   (9 alias + 17 stub); tam API davranışı (nota/strumline/cutscene sistemleri)
   hâlâ eksik.
10. ~~Tam-yol extend çözümlemesi (port modların `extends funkin.play.event.X`
    sözdizimi)~~ ✅ v14 (polymod validateImports patch)
