package vslice.menus.states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.StageData;
import backend.Paths;
import backend.Mods;
import backend.Language;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Exception;
import vslice.compatibility.freeplay.FreeplaySongData;
import vslice.menus.components.crash.UserErrorSubstate;
import openfl.utils.AssetType;
import states.LoadingState;
import states.PlayState;

class SongPrepareState extends MusicBeatState
{
	public var cap:FreeplaySongData;
	public var currentDifficulty:String;
	public var targetInstId:Null<String>;
	var started:Bool = false;

	public function new(cap:FreeplaySongData, currentDifficulty:String, ?targetInstId:String)
	{
		super();
		this.cap = cap;
		this.currentDifficulty = currentDifficulty;
		this.targetInstId = targetInstId;
	}

	override function create()
	{
		super.create();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var txt = new FlxText(0, 0, FlxG.width, Language.getPhrase('loading_text', 'Yükleniyor...'), 32);
		txt.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		txt.screenCenter();
		add(txt);

		new FlxTimer().start(0.01, function(_)
		{
			startLoading();
		});
	}

	function startLoading():Void
	{
		if (started) return;
		started = true;

		if (cap == null)
		{
			UserErrorSubstate.makeMessage(
				Language.getPhrase('error_song_load_title', 'Failed to load a song'),
				'FreeplaySongData is null.'
			);
			return;
		}

		if (cap.folder != null)
			Mods.currentModDirectory = cap.folder;
		else
			Mods.loadTopMod();

		var diffId:Int = cap.loadAndGetDiffId();
		if (diffId == -1)
		{
			trace("SELECTED DIFFICULTY IS MISSING: " + currentDifficulty);
			diffId = 0;
		}

		if (targetInstId != null && targetInstId != "default")
		{
			var instPath = '${Paths.formatToSongPath(targetInstId)}/Inst.ogg';
			if (Paths.fileExists(instPath, AssetType.BINARY, false, "songs"))
			{
				PlayState.altInstrumentals = targetInstId;
			}
			else
			{
				UserErrorSubstate.makeMessage(
					Language.getPhrase('error_missing_inst_title', 'Missing instrumentals'),
					Language.getPhrase('error_missing_inst_body',
						'Couldn\'t find Inst in \nsongs/{1}\nMake sure that there is a Inst.ogg file')
						.replace('{1}', instPath)
				);
				return;
			}
		}
		else
		{
			PlayState.altInstrumentals = null;
		}

		var songLowercase:String = Paths.formatToSongPath(cap.getNativeSongId());
		var poop:String = Highscore.formatSong(songLowercase, diffId);

		try
		{
			PlayState.SONG = Song.loadFromJson(poop, songLowercase);
			if (PlayState.SONG == null)
				throw "Song parsing failed!";

			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = diffId;

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;

			trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
		}
		catch (e:Dynamic)
		{
			trace('ERROR! ' + Std.string(e));

			var errMsg:String = Std.string(e);

			try
			{
				var ex:Exception = cast e;
				errMsg = ex.message + "\n\n" + ex.details();
			}
			catch (_:Dynamic) {}

			UserErrorSubstate.makeMessage(
				Language.getPhrase('error_song_load_title', 'Failed to load a song'),
				errMsg
			);
			return;
		}

		#if !SHOW_LOADING_SCREEN
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		#end

		LoadingState.loadAndSwitchState(new PlayState(), true);

		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;

		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
	}
}
