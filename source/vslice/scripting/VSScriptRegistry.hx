package vslice.scripting;

#if POLYMOD_ALLOWED
import sys.FileSystem;
import sys.io.File;
import backend.Mods;
import backend.Paths;
import objects.Character;
import backend.BaseStage;
import polymod.hscript._internal.PolymodScriptClass;
import polymod.hscript._internal.Interp as PolymodInterp;

/**
 * VSScriptRegistry — V-Slice (Polymod) class-tabanlı `.hxc` script'lerinin
 * Further'daki merkezi kayıt ve çözümleme noktası.
 *
 * GÖREVLER:
 *   1. `funkin.*` import adlarını Further'daki karşılıklara yönlendir (importOverrides).
 *   2. Psych tarzı mod klasörlerindeki (`mods/<mod>/scripts/...`) class-tabanlı
 *      `.hxc`/`.hx` dosyalarını Polymod köprüsüne elle kaydet.
 *      (Polymod kendi modlarını `useScriptedClasses: true` ile zaten tarar.)
 *   3. PlayState'in ihtiyacı olan çözümlemeleri sağlar:
 *      - resolveCharacter(x, y, char, isPlayer): scripted karakter varsa örnek döner.
 *      - resolveStage(stageName): adı eşleşen scripted sahneyi kurar.
 */
class VSScriptRegistry
{
	/** karakterId -> { cls, oneArg, wrapper } önbelleği */
	static var charIndex:Map<String, {cls:String, oneArg:Bool, wrapper:Class<Dynamic>}> = null;

	/** Kayıt edilmiş dosya yolları (çift kaydı önler). */
	static var registeredPaths:Array<String> = [];

	/**
	 * PolymodHandler.init() başarıyla bittikten sonra çağrılır.
	 * Hem polymod modları hem Psych tarzı modlar için köprüyü hazırlar.
	 */
	public static function initialize():Void
	{
		registerImportOverrides();
		registerManualFolders();
		PolymodInterp.validateImports();
		buildModules();
	}

	/**
	 * Polymod.init()'ten ÖNCE çağrılır (PolymodHandler.init).
	 * Mod script'leri init sırasında import'larını hemen çözdürdüğü için
	 * override haritası o anda hazır olmalı. Assets script kaydı burada
	 * yapılmaz: Polymod.init önceden kayıtlı script'leri temizler.
	 */
	public static function prepare():Void
	{
		registerImportOverrides();
	}

	/**
	 * FNF mod script'lerinin en sık import ettiği `funkin.*` adlarını
	 * Further'daki gerçek karşılıklara yönlendirir.
	 */
	public static function registerImportOverrides():Void
	{
		PolymodScriptClass.importOverrides.set('funkin.play.PlayState', states.PlayState);
		PolymodScriptClass.importOverrides.set('funkin.PlayState', states.PlayState);
		PolymodScriptClass.importOverrides.set('funkin.audio.FunkinSound', vslice.funkin.FunkinSound);
		PolymodScriptClass.importOverrides.set('funkin.util.MathUtil', vslice.funkin.utils.MathUtil);

		// v14: FNF mod'larinin sik kullandigi siniflar -> Psych karsiliklari
		// (tip cozumu icin; metod seviyesinde farkliliklar olabilir, v1).
		PolymodScriptClass.importOverrides.set('funkin.Paths', backend.Paths);
		PolymodScriptClass.importOverrides.set('funkin.Conductor', backend.Conductor);
		PolymodScriptClass.importOverrides.set('funkin.Highscore', backend.Highscore);
		PolymodScriptClass.importOverrides.set('funkin.ui.title.TitleState', states.TitleState);
		PolymodScriptClass.importOverrides.set('funkin.graphics.FunkinCamera', flixel.FlxCamera);
		PolymodScriptClass.importOverrides.set('funkin.play.components.HealthIcon', objects.HealthIcon);
		PolymodScriptClass.importOverrides.set('funkin.play.notes.NoteSprite', objects.Note);
		PolymodScriptClass.importOverrides.set('funkin.play.notes.StrumlineNote', objects.StrumNote);
		PolymodScriptClass.importOverrides.set('funkin.play.notes.NoteSplash', objects.NoteSplash);
	}

	/**
	 * Psych tarzı modlar + temel assets içindeki class-tabanlı `.hxc`/`.hx`
	 * dosyalarını tarar ve Polymod köprüsüne kaydeder.
	 */
	static function registerManualFolders():Void
	{
		var roots:Array<String> = ['assets/'];
		#if MODS_ALLOWED
		for (d in Mods.parseList().enabled) roots.push(Paths.mods(d + '/'));
		for (d in Mods.getGlobalMods()) roots.push(Paths.mods(d + '/'));
		#end

		for (root in roots)
		{
			registerFolder(root + 'scripts/');
			registerFolder(root + 'data/scripts/');
			registerFolder(root + 'data/characters/');
			registerFolder(root + 'data/stages/');
		}
	}

	static function registerFolder(dir:String):Void
	{
		if (dir == null || !FileSystem.exists(dir)) return;
		for (file in FileSystem.readDirectory(dir))
		{
			if (file == null) continue;
			var lower:String = file.toLowerCase();
			if (!lower.endsWith('.hxc') && !lower.endsWith('.hx')) continue;
			var full:String = dir + file;
			if (FileSystem.isDirectory(full)) continue;
			registerScriptFile(full);
		}
	}

	/**
	 * Bir `.hxc`/`.hx` dosyasını köprüye kaydeder (class içermiyorsa atlar —
	 * düz fonksiyon script'leri Iris/VSliceScriptLoader'a kalır).
	 */
	public static function registerScriptFile(path:String):Bool
	{
		if (path == null || registeredPaths.contains(path)) return false;
		var text:String = null;
		try { text = File.getContent(path); }
		catch (e:Dynamic) { return false; }
		if (text == null || text.indexOf('class ') < 0) return false;
		try
		{
			PolymodScriptClass.registerScriptClassByString(text, path);
			registeredPaths.push(path);
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[VSScriptRegistry] Kayit hatasi: $path — $e');
			return false;
		}
	}

	/** Daha sonra eklenen kayıtlar için import doğrulamasını tazeler. */
	public static function validateNow():Void
	{
		PolymodInterp.validateImports();
	}

	/* ============================== KARAKTER ============================== */

	static function buildCharIndex():Void
	{
		if (charIndex != null) return;
		charIndex = new Map<String, {cls:String, oneArg:Bool, wrapper:Class<Dynamic>}>();

		indexWrapper(ScriptedCharacter, false);
		indexWrapper(ScriptedBaseCharacter, true);
		indexWrapper(ScriptedSparrowCharacter, true);
		indexWrapper(ScriptedPackerCharacter, true);
		indexWrapper(ScriptedAnimateAtlasCharacter, true);
		indexWrapper(ScriptedMultiSparrowCharacter, true);
		indexWrapper(ScriptedMultiAnimateAtlasCharacter, true);
	}

	static function indexWrapper(wrapper:Class<Dynamic>, oneArg:Bool):Void
	{
		var names:Array<String> = null;
		try
		{
			names = cast Reflect.callMethod(wrapper, Reflect.field(wrapper, 'listScriptClasses'), []);
		}
		catch (e:Dynamic)
		{
			trace('[VSScriptRegistry] Script listesi alinamadi: ${Type.getClassName(wrapper)} — $e');
			return;
		}
		if (names == null) return;

		for (cls in names)
		{
			var args:Array<Dynamic> = oneArg ? [cls, 'bf'] : [cls, 0, 0, 'bf', false];
			try
			{
				var inst:Dynamic = Reflect.callMethod(wrapper, Reflect.field(wrapper, 'scriptInit'), args);
				if (inst != null && inst.curCharacter != null)
				{
					charIndex.set(Std.string(inst.curCharacter), {cls: cls, oneArg: oneArg, wrapper: wrapper});
					try { inst.destroy(); } catch (e:Dynamic) {}
				}
			}
			catch (e:Dynamic)
			{
				trace('[VSScriptRegistry] Scripted karakter kurulamadi: $cls — $e');
			}
		}
	}

	/**
	 * `char` id'sine bağlı scripted karakter varsa yeni bir örneğini kurar;
	 * yoksa null döner (çağıran taraf `new Character(...)` ile devam eder).
	 *
	 * İki yol denenir:
	 *   1. Indexlenmiş script (script, o karakter id'si ile kurulmuştu).
	 *   2. FNF tarzı: aktif modun V-Slice karakter JSON'undaki `scriptClass`
	 *      tam sınıf adı -> doğrudan kurulur.
	 */
	public static function resolveCharacter(x:Float, y:Float, char:String, isPlayer:Bool = false):Null<Character>
	{
		if (char == null) return null;
		buildCharIndex();
		var entry = charIndex.get(char);
		if (entry != null)
		{
			var args:Array<Dynamic> = entry.oneArg ? [entry.cls, char] : [entry.cls, x, y, char, isPlayer];
			try
			{
				var inst:Dynamic = Reflect.callMethod(entry.wrapper, Reflect.field(entry.wrapper, 'scriptInit'), args);
				if (inst != null) return cast inst;
			}
			catch (e:Dynamic)
			{
				trace('[VSScriptRegistry] Scripted karakter kurulamadi: ${entry.cls} — $e');
			}
			return null;
		}

		#if MODS_ALLOWED
		var sc:String = findScriptClassForCharacter(char);
		if (sc != null)
		{
			try
			{
				var inst:Dynamic = ScriptedCharacter.scriptInit(sc, x, y, char, isPlayer);
				if (inst != null) return cast inst;
			}
			catch (e:Dynamic)
			{
				trace('[VSScriptRegistry] scriptClass kurulamadi: $sc — $e');
			}
		}
		#end
		return null;
	}

	/** Aktif mod(lar)ın V-Slice karakter JSON'undaki `scriptClass` alanını arar. */
	static function findScriptClassForCharacter(char:String):String
	{
		#if MODS_ALLOWED
		var ids:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			ids.push(Mods.currentModDirectory);
		for (g in Mods.getGlobalMods())
			ids.push(g);

		for (mod in ids)
		{
			var j:Dynamic = null;
			try { j = vslice.compatibility.VSliceCharacterConverter.convertFromMod(mod, char); }
			catch (e:Dynamic) { continue; }
			if (j != null && Reflect.field(j, 'scriptClass') != null)
				return Std.string(Reflect.field(j, 'scriptClass'));
		}
		#end
		return null;
	}

	/* =============================== SAHNE =============================== */

	/**
	 * Adı `stageName` ile eşleşen scripted sahneyi kurar; yoksa null.
	 * Sözleşme: script sınıfının adı sahne adına eşit olmalı (örn. Mall -> "mall").
	 */
	public static function resolveStage(stageName:String):Null<BaseStage>
	{
		if (stageName == null || stageName.length == 0) return null;
		var names:Array<String> = null;
		try { names = ScriptedStage.listScriptClasses(); }
		catch (e:Dynamic) { return null; }
		if (names == null || names.length == 0) return null;

		var lower:String = stageName.toLowerCase();
		for (cls in names)
		{
			if (cls.toLowerCase() == lower)
			{
				try { return ScriptedStage.scriptInit(cls); }
				catch (e:Dynamic)
				{
					trace('[VSScriptRegistry] Scripted sahne kurulamadi: $cls — $e');
					return null;
				}
			}
		}
		return null;
	}

	/* ============================== MODULE ============================== */

	/** Startup'ta kurulan scripted module'ler (state'ler arası yaşar). */
	public static var modules:Array<funkin.modding.module.Module> = [];

	static var modulesBuilt:Bool = false;

	static function buildModules():Void
	{
		if (modulesBuilt) return;
		modulesBuilt = true;

		var names:Array<String> = null;
		try { names = ScriptedModule.listScriptClasses(); }
		catch (e:Dynamic) { return; }
		if (names == null) return;

		for (cls in names)
		{
			try
			{
				var inst:Dynamic = ScriptedModule.scriptInit(cls, cls, 1000);
				if (inst != null && inst.active != null)
					modules.push(cast inst);
			}
			catch (e:Dynamic)
			{
				trace('[VSScriptRegistry] Scripted module kurulamadi: $cls — $e');
			}
		}
	}

	/* =============================== ŞARKI =============================== */

	/** songId (küçük harf) -> script sınıf adı */
	static var songIndex:Map<String, String> = null;

	static function buildSongIndex():Void
	{
		if (songIndex != null) return;
		songIndex = new Map<String, String>();
		var names:Array<String> = null;
		try { names = ScriptedSong.listScriptClasses(); }
		catch (e:Dynamic) { return; }
		if (names == null) return;

		for (cls in names)
		{
			try
			{
				var inst:Dynamic = ScriptedSong.scriptInit(cls, cls);
				if (inst != null)
					songIndex.set(cls.toLowerCase(), cls);
			}
			catch (e:Dynamic)
			{
				trace('[VSScriptRegistry] Scripted song kurulamadi: $cls — $e');
			}
		}
	}

	/**
	 * `songId` ile eşleşen scripted şarkıyı kurar; yoksa null.
	 * Sözleşme: script sınıfının adı şarkı id'sine eşit olmalı.
	 */
	public static function resolveSong(songId:String):Null<funkin.play.song.Song>
	{
		if (songId == null) return null;
		buildSongIndex();
		var cls:String = songIndex.get(songId.toLowerCase());
		if (cls == null) return null;
		try { return ScriptedSong.scriptInit(cls, cls); }
		catch (e:Dynamic)
		{
			trace('[VSScriptRegistry] Scripted song kurulamadi: $cls — $e');
			return null;
		}
	}

	/**
	 * Scripted şarkının `isSongNew()` override'ını yoklar:
	 * script'te tanımlıysa sonucunu döner, yoksa null.
	 * (Freeplay "NEW" rozeti bunu kullanır.)
	 */
	public static function scriptedSongIsNew(songId:String):Null<Bool>
	{
		if (songId == null) return null;
		buildSongIndex();
		var cls:String = songIndex.get(songId.toLowerCase());
		if (cls == null) return null;

		var inst:funkin.play.song.Song = null;
		try { inst = ScriptedSong.scriptInit(cls, cls); }
		catch (e:Dynamic) { return null; }
		if (inst == null) return null;

		try
		{
			var t:IHScriptedEvents = cast inst;
			if (!t.scriptHas('isSongNew')) return null;
			var v:Dynamic = t.scriptCall('isSongNew', []);
			return (v == true);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
}
#end
