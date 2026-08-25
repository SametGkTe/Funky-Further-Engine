package vslice.compatibility;

import backend.Mods;
import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * VSliceLooseSongs — Hiçbir V-Slice level'ında (data/levels/) listelenmeyen
 * şarkılar için freeplay-only sentetik haftalar üretir.
 *
 * FFE'nin freeplay'i tamamen hafta tabanlıdır; V-Slice şarkı modlarının çoğu
 * level dosyası içermez, bu yüzden şarkıları görünmezdi. Bu tarayıcı
 * `data/songs/<id>/<id>-chart.json` dosyalarını bulur, zaten bir haftada
 * olanları eler ve kalanlardan `vslice_<mod>` sentetik haftası oluşturur.
 *
 * NOT: backend.WeekData'ya derleme zamanı bağımlılık YOKTUR; erişim
 * reflection üzerinden yapılır (CNEWeekConverter ile aynı desen — import.hx
 * kaynaklı modül döngülerini kırar).
 */
@:keep // WeekData tarafından reflection ile çağrılır; DCE koruması
class VSliceLooseSongs
{
	static var _weekDataClass:Class<Dynamic> = null;

	static function weekDataClass():Class<Dynamic>
	{
		if (_weekDataClass == null)
			_weekDataClass = Type.resolveClass('backend.WeekData');
		return _weekDataClass;
	}

	/** Tüm aktif modları tarar; V-Slice şarkı modlarından haftasız olanları ekler. */
	public static function addAllFromMods():Void
	{
		#if (MODS_ALLOWED && sys)
		var wd:Class<Dynamic> = weekDataClass();
		if (wd == null) return;
		var loaded:Map<String, Dynamic> = cast Reflect.field(wd, 'weeksLoaded');
		var list:Array<String> = cast Reflect.field(wd, 'weeksList');
		if (loaded == null || list == null) return;

		try
		{
			for (mod in Mods.parseList().enabled)
			{
				if (Mods.isBlocked(mod)) continue;
				addLooseSongsFromMod(mod, loaded, list, wd);
			}
		}
		catch (e:Dynamic)
		{
			trace('[VSliceLooseSongs] Tarama hatası: $e');
		}
		#end
	}

	static function addLooseSongsFromMod(mod:String, loaded:Map<String, Dynamic>, list:Array<String>, wd:Class<Dynamic>):Void
	{
		var songsBase:String = Paths.mods(mod + '/data/songs/');
		if (!FileSystem.exists(songsBase) || !FileSystem.isDirectory(songsBase)) return;

		// V-Slice chart'ı olan şarkı id'leri
		var songIds:Array<String> = [];
		for (dir in FileSystem.readDirectory(songsBase))
		{
			var full:String = songsBase + dir;
			if (!FileSystem.isDirectory(full)) continue;
			if (FileSystem.exists(full + '/' + dir + '-chart.json'))
				songIds.push(dir);
		}
		if (songIds.length < 1) return;

		// Zaten bir haftada listelenen şarkıları ele
		var covered:Map<String, Bool> = new Map();
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
		for (id in songIds)
			if (!covered.exists(id.toLowerCase())) loose.push(id);
		if (loose.length < 1) return;

		var weekId:String = 'vslice_' + StringTools.replace(mod.toLowerCase(), ' ', '_');
		if (loaded.exists(weekId)) return;

		var songs:Array<Dynamic> = [];
		for (id in loose)
		{
			var metaName:String = songDisplayName(mod, id);
			var icon:String = songIcon(mod, id);
			songs.push([metaName, icon, [146, 113, 253]]);
		}

		var weekFile:Dynamic = {
			songs: songs,
			weekCharacters: ['none', 'bf', 'none'],
			weekBackground: 'stage',
			weekBefore: '',
			storyName: mod + ' (V-Slice)',
			weekName: mod + ' (V-Slice Songs)',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: true,
			hideFreeplay: false,
			difficulties: ''
		};
		var week:Dynamic = Type.createInstance(wd, [weekFile, weekId]);
		week.folder = mod;
		loaded.set(weekId, week);
		list.push(weekId);
		trace('[VSliceLooseSongs] Sentetik freeplay haftası eklendi: "$weekId" (' + loose.length + ' şarkı)');
	}

	/** Metadata'dan görünen şarkı adı (yoksa id). */
	static function songDisplayName(mod:String, songId:String):String
	{
		var metaPath:String = Paths.mods(mod + '/data/songs/$songId/$songId-metadata.json');
		try
		{
			if (FileSystem.exists(metaPath))
			{
				var meta:Dynamic = Json.parse(File.getContent(metaPath));
				if (meta != null && Reflect.hasField(meta, 'songName') && meta.songName != null)
				{
					var nm:String = Std.string(meta.songName);
					if (nm.length > 0 && nm != 'Unknown') return nm;
				}
			}
		}
		catch (e:Dynamic) {}
		return songId;
	}

	/** Metadata'daki karşı karakterin ikon dosyası varsa adı, yoksa 'face'. */
	static function songIcon(mod:String, songId:String):String
	{
		var metaPath:String = Paths.mods(mod + '/data/songs/$songId/$songId-metadata.json');
		try
		{
			if (FileSystem.exists(metaPath))
			{
				var meta:Dynamic = Json.parse(File.getContent(metaPath));
				var chars:Dynamic = (meta != null && Reflect.hasField(meta, 'playData')) ? Reflect.field(meta.playData, 'characters') : null;
				var opp:Dynamic = chars != null ? Reflect.field(chars, 'opponent') : null;
				if (opp != null && Std.string(opp).length > 0)
				{
					var iconFile:String = 'icon-' + Std.string(opp).toLowerCase();
					for (base in ['images/icons/', 'shared/images/icons/'])
						if (FileSystem.exists(Paths.mods(mod + '/' + base + iconFile + '.png')))
							return Std.string(opp);
				}
			}
		}
		catch (e:Dynamic) {}
		return 'face';
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
