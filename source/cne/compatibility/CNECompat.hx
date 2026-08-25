package cne.compatibility;

import backend.Mods;
import backend.Paths;
import haxe.Json;

#if sys
import sys.FileSystem;
#end

/**
 * CNECompat — Codename Engine (CNE) mod tespiti ve asset yol yardımcıları.
 *
 * Codename Engine modlarının fiziksel düzeni (assets ağacı DOĞRUDAN mod
 * kökündedir; CNE'deki 'assets/' yalnızca sanal yol önekidir):
 *
 *   mods/MyMod/
 *     data/characters/*.xml        mods/MyMod/data/stages/*.xml
 *     data/weeks/weeks/*.xml       data/config/modpack.ini
 *     songs/<şarkı>/charts/*.json  songs/<şarkı>/meta.json
 *     songs/<şarkı>/song/Inst.ogg  songs/<şarkı>/song/Voices.ogg
 *     images/  music/  sounds/  fonts/  videos/  shaders/ ...
 *
 * Ayrıca '<mod>/assets/' altına sarılmış düzenler de desteklenir.
 *
 * Bu sınıf:
 *   - Bir mod klasörünün CNE modu olup olmadığını Psych modlarıyla
 *     çakışmayacak marker'larla (önbellekli) tespit eder.
 *   - `Paths.modFolders` ve arkadaşlarının kullanması için `cneFile()`
 *     çözümlemesini sunar.
 *   - Şarkı (chart/meta/ses), karakter XML'i, sahne XML'i bulma yardımcıları
 *     sağlar (büyük/küçük harf duyarsız).
 *
 * ÖNEMLİ: Bu sınıf yalnızca dosya sistemi çözümlemesi yapar; içeriği Psych
 * formatına çevirme işi CNECharacterConverter / CNEStageConverter /
 * CNESongConverter / CNEWeekConverter sınıflarındadır.
 *
 * HScript/Lua script desteği, ZIP modlar ve CNE addon'ları KAPSAM DIŞIDIR.
 */
class CNECompat
{
	static var _modCache:Map<String, Bool> = new Map();
	static var _rootCache:Map<String, String> = new Map();
	static var _metaCache:Map<String, Dynamic> = new Map();

	/** Önbellekleri sıfırlar (mod listesi değiştiğinde çağrılmalı). */
	public static function invalidate():Void
	{
		_modCache = new Map();
		_rootCache = new Map();
		_metaCache = new Map();
	}

	/** Klasör bir Codename Engine modu mu? */
	public static function isCNEMod(folder:String):Bool
	{
		return cneRoot(folder) != null;
	}

	/**
	 * CNE modunun fiziksel asset kökünü döndürür (mutlak yol), CNE modu
	 * değilse null. Sonuç önbelleğe alınır.
	 */
	public static function cneRoot(folder:String):String
	{
		if (folder == null || folder.length < 1) return null;
		#if (MODS_ALLOWED && sys)
		if (_modCache.exists(folder))
			return _rootCache.get(folder);

		var result:String = null;
		try
		{
			var base:String = Paths.mods(folder);
			if (hasCNEMarkers(base))
				result = base;
			else
			{
				var wrapped:String = base + '/assets';
				if (FileSystem.exists(wrapped) && FileSystem.isDirectory(wrapped) && hasCNEMarkers(wrapped))
					result = wrapped;
			}
		}
		catch (e:Dynamic) {}

		_modCache.set(folder, result != null);
		_rootCache.set(folder, result);
		return result;
		#else
		return null;
		#end
	}

	/**
	 * Bir klasörün CNE asset ağacı olup olmadığını gösteren işaretler.
	 * Psych modlarıyla çakışmayacak kadar spesifik seçildiler:
	 *   - data/config/modpack.ini (CNE mod yapılandırması)
	 *   - data/weeks/weeks/ klasörü (CNE hafta XML'leri)
	 *   - songs/<şarkı>/charts/ klasörü (CNE chart düzeni)
	 *   - data/stages/*.xml veya data/characters/*.xml
	 */
	static function hasCNEMarkers(base:String):Bool
	{
		#if (MODS_ALLOWED && sys)
		if (base == null || !FileSystem.exists(base)) return false;

		if (FileSystem.exists(base + '/data/config/modpack.ini')) return true;
		if (FileSystem.exists(base + '/data/weeks/weeks')) return true;

		try
		{
			var songsDir:String = base + '/songs/';
			if (FileSystem.exists(songsDir) && FileSystem.isDirectory(songsDir))
			{
				for (sub in FileSystem.readDirectory(songsDir))
				{
					var full:String = songsDir + sub;
					if (FileSystem.isDirectory(full) && FileSystem.exists(full + '/charts'))
						return true;
				}
			}
		}
		catch (e:Dynamic) {}

		for (sub in ['data/stages/', 'data/characters/'])
		{
			try
			{
				var dir:String = base + '/' + sub;
				if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;
				for (f in FileSystem.readDirectory(dir))
					if (StringTools.endsWith(f.toLowerCase(), '.xml')) return true;
			}
			catch (e:Dynamic) {}
		}
		#end
		return false;
	}

	/**
	 * `<kök>/<key>` yolu varsa döndürür (dosya veya klasör), yoksa null.
	 * Psych yolları her zaman önce denenmelidir; bu yalnızca CNE köprüsüdür.
	 */
	public static function cneFile(mod:String, key:String):String
	{
		#if (MODS_ALLOWED && sys)
		var root:String = cneRoot(mod);
		if (root == null) return null;
		var p:String = root + '/' + key;
		if (FileSystem.exists(p)) return p;
		#end
		return null;
	}

	/**
	 * CNE varlıkları aranırken kullanılacak mod sırası:
	 * aktif mod > global modlar > modsList.txt sırası.
	 */
	public static function modSearchOrder():Array<String>
	{
		var list:Array<String> = [];
		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			list.push(Mods.currentModDirectory);
		try
		{
			for (mod in Mods.getGlobalMods())
				if (!list.contains(mod)) list.push(mod);
		}
		catch (e:Dynamic) {}
		try
		{
			for (mod in Mods.parseList().enabled)
				if (!Mods.isBlocked(mod) && !list.contains(mod)) list.push(mod);
		}
		catch (e:Dynamic) {}
		#end
		return list;
	}

	/** Psych/CNE şarkı adı normalizasyonu (küçük harf, boşluk -> tire). */
	public static function normalizeSong(name:String):String
	{
		if (name == null) return '';
		return StringTools.trim(name).toLowerCase().split(' ').join('-');
	}

	/** Moddaki şarkı klasörünü büyük/küçük harf duyarsız bulur. */
	public static function songDir(mod:String, song:String):String
	{
		#if (MODS_ALLOWED && sys)
		var root:String = cneRoot(mod);
		if (root == null) return null;
		var base:String = root + '/songs/';
		if (!FileSystem.exists(base) || !FileSystem.isDirectory(base)) return null;
		var want:String = normalizeSong(song);
		try
		{
			for (dir in FileSystem.readDirectory(base))
			{
				if (normalizeSong(dir) != want) continue;
				var full:String = base + dir;
				if (FileSystem.isDirectory(full)) return full;
			}
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	/**
	 * Bir CNE şarkısının chart dosyasını bulur: `<kök>/songs/<song>/charts/<difficulty>.json`.
	 * İstenen zorluk yoksa sırasıyla normal > hard > easy > ilk json kullanılır.
	 */
	public static function findChartFile(mod:String, song:String, ?difficulty:String):String
	{
		#if (MODS_ALLOWED && sys)
		var dir:String = songDir(mod, song);
		if (dir == null) return null;
		var chartsDir:String = dir + '/charts/';
		if (!FileSystem.exists(chartsDir) || !FileSystem.isDirectory(chartsDir)) return null;

		var jsons:Array<String> = [];
		try
		{
			for (f in FileSystem.readDirectory(chartsDir))
				if (StringTools.endsWith(f.toLowerCase(), '.json')) jsons.push(f);
		}
		catch (e:Dynamic) {}
		if (jsons.length < 1) return null;

		var want:String = (difficulty != null && difficulty.length > 0) ? difficulty.toLowerCase() : 'normal';
		for (f in jsons)
			if (haxe.io.Path.withoutExtension(f).toLowerCase() == want) return chartsDir + f;
		for (fallback in ['normal', 'hard', 'easy'])
			for (f in jsons)
				if (haxe.io.Path.withoutExtension(f).toLowerCase() == fallback) return chartsDir + f;
		return chartsDir + jsons[0];
		#else
		return null;
		#end
	}

	/** `<kök>/songs/<song>/meta.json` içeriği (önbellekli, yoksa null). */
	public static function getSongMeta(mod:String, song:String):Dynamic
	{
		#if (MODS_ALLOWED && sys)
		var key:String = mod + '::' + normalizeSong(song);
		if (_metaCache.exists(key)) return _metaCache.get(key);
		var meta:Dynamic = null;
		var dir:String = songDir(mod, song);
		if (dir != null && FileSystem.exists(dir + '/meta.json'))
		{
			try meta = Json.parse(File.getContent(dir + '/meta.json'))
			catch (e:Dynamic) meta = null;
		}
		_metaCache.set(key, meta);
		return meta;
		#else
		return null;
		#end
	}

	/**
	 * CNE şarkı sesini bulur. CNE sesleri `songs/<song>/song/` altında tutar:
	 * `Inst.ogg`, `Inst-<difficulty>.ogg`, `Voices.ogg` (+ meta.json içindeki
	 * `instSuffix` / `vocalsSuffix` türevleri).
	 *
	 * @param song       Şarkı adı
	 * @param base       'Inst' veya 'Voices'
	 * @param difficulty Zorluk adı (ör. 'hard'); opsiyonel
	 * @param mod        Belirli bir modda ara; null ise modSearchOrder() kullanılır
	 */
	public static function findSongAudio(song:String, base:String, ?difficulty:String, ?mod:String):String
	{
		#if (MODS_ALLOWED && sys)
		var mods:Array<String> = (mod != null && mod.length > 0) ? [mod] : modSearchOrder();
		for (m in mods)
		{
			var found:String = findSongAudioInMod(m, song, base, difficulty);
			if (found != null) return found;
		}
		#end
		return null;
	}

	/** Tek bir mod içinde CNE şarkı sesi arar. */
	public static function findSongAudioInMod(mod:String, song:String, base:String, ?difficulty:String):String
	{
		#if (MODS_ALLOWED && sys)
		var dir:String = songDir(mod, song);
		if (dir == null) return null;

		var suffix:String = null;
		var meta:Dynamic = getSongMeta(mod, song);
		if (meta != null)
		{
			var field:String = (base == 'Inst') ? 'instSuffix' : 'vocalsSuffix';
			if (Reflect.hasField(meta, field) && Reflect.field(meta, field) != null)
				suffix = Std.string(Reflect.field(meta, field));
		}

		var names:Array<String> = [];
		var diff:String = (difficulty != null && difficulty.length > 0) ? difficulty.toLowerCase() : null;
		var suffixed:String = (suffix != null && suffix.length > 0) ? base + suffix : null;
		if (suffixed != null && diff != null) names.push(suffixed + '-' + diff);
		if (suffixed != null) names.push(suffixed);
		if (diff != null) names.push(base + '-' + diff);
		names.push(base);

		for (sub in ['song/', ''])
			for (n in names)
				for (ext in ['.ogg', '.mp3'])
				{
					var p:String = dir + '/' + sub + n + ext;
					if (FileSystem.exists(p)) return p;
				}
		#end
		return null;
	}

	/** `data/characters/<name>.xml` dosyasını bulur (case-insensitive). */
	public static function findCharacterXml(mod:String, character:String):String
	{
		return findDataXml(mod, 'characters', character);
	}

	/** `data/stages/<name>.xml` dosyasını bulur (case-insensitive). */
	public static function findStageXml(mod:String, stage:String):String
	{
		return findDataXml(mod, 'stages', stage);
	}

	static function findDataXml(mod:String, sub:String, name:String):String
	{
		#if (MODS_ALLOWED && sys)
		if (mod == null || name == null) return null;
		var root:String = cneRoot(mod);
		if (root == null) return null;
		var base:String = root + '/data/' + sub + '/';
		if (!FileSystem.exists(base) || !FileSystem.isDirectory(base)) return null;
		var want:String = name.toLowerCase() + '.xml';
		try
		{
			for (f in FileSystem.readDirectory(base))
				if (f.toLowerCase() == want) return base + f;
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	/** Moddaki chart'ı olan tüm CNE şarkı klasörlerini listeler. */
	public static function listSongs(mod:String):Array<String>
	{
		var out:Array<String> = [];
		#if (MODS_ALLOWED && sys)
		var root:String = cneRoot(mod);
		if (root == null) return out;
		var base:String = root + '/songs/';
		if (!FileSystem.exists(base) || !FileSystem.isDirectory(base)) return out;
		try
		{
			for (dir in FileSystem.readDirectory(base))
			{
				var full:String = base + dir;
				if (!FileSystem.isDirectory(full)) continue;
				if (FileSystem.exists(full + '/charts')) out.push(dir);
			}
		}
		catch (e:Dynamic) {}
		#end
		return out;
	}

	/** '#RRGGBB' renk metnini [r, g, b] dizisine çevirir; olmazsa null. */
	public static function parseColor(str:String):Array<Int>
	{
		if (str == null) return null;
		str = StringTools.trim(str);
		if (str.length < 1) return null;
		if (str.charAt(0) == '#') str = str.substr(1);
		if (str.length == 6)
		{
			var v:Null<Int> = Std.parseInt('0x' + str);
			if (v != null)
				return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
		}
		return null;
	}

	/** '0,1,2' gibi bir listeyi Int dizisine çevirir; boşsa null. */
	public static function parseIntList(str:String):Array<Int>
	{
		if (str == null || StringTools.trim(str).length < 1) return null;
		var out:Array<Int> = [];
		for (part in str.split(','))
		{
			var v:Null<Int> = Std.parseInt(StringTools.trim(part));
			if (v != null) out.push(v);
		}
		return out.length > 0 ? out : null;
	}

	/** XML attribute'unu Float olarak okur; yoksa/geçersizse varsayılan. */
	public static function parseFloatAttr(node:Xml, att:String, def:Float):Float
	{
		if (node == null || !node.exists(att)) return def;
		var v:Float = Std.parseFloat(node.get(att));
		return Math.isNaN(v) ? def : v;
	}
}
