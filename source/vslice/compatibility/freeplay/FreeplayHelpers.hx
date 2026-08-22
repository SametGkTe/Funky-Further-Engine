package vslice.compatibility.freeplay;

import backend.CustomFadeTransition;
import backend.WeekData;
import vslice.menus.states.SongPrepareState;
import haxe.Exception;
import backend.StageData;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import vslice.menus.components.crash.UserErrorSubstate;
import openfl.utils.AssetType;
import vslice.menus.freeplay.pslice.BPMCache;
import vslice.menus.freeplay.FreeplayState;
import backend.Song;
import backend.Highscore;
import backend.WeekData;
import states.StoryMenuState;

class FreeplayHelpers
{
	public static var BPM(get, set):Float;

	public static function set_BPM(value:Float)
	{
		Conductor.bpm = value;
		return value;
	}

	public static function get_BPM()
	{
		return Conductor.bpm;
	}

	public static function withCategoryHeaders(list:Array<Null<FreeplaySongData>>, ?search:String):Array<Null<FreeplaySongData>>
	{
		if (list == null)
			return [];
		if (!backend.freeplay.FreeplayCatalog.isGrouped())
		{
			var stripped:Array<Null<FreeplaySongData>> = [];
			for (item in list)
			{
				if (item != null && item.isCategoryHeader)
					continue;
				if (item != null && backend.freeplay.FreeplayCatalog.shouldHideFolder(item.folder))
					continue;
				stripped.push(item);
			}
			return stripped;
		}

		var leading:Array<Null<FreeplaySongData>> = [];
		var rest:Array<FreeplaySongData> = [];
		var sawSong:Bool = false;
		for (item in list)
		{
			if (item != null && item.isCategoryHeader)
				continue;
			if (!sawSong && item == null)
			{
				leading.push(item);
				continue;
			}
			sawSong = true;
			if (item != null)
				rest.push(item);
		}

		var sources:Array<backend.freeplay.FreeplayRowSource> = [];
		for (i in 0...rest.length)
			sources.push({index: i, name: rest[i].songName, folder: rest[i].folder});

		var rows = backend.freeplay.FreeplayCatalog.buildRows(sources, search != null ? search : '');
		var out:Array<Null<FreeplaySongData>> = leading.copy();
		for (row in rows)
		{
			if (row.isHeader)
				out.push(FreeplaySongData.makeHeader(row.categoryId, row.categoryLabel, row.collapsed));
			else
				out.push(rest[row.sourceIndex]);
		}
		return out;
	}

	public static function loadSongs():Array<FreeplaySongData>
	{
		var songs = [];
		var catalogEntries = backend.freeplay.FreeplayCatalog.ensureLoaded();
		var hydrated = false;

		for (entry in catalogEntries)
		{
			if (backend.freeplay.FreeplayCatalog.shouldHideFolder(entry.folder))
				continue;

			var sngCard = FreeplaySongData.fromEntry(entry);
			if (!ClientPrefs.data.quickFreeplay)
			{
				// Full resolve already ran inside the constructor (light flag off).
				backend.freeplay.FreeplayCatalog.captureFromHydrated(
					entry,
					sngCard.songDifficulties,
					sngCard.songPlayer,
					sngCard.albumId,
					sngCard.difficultyRating,
					sngCard.allowErect,
					sngCard.songStartingBpm,
					sngCard.levelName
				);
				hydrated = true;
			}
			if (sngCard.songDifficulties.length == 0)
				continue;
			songs.push(sngCard);
		}

		if (hydrated)
			backend.freeplay.FreeplayCatalog.saveAfterHydrate();

		return songs;
	}

	public static function moveToPlaystate(state:FreeplayState, cap:FreeplaySongData, currentDifficulty:String, ?targetInstId:String)
	{
		state.persistentUpdate = false;

		// Şarkıya giriş: CustomFadeTransition (siyah) ile geçiş
		FlxG.state.openSubState(new CustomFadeTransition(0.5, false));
		CustomFadeTransition.finishCallback = function() FlxG.switchState(new SongPrepareState(cap, currentDifficulty, targetInstId));
	}

	public static function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore != null
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	public static function exitFreeplay()
	{
		BPMCache.instance.clearCache();
		Mods.loadTopMod();
		FlxG.signals.postStateSwitch.dispatch(); // ? for the screenshot plugin to clean itself
	}

	public inline static function openResetScoreState(state:FreeplayState, sng:FreeplaySongData, onScoreReset:() -> Void = null)
	{
		state.openOverlaySubState(new ResetScoreSubState(sng.songName, sng.loadAndGetDiffId(), sng.songCharacter, -1));
	}

	public inline static function openGameplayChanges(state:FreeplayState)
	{
		state.openOverlaySubState(new GameplayChangersSubstate());
	}

	public static function loadDiffsFromWeek(songData:FreeplaySongData)
	{
		Mods.currentModDirectory = songData.folder;
		PlayState.storyWeek = songData.levelId; // TODO
		Difficulty.loadFromWeek();
	}

	public static function getDifficultyName()
	{
		return Difficulty.list[PlayState.storyDifficulty].toUpperCase();
	}

	public static function updateConductorSongTime(time:Float)
	{
		Conductor.songPosition = time;
	}
}
