package backend.freeplay;

import haxe.Json;
import backend.WeekData;
import backend.Difficulty;
import backend.Mods;
import backend.ClientPrefs;
import backend.Language;
import backend.modpack.ModpackTypes.ModpackManifest;
import backend.modpack.ModpackPaths;
import states.StoryMenuState;
import vslice.funkin.custom.FreeplayMeta;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class FreeplayCatalog
{
	public static inline var CACHE_VERSION:Int = 1;
	public static inline var LISTING_ORIGINAL:String = 'original';
	public static inline var LISTING_MODS:String = 'mods';
	public static inline var LISTING_MODPACK:String = 'modpack';

	public static var entries:Array<FreeplayEntry> = [];
	public static var pendingApply:Bool = false;

	static var _loaded:Bool = false;
	static var _invalidated:Bool = true;
	static var _loadedSignature:String = '';
	static var _headerCards:Map<String, Dynamic> = new Map();
	static var _packCache:Array<ModpackManifest> = null;
	static var _packByFolder:Map<String, ModpackManifest> = null;

	public static function invalidate():Void
	{
		_invalidated = true;
		_loaded = false;
		_packCache = null;
		_packByFolder = null;
		_headerCards = new Map();
		#if sys
		try
		{
			var path = cachePath();
			if (path != null && FileSystem.exists(path))
				FileSystem.deleteFile(path);
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function markDirty():Void
	{
		pendingApply = true;
	}

	public static function consumePendingApply():Bool
	{
		if (!pendingApply)
			return false;
		pendingApply = false;
		return true;
	}

	public static function listingMode():String
	{
		var mode:String = ClientPrefs.data.freeplayListing;
		if (mode == LISTING_MODS || mode == LISTING_MODPACK)
			return mode;
		return LISTING_ORIGINAL;
	}

	public static function isGrouped():Bool
	{
		return listingMode() != LISTING_ORIGINAL;
	}

	public static function isCollapsed(id:String):Bool
	{
		if (id == null || id.length < 1)
			return false;
		var arr = ClientPrefs.data.freeplayCollapsedCategories;
		return arr != null && arr.contains(id);
	}

	public static function toggleCollapsed(id:String):Bool
	{
		if (id == null || id.length < 1)
			return false;
		if (ClientPrefs.data.freeplayCollapsedCategories == null)
			ClientPrefs.data.freeplayCollapsedCategories = [];
		var arr = ClientPrefs.data.freeplayCollapsedCategories;
		if (arr.contains(id))
			arr.remove(id);
		else
			arr.push(id);
		ClientPrefs.saveSettings();
		return arr.contains(id);
	}

	public static function formatHeaderLabel(label:String, collapsed:Bool):String
	{
		var name:String = sanitizeLabel(label);
		if (collapsed)
			return '> -- ' + name;
		return 'V -- ' + name;
	}

	public static function sanitizeLabel(label:String):String
	{
		if (label == null)
			return '';
		var out:String = label.split('(').join('').split(')').join('');
		out = out.split('[').join('').split(']').join('');
		return out.trim();
	}

	public static function baseGameName():String
	{
		return Language.getPhrase('freeplay_base_game', "Friday Night Funkin'");
	}

	public static function otherModsName():String
	{
		return Language.getPhrase('freeplay_other_mods', 'Diger Modlar');
	}

	public static function ensureLoaded():Array<FreeplayEntry>
	{
		var wantQuick:Bool = ClientPrefs.data.quickFreeplay;
		var sig:String = currentSignature();

		if (wantQuick && _loaded && !_invalidated && _loadedSignature == sig && entries != null && entries.length > 0)
			return entries;

		if (wantQuick && !_invalidated)
		{
			if (tryLoadDisk(sig))
				return entries;
		}

		rebuild(!wantQuick);
		saveDisk(sig);
		return entries;
	}

	public static function currentSignature():String
	{
		var enabled:Array<String> = [];
		#if MODS_ALLOWED
		try
		{
			enabled = Mods.parseList().enabled.copy();
		}
		catch (e:Dynamic) {}
		#end

		var packs:Array<String> = [];
		for (pack in getInstalledPacks())
		{
			if (pack == null || pack.packId == null)
				continue;
			var ver:String = pack.version != null ? pack.version : '';
			packs.push(pack.packId + ':' + ver);
		}

		var weeks:Array<String> = WeekData.weeksList != null ? WeekData.weeksList.copy() : [];
		return 'v' + CACHE_VERSION + '|mods=' + enabled.join(',') + '|packs=' + packs.join(',') + '|weeks=' + weeks.join(',');
	}

	public static function hideOtherMods():Bool
	{
		return listingMode() == LISTING_MODPACK && ClientPrefs.data.freeplayHideOtherMods;
	}

	public static function shouldHideFolder(folder:String):Bool
	{
		return hideOtherMods() && resolveCategory(folder).id == 'other';
	}

	public static function resolveCategory(folder:String):FreeplayCategory
	{
		var mode:String = listingMode();
		var clean:String = folder != null ? folder : '';

		if (mode == LISTING_MODPACK)
		{
			if (clean.length < 1)
				return {id: 'base', label: baseGameName()};
			ensurePackIndex();
			if (_packByFolder != null && _packByFolder.exists(clean))
			{
				var pack = _packByFolder.get(clean);
				var label:String = (pack.displayName != null && pack.displayName.length > 0) ? pack.displayName : pack.packId;
				return {id: 'pack:' + pack.packId, label: label};
			}
			return {id: 'other', label: otherModsName()};
		}

		if (mode == LISTING_MODS)
		{
			if (clean.length < 1)
				return {id: 'base', label: baseGameName()};
			return {id: 'mod:' + clean, label: getModDisplayName(clean)};
		}

		return {id: 'all', label: ''};
	}

	public static function buildRows(items:Array<FreeplayRowSource>, search:String):Array<FreeplayListRow>
	{
		var rows:Array<FreeplayListRow> = [];
		if (items == null || items.length < 1)
			return rows;

		var searchLower:String = search != null ? search.toLowerCase().trim().replace('-', ' ') : '';
		var filtered:Array<FreeplayRowSource> = [];
		for (item in items)
		{
			if (item == null)
				continue;
			if (shouldHideFolder(item.folder))
				continue;
			if (searchLower.length > 0)
			{
				var nameLower:String = item.name.toLowerCase().replace('-', ' ');
				if (!nameLower.contains(searchLower))
					continue;
			}
			filtered.push(item);
		}

		if (!isGrouped())
		{
			for (item in filtered)
			{
				rows.push({
					isHeader: false,
					categoryId: '',
					categoryLabel: '',
					collapsed: false,
					sourceIndex: item.index
				});
			}
			return rows;
		}

		var groups:Array<FreeplayCategory> = [];
		var groupSongs:Map<String, Array<FreeplayRowSource>> = new Map();
		for (item in filtered)
		{
			var cat = resolveCategory(item.folder);
			if (!groupSongs.exists(cat.id))
			{
				groups.push(cat);
				groupSongs.set(cat.id, []);
			}
			groupSongs.get(cat.id).push(item);
		}

		groups.sort(function(a, b) return compareCategory(a.id, b.id));

		for (cat in groups)
		{
			if (cat.id == 'other' && hideOtherMods())
				continue;

			var collapsed:Bool = isCollapsed(cat.id);
			if (searchLower.length > 0)
				collapsed = false;
			rows.push({
				isHeader: true,
				categoryId: cat.id,
				categoryLabel: cat.label,
				collapsed: collapsed,
				sourceIndex: -1
			});
			if (collapsed)
				continue;
			for (item in groupSongs.get(cat.id))
			{
				rows.push({
					isHeader: false,
					categoryId: cat.id,
					categoryLabel: cat.label,
					collapsed: false,
					sourceIndex: item.index
				});
			}
		}
		return rows;
	}

	public static function getModDisplayName(folder:String):String
	{
		if (folder == null || folder.length < 1)
			return baseGameName();
		try
		{
			var pack:Dynamic = Mods.getPack(folder);
			if (pack != null)
			{
				if (Reflect.hasField(pack, 'name') && pack.name != null && Std.string(pack.name).length > 0)
					return Std.string(pack.name);
				if (Reflect.hasField(pack, 'title') && pack.title != null && Std.string(pack.title).length > 0)
					return Std.string(pack.title);
			}
		}
		catch (e:Dynamic) {}
		return folder;
	}

	public static function getInstalledPacks():Array<ModpackManifest>
	{
		if (_packCache != null)
			return _packCache;

		var list:Array<ModpackManifest> = [];
		#if sys
		try
		{
			var dir:String = ModpackPaths.getInstalledDirectory();
			if (dir != null && FileSystem.exists(dir) && FileSystem.isDirectory(dir))
			{
				var files = FileSystem.readDirectory(dir);
				files.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
				for (file in files)
				{
					if (file == null || !file.toLowerCase().endsWith('.json'))
						continue;
					try
					{
						var raw:String = File.getContent(haxe.io.Path.join([dir, file]));
						if (raw == null || raw.length < 2)
							continue;
						var manifest:ModpackManifest = cast Json.parse(raw);
						if (manifest != null && manifest.packId != null && manifest.packId.length > 0)
							list.push(manifest);
					}
					catch (e:Dynamic) {}
				}
			}
		}
		catch (e:Dynamic) {}
		#end
		_packCache = list;
		return list;
	}

	public static function readSongParts(raw:Dynamic):Null<FreeplaySongParts>
	{
		if (raw == null)
			return null;

		if (Std.isOfType(raw, String))
		{
			var nameOnly:String = Std.string(raw);
			if (nameOnly.length < 1)
				return null;
			return {name: nameOnly, char: 'bf', color: [146, 113, 253]};
		}

		if (Reflect.hasField(raw, 'name') || Reflect.hasField(raw, 'song'))
		{
			var objName:String = '';
			if (Reflect.hasField(raw, 'name') && raw.name != null)
				objName = Std.string(raw.name);
			else if (Reflect.hasField(raw, 'song') && raw.song != null)
				objName = Std.string(raw.song);
			if (objName.length < 1)
				return null;
			var icon:String = 'bf';
			if (Reflect.hasField(raw, 'icon') && raw.icon != null && Std.string(raw.icon).length > 0)
				icon = Std.string(raw.icon);
			else if (Reflect.hasField(raw, 'character') && raw.character != null)
				icon = Std.string(raw.character);
			var color:Array<Int> = [146, 113, 253];
			if (Reflect.hasField(raw, 'color') && raw.color != null)
			{
				try
				{
					var parsed:Array<Int> = cast raw.color;
					if (parsed != null && parsed.length >= 3)
						color = parsed;
				}
				catch (e:Dynamic) {}
			}
			return {name: objName, char: icon, color: color};
		}

		try
		{
			var arr:Array<Dynamic> = cast raw;
			if (arr == null || arr.length < 1 || arr[0] == null)
				return null;
			var arrName:String = Std.string(arr[0]);
			if (arrName.length < 1)
				return null;
			var arrChar:String = arr.length > 1 && arr[1] != null ? Std.string(arr[1]) : 'bf';
			var arrColor:Array<Int> = [146, 113, 253];
			if (arr.length > 2 && arr[2] != null)
			{
				try
				{
					var parsedArr:Array<Int> = cast arr[2];
					if (parsedArr != null && parsedArr.length >= 3)
						arrColor = parsedArr;
				}
				catch (e:Dynamic) {}
			}
			return {name: arrName, char: arrChar, color: arrColor};
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function captureFromHydrated(entry:FreeplayEntry, diffs:Array<String>, songPlayer:String, albumId:String, songRating:Int, allowErect:Bool, startingBpm:Float, weekName:String):Void
	{
		if (entry == null)
			return;
		if (diffs != null && diffs.length > 0)
			entry.difficulties = diffs.copy();
		if (songPlayer != null)
			entry.songPlayer = songPlayer;
		if (albumId != null)
			entry.albumId = albumId;
		entry.songRating = songRating;
		entry.allowErect = allowErect;
		if (startingBpm > 0)
			entry.startingBpm = startingBpm;
		if (weekName != null && weekName.length > 0)
			entry.weekName = weekName;
	}

	public static function saveAfterHydrate():Void
	{
		saveDisk(currentSignature());
	}

	public static function updateHydratedSong(songName:String, folder:String, diffs:Array<String>, bpm:Float):Bool
	{
		if (entries == null || entries.length < 1 || songName == null)
			return false;

		var wantFolder:String = folder != null ? folder : '';
		var changed:Bool = false;
		for (entry in entries)
		{
			if (entry == null || entry.songName != songName)
				continue;
			var entryFolder:String = entry.folder != null ? entry.folder : '';
			if (entryFolder != wantFolder)
				continue;

			if (diffs != null && diffs.length > 0 && !sameStringList(entry.difficulties, diffs))
			{
				entry.difficulties = diffs.copy();
				changed = true;
			}
			if (bpm > 0 && entry.startingBpm != bpm)
			{
				entry.startingBpm = bpm;
				changed = true;
			}
		}

		if (changed)
			saveAfterHydrate();
		return changed;
	}

	static function sameStringList(a:Array<String>, b:Array<String>):Bool
	{
		if (a == b)
			return true;
		if (a == null || b == null || a.length != b.length)
			return false;
		for (i in 0...a.length)
		{
			if (a[i] != b[i])
				return false;
		}
		return true;
	}

	static function rebuild(heavy:Bool):Void
	{
		WeekData.reloadWeekFiles(false);
		entries = [];
		_packCache = null;
		_packByFolder = null;
		ensurePackIndex();

		for (i in 0...WeekData.weeksList.length)
		{
			var weekName:String = WeekData.weeksList[i];
			if (weekIsLocked(weekName))
				continue;
			var leWeek:WeekData = WeekData.weeksLoaded.get(weekName);
			if (leWeek == null || leWeek.songs == null)
				continue;

			WeekData.setDirectoryFromWeek(leWeek);
			var folder:String = leWeek.folder != null ? leWeek.folder : '';
			var diffs:Array<String> = [];
			if (leWeek.difficulties != null)
				diffs = leWeek.difficulties.extractWeeks();
			if (diffs == null || diffs.length < 1)
				diffs = Difficulty.defaultList.copy();

			for (raw in leWeek.songs)
			{
				var parts = readSongParts(raw);
				if (parts == null)
					continue;

				var color:Int = flixel.util.FlxColor.fromRGB(parts.color[0], parts.color[1], parts.color[2]);
				var entry = new FreeplayEntry();
				entry.songName = parts.name;
				entry.weekIndex = i;
				entry.weekFile = weekName;
				entry.weekName = leWeek.weekName != null ? leWeek.weekName : weekName;
				entry.songCharacter = parts.char;
				entry.color = color;
				entry.folder = folder;
				entry.difficulties = diffs.copy();
				entry.modDisplayName = getModDisplayName(folder);
				var cat = resolveCategory(folder);
				if (cat.id.startsWith('pack:'))
				{
					entry.modpackId = cat.id.substr(5);
					entry.modpackName = cat.label;
				}

				if (!heavy)
					fillLightMeta(entry);

				entries.push(entry);
			}
		}

		Mods.loadTopMod();
		_loaded = true;
		_invalidated = false;
		_loadedSignature = currentSignature();
	}

	static function fillLightMeta(entry:FreeplayEntry):Void
	{
		try
		{
			var prevDir:String = Mods.currentModDirectory;
			Mods.currentModDirectory = entry.folder;
			var meta = FreeplayMeta.getMeta(entry.songName);
			if (meta != null)
			{
				if (meta.freeplayCharacter != null)
					entry.songPlayer = meta.freeplayCharacter;
				if (meta.albumId != null)
					entry.albumId = meta.albumId;
				entry.songRating = meta.songRating;
				entry.allowErect = meta.allowErectVariants;
				if (meta.freeplayWeekName != null && meta.freeplayWeekName.length > 0)
					entry.weekName = meta.freeplayWeekName;
			}
			Mods.currentModDirectory = prevDir;
		}
		catch (e:Dynamic) {}
	}

	static function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		if (leWeek == null)
			return false;
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore != null
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	static function ensurePackIndex():Void
	{
		if (_packByFolder != null)
			return;
		_packByFolder = new Map();
		for (pack in getInstalledPacks())
		{
			if (pack.modFolders == null)
				continue;
			for (folder in pack.modFolders)
			{
				if (folder == null || folder.length < 1)
					continue;
				if (!_packByFolder.exists(folder))
					_packByFolder.set(folder, pack);
			}
		}
	}

	static function compareCategory(a:String, b:String):Int
	{
		if (a == b)
			return 0;
		var ia:Int = categoryRank(a);
		var ib:Int = categoryRank(b);
		if (ia != ib)
			return ia - ib;
		return Reflect.compare(a.toLowerCase(), b.toLowerCase());
	}

	static function categoryRank(id:String):Int
	{
		if (id == 'base')
			return 0;
		if (id.startsWith('pack:'))
		{
			var packId:String = id.substr(5);
			var packs = getInstalledPacks();
			for (i in 0...packs.length)
			{
				if (packs[i].packId == packId)
					return 100 + i;
			}
			return 400;
		}
		if (id.startsWith('mod:'))
		{
			var folder:String = id.substr(4);
			#if MODS_ALLOWED
			try
			{
				var enabled = Mods.parseList().enabled;
				var idx:Int = enabled.indexOf(folder);
				if (idx >= 0)
					return 200 + idx;
			}
			catch (e:Dynamic) {}
			#end
			return 350;
		}
		if (id == 'other')
			return 900;
		return 500;
	}

	static function cachePath():String
	{
		#if sys
		return mobile.backend.StorageUtil.getStorageDirectory() + 'FreeplaySongList.json';
		#else
		return null;
		#end
	}

	static function tryLoadDisk(expectedSig:String):Bool
	{
		#if sys
		try
		{
			var path = cachePath();
			if (path == null || !FileSystem.exists(path))
				return false;
			var raw:String = File.getContent(path);
			if (raw == null || raw.length < 2)
				return false;
			var data:Dynamic = Json.parse(raw);
			if (data == null || data.version != CACHE_VERSION)
				return false;
			if (Std.string(data.signature) != expectedSig)
				return false;
			var rawEntries:Array<Dynamic> = cast data.entries;
			if (rawEntries == null)
				return false;
			var loaded:Array<FreeplayEntry> = [];
			for (item in rawEntries)
			{
				var entry = FreeplayEntry.fromDynamic(item);
				if (entry != null)
					loaded.push(entry);
			}
			entries = loaded;
			_loaded = true;
			_invalidated = false;
			_loadedSignature = expectedSig;
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[FreeplayCatalog] Cache okunamadı: ' + e);
		}
		#end
		return false;
	}

	static function saveDisk(sig:String):Void
	{
		#if sys
		try
		{
			var path = cachePath();
			if (path == null)
				return;
			var dump:Array<Dynamic> = [];
			for (entry in entries)
				dump.push(entry.toDynamic());
			var payload = {
				version: CACHE_VERSION,
				signature: sig,
				entries: dump
			};
			File.saveContent(path, Json.stringify(payload));
			_loadedSignature = sig;
		}
		catch (e:Dynamic)
		{
			trace('[FreeplayCatalog] Cache yazılamadı: ' + e);
		}
		#end
	}
}

typedef FreeplaySongParts =
{
	var name:String;
	var char:String;
	var color:Array<Int>;
}

typedef FreeplayCategory =
{
	var id:String;
	var label:String;
}

typedef FreeplayListRow =
{
	var isHeader:Bool;
	var categoryId:String;
	var categoryLabel:String;
	var collapsed:Bool;
	var sourceIndex:Int;
}
