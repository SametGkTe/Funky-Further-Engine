package funkin.backend.scripting;

#if HSC_ALLOWED
import backend.Paths;
import backend.Mods;
import backend.FunkinFileSystem;
import funkin.backend.scripting.HScript; // Script / ScriptPack / DummyScript bu modülde

/**
 * CNE HScript dosyalarını mod klasörlerinden bulup yükleyen yardımcı.
 * PEXO'daki findAndStartScripts mantığının Further için sadeleştirilmiş hali.
 */
class ScriptLoader
{
	/** CNE'nin desteklediği script uzantıları (hxc dahil!) */
	public static final EXTENSIONS:Array<String> = ["hx", "hscript", "hxs", "hxc", "hsc"];

	/**
	 * `data/states/FreeplayState` gibi uzantısız bir temel yol verilir;
	 * aktif mod + global modlar + base assets içinde aranır.
	 * Bulunamazsa null döner.
	 */
	public static function create(basePath:String):Script
	{
		var path:String = find(basePath);
		if (path == null) return null;
		var s:Script = Script.create(path);
		if (s is DummyScript) return null;
		return s;
	}

	public static function find(basePath:String):String
	{
		if (basePath == null) return null;
		var dirs:Array<String> = [];
		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			dirs.push(Paths.mods(Mods.currentModDirectory + '/'));
		for (g in Mods.getGlobalMods())
		{
			var d:String = Paths.mods(g + '/');
			if (!dirs.contains(d)) dirs.push(d);
		}
		#end
		dirs.push(baseAssets());

		for (d in dirs)
			for (ex in EXTENSIONS)
				if (FunkinFileSystem.exists('$d$basePath.$ex'))
					return '$d$basePath.$ex';
		return null;
	}

	/** Taban asset kökü (Psych'in getPreloadPath karşılığı) */
	inline static function baseAssets():String
	{
		return 'assets/';
	}

	/**
	 * Bir klasördeki tüm CNE scriptlerini pakete ekler.
	 * `folder` ya tam yol olabilir (`/mods/x/songs/y/scripts`) ya da
	 * mod köküne göre göreli yol (`codenameScripts`).
	 * @return Eklenen script sayısı
	 */
	public static function addAllFromFolder(folder:String, pack:ScriptPack):Int
	{
		if (folder == null || pack == null) return 0;
		var count:Int = 0;

		var dirs:Array<String> = [];
		if (FunkinFileSystem.exists(folder)) dirs.push(folder);
		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			dirs.push(Paths.mods(Mods.currentModDirectory + '/' + folder));
		for (g in Mods.getGlobalMods())
		{
			var d:String = Paths.mods(g + '/' + folder);
			if (!dirs.contains(d)) dirs.push(d);
		}
		#end
		dirs.push(baseAssets() + folder);

		for (d in dirs)
		{
			if (!FunkinFileSystem.exists(d)) continue;
			for (file in FunkinFileSystem.readDirectory(d))
			{
				var lower:String = file.toLowerCase();
				var ok:Bool = false;
				for (ex in EXTENSIONS)
					if (StringTools.endsWith(lower, '.' + ex)) { ok = true; break; }
				if (!ok) continue;

				var s:Script = Script.create('$d/$file');
				if (s is DummyScript) continue;
				pack.add(s);
				count++;
			}
		}
		return count;
	}
}
#end
