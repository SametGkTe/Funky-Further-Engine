package vslice.compatibility.freeplay;

import vslice.menus.freeplay.obj.SngCapsuleData;
import vslice.menus.freeplay.pslice.BPMCache;
import vslice.funkin.Scoring.ScoringRank;
import backend.Highscore;
import backend.WeekData;
import backend.freeplay.FreeplayCatalog;
import backend.freeplay.FreeplayEntry;
import haxe.ds.StringMap;
import haxe.io.Path;

/**
 * Data about a specific song in the freeplay menu. Very heaviely dependent on exact engine
 */
class FreeplaySongData extends SngCapsuleData
{
	static var _resolvedSongPathCache:StringMap<String> = new StringMap<String>();
	static var _failedSongPathLogged:StringMap<Bool> = new StringMap<Bool>();
	static var _headerCache:Map<String, FreeplaySongData> = new Map();

	public var lightMode:Bool = false;
	public var isCategoryHeader:Bool = false;
	public var categoryId:String = '';
	public var categoryLabel:String = '';
	public var collapsed:Bool = false;
	public var chartsHydrated:Bool = false;

	public function new(levelId:Int, songId:String, songCharacter:String, color:FlxColor)
	{
		super(levelId,songId,songCharacter,color);
		this.isFav = ClientPrefs.data.favSongIds.contains(songId + this.levelName); // Save.instance.isSongFavorited(songId);
	}

	public static function fromEntry(entry:FreeplayEntry):FreeplaySongData
	{
		var prev:Bool = SngCapsuleData.constructingLight;
		SngCapsuleData.constructingLight = ClientPrefs.data.quickFreeplay;
		var sng = new FreeplaySongData(entry.weekIndex, entry.songName, entry.songCharacter, entry.color);
		SngCapsuleData.constructingLight = prev;
		if (ClientPrefs.data.quickFreeplay)
			sng.applyCatalog(entry);
		else
		{
			sng.lightMode = false;
			sng.skipMetaUpdate = false;
		}
		return sng;
	}

	public static function makeHeader(id:String, label:String, nextCollapsed:Bool):FreeplaySongData
	{
		var existing = _headerCache.get(id);
		if (existing != null)
		{
			existing.updateHeader(label, nextCollapsed);
			return existing;
		}

		var prev:Bool = SngCapsuleData.constructingLight;
		SngCapsuleData.constructingLight = true;
		var sng = new FreeplaySongData(0, id, 'face', 0xFFFFD54A);
		SngCapsuleData.constructingLight = prev;
		sng.isCategoryHeader = true;
		sng.skipMetaUpdate = true;
		sng.lightMode = true;
		sng.categoryId = id;
		sng.categoryLabel = label;
		sng.collapsed = nextCollapsed;
		sng.songDifficulties = ['easy', 'normal', 'hard'];
		sng.isFav = false;
		_headerCache.set(id, sng);
		return sng;
	}

	public function updateHeader(label:String, nextCollapsed:Bool):Void
	{
		categoryLabel = label;
		collapsed = nextCollapsed;
	}

	public function applyCatalog(entry:FreeplayEntry):Void
	{
		if (entry == null)
			return;

		this.folder = entry.folder != null ? entry.folder : '';
		this.levelName = entry.weekName != null ? entry.weekName : '';
		this.songWeekName = entry.weekName != null ? entry.weekName : '';
		if (entry.difficulties != null && entry.difficulties.length > 0)
			this.songDifficulties = entry.difficulties.copy();
		else
			this.songDifficulties = Difficulty.defaultList.copy();
		this.songPlayer = entry.songPlayer != null ? entry.songPlayer : '';
		this.albumId = entry.albumId;
		this.difficultyRating = entry.songRating;
		this.allowErect = entry.allowErect;
		this.songStartingBpm = entry.startingBpm;
		this.skipMetaUpdate = true;
		this.lightMode = true;
		this.isFav = ClientPrefs.data.favSongIds.contains(this.songId + this.levelName);

		if (!this.songDifficulties.contains(currentDifficulty) && this.songDifficulties.length > 0)
		{
			@:bypassAccessor
			currentDifficulty = this.songDifficulties[0];
		}

		refreshScoreOnly();
	}

	/**
	 * Quick mode: scan this song's chart folder on first select/play only.
	 * Fixes week-level difficulties without walking the whole list.
	 */
	public function hydrateChartsIfNeeded():Bool
	{
		if (isCategoryHeader || chartsHydrated)
			return false;

		if (!ClientPrefs.data.quickFreeplay && !lightMode)
		{
			chartsHydrated = true;
			return false;
		}

		var prevDir:String = Mods.currentModDirectory;
		if (folder != null)
			Mods.currentModDirectory = folder;

		var fileSngName:String = Paths.formatToSongPath(getNativeSongId());
		var sngDataPath:String = resolveSongDataPath(fileSngName);
		var discovered:Array<String> = discoverDifficultiesFromPath(sngDataPath, fileSngName);

		if (allowErect && !hasErectSong())
		{
			discovered.remove('erect');
			discovered.remove('nightmare');
		}

		var changed:Bool = false;
		if (discovered.length > 0 && !sameDiffList(songDifficulties, discovered))
		{
			songDifficulties = discovered;
			changed = true;
		}
		else if (discovered.length == 0 && (songDifficulties == null || songDifficulties.length == 0))
		{
			songDifficulties = ['normal'];
			changed = true;
		}

		var bpm:Float = BPMCache.instance.getBPM(sngDataPath, fileSngName);
		if (bpm > 0 && songStartingBpm != bpm)
		{
			songStartingBpm = bpm;
			changed = true;
		}

		if (songDifficulties != null && songDifficulties.length > 0 && !songDifficulties.contains(currentDifficulty))
		{
			@:bypassAccessor
			currentDifficulty = songDifficulties[0];
		}

		chartsHydrated = true;
		Mods.currentModDirectory = prevDir;

		if (changed)
			FreeplayCatalog.updateHydratedSong(songId, folder, songDifficulties, songStartingBpm);

		refreshScoreOnly();
		return changed;
	}

	static function sameDiffList(a:Array<String>, b:Array<String>):Bool
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

	function discoverDifficultiesFromPath(sngDataPath:String, fileSngName:String):Array<String>
	{
		var discoveredDiffs:Array<String> = [];
		if (sngDataPath == null || fileSngName == null)
			return discoveredDiffs;

		#if sys
		if (!sys.FileSystem.exists(sngDataPath) || !sys.FileSystem.isDirectory(sngDataPath))
			return discoveredDiffs;

		var chartFiles = sys.FileSystem.readDirectory(sngDataPath).filter(s ->
			s != null && s.toLowerCase().endsWith('.json')
		);
		var diffNames:Array<String> = [];

		for (file in chartFiles)
		{
			var lower = file.toLowerCase();
			var lowerSong = fileSngName.toLowerCase();

			if (lower == lowerSong + '.json')
			{
				if (!diffNames.contains('normal'))
					diffNames.push('normal');
			}
			else if (lower.startsWith(lowerSong + '-'))
			{
				var diff = lower.substring(lowerSong.length + 1, lower.length - 5).trim();
				if (diff.length > 0 && !diffNames.contains(diff))
					diffNames.push(diff);
			}
		}

		var ordered:Array<String> = [];
		if (diffNames.contains('easy'))
			ordered.push('easy');
		if (diffNames.contains('normal'))
			ordered.push('normal');
		if (diffNames.contains('hard'))
			ordered.push('hard');
		for (diff in diffNames)
		{
			if (!ordered.contains(diff))
				ordered.push(diff);
		}
		discoveredDiffs = ordered;
		#end

		return discoveredDiffs;
	}

	function refreshScoreOnly():Void
	{
		try
		{
			this.scoringRank = Scoring.calculateRankForSong(Highscore.formatSong(getNativeSongId(), loadAndGetDiffId()));
		}
		catch (e:Dynamic)
		{
			this.scoringRank = null;
		}
		updateIsNewTag();
	}

	/**
	 * Toggle whether or not the song is favorited, then flush to save data.
	 * @return Whether or not the song is now favorited.
	 */
	public function toggleFavorite():Bool
	{
		isFav = !isFav;

		if (ClientPrefs.data.favSongIds == null)
			ClientPrefs.data.favSongIds = [];

		var key = this.songId + this.levelName;

		if (isFav)
		{
			if (!ClientPrefs.data.favSongIds.contains(key))
				ClientPrefs.data.favSongIds.push(key);
		}
		else
		{
			ClientPrefs.data.favSongIds.remove(key);
		}

		ClientPrefs.saveSettings();
		return isFav;
	}
	
	private function isAbsolutePath(path:String):Bool
	{
		if (path == null || path.length == 0) return false;
		if (path.charAt(0) == "/" || path.charAt(0) == "\\") return true;
		return path.length > 1 && path.charAt(1) == ":";
	}

	private function toRuntimePath(path:String):String
	{
		if (path == null || path.length == 0) return path;
		if (isAbsolutePath(path)) return Path.normalize(path);

		var exeDir = Path.directory(Sys.programPath());
		return Path.normalize(Path.join([exeDir, path]));
	}

	private function addCandidate(list:Array<String>, path:String):Void
	{
		if (path == null || path.length == 0) return;
		path = normalizePath(path);
		if (path.length == 0) return;

		if (!list.contains(path))
			list.push(path);

		var runtimePath = toRuntimePath(path);
		if (runtimePath != path && !list.contains(runtimePath))
			list.push(runtimePath);
	}

	private function normalizePath(path:String):String
	{
		if (path == null) return "";
		path = path.split("\\").join("/");
		while (path.indexOf("//") >= 0)
			path = path.split("//").join("/");
		if (path.length > 1 && path.endsWith("/"))
			path = path.substr(0, path.length - 1);
		return path;
	}

	public static function clearPathCache():Void
	{
		_resolvedSongPathCache = new StringMap<String>();
		_failedSongPathLogged = new StringMap<Bool>();
	}

	private function dirHasJson(path:String):Bool
	{
		#if sys
		try
		{
			if (path == null || !sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path))
				return false;
			for (file in sys.FileSystem.readDirectory(path))
			{
				if (file != null && file.toLowerCase().endsWith(".json"))
					return true;
			}
		}
		catch (e:Dynamic) {}
		#end
		return false;
	}

	/** Klasörün kendisinde veya charts/ altında chart json varsa o klasörü döner. */
	private function chartDirIfValid(path:String):String
	{
		#if sys
		try
		{
			path = normalizePath(path);
			if (path == null || path.length == 0) return null;
			if (!sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path))
				return null;
			if (dirHasJson(path))
				return path;
			var charts = path + "/charts";
			if (dirHasJson(charts))
				return charts;
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	private function pushModSongCandidates(list:Array<String>, modsRoot:String, modFolder:String, fileSngName:String):Void
	{
		if (modFolder == null) modFolder = "";
		modFolder = normalizePath(modFolder);
		var prefix = modsRoot;
		if (modFolder.length > 0)
			prefix = modsRoot + "/" + modFolder;

		addCandidate(list, prefix + "/data/" + fileSngName);
		addCandidate(list, prefix + "/data/songs/" + fileSngName);
		addCandidate(list, prefix + "/songs/" + fileSngName + "/charts");
		addCandidate(list, prefix + "/songs/" + fileSngName);
		addCandidate(list, prefix + "/charts/" + fileSngName);
	}

	private function resolveSongDataPath(fileSngName:String):String
	{
		var cacheKey = (this.folder != null ? this.folder : "") + "::" + fileSngName;
		if (_resolvedSongPathCache.exists(cacheKey))
			return _resolvedSongPathCache.get(cacheKey);

		var cwd:String = normalizePath(Sys.getCwd());
		#if android
		try
		{
			var storage = mobile.backend.StorageUtil.getExternalStorageDirectory();
			if (storage != null && storage.length > 0)
				cwd = normalizePath(storage);
		}
		catch (e:Dynamic) {}
		#end

		var modsRoot:String = cwd + "/mods";
		#if MODS_ALLOWED
		try
		{
			var fromPaths = normalizePath(Paths.mods());
			if (fromPaths != null && fromPaths.length > 0)
				modsRoot = fromPaths;
		}
		catch (e:Dynamic) {}
		#end

		var candidates:Array<String> = [];

		#if MODS_ALLOWED
		// 1) Week'in kendi mod klasörü (asıl eksik olan buydu)
		if (this.folder != null && this.folder.length > 0)
			pushModSongCandidates(candidates, modsRoot, this.folder, fileSngName);

		// 2) Seçili / current mod
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0
			&& Mods.currentModDirectory != this.folder)
			pushModSongCandidates(candidates, modsRoot, Mods.currentModDirectory, fileSngName);

		// 3) Global + loose mods/data
		pushModSongCandidates(candidates, modsRoot, "", fileSngName);

		// 4) Açık diğer modlar
		try
		{
			for (mod in Mods.parseList().enabled)
			{
				if (mod == null || mod.length == 0) continue;
				if (mod == this.folder || mod == Mods.currentModDirectory) continue;
				pushModSongCandidates(candidates, modsRoot, mod, fileSngName);
			}
		}
		catch (e:Dynamic) {}
		#end

		addCandidate(candidates, cwd + "/assets/shared/data/" + fileSngName);
		addCandidate(candidates, cwd + "/assets/shared/data/songs/" + fileSngName);
		addCandidate(candidates, cwd + "/assets/data/" + fileSngName);
		addCandidate(candidates, cwd + "/assets/data/songs/" + fileSngName);

		for (path in candidates)
		{
			var hit = chartDirIfValid(path);
			if (hit != null)
			{
				_resolvedSongPathCache.set(cacheKey, hit);
				return hit;
			}
		}

		var fallback = cwd + "/assets/shared/data/" + fileSngName;
		_resolvedSongPathCache.set(cacheKey, fallback);

		if (!_failedSongPathLogged.exists(cacheKey))
		{
			_failedSongPathLogged.set(cacheKey, true);
			var preview = candidates.slice(0, 8).join(" | ");
			trace('[FreeplaySongData] Failed to resolve "$fileSngName" (mod="${this.folder}"). Tried: ' + preview);
		}

		return fallback;
	}
	
	function updateValues():Void
	{
		if (isCategoryHeader)
			return;

		if (lightMode || SngCapsuleData.constructingLight || ClientPrefs.data.quickFreeplay)
		{
			refreshScoreOnly();
			return;
		}

		var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[levelId]);
		if (leWeek == null)
		{
			refreshScoreOnly();
			return;
		}

		levelName = leWeek.weekName;
		this.songDifficulties = leWeek.difficulties.extractWeeks();
		this.folder = leWeek.folder;

		Mods.currentModDirectory = this.folder;

		var fileSngName = Paths.formatToSongPath(getNativeSongId());
		var sngDataPath = resolveSongDataPath(fileSngName);

		var discoveredDiffs:Array<String> = [];
		
		if (sngDataPath != null && sys.FileSystem.exists(sngDataPath) && sys.FileSystem.isDirectory(sngDataPath))
		{
			var chartFiles = sys.FileSystem.readDirectory(sngDataPath).filter(s ->
				s != null && s.toLowerCase().endsWith(".json")
			);
			var diffNames:Array<String> = [];

			for (file in chartFiles)
			{
				var lower = file.toLowerCase();
				var lowerSong = fileSngName.toLowerCase();

				// normal: tutorial.json
				if (lower == lowerSong + ".json")
				{
					if (!diffNames.contains("normal"))
						diffNames.push("normal");
				}
				// hard/easy/other: tutorial-hard.json
				else if (lower.startsWith(lowerSong + "-"))
				{
					var diff = lower.substring(lowerSong.length + 1, lower.length - 5).trim();
					if (diff.length > 0 && !diffNames.contains(diff))
						diffNames.push(diff);
				}
			}

			var ordered:Array<String> = [];

			if (diffNames.contains("easy")) ordered.push("easy");
			if (diffNames.contains("normal")) ordered.push("normal");
			if (diffNames.contains("hard")) ordered.push("hard");

			for (diff in diffNames)
			{
				if (!ordered.contains(diff))
					ordered.push(diff);
			}

			discoveredDiffs = ordered;
		}

		if (discoveredDiffs.length > 0)
		{
			this.songDifficulties = discoveredDiffs;
		}
		else if (this.songDifficulties.length == 0)
		{
			this.songDifficulties = ['normal'];

			if (!_failedSongPathLogged.exists(fileSngName + "_diffs"))
			{
				_failedSongPathLogged.set(fileSngName + "_diffs", true);
				trace('Directory $sngDataPath does not exist! $songName has no charts (difficulties)!');
			}
		}

		if (allowErect && !hasErectSong())
		{
			this.songDifficulties.remove("erect");
			this.songDifficulties.remove("nightmare");
		}

		if (!this.songDifficulties.contains(currentDifficulty))
		{
			@:bypassAccessor
			currentDifficulty = songDifficulties[0];
		}

		songStartingBpm = BPMCache.instance.getBPM(sngDataPath, fileSngName);

		this.scoringRank = Scoring.calculateRankForSong(
			Highscore.formatSong(getNativeSongId(), loadAndGetDiffId())
		);

		chartsHydrated = true;
		updateIsNewTag();
	}

	public function updateIsNewTag()
	{
		if(!metaAllowNew && !ClientPrefs.data.vsliceForceNewTag){
			isNew = false;
			return;
		}
		var wasCompleted = false;
		var saveSongName = Paths.formatToSongPath(getNativeSongId());
		for (x in Highscore.songScores.keys())
		{
			if (x.startsWith(saveSongName) && Highscore.songScores[x] > 0)
			{
				wasCompleted = true;
				break;
			}
		}
		isNew = !wasCompleted;
	}

	public function loadAndGetDiffId()
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[levelId]);
		Difficulty.loadFromWeek(leWeek);
		return Difficulty.list.findIndex(s -> s.trim().toLowerCase() == currentDifficulty);
	}

	public function hasErectSong():Bool
	{
		var fileSngName = Paths.formatToSongPath(songId + "-erect");
		var sngDataPath = resolveSongDataPath(fileSngName);
		return sngDataPath != null && sys.FileSystem.exists(sngDataPath) && sys.FileSystem.isDirectory(sngDataPath);
	}
}
