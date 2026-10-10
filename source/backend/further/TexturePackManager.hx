package backend.further;

import backend.further.TexturePackTypes;
import backend.Mods;
import backend.Paths;
import backend.SafeMode;
import haxe.Json;
import flixel.util.FlxColor;

/**
 * Global Texture Pack yöneticisi.
 *
 * Öncelik zinciri (yüksekten düşüğe):
 *   Texture Pack yığını (son → ilk; dosya bazlı, tema: en üst kazanır)
 *   → aktif modlar (Psych davranışı) → motor varsayılanları.
 *
 * Tek hook noktası: Paths.modFolders() + Paths.fileExistsUncached().
 * Kural sözleşmesi: docs/TEXTUREPACK_TR.md
 */
class TexturePackManager
{
	public static var packs:Array<TexturePack> = [];

	/** Yığın: index 0 = ALT (kaybeden), son index = ÜST (kazanan). */
	static var stack:Array<TexturePackStackEntry> = [];
	static var activeCache:Array<TexturePack> = [];
	static var suspendCache:Map<String, Bool> = new Map();
	static var candidates:Array<String> = [];
	static var initialized:Bool = false;

	public static function init():Void
	{
		TexturePackPaths.ensureDirectories();
		loadConfig();
		rescan();
		initialized = true;
		applyTheme();
		if (packs.length > 0)
			trace('[TexturePack] ${packs.length} paket yüklendi, aktif yığın: ${getActiveStack().length}');
	}

	public static function rescan():Void
	{
		packs = [];
		var root:String = TexturePackPaths.getPacksDirectory();
		if (sys.FileSystem.exists(root))
		{
			for (folder in Paths.readDirectory(root))
			{
				if (folder == null || folder.length == 0 || folder == 'texturepacks.json')
					continue;
				var dir:String = root + folder;
				if (!sys.FileSystem.isDirectory(dir))
					continue;
				var manifestPath:String = dir + '/texturepack.json';
				if (!sys.FileSystem.exists(manifestPath))
					continue;
				try
				{
					var man:TexturePackManifest = cast Json.parse(Paths.readTextFileBom(manifestPath));
					if (man == null || man.id == null || man.id.length == 0)
						continue;
					var theme:TexturePackTheme = null;
					var themePath:String = dir + '/theme.json';
					if (sys.FileSystem.exists(themePath))
					{
						try
						{
							theme = cast Json.parse(Paths.readTextFileBom(themePath));
						}
						catch (e:Dynamic)
						{
							trace('[TexturePack] theme.json bozuk: $folder');
							theme = null;
						}
					}
					packs.push(new TexturePack(man.id, TexturePackPaths.normalizeDir(dir), man, theme));
				}
				catch (e:Dynamic)
				{
					trace('[TexturePack] texturepack.json bozuk: $folder → ' + Std.string(e));
				}
			}
		}
		reconcileStack();
		rebuildActiveCache();
	}

	// ______________________________ Yığın yönetimi ______________________________

	static function reconcileStack():Void
	{
		var known:Map<String, Bool> = new Map();
		for (p in packs)
			known.set(p.id, true);

		var newStack:Array<TexturePackStackEntry> = [];
		for (e in stack)
			if (e != null && e.id != null && known.exists(e.id))
				newStack.push(e);

		for (p in packs)
		{
			var found:Bool = false;
			for (e in newStack)
				if (e.id == p.id)
				{
					found = true;
					break;
				}
			// Yeni kurulan paket en üste (kullanıcı etkiyi hemen görsün).
			if (!found)
				newStack.push({id: p.id, enabled: true});
		}
		stack = newStack;
		saveConfig();
	}

	static function rebuildActiveCache():Void
	{
		activeCache = [];
		for (e in stack)
		{
			if (e.enabled == false)
				continue;
			var p:TexturePack = findPack(e.id);
			if (p != null)
				activeCache.push(p);
		}
	}

	public static function findPack(id:String):TexturePack
	{
		for (p in packs)
			if (p.id == id)
				return p;
		return null;
	}

	/** Etkin paketler — ALT'tan ÜST'e. */
	public static function getActiveStack():Array<TexturePack>
		return activeCache;

	/** Tüm paketler + yığın durumu (UI için). */
	public static function getStackOrder():Array<TexturePackStackEntry>
		return stack;

	public static function isEnabled(id:String):Bool
	{
		for (e in stack)
			if (e.id == id)
				return e.enabled != false;
		return false;
	}

	public static function setEnabled(id:String, enabled:Bool):Void
	{
		for (e in stack)
			if (e.id == id)
			{
				e.enabled = enabled;
				break;
			}
		rebuildActiveCache();
		saveConfig();
		applyTheme();
	}

	/** Yukarı = öncelik artsın (yığının üstüne). */
	public static function moveUp(id:String):Void
	{
		for (i in 0...stack.length - 1)
			if (stack[i].id == id)
			{
				var tmp = stack[i];
				stack[i] = stack[i + 1];
				stack[i + 1] = tmp;
				break;
			}
		rebuildActiveCache();
		saveConfig();
		applyTheme();
	}

	public static function moveDown(id:String):Void
	{
		for (i in 1...stack.length)
			if (stack[i].id == id)
			{
				var tmp = stack[i];
				stack[i] = stack[i - 1];
				stack[i - 1] = tmp;
				break;
			}
		rebuildActiveCache();
		saveConfig();
		applyTheme();
	}

	static function loadConfig():Void
	{
		stack = [];
		var path:String = TexturePackPaths.getStackConfigPath();
		if (sys.FileSystem.exists(path))
		{
			try
			{
				var cfg:TexturePackStackConfig = cast Json.parse(Paths.readTextFileBom(path));
				if (cfg != null && cfg.stack != null)
				{
					for (e in cfg.stack)
						if (e != null && e.id != null)
							stack.push({id: e.id, enabled: e.enabled != false});
				}
			}
			catch (e:Dynamic)
			{
				trace('[TexturePack] texturepacks.json okunamadı: ' + Std.string(e));
			}
		}
	}

	static function saveConfig():Void
	{
		var cfg:TexturePackStackConfig = {stack: stack};
		try
		{
			sys.io.File.saveContent(TexturePackPaths.getStackConfigPath(), Json.stringify(cfg, "\t"));
		}
		catch (e:Dynamic)
		{
			trace('[TexturePack] texturepacks.json yazılamadı: ' + Std.string(e));
		}
		invalidateCaches();
	}

	static function invalidateCaches():Void
	{
		Paths.clearFileExistsCache();
		Paths.invalidateExistsCache();
	}

	// ______________________________ Çözümleme ______________________________

	/**
	 * Tam deneyim modları: pack.json içine "ignoreTexturePacks": true yazan mod
	 * oynarken yığın oturum boyunca askıya alınır.
	 */
	public static function isSuspended():Bool
	{
		#if MODS_ALLOWED
		var mod:String = Mods.currentModDirectory;
		if (mod == null || mod.length == 0)
			return false;
		var cached:Null<Bool> = suspendCache.get(mod);
		if (cached != null)
			return cached;
		var result:Bool = false;
		try
		{
			var pack:Dynamic = Mods.getPack(mod);
			if (pack != null && Reflect.field(pack, 'ignoreTexturePacks') == true)
				result = true;
		}
		catch (e:Dynamic) {}
		suspendCache.set(mod, result);
		return result;
		#else
		return false;
		#end
	}

	/**
	 * Asset anahtarını (ör: 'images/mainmenu/menu_story_mode.png',
	 * 'shared/images/menuBG.png', 'fonts/vcr.ttf') yığında arar.
	 * Bulursa mutlak dosya yolu, bulamazsa null döner.
	 */
	public static function resolve(key:String):Null<String>
	{
		if (key == null || key.length == 0)
			return null;
		if (SafeMode.active)
			return null;
		if (activeCache.length == 0)
			return null;
		if (isSuspended())
			return null;

		var norm:Array<String> = normalizeKey(key);
		var i:Int = activeCache.length - 1;
		while (i >= 0)
		{
			var p:TexturePack = activeCache[i];
			for (cand in norm)
			{
				var full:String = p.root + cand;
				if (Paths.existsCached(full))
					return full;
			}
			var remap:Null<String> = themeRemap(p, key);
			if (remap != null && Paths.existsCached(remap))
				return remap;
			i--;
		}
		return null;
	}

	static inline var SHARED_PREFIX:String = 'shared/';

	static var ROOT_FOLDERS:Array<String> = [
		'images', 'music', 'sounds', 'fonts', 'data', 'videos', 'stages',
		'characters', 'weeks', 'shaders', 'scripts', 'achievements', 'registry',
		'other', 'songs'
	];

	/**
	 * Anahtar adayları: ham anahtar → 'shared/' sökülmüş → ilk segment
	 * klasör/hafta klasörüyse sökülmüş. Böylece paketler mods/ gibi DÜZ
	 * yerleşim kullanabilir (images/..., music/...).
	 */
	static function normalizeKey(key:String):Array<String>
	{
		candidates.resize(0);
		candidates.push(key);
		var k:String = key;
		if (StringTools.startsWith(k, SHARED_PREFIX))
			k = k.substr(SHARED_PREFIX.length);
		if (k != key)
			candidates.push(k);
		var slash:Int = k.indexOf('/');
		if (slash > 0)
		{
			var first:String = k.substr(0, slash);
			if (!ROOT_FOLDERS.contains(first))
				candidates.push(k.substr(slash + 1));
		}
		return candidates;
	}

	/** theme.json eşlemeleri: font takası ve menü müziği takası. */
	static function themeRemap(p:TexturePack, key:String):Null<String>
	{
		if (p == null || p.theme == null)
			return null;

		if (p.theme.fonts != null && StringTools.startsWith(key, 'fonts/'))
		{
			var fname:String = key.substr(6);
			var target:Dynamic = Reflect.field(p.theme.fonts, fname);
			if (target == null && fname == 'vcr.ttf')
				target = Reflect.field(p.theme.fonts, 'default');
			if (target != null)
				return p.root + Std.string(target);
		}

		if (p.theme.menuMusic != null && StringTools.startsWith(key, 'music/freakyMenu'))
		{
			var t:String = p.theme.menuMusic;
			if (t.indexOf('.') == -1)
				t += '.' + Paths.SOUND_EXT;
			return p.root + t;
		}
		return null;
	}

	// ______________________________ Tema ______________________________

	/**
	 * Tema renkleri: yığının en üstündeki theme.json.colors kazanır
	 * (kanal bazlı: yazmayan kanal bir alttakine düşer).
	 */
	public static function applyTheme():Void
	{
		var a:Null<FlxColor> = null;
		var b:Null<FlxColor> = null;
		var t:Null<FlxColor> = null;
		var i:Int = activeCache.length - 1;
		while (i >= 0)
		{
			var th:TexturePackTheme = activeCache[i].theme;
			if (th != null && th.colors != null)
			{
				if (a == null && th.colors.accent != null)
					a = parseColor(th.colors.accent);
				if (b == null && th.colors.background != null)
					b = parseColor(th.colors.background);
				if (t == null && th.colors.text != null)
					t = parseColor(th.colors.text);
			}
			i--;
		}
		Theme.set(a, b, t);
	}

	/** '#RRGGBB', '#AARRGGBB', '0x...' destekler. */
	public static function parseColor(s:String):Null<FlxColor>
	{
		if (s == null || s.length == 0)
			return null;
		s = StringTools.trim(s);
		if (StringTools.startsWith(s, '#'))
			s = s.substr(1);
		else if (StringTools.startsWith(s, '0x') || StringTools.startsWith(s, '0X'))
			s = s.substr(2);
		var val:Null<Int> = Std.parseInt('0x' + s);
		if (val == null)
			return null;
		if (s.length <= 6)
			val = val | 0xFF000000;
		return cast val;
	}
}
