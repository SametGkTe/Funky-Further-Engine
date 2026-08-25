package cne.compatibility;

import backend.Mods;
import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * CNEWeekConverter — Codename Engine hafta XML'lerini
 * (`data/weeks/weeks/*.xml`) runtime'da Psych `WeekFile` formatına çevirir ve
 * ayrıca hiçbir haftaya bağlı olmayan CNE şarkıları için serbest oynatma
 * (freeplay-only) sentetik haftalar üretir.
 *
 * FORMAT EŞLEŞMESİ:
 *   CNE XML                                  Psych WeekFile
 *   --------------------------------------   --------------------------------
 *   <week name="..." chars="dad,bf,gf">      storyName / weekName / weekCharacters
 *   <week sprite="week1">                    weekBackground
 *   <week bgColor="#...">                    şarkı renkleri [r,g,b]
 *   <song>Bopeebo</song>                     songs: [["Bopeebo", icon, [r,g,b]]]
 *   <difficulty name="hard"/>                difficulties: "hard,..."
 *
 * Şarkı ikonları chart'taki karşı taraf karakterinden ve karakter XML'inin
 * `icon` attribute'undan okunur (bulunamazsa 'face').
 *
 * NOT: backend.WeekData'ya derleme zamanı bağımlılık YOKTUR; erişim
 * reflection üzerinden yapılır. Sebep: source/import.hx her dosyaya
 * FreeplayState/FreeplayCatalog importu eklediği için WeekData ile doğrudan
 * modül bağımlılığı döngüsel hale geliyor ve "Type not found" hatası veriyor.
 *
 * KISITLAR: Hafta karakter sprite'ları (`data/weeks/characters/*.xml`)
 * kullanılmaz; Psych'in kendi menu karakter sistemi geçerlidir.
 */
@:keep // WeekData tarafından reflection ile çağrılır; DCE/ölü kod eleme koruması
class CNEWeekConverter
{
	static var _weekDataClass:Class<Dynamic> = null;

	static function weekDataClass():Class<Dynamic>
	{
		if (_weekDataClass == null)
			_weekDataClass = Type.resolveClass('backend.WeekData');
		return _weekDataClass;
	}

	static function weeksLoaded():Map<String, Dynamic>
	{
		return cast Reflect.field(weekDataClass(), 'weeksLoaded');
	}

	static function weeksList():Array<String>
	{
		return cast Reflect.field(weekDataClass(), 'weeksList');
	}

	static function makeWeek(weekFile:Dynamic, id:String):Dynamic
	{
		return Type.createInstance(weekDataClass(), [weekFile, id]);
	}

	/**
	 * Tüm aktif CNE modlarını tarar: CNE haftalarını ve haftasız şarkıları
	 * WeekData'ya ekler. `backend.WeekData.reloadWeekFiles()` sonundan
	 * reflection ile çağrılır.
	 */
	public static function addAllFromMods():Void
	{
		#if (MODS_ALLOWED && sys)
		if (weekDataClass() == null)
		{
			trace('[CNEWeek] backend.WeekData sınıfı bulunamadı!');
			return;
		}
		try
		{
			var enabled:Array<String> = Mods.parseList().enabled;
			trace('[CNEWeek] Tarama başladı — aktif modlar: ' + enabled.join(', '));
			for (mod in enabled)
			{
				if (Mods.isBlocked(mod)) continue;
				var root:String = CNECompat.cneRoot(mod);
				trace('[CNEWeek] mod "$mod" → CNE kökü: ' + root);
				if (root == null) continue;
				addWeeksFromMod(mod);
				addLooseSongsFromMod(mod);
			}
		}
		catch (e:Dynamic)
		{
			trace('[CNEWeek] Tarama hatası: $e');
		}
		#end
	}

	static function addWeeksFromMod(mod:String):Void
	{
		var root:String = CNECompat.cneRoot(mod);
		if (root == null) return;
		var weeksDir:String = root + '/data/weeks/weeks/';
		if (!FileSystem.exists(weeksDir) || !FileSystem.isDirectory(weeksDir)) return;

		var loaded:Map<String, Dynamic> = weeksLoaded();
		for (file in FileSystem.readDirectory(weeksDir))
		{
			if (!StringTools.endsWith(file.toLowerCase(), '.xml')) continue;
			var id:String = file.substr(0, file.length - 4);
			if (loaded.exists(id)) continue;

			var weekFile:Dynamic = convertWeekXml(mod, weeksDir + file, id);
			if (weekFile == null) continue;

			var week:Dynamic = makeWeek(weekFile, id);
			week.folder = mod;
			loaded.set(id, week);
			weeksList().push(id);
			trace('[CNEWeek] Hafta eklendi: "$id"');
		}
	}

	/** Tek bir CNE hafta XML'ini Psych WeekFile'a çevirir. */
	public static function convertWeekXml(mod:String, path:String, id:String):Dynamic
	{
		try
		{
			var root:Xml = Xml.parse(File.getContent(path)).firstElement();
			if (root == null) return null;

			var displayName:String = root.exists('name') ? root.get('name') : id;
			var bgColor:Array<Int> = CNECompat.parseColor(root.exists('bgColor') ? root.get('bgColor') : null);
			if (bgColor == null) bgColor = [146, 113, 253];

			var songs:Array<Dynamic> = [];
			for (el in root.elements())
			{
				if (el.nodeName != 'song') continue;
				if (el.exists('hide') && el.get('hide') == 'true') continue;
				var name:String = (el.firstChild() != null) ? StringTools.trim(el.firstChild().nodeValue) : '';
				if (name == null || name.length < 1) continue;
				songs.push([name, songIcon(mod, name), bgColor.copy()]);
			}
			if (songs.length < 1) return null;

			var chars:Array<String> = ['dad', 'bf', 'gf'];
			if (root.exists('chars'))
			{
				chars = [];
				for (p in root.get('chars').split(','))
				{
					var c:String = StringTools.trim(p);
					if (c.length < 1 || c == 'none' || c == 'null') c = 'none';
					chars.push(c);
				}
				while (chars.length < 3)
					chars.push('none');
			}

			var diffList:Array<String> = [];
			for (d in root.elementsNamed('difficulty'))
				if (d.exists('name')) diffList.push(d.get('name'));

			return {
				songs: songs,
				weekCharacters: chars,
				weekBackground: root.exists('sprite') ? root.get('sprite') : id,
				weekBefore: '',
				storyName: displayName,
				weekName: displayName,
				startUnlocked: true,
				hiddenUntilUnlocked: false,
				hideStoryMode: false,
				hideFreeplay: false,
				difficulties: diffList.join(',')
			};
		}
		catch (e:Dynamic)
		{
			trace('[CNEWeek] "$id" haftası çevrilemedi: $e');
			return null;
		}
	}

	/** Haftalara bağlı olmayan CNE şarkıları için freeplay-only sentetik hafta. */
	static function addLooseSongsFromMod(mod:String):Void
	{
		var songNames:Array<String> = CNECompat.listSongs(mod);
		if (songNames.length < 1) return;

		// Zaten bir haftada listelenen şarkıları ele
		var covered:Map<String, Bool> = new Map();
		var loaded:Map<String, Dynamic> = weeksLoaded();
		for (wk in loaded)
		{
			if (wk == null || wk.songs == null) continue;
			for (s in (wk.songs : Array<Dynamic>))
			{
				var nm:String = extractSongName(s);
				if (nm != null && nm.length > 0) covered.set(nm.toLowerCase(), true);
			}
		}

		var loose:Array<String> = [];
		for (s in songNames)
			if (!covered.exists(s.toLowerCase())) loose.push(s);
		if (loose.length < 1) return;

		var id:String = 'cne_' + StringTools.replace(mod.toLowerCase(), ' ', '_');
		if (loaded.exists(id)) return;

		var songs:Array<Dynamic> = [];
		for (s in loose)
			songs.push([s, songIcon(mod, s), [146, 113, 253]]);

		var weekFile:Dynamic = {
			songs: songs,
			weekCharacters: ['none', 'bf', 'none'],
			weekBackground: 'stage',
			weekBefore: '',
			storyName: mod + ' (CNE)',
			weekName: mod + ' (CNE Songs)',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: true,
			hideFreeplay: false,
			difficulties: ''
		};
		var week:Dynamic = makeWeek(weekFile, id);
		week.folder = mod;
		loaded.set(id, week);
		weeksList().push(id);
		trace('[CNEWeek] Sentetik freeplay haftası eklendi: "$id" (' + loose.length + ' şarkı)');
	}

	/** Bir şarkının freeplay ikonu: karşı karakterin icon attribute'u. */
	static function songIcon(mod:String, song:String):String
	{
		try
		{
			var chartPath:String = CNECompat.findChartFile(mod, song, null);
			if (chartPath != null)
			{
				var chart:Dynamic = Json.parse(File.getContent(chartPath));
				var strumLines:Array<Dynamic> = (chart != null && chart.strumLines != null) ? chart.strumLines : [];
				for (sl in strumLines)
				{
					if (sl == null) continue;
					if (sl.type != null && Std.int(sl.type) != 0) continue;
					var chars:Array<Dynamic> = (sl.characters != null) ? sl.characters : [];
					if (chars.length > 0 && chars[0] != null)
					{
						var charName:String = Std.string(chars[0]);
						var icon:String = characterIcon(mod, charName);
						return (icon != null) ? icon : charName;
					}
				}
			}
		}
		catch (e:Dynamic) {}
		return 'face';
	}

	static function characterIcon(mod:String, character:String):String
	{
		var path:String = CNECompat.findCharacterXml(mod, character);
		if (path == null) return null;
		try
		{
			var root:Xml = Xml.parse(File.getContent(path)).firstElement();
			if (root != null && root.exists('icon')) return root.get('icon');
		}
		catch (e:Dynamic) {}
		return null;
	}

	static function extractSongName(s:Dynamic):String
	{
		if (s == null) return null;
		if (Std.isOfType(s, String)) return Std.string(s);
		if (Std.isOfType(s, Array))
		{
			var arr:Array<Dynamic> = cast s;
			return (arr.length > 0 && arr[0] != null) ? Std.string(arr[0]) : null;
		}
		if (Reflect.hasField(s, 'name')) return Std.string(Reflect.field(s, 'name'));
		return null;
	}
}
