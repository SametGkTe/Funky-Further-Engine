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

	public static function loadSongs():Array<FreeplaySongData>
	{
		var songs = [];
		WeekData.reloadWeekFiles(false);
		// programmatically adds the songs via LevelRegistry and SongRegistry
		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]); // TODO tweak this
			if (leWeek == null)
				continue;

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				// trace("pushing "+song);
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				var sngCard = new FreeplaySongData(i, song[0], song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
				if (sngCard.songDifficulties.length == 0)
					continue;

				songs.push(sngCard);
			}
		}
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
		state.openSubState(new ResetScoreSubState(sng.songName, sng.loadAndGetDiffId(), sng.songCharacter, -1));
	}

	public inline static function openGameplayChanges(state:FreeplayState)
	{
		state.openSubState(new GameplayChangersSubstate());
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
