package states;

#if FURTHER_ONLINE
import online.PlayStateSync;
import online.GameClient;
#end

import sys.thread.Thread;
import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;
import backend.LeaderboardAPI;
import backend.PinnedNotes;

import vslice.menus.results.ResultState;
import vslice.menus.results.Tallies.SaveScoreData;
import vslice.funkin.Scoring;
import vslice.funkin.Scoring.ScoringRank;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxSort;

#if HSC_ALLOWED
import funkin.backend.scripting.HScript.ScriptPack;
import funkin.backend.scripting.ScriptLoader;
import funkin.backend.scripting.EventManager;
import funkin.backend.scripting.StrumLineCompat;
import funkin.backend.scripting.StrumLineCompat.StrumLineCompatMember;
import funkin.backend.scripting.events.NoteHitEvent;
#end
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import cutscenes.DialogueBoxPsych;

import states.StoryMenuState;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.PauseSubState;
import substates.GameOverSubstate;

#if !flash
import openfl.filters.ShaderFilter;
#end

import shaders.ErrorHandledShader;

import objects.VideoSprite;
import objects.Note.EventNote;
import objects.AlertMgr.AlertMsg;
import objects.*;
import states.stages.*;
import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.HScriptInfos;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

/**
 * This is where all the Gameplay stuff happens and is managed
 *
 * here's some useful tips if you are making a mod in source:
 *
 * If you want to add your stage to the game, copy states/stages/Template.hx,
 * and put your stage code there, then, on PlayState, search for
 * "switch (curStage)", and add your stage to that list.
 *
 * If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
 *
 * "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
 * "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
 * "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
 * "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for
**/

class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['Berbat!', 0.2], //From 0% to 19%
		['Çok Kötü', 0.4], //From 20% to 39%
		['Kötü', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Eh İşte', 0.69], //From 60% to 68%
		['Fena Değil', 0.7], //69%
		['İyi', 0.8], //From 70% to 79%
		['Harika', 0.9], //From 80% to 89%
		['Muhteşem!', 1], //From 90% to 99%
		['Mükemmel!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];
	
	public static var campaignSaveData:SaveScoreData = {
		score: 0,
		accPoints: 0,
		sick: 0,
		good: 0,
		bad: 0,
		shit: 0,
		missed: 0,
		combo: 0,
		maxCombo: 0,
		totalNotesHit: 0,
		totalNotes: 0
	};
	
	function emptySaveScoreData():SaveScoreData
	{
		return {
			score: 0,
			accPoints: 0,
			sick: 0,
			good: 0,
			bad: 0,
			shit: 0,
			missed: 0,
			combo: 0,
			maxCombo: 0,
			totalNotesHit: 0,
			totalNotes: 0
		};
	}

	function combineSaveScoreData(base:SaveScoreData, extra:SaveScoreData):SaveScoreData
	{
		return {
			score: base.score + extra.score,
			accPoints: base.accPoints + extra.accPoints,
			sick: base.sick + extra.sick,
			good: base.good + extra.good,
			bad: base.bad + extra.bad,
			shit: base.shit + extra.shit,
			missed: base.missed + extra.missed,
			combo: extra.combo,
			maxCombo: Std.int(Math.max(base.maxCombo, extra.maxCombo)),
			totalNotesHit: base.totalNotesHit + extra.totalNotesHit,
			totalNotes: base.totalNotes + extra.totalNotes
		};
	}

	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();
	
	public static var storyDifficultyColor:FlxColor = FlxColor.GRAY;
	public static var altInstrumentals:String = null;

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var curStage:String = '';
	public static var stageUI(default, set):String = "normal";
	public static var uiPrefix:String = "";
	public static var uiPostfix:String = "";
	public static var isPixelStage(get, never):Bool;
	
	public var luaExtraKeys:Int = -1; // Extra Keys Lua Scripts Support
	
	var canSaveScore:Bool = false;

	@:noCompletion
	static function set_stageUI(value:String):String
	{
		uiPrefix = uiPostfix = "";
		if (value != "normal")
		{
			uiPrefix = value.split("-pixel")[0].trim();
			if (value == "pixel" || value.endsWith("-pixel")) uiPostfix = "-pixel";
		}
		return stageUI = value;
	}

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 2000;
	
	// P.E.T Filigran değişkenleri
	var petLogo:FlxSprite;
	var petText:FlxText;
	
	
	var leaderboardSubmitted:Bool = false;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	public var grpHoldSplashes:FlxTypedGroup<SustainSplash> = new FlxTypedGroup<SustainSplash>();

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health(default, set):Float = 1;
	public var combo:Int = 0;

	public var healthBar:Bar;
	public var timeBar:Bar;
	var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;

	public var guitarHeroSustains:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;
	public var pressMissDamage:Float = 0.05;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camBar:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var luaTpadCam:FlxCamera;
	public var cameraSpeed:Float = 1;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	public static var instance:PlayState;

	#if HSC_ALLOWED
	/** CNE (Codename Engine) HScript şarkı scriptleri */
	public var cneScripts:ScriptPack;
	#end
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end
	public var introSoundsSuffix:String = '';

	private var keysArray:Array<String>;
	public var songName:String;

	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	private var shutdownThread:Bool = false;
	private var gameFroze:Bool = false;
	private var requiresSyncing:Bool = false;
	private var lastCorrectSongPos:Float = -1.0;

	private static var _lastLoadedModDirectory:String = '';
	public static var nextReloadAll:Bool = false;

	public var luaTouchPad:TouchPad;

	override public function create()
	{
		//trace('Playback Rate: ' + playbackRate);
		#if MODS_ALLOWED
		Song.restoreModDirectory();
		#end
		_lastLoadedModDirectory = Mods.currentModDirectory;
		Paths.clearStoredMemory();
		if(nextReloadAll)
		{
			Paths.clearUnusedMemory();
			Language.reloadPhrases();
		}
		nextReloadAll = false;

		// Sabitlenmiş Notalar: modlar dokunmadan prefs'i kaydet + izin diyalogunu hazırla
		PinnedNotes.snapshotPrefs();
		PinnedNotes.onSongStart(this);

		startCallback = startCountdown;
		endCallback = endSong;

		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		keysArray = [
			'note_left', 'note_down', 'note_up', 'note_right',
			'note_extra1', 'note_extra2', 'note_extra3', 'note_extra4', 'note_extra5'
		];

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();

		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initPsychCamera();
		camBar = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		luaTpadCam = new FlxCamera();
		camBar.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		luaTpadCam.bgColor.alpha = 0;

		FlxG.cameras.add(camBar, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		FlxG.cameras.add(luaTpadCam, false);

		persistentUpdate = true;
		persistentDraw = true;

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if DISCORD_ALLOWED
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		storyDifficultyText = Difficulty.getString();

		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if(SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));

		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else if (stageData.isPixelStage == true) //Backward compatibility
			stageUI = "pixel";

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage)
		{
			case 'stage': new StageWeek1(); 			//Week 1
			case 'spooky': new Spooky();				//Week 2
			case 'philly': new Philly();				//Week 3
			case 'limo': new Limo();					//Week 4
			case 'mall': new Mall();					//Week 5 - Cocoa, Eggnog
			case 'mallEvil': new MallEvil();			//Week 5 - Winter Horrorland
			case 'school': new School();				//Week 6 - Senpai, Roses
			case 'schoolEvil': new SchoolEvil();		//Week 6 - Thorns
			case 'tank': new Tank();					//Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new PhillyStreets(); 	//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new PhillyBlazin();	//Weekend 1 - Blazin
		}
		if(isPixelStage) introSoundsSuffix = '-pixel';

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		luaDebugGroup = new FlxTypedGroup<psychlua.DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		if (!stageData.hide_girlfriend)
		{
			if(SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		
		if(stageData.objects != null && stageData.objects.length > 0)
		{
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup, boyfriendGroup, this);
			for (key => spr in list)
				if(!StageData.reservedNames.contains(key))
					variables.set(key, spr);
		}
		else
		{
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
			#if linux
			for (file in CoolUtil.sortAlphabetically(Paths.readDirectory(folder)))
			#else
			for (file in Paths.readDirectory(folder))
			#end
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					pushFunkinLua(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}
		#end
			
		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		#if LUA_ALLOWED startLuasNamed('stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('stages/' + curStage + '.hx'); #end

		if(gf != null) startCharacterScripts(gf.curCharacter);
		startCharacterScripts(dad.curCharacter);
		startCharacterScripts(boyfriend.curCharacter);
		#end

		uiGroup = new FlxSpriteGroup();
		comboGroup = new FlxSpriteGroup();
		noteGroup = new FlxTypedGroup<FlxBasic>();
		add(comboGroup);
		add(uiGroup);
		add(noteGroup);

		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if(ClientPrefs.data.downScroll) timeTxt.y = FlxG.height - 44;
		if(ClientPrefs.data.timeBarType == 'Song Name') timeTxt.text = SONG.song;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		noteGroup.add(strumLineNotes);

		if(ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		generateSong();

		noteGroup.add(grpNoteSplashes);
		noteGroup.add(grpHoldSplashes);

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		uiGroup.add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		uiGroup.add(scoreTxt);

		botplayTxt = new FlxText(400, healthBar.y - 90, FlxG.width - 800, Language.getPhrase("botplay", "Bot Oynayışı").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		uiGroup.add(botplayTxt);
		if(ClientPrefs.data.downScroll)
			botplayTxt.y = healthBar.y + 70;

		uiGroup.cameras = [camHUD];
		noteGroup.cameras = [camHUD];
		comboGroup.cameras = [camHUD];

		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypes)
			startLuasNamed('custom_notetypes/' + notetype + '.lua');
		for (event in eventsPushed)
		{
			// V-SLICE KÖPRÜSÜ: custom_events/ altında yoksa V-Slice modlarının
			// doğal konumu olan scripts/events/<Event>.lua da denenir.
			if (!startLuasNamed('custom_events/' + event + '.lua'))
				startLuasNamed('scripts/events/' + event + '.lua');
		}
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
			startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		for (event in eventsPushed)
			startHScriptsNamed('custom_events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/$songName/'))
			#if linux
			for (file in CoolUtil.sortAlphabetically(Paths.readDirectory(folder)))
			#else
			for (file in Paths.readDirectory(folder))
			#end
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					pushFunkinLua(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}

		#if (LUA_ALLOWED && MODS_ALLOWED)
		// V-SLICE KÖPRÜSÜ: scripts/songs/<şarkı>.lua — mod kökündeki doğal konum.
		// CODENAME KÖPRÜSÜ: songs/<şarkı>/scripts/*.lua — CNE kökündeki doğal konum.
		var nativeSearchMods:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			nativeSearchMods.push(Mods.currentModDirectory);
		for (g in Mods.getGlobalMods())
			if (!nativeSearchMods.contains(g)) nativeSearchMods.push(g);
		function pushNativeLua(pth:String):Void
		{
			for (script in luaArray)
				if (script.scriptName == pth) return;
			pushFunkinLua(pth);
		}
		for (nativeMod in nativeSearchMods)
		{
			var vsSongLua:String = Paths.mods(nativeMod + '/scripts/songs/$songName.lua');
			if (FileSystem.exists(vsSongLua)) pushNativeLua(vsSongLua);

			var cneSongDir:String = cne.compatibility.CNECompat.songDir(nativeMod, songName);
			if (cneSongDir != null)
			{
				var cneScripts:String = cneSongDir + '/scripts/';
				if (FileSystem.exists(cneScripts) && FileSystem.isDirectory(cneScripts))
				{
					for (file in Paths.readDirectory(cneScripts))
						if (StringTools.endsWith(file.toLowerCase(), '.lua'))
							pushNativeLua(cneScripts + file);
				}
			}
		}
		#end
		#end
		#if HSC_ALLOWED
		// CNE HSCRIPT KÖPRÜSÜ: songs/<şarkı>/scripts/*.{hx,hscript,hxs,hxc,hsc} + codenameScripts/
		loadCneHScripts();
		cneScripts.set('dad', dad);
		cneScripts.set('boyfriend', boyfriend);
		cneScripts.set('gf', gf);
		cneScripts.set('strumLines', buildCneStrumLines());
		cneScripts.setupPlayState();
		cneScripts.call('create');
		#end
		addMobileControls();
		if (mobileControls != null)
		{
			mobileControls.instance.visible = true;
			mobileControls.onButtonDown.add(onButtonPress);
			mobileControls.onButtonUp.add(onButtonRelease);
		}

		if(eventNotes.length > 0)
		{
			for (event in eventNotes) event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		#if FURTHER_ONLINE
		if (GameClient.isConnected())
		{
			// Countdown waits for both clients (PlayStateSync on startSong)
			trace("[Online] deferring startCallback until startSong");
		}
		else
		#end
		startCallback();
		RecalculateRating(false, false);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		//PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		if(ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');
		if(!ClientPrefs.data.ghostTapping) for (i in 1...4) Paths.sound('missnote$i');
		Paths.image('alphabet');

		if (PauseSubState.songName != null)
			Paths.music(PauseSubState.songName);
		else if(Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
			Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));

		resetRPC();

		stagesFunc(function(stage:BaseStage) stage.createPost());
		callOnScripts('onCreatePost');
		
		
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; //cant make it invisible or it won't allow precaching
		splash.kill();

		#if mobile
		addTouchPad('NONE', 'PAUSE');
		addTouchPadCamera();
		#end
		
		if (ClientPrefs.data.petwatermark) createPETWatermark();

		super.create();

		cacheCountdown();
		cachePopUpScore();
		
		if (!ClientPrefs.data.serverConnection && !ClientPrefs.data.hideServerConnectionWarning)
		{
			AlertMsg.showChoice(
				"Sunucu Bağlantısı kapalı!",
				"Puanlarınız ve Skorlarınız sunucuya gönderilmeyecektir! Ayarlar > Oynanış'dan aktif edin",
				5,
				AlertMsg.COLOR_WARNING,
				"TAMAM",
				null,
				"BİR DAHA GÖSTERME",
				function()
				{
					ClientPrefs.data.hideServerConnectionWarning = true;
					ClientPrefs.saveSettings();
				},
				true
			);
		}

		if(eventNotes.length < 1) checkEventNote();

		#if FURTHER_ONLINE
		if (GameClient.isConnected())
		{
			PlayStateSync.bind(this);
			practiceMode = true; // no game-over fail online
			cpuControlled = false;
			// CRITICAL: window minimize / alt-tab must NOT pause the song (desync)
			FlxG.autoPause = false;
		}
		#end
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
		{
			if (vocals != null) vocals.pitch = value;
			if (opponentVocals != null) opponentVocals.pitch = value;
			if (FlxG.sound.music != null) FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.offset = Reflect.hasField(PlayState.SONG, 'offset') ? (PlayState.SONG.offset / value) : 0;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if VIDEOS_ALLOWED
		if(videoCutscene != null && videoCutscene.videoSprite != null) videoCutscene.videoSprite.bitmap.rate = value;
		#end
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return playbackRate;
	}

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	public function addTextToDebug(text:String, color:FlxColor) {
		var newText:psychlua.DebugLuaText = luaDebugGroup.recycle(psychlua.DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:psychlua.DebugLuaText) {
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);

		Sys.println(text);
	}
	#end

	public function reloadHealthBarColors() {
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String)
	{
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(replacePath))
		{
			luaFile = replacePath;
			doPush = true;
		}
		else
		{
			luaFile = Paths.getSharedPath(luaFile);
			if(FileSystem.exists(luaFile))
				doPush = true;
		}
		#else
		luaFile = Paths.getSharedPath(luaFile);
		if(Assets.exists(luaFile)) doPush = true;
		#end

		if(doPush)
		{
			for (script in luaArray)
			{
				if(script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}
			if(doPush) pushFunkinLua(luaFile);
		}
		#end

		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(scriptFile);
		if(FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		#end
		{
			scriptFile = Paths.getSharedPath(scriptFile);
			if(FileSystem.exists(scriptFile))
				doPush = true;
		}

		if(doPush)
		{
			if(Iris.instances.exists(scriptFile))
				doPush = false;

			if(doPush) initHScript(scriptFile);
		}
		#end
	}

	public function getLuaObject(tag:String):Dynamic
		return variables.get(tag);

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public var videoCutscene:VideoSprite = null;
	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = !forMidSong;
		canPause = forMidSong;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;

		if (foundFile)
		{
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);
			if(forMidSong) videoCutscene.videoSprite.bitmap.rate = playbackRate;

			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (!isDead && generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = true;

			SustainSplash.startCrochet = Conductor.stepCrochet;
			SustainSplash.frameRate = Math.floor(24 / 100 * SONG.bpm);
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
			}
			if (GameOverSubstate.instance != null && isDead) GameOverSubstate.instance.add(videoCutscene);
			else add(videoCutscene);

			if (playOnLoad)
				videoCutscene.play();
			return videoCutscene;
		}
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		else addTextToDebug("Video bulunamadı: " + fileName, FlxColor.RED);
		#else
		else FlxG.log.error("Video bulunamadı: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform desteklenmiyor!');
		startAndEnd();
		#end
		return null;
	}

	function startAndEnd()
	{
		if(endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('diyalog dosyanızın formatı yanlış!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = switch(stageUI) {
			case "pixel": ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
			case "normal": ["ready", "set" ,"go"];
			default: ['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
		}
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts) Paths.image(asset);

		for (base in ['intro3', 'intro2', 'intro1', 'introGo'])
			Paths.sound(resolveIntroSound(base));
	}

	function resolveIntroSound(base:String):String
	{
		var preferred:String = base + introSoundsSuffix;
		if (preferred != base && Paths.fileExists('sounds/' + preferred + '.' + Paths.SOUND_EXT, openfl.utils.AssetType.SOUND))
			return preferred;
		return base;
	}

	public function startCountdown()
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if(ret != LuaUtils.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			canPause = true;

			generateStaticArrows(0);
			generateStaticArrows(1);

			// Mania dahil: her oyuncu şeridi için blok bayrağı (noteData 8'e kadar erişilebilir)
			strumsBlocked = [];
			for (i in 0...playerStrums.length)
				strumsBlocked.push(false);

			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}

			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}

				if (ClientPrefs.data.ogGameControls) enableVSliceControls();

				PinnedNotes.capture(this);
				PinnedNotes.captureHud(this);

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			var swagCounter:Int = 0;
			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch(stageUI) {
					case "pixel": ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
					case "normal": ["ready", "set" ,"go"];
					default: ['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
				var tick:Countdown = THREE;

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound(resolveIntroSound('intro3')), 0.6);
						tick = THREE;
					case 1:
						countdownReady = createCountdownSprite(introAlts[0], antialias);
						FlxG.sound.play(Paths.sound(resolveIntroSound('intro2')), 0.6);
						tick = TWO;
					case 2:
						countdownSet = createCountdownSprite(introAlts[1], antialias);
						FlxG.sound.play(Paths.sound(resolveIntroSound('intro1')), 0.6);
						tick = ONE;
					case 3:
						countdownGo = createCountdownSprite(introAlts[2], antialias);
						FlxG.sound.play(Paths.sound(resolveIntroSound('introGo')), 0.6);
						tick = GO;
					case 4:
						tick = START;
				}

				if(!skipArrowStartTween)
				{
					notes.forEachAlive(function(note:Note) {
						if(ClientPrefs.data.opponentStrums || note.mustPress)
						{
							note.copyAlpha = false;
							note.alpha = note.multAlpha;
							if(ClientPrefs.data.middleScroll && !note.mustPress)
								note.alpha *= 0.35;
						}
					});
				}

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tick, swagCounter]);

				swagCounter += 1;
			}, 5);
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(noteGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				//if(!ClientPrefs.data.lowQuality || !cpuControlled) daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	public dynamic function updateScore(miss:Bool = false, scoreBop:Bool = true)
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [miss], true);
		if (ret == LuaUtils.Function_Stop)
			return;

		updateScoreText();
		if (!miss && !cpuControlled && scoreBop)
			doScoreBop();

		callOnScripts('onUpdateScore', [miss]);
	}

	public dynamic function updateScoreText()
	{
		var str:String = Language.getPhrase('rating_$ratingName', ratingName);
		if(totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' (${percent}%) - ' + Language.getPhrase(ratingFC);
		}

		var tempScore:String;
		if(!instakillOnMiss) tempScore = Language.getPhrase('score_text', 'Skor: {1} | Iskalar: {2} | Doğruluk: {3}', [songScore, songMisses, str]);
		else tempScore = Language.getPhrase('score_text_instakill', 'Skor: {1} | Doğruluk: {2}', [songScore, str]);
		scoreTxt.text = tempScore;
		#if FURTHER_ONLINE
		if (GameClient.isConnected() && GameClient.room != null && GameClient.room.state != null)
		{
			try {
				var extra = " | ";
				var keys:Array<String> = [];
				var items:Dynamic = Reflect.field(GameClient.room.state.players, "items");
				if (items != null) {
					var ks:Array<Dynamic> = cast Reflect.field(items, "_keys");
					if (ks != null) for (k in ks) keys.push(Std.string(k));
				}
				for (sid in keys) {
					var pl = GameClient.room.state.players.get(sid);
					if (pl == null) continue;
					var tag = (sid == GameClient.room.sessionId) ? "YOU" : "OPP";
					extra += tag + ":" + Std.int(pl.score) + " ";
				}
				scoreTxt.text = tempScore + extra;
			} catch (_:Dynamic) {}
		}
		#end
	}

	public dynamic function fullComboFunction()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = "";
		if(songMisses == 0)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else {
			if (songMisses < 10) ratingFC = 'SDCB';
			else ratingFC = 'Clear';
		}
	}

	public function doScoreBop():Void {
		if(!ClientPrefs.data.scoreZoom)
			return;

		if(scoreTxtTween != null)
			scoreTxtTween.cancel();

		scoreTxt.scale.x = 1.075;
		scoreTxt.scale.y = 1.075;
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(twn:FlxTween) {
				scoreTxtTween = null;
			}
		});
	}

	public function setSongTime(time:Float)
	{
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();

		FlxG.sound.music.time = time - Conductor.offset;
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.play();

		if (Conductor.songPosition < vocals.length)
		{
			vocals.time = time - Conductor.offset;
			#if FLX_PITCH vocals.pitch = playbackRate; #end
			vocals.play();
		}
		else vocals.pause();

		if (Conductor.songPosition < opponentVocals.length)
		{
			opponentVocals.time = time - Conductor.offset;
			#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
			opponentVocals.play();
		}
		else opponentVocals.pause();
		Conductor.songPosition = time;
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;

		@:privateAccess
		if (inst == null || inst._sound == null)
		{
			try
			{
			#if MODS_ALLOWED
			Song.restoreModDirectory();
			#end
			if ((Mods.currentModDirectory == null || Mods.currentModDirectory.length < 1)
				&& _lastLoadedModDirectory != null && _lastLoadedModDirectory.length > 0)
				Mods.currentModDirectory = _lastLoadedModDirectory;
			var snd = Paths.inst(SONG != null ? SONG.song : songName);
				if (snd != null)
				{
					if (inst == null) inst = new FlxSound();
					inst.loadEmbedded(snd);
					if (!FlxG.sound.list.members.contains(inst))
						FlxG.sound.list.add(inst);
				}
			}
			catch (e:Dynamic) {}
		}

		@:privateAccess
		if (inst == null || inst._sound == null)
		{
			AlertMsg.show(
				Language.getPhrase('inst_missing_title', 'Şarkı Müziği Yüklenemedi'),
				Language.getPhrase('inst_missing_body', '"{1}" şarkısının Inst dosyası bulunamadı.', [songName]),
				8,
				AlertMsg.COLOR_ERROR
			);
			return;
		}

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		if (FlxG.sound.music != null)
			FlxG.sound.music.onComplete = finishSong.bind();
		vocals.play();
		opponentVocals.play();

		setSongTime(Math.max(0, startOnTime - 500) + Conductor.offset);
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		if(autoUpdateRPC) DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');

		runSongSyncThread();
	}

	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];
	public var totalColumns: Int = resolveTotalColumns();

	static function resolveTotalColumns():Int
	{
		var cols:Int = ClientPrefs.data.mania >= 5 ? ClientPrefs.data.mania : 4;
		// Şarkı kendi mania değerini bildiriyorsa (CNE mania chart'ları dahil) ayar onu kullanır
		if (PlayState.SONG != null && PlayState.SONG.mania != null && PlayState.SONG.mania > 4)
			cols = PlayState.SONG.mania;
		return Std.int(Math.min(9, Math.max(4, cols)));
	}

	/** Oyun sırasında geçerli mania tuş sayısı (hitbox ve UI için). */
	public static function getManiaColumns():Int
	{
		if (instance != null && instance.totalColumns > 4)
			return instance.totalColumns;
		return ClientPrefs.data.mania >= 5 ? ClientPrefs.data.mania : 4;
	}

	private function generateSong():Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(songData.song, (boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song));
				
				var oppVocals = Paths.voices(songData.song, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
				if(oppVocals != null && oppVocals.length > 0) opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch (e:Dynamic) {}

		#if FLX_PITCH
		vocals.pitch = playbackRate;
		opponentVocals.pitch = playbackRate;
		#end
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			#if MODS_ALLOWED
			Song.restoreModDirectory();
			#end
			if ((Mods.currentModDirectory == null || Mods.currentModDirectory.length < 1)
				&& _lastLoadedModDirectory != null && _lastLoadedModDirectory.length > 0)
				Mods.currentModDirectory = _lastLoadedModDirectory;
			var loadedInst = Paths.inst(songData.song);
			if (loadedInst != null)
				inst.loadEmbedded(loadedInst);
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		noteGroup.add(notes);

		try
		{
			var externalEvents = Song.getExternalEvents(songName);
			trace('[PlayState] External events loaded: ${externalEvents.length}');
			for (event in externalEvents)
				if (event != null && event.length > 1 && event[1] != null)
					for (i in 0...event[1].length)
						makeEvent(event, i);
		}
		catch(e:Dynamic)
		{
			trace('[PlayState] events.json işlenemedi: $e');
		}

		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = PlayState.SONG.notes;
		var ghostNotesCaught:Int = 0;
		var daBpm:Float = Conductor.bpm;
	
		for (section in sectionsData)
		{
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i in 0...section.sectionNotes.length)
			{
				final songNotes: Array<Dynamic> = section.sectionNotes[i];
				var spawnTime: Float = songNotes[0];
				var rawLane:Int = Std.int(songNotes[1]);
				var holdLength: Float = songNotes[2];
				var noteType: String = !Std.isOfType(songNotes[3], String) ? Note.defaultNoteTypes[songNotes[3]] : songNotes[3];
				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				var noteColumn:Int;
				var gottaHitNote:Bool;
				if (totalColumns > 4)
				{
					// Mania: 0-3 oyuncu, 4-7 rakip, 8+ oyuncu ekstra tuşları
					var mapped:Null<ManiaLane> = maniaMapLane(rawLane);
					if (mapped == null) continue; // bu düzende oynanamayan şerit
					noteColumn = mapped.column;
					gottaHitNote = mapped.isPlayer;
				}
				else
				{
					if (rawLane < 0 || rawLane >= 8) continue; // 4K'da mania şeritleri oynanamaz
					noteColumn = rawLane % 4;
					gottaHitNote = rawLane < 4;
				}

				if (i != 0) {
					// CLEAR ANY POSSIBLE GHOST NOTES
					for (evilNote in unspawnNotes) {
						var matches: Bool = (noteColumn == evilNote.noteData && gottaHitNote == evilNote.mustPress && evilNote.noteType == noteType);
						if (matches && Math.abs(spawnTime - evilNote.strumTime) < flixel.math.FlxMath.EPSILON) {
							if (evilNote.tail.length > 0)
								for (tail in evilNote.tail)
								{
									tail.destroy();
									unspawnNotes.remove(tail);
								}
							evilNote.destroy();
							unspawnNotes.remove(evilNote);
							ghostNotesCaught++;
						}
					}
				}

				var swagNote:Note = new Note(spawnTime, noteColumn, oldNote);
				var isAlt: Bool = section.altAnim && !gottaHitNote;
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
				swagNote.animSuffix = isAlt ? "-alt" : "";
				swagNote.mustPress = gottaHitNote;
				#if FURTHER_ONLINE
				// Guest (bfSide=false) plays opponent chart lane
				if (GameClient.isConnected() && !GameClient.playsAsBF())
					swagNote.mustPress = !swagNote.mustPress;
				#end
				if (totalColumns > 4)
				{
					var strumGroup:FlxTypedGroup<StrumNote> = gottaHitNote ? playerStrums : opponentStrums;
					var strum:StrumNote = strumGroup.members[noteColumn];
					if (strum != null)
					{
						// Nota strum'a hizalanır (genel yarım ekran ofseti UYGULANMAZ!)
						swagNote.x = strum.x + (strum.width - swagNote.width) / 2;
						if (strum.scale.x < 1 || strum.scale.y < 1)
						{
							swagNote.scale.set(strum.scale.x, strum.scale.y);
							swagNote.updateHitbox();
						}
					}
				}
				swagNote.sustainLength = holdLength;
				swagNote.noteType = noteType;
	
				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);

				var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
				final roundSus:Int = Math.round(swagNote.sustainLength / curStepCrochet);
				if(roundSus > 0)
				{
					for (susNote in 0...roundSus)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(spawnTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);

						sustainNote.correctionOffset = swagNote.height / 2;
						if (totalColumns > 4)
						{
							if (swagNote.scale.x < 1)
							{
								sustainNote.scale.x = swagNote.scale.x;
								sustainNote.updateHitbox();
							}
							sustainNote.x = swagNote.x + (swagNote.width - sustainNote.width) / 2;
						}
						if(!PlayState.isPixelStage)
						{
							if(oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
							}

							if(ClientPrefs.data.downScroll)
								sustainNote.correctionOffset = 0;
						}
						else if(oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
						}

						if (totalColumns <= 4)
						{
							if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
							else if(ClientPrefs.data.middleScroll)
							{
								sustainNote.x += 310;
								if(noteColumn > 1) //Up and Right
									sustainNote.x += FlxG.width / 2 + 25;
							}
						}
					}
				}

				if (totalColumns <= 4)
				{
					if (swagNote.mustPress)
					{
						swagNote.x += FlxG.width / 2; // general offset
					}
					else if(ClientPrefs.data.middleScroll)
					{
						swagNote.x += 310;
						if(noteColumn > 1) //Up and Right
						{
							swagNote.x += FlxG.width / 2 + 25;
						}
					}
				}
				if(!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);

				oldNote = swagNote;
			}
		}
		trace('["${SONG.song.toUpperCase()}" CHART INFO]: Ghost Notes Cleared: $ghostNotesCaught');
		for (event in songData.events) //Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}
	
	function submitLeaderboardOnce():Void
	{
		if (leaderboardSubmitted)
			return;

		leaderboardSubmitted = true;

		var submitPercent:Float = ratingPercent;
		if (Math.isNaN(submitPercent))
			submitPercent = 0;

		var botplay:Bool = cpuControlled || ClientPrefs.getGameplaySetting('botplay');
		var allowSave:Bool = !practiceMode && !botplay;

		trace('[LeaderboardAPI] submitLeaderboardOnce()');
		trace('[LeaderboardAPI] allowSave=' + allowSave
			+ ' practiceMode=' + practiceMode
			+ ' cpuControlled=' + cpuControlled
			+ ' gameplayBotplay=' + ClientPrefs.getGameplaySetting('botplay')
			+ ' loggedIn=' + backend.AuthManager.isLoggedIn
			+ ' score=' + songScore
			+ ' percent=' + submitPercent
			+ ' misses=' + songMisses
			+ ' combo=' + combo
			+ ' song=' + (PlayState.SONG != null ? PlayState.SONG.song : 'null'));

		if (!allowSave)
		{
			trace('[LeaderboardAPI] SKIP: allowSave false');
			return;
		}

		if (!backend.AuthManager.isLoggedIn)
		{
			trace('[LeaderboardAPI] SKIP: not logged in');
			return;
		}

		if (songScore <= 0)
		{
			trace('[LeaderboardAPI] SKIP: songScore <= 0');
			return;
		}

		if (submitPercent <= 0)
		{
			trace('[LeaderboardAPI] SKIP: submitPercent <= 0');
			return;
		}

		trace('[LeaderboardAPI] Calling submitScore...');

		LeaderboardAPI.submitScore(
			backend.AuthManager.currentUsername,
			PlayState.SONG.song,
			Difficulty.getString(storyDifficulty),
			songScore,
			submitPercent * 100,
			ratingName,
			songMisses,
			combo
		);
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote) {
		eventPushedUnique(event);
		if(eventsPushed.contains(event.event)) {
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote) {
		switch(event.event) {
			case "Change Character":
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if(Math.isNaN(val1)) val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				Paths.sound(event.value1); //Precache sound
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float {
		var returnedValue:Null<Float> = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true);
		if(returnedValue != null && returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', [subEvent.event, subEvent.value1 != null ? subEvent.value1 : '', subEvent.value2 != null ? subEvent.value2 : '', subEvent.strumTime]);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		// Mania: oyuncu tarafı totalColumns kadar ok alır, rakip hep 4K kalır
		var maxStrum:Int = (player == 1 && totalColumns > 4) ? totalColumns : 4;
		for (i in 0...maxStrum)
		{
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else
			{
				if(ClientPrefs.data.middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) {
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();

			if (player == 1 && totalColumns > 4)
			{
				// Mania: oklar oyun alanına eşit aralıklarla ve ortalanmış dizilir;
				// şerit ok genişliğinden dar kalırsa oklar orantılı küçülür (çakışma olmaz)
				var laneW:Float = getManiaLaneWidth();
				var strumScale:Float = Math.min(1, laneW / Note.swagWidth);
				if (strumScale < 1)
				{
					babyArrow.scale.set(strumScale, strumScale);
					babyArrow.updateHitbox();
				}
				babyArrow.x = getManiaStrumX(i);
			}
		}
	}

	/** Mania şerit eşlemesi: standart chart şeridi → {kolon, oyuncu mu} */

	function maniaMapLane(rawLane:Int):Null<ManiaLane>
	{
		if (rawLane >= 0 && rawLane < 4) return {column: rawLane, isPlayer: true};
		if (rawLane >= 4 && rawLane < 8) return {column: rawLane - 4, isPlayer: false};
		// 8+ : oyuncu ekstra tuşları (mania-native chart'lar)
		var extraColumn:Int = 4 + (rawLane - 8);
		if (extraColumn < totalColumns) return {column: extraColumn, isPlayer: true};
		return null;
	}

	function getManiaLaneWidth():Float
	{
		var playWidth:Float = ClientPrefs.data.middleScroll ? FlxG.width : FlxG.width / 2;
		return playWidth / totalColumns;
	}

	function getManiaStrumX(lane:Int):Float
	{
		var laneW:Float = getManiaLaneWidth();
		var strumW:Float = Note.swagWidth * Math.min(1, laneW / Note.swagWidth);
		var start:Float = ClientPrefs.data.middleScroll ? 0 : FlxG.width / 2;
		return start + (lane + 0.5) * laneW - strumW / 2;
	}

	public static function getExtraKeys():Int
	{
		if (instance != null && instance.luaExtraKeys >= 0) return instance.luaExtraKeys;
		return ClientPrefs.data.extraKeys;
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				opponentVocals.pause();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		super.closeSubState();
		
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong && canResync)
			{
				resyncVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = true);

			paused = false;
			callOnScripts('onResume');
			resetRPC(startTimer != null && startTimer.finished);
			runSongSyncThread();
		}
	}

	#if DISCORD_ALLOWED
	override public function onFocus():Void
	{
		super.onFocus();
		if (!paused && health > 0)
		{
			resetRPC(Conductor.songPosition > 0.0);
		}
		shutdownThread = false;
		runSongSyncThread();
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();
		#if FURTHER_ONLINE
		if (GameClient.isConnected())
		{
			FlxG.autoPause = false;
			shutdownThread = false;
			return;
		}
		#end
		if (!paused && health > 0 && autoUpdateRPC)
		{
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
		shutdownThread = true;
	}
	#end

	// Updating Discord Rich Presence.
	public var autoUpdateRPC:Bool = true; //performance setting for custom RPC things
	function resetRPC(?showTime:Bool = false)
	{
		#if DISCORD_ALLOWED
		if(!autoUpdateRPC) return;

		if (showTime)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.data.noteOffset);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			}
			else voc.pause();
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var freezeCamera:Bool = false;
	var allowDebugKeys:Bool = true;

	override public function update(elapsed:Float)
	{
		#if FURTHER_ONLINE
		PlayStateSync.update(this);
		if (PlayStateSync.isWaitingStart() || PlayStateSync.isMatchOver())
		{
			// Freeze gameplay until startSong / after matchEnded
			super.update(elapsed);
			return;
		}
		#end
		if(!inCutscene && !paused && !freezeCamera) {
			FlxG.camera.followLerp = 0.04 * cameraSpeed * playbackRate;
			var idleAnim:Bool = boyfriend != null && (boyfriend.getAnimationName().startsWith('idle') || boyfriend.getAnimationName().startsWith('danceLeft') || boyfriend.getAnimationName().startsWith('danceRight'));
			if(!startingSong && !endingSong && idleAnim) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		}
		else FlxG.camera.followLerp = 0;
		callOnScripts('onUpdate', [elapsed]);

		super.update(elapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if(botplayTxt != null && botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		#if TOUCH_CONTROLS_ALLOWED
		var mobilePausePressed:Bool = (touchPad != null && touchPad.buttonP != null && touchPad.buttonP.justPressed)
			|| (mobileManager != null && mobileManager.mobilePad != null && mobileManager.mobilePad.getButton('buttonP') != null
				&& mobileManager.mobilePad.getButton('buttonP').justPressed)
			|| (luaTouchPad != null && luaTouchPad.buttonP != null && luaTouchPad.buttonP.justPressed);
		#else
		var mobilePausePressed:Bool = false;
		#end

		if ((controls.PAUSE #if android || FlxG.android.justReleased.BACK #end || mobilePausePressed) && startedCountdown && canPause)
		{
			#if FURTHER_ONLINE
			if (PlayStateSync.active()) return;
			#end
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if(ret != LuaUtils.Function_Stop) {
				openPauseMenu();
			}
		}

		if(!endingSong && !inCutscene && allowDebugKeys)
		{
			if (controls.justPressed('debug_1'))
				openChartEditor();
			else if (controls.justPressed('debug_2'))
				openCharacterEditor();
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
			health = healthBar.bounds.max;

		updateIconsScale(elapsed);
		updateIconsPosition();

		if (startedCountdown && !paused)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			if (Conductor.songPosition >= Conductor.offset && FlxG.sound.music != null)
			{
				Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));
				var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			var songCalc:Float = (songLength - curTime);
			if(ClientPrefs.data.timeBarType == 'Time Elapsed') songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if(secondsTotal < 0) secondsTotal = 0;

			if(ClientPrefs.data.timeBarType != 'Song Name')
				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if(songSpeed < 1) time /= songSpeed;
			if(unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled)
					keysCheck();
				else
					playerDance();

				if(notes.length > 0)
				{
					if(startedCountdown)
					{
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						var i:Int = 0;
						while(i < notes.length)
						{
							var daNote:Note = notes.members[i];
							if(daNote == null) continue;

							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if(!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							if (strum == null) continue; // Fucking Null
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if(daNote.mustPress)
							{
								if(cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote
							#if FURTHER_ONLINE
							&& PlayStateSync.allowOpponentAutoHit()
							#end
						)
							opponentNoteHit(daNote);

							if(daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

							if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
							{
								var shouldMiss:Bool = daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit);

								if (shouldMiss && daNote.isSustainNote && daNote.parent != null && daNote.parent.wasGoodHit)
								{
									var parentNote:Note = daNote.parent;

									if (parentNote.tail != null && parentNote.tail.length > 0)
									{
										var endNote:Note = parentNote.tail[parentNote.tail.length - 1];

										if (endNote != null)
										{
											var totalSustainLength:Float = endNote.strumTime - parentNote.strumTime;

											if (totalSustainLength > 0)
											{
												var progressFromParent:Float = (daNote.strumTime - parentNote.strumTime) / totalSustainLength;

												if (progressFromParent >= 0.95)
													shouldMiss = false;
											}
										}
									}
								}

								if (shouldMiss)
									noteMiss(daNote);

								daNote.active = daNote.visible = false;
								invalidateNote(daNote);
							}
							if(daNote.exists) i++;
						}
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		setOnScripts('botPlay', cpuControlled);
		callOnScripts('onUpdatePost', [elapsed]);

		if (PinnedNotes.active)
			PinnedNotes.enforce(this, (60 / SONG.bpm) * 1000, songSpeed / playbackRate);

		if (PinnedNotes.hudActive())
			PinnedNotes.enforceHud(this);
	}

	public dynamic function updateIconsScale(elapsed:Float)
	{
		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	public dynamic function updateIconsPosition()
	{
		var iconOffset:Int = 26;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
	}

	var iconsAnimations:Bool = true;
	function set_health(value:Float):Float // You can alter how icon animations work here
	{
		value = FlxMath.roundDecimal(value, 5); //Fix Float imprecision
		if(!iconsAnimations || healthBar == null || !healthBar.enabled || healthBar.valueFunction == null)
		{
			health = value;
			return health;
		}

		health = value;
		var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max), healthBar.bounds.min, healthBar.bounds.max, 0, 100);
		var targetPercent:Float = (newPercent != null ? newPercent : 0);
		if (ClientPrefs.data.vsliceSmoothBar)
			targetPercent = FlxMath.lerp(healthBar.percent, targetPercent, 0.15);
		healthBar.percent = targetPercent;

		iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : 0; //If health is under 20%, change player icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		iconP2.animation.curAnim.curFrame = (healthBar.percent > 80) ? 1 : 0; //If health is over 80%, change opponent icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		return health;
	}
	
	function buildCurrentSaveScoreData():SaveScoreData
	{
		var percent:Float = ratingPercent;
		if (Math.isNaN(percent)) percent = 0;

		return {
			score: songScore,
			accPoints: percent * totalPlayed,

			sick: ratingsData[0].hits,
			good: ratingsData[1].hits,
			bad: ratingsData[2].hits,
			shit: ratingsData[3].hits,
			missed: songMisses,

			combo: combo,
			maxCombo: combo,
			totalNotesHit: totalPlayed,
			totalNotes: totalPlayed
		};
	}
	
	function getResultsTitle():String
	{
		if (isStoryMode)
		{
			var weekData:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[storyWeek]);
			if (weekData != null && weekData.storyName != null && weekData.storyName.length > 0)
				return weekData.storyName;

			return WeekData.getWeekFileName();
		}

		var modManifest = Mods.getPack();
		if (modManifest != null)
		{
			return Language.getPhrase('results_song_from_mod', '{1} from {2}')
				.replace('{1}', curSong)
				.replace('{2}', modManifest.name);
		}

		return curSong;
	}
	
	function zoomIntoResultsScreen(isNewHighscore:Bool, scoreData:SaveScoreData, prevScoreRank:ScoringRank):Void
	{
		var targetDad:Bool = dad != null && dad.curCharacter == 'gf';
		var targetBF:Bool = gf == null && !targetDad;

		if (targetBF)
			FlxG.camera.follow(boyfriend, null, 0.05);
		else if (targetDad)
			FlxG.camera.follow(dad, null, 0.05);
		else if (gf != null)
			FlxG.camera.follow(gf, null, 0.05);

		FlxG.camera.targetOffset.y -= 350;
		FlxG.camera.targetOffset.x += 20;

		FlxG.camera.fade(FlxColor.BLACK, 0.6);

		FlxTween.tween(camHUD, {alpha: 0}, 0.6, {
			onComplete: function(_)
			{
				moveToResultsScreen(isNewHighscore, scoreData, prevScoreRank);
			}
		});

		new FlxTimer().start(0.8, function(_)
		{
			if (targetBF)
				boyfriend.animation.play('hey');
			else if (targetDad)
				dad.animation.play('cheer');
			else if (gf != null)
				gf.animation.play('cheer');
		});
	}
	
	function moveToResultsScreen(isNewHighscore:Bool, scoreData:SaveScoreData, prevScoreRank:ScoringRank):Void
	{
		persistentUpdate = false;

		if (vocals != null)
			vocals.stop();

		if (opponentVocals != null)
			opponentVocals.stop();

		camHUD.alpha = 1;

		var res:ResultState = new ResultState({
			storyMode: isStoryMode,
			songId: curSong,
			difficultyId: Difficulty.getString(storyDifficulty),
			title: getResultsTitle(),
			scoreData: scoreData,
			prevScoreRank: prevScoreRank,
			isNewHighscore: isNewHighscore,
			characterId: SONG.player1
		});

		persistentDraw = false;
		openSubState(res);
	}

	function openPauseMenu()
	{
		#if FURTHER_ONLINE
		if (GameClient.isConnected())
		{
			trace("[Online] pause disabled (would desync)");
			return;
		}
		#end
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		if(FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}
		if(!cpuControlled)
		{
			for (note in playerStrums)
				if(note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}
		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		if(autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	public function openChartEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		chartingMode = true;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		MusicBeatState.switchState(new ChartingState());
	}

	function openCharacterEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	public var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		#if FURTHER_ONLINE
		if (PlayStateSync.suppressDeath()) return false;
		#end
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead && gameOverTimer == null)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if(ret != LuaUtils.Function_Stop)
			{
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;
				#if VIDEOS_ALLOWED
				if(videoCutscene != null)
				{
					videoCutscene.destroy();
					videoCutscene = null;
				}
				#end

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				FlxG.camera.setFilters([]);

				if(GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				return;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float) {
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if(Math.isNaN(flValue1)) flValue1 = null;
		if(Math.isNaN(flValue2)) flValue2 = null;

		switch(eventName) {
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				if(flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if(flValue1 == null || flValue1 < 1) flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if(ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35) {
					if(flValue1 == null) flValue1 = 0.015;
					if(flValue2 == null) flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						if(flValue2 == null) flValue2 = 0;
						switch(Math.round(flValue2)) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					isCameraOnForcedPos = false;
					if(flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if(flValue1 == null) flValue1 = 0;
						if(flValue2 == null) flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf') {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if(flValue1 == null) flValue1 = 1;
					if(flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if(flValue2 <= 0)
						songSpeed = newValue;
					else
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {ease: FlxEase.linear, onComplete:
							function (twn:FlxTween)
							{
								songSpeedTween = null;
							}
						});
				}

			case 'Set Property':
				try
				{
					var trueValue:Dynamic = value2.trim();
					if (trueValue == 'true' || trueValue == 'false') trueValue = trueValue == 'true';
					else if (flValue2 != null) trueValue = flValue2;
					else trueValue = value2;

					var split:Array<String> = value1.split('.');
					if(split.length > 1) {
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1], trueValue);
					} else {
						LuaUtils.setVarInArray(this, value1, trueValue);
					}
				}
				catch(e:Dynamic)
				{
					var len:Int = e.message.indexOf('\n') + 1;
					if(len <= 0) len = e.message.length;
					#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
					#else
					FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
					#end
				}

			case 'Play Sound':
				if(flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
	}

	public function moveCameraSection(?sec:Null<Int>):Void {
		if(sec == null) sec = curSection;
		if(sec < 0) sec = 0;

		if(SONG.notes[sec] == null) return;

		if (gf != null && SONG.notes[sec].gfSection)
		{
			moveCameraToGirlfriend();
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		moveCamera(isDad);
		if (isDad)
			callOnScripts('onMoveCamera', ['dad']);
		else
			callOnScripts('onMoveCamera', ['boyfriend']);
	}
	
	public function moveCameraToGirlfriend()
	{
		if(!ClientPrefs.data.camMovement) return;

		camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
		camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
		camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
		tweenCamIn();
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if(!ClientPrefs.data.camMovement) return;

		if(isDad)
		{
			if(dad == null) return;
			camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			if(boyfriend == null) return;
			camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
					function (twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	public function tweenCamIn() {
		if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3) {
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();
		opponentVocals.volume = 0;
		opponentVocals.pause();

		if(ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset) {
			if (endCallback != null)
				endCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
				endCallback();
			});
		}
	}

	public var transitioning = false;
	public function endSong()
	{
		trace('=== FREEPLAY RETURN DEBUG ===');
		trace('vsliceResults = ' + ClientPrefs.data.vsliceResults);
		trace('isNewStyle = ' + MenuStyleRouter.isNewStyle());
		trace('menuStyle = ' + ClientPrefs.data.menuStyle);
		#if !android
		if (touchPad != null)
			touchPad.visible = false;
		#end

		if (mobileControls != null && mobileControls.instance != null)
			mobileControls.instance.visible = false;

		if(!startingSong)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			});
			for (daNote in unspawnNotes)
			{
				if(daNote != null && daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			}

			if(doDeathCheck()) {
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		#if FURTHER_ONLINE
		PlayStateSync.onLocalSongEnd(this);
		#end
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie' #if BASE_GAME_FILES, 'debugger' #end]);
		#end
		
		trace("menuStyle = " + ClientPrefs.data.menuStyle);
		trace("isNewStyle = " + MenuStyleRouter.isNewStyle());

		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if(ret != LuaUtils.Function_Stop && !transitioning)
		{
			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			var botplay:Bool = cpuControlled || ClientPrefs.getGameplaySetting('botplay');
			canSaveScore = !practiceMode && !botplay;

			var currentTallies:SaveScoreData = buildCurrentSaveScoreData();

			submitLeaderboardOnce();
			
			#if FURTHER_ONLINE
			if (GameClient.isConnected())
			{
				trace('[Online] hold transitions until matchEnded');
				return false;
			}
			#end
			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;
				campaignSaveData = combineSaveScoreData(campaignSaveData, currentTallies);

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					#if DISCORD_ALLOWED
					DiscordClient.resetClientID();
					#end

					canResync = false;

					var prevWeekScore:Int = Highscore.getWeekScore(WeekData.getWeekFileName(), storyDifficulty);
					var prevWeekRank:ScoringRank = SHIT;

					if (canSaveScore)
					{
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}

					var isNewWeekHighscore:Bool = canSaveScore && (campaignScore > prevWeekScore);

					if (ClientPrefs.data.vsliceResults && !botplay)
					{
						zoomIntoResultsScreen(isNewWeekHighscore, campaignSaveData, prevWeekRank);
					}
					else
					{
						Mods.loadTopMod();
						MenuStyleRouter.goToStoryMode();
						TitleState.playFreakyMusic();
					}

					campaignSaveData = emptySaveScoreData();
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = Difficulty.getFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					prevCamFollow = camFollow;

					Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					canResync = false;
					LoadingState.prepareToSong();
					LoadingState.loadAndSwitchState(new PlayState(), false, false);
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				#if FURTHER_ONLINE
			if (GameClient.isConnected())
				{
					trace('[Online] endSong held for matchEnded (connected)');
					// Keep PlayState until matchEnded switches to OnlineResults
					// Soft-freeze: stop music already ended
					return false;
				}
				#end
				Mods.loadTopMod();

				#if DISCORD_ALLOWED
				DiscordClient.resetClientID();
				#end

				canResync = false;

				var prevScore:Int = Highscore.getScore(Song.loadedSongName, storyDifficulty);
				var prevRank:ScoringRank = SHIT;

				var prevAcc:Float = Highscore.getRating(Song.loadedSongName, storyDifficulty);
				var prevWasFC:Bool = false;
				prevRank = Scoring.calculateRankFromData(prevScore, prevAcc, prevWasFC) ?? SHIT;

				if (canSaveScore)
				{
					var percent:Float = ratingPercent;
					if (Math.isNaN(percent)) percent = 0;
					Highscore.saveScore(Song.loadedSongName, songScore, storyDifficulty, percent);
				}

				var isNewSongHighscore:Bool = canSaveScore && (songScore > prevScore);
				var currentRank:ScoringRank = Scoring.calculateRank(currentTallies) ?? SHIT;
				var hasNewRank:Bool = currentRank > prevRank;

				if (ClientPrefs.data.vsliceResults && !botplay)
				{
					zoomIntoResultsScreen(isNewSongHighscore, currentTallies, prevRank);
				}
				else
				{
					var resultParams = hasNewRank ? {
						fromResults:
						{
							oldRank: prevRank,
							newRank: currentRank,
							songId: Song.loadedSongName,
							difficultyId: Difficulty.getString(storyDifficulty, false),
							playRankAnim: true
						}
					} : null;

					if (MenuStyleRouter.isNewStyle())
					{
						var nextState = cast new vslice.menus.freeplay.FreeplayHostState(resultParams);
						trace("Switching to VSlice FreeplayHostState directly");
						FlxG.switchState(nextState);
					}
					else
					{
						trace("Switching to classic states.FreeplayState");
						FlxG.switchState(new states.FreeplayState(resultParams));
					}

					TitleState.playFreakyMusic();
				}

				changedDifficulty = false;
			}
			transitioning = true;
		}
		return true;
	}

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	// Stores Ratings and Combo Sprites in a group
	public var comboGroup:FlxSpriteGroup;
	// Stores HUD Objects in a Group
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	public var noteGroup:FlxTypedGroup<FlxBasic>;

	private function cachePopUpScore()
	{
		var uiFolder:String = "";
		if (stageUI != "normal")
			uiFolder = uiPrefix + "UI/";

		for (rating in ratingsData)
			Paths.image(uiFolder + rating.image + uiPostfix);
		for (i in 0...10)
			Paths.image(uiFolder + 'num' + i + uiPostfix);
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		vocals.volume = 1;

		if (!ClientPrefs.data.comboStacking && comboGroup.members.length > 0)
		{
			for (spr in comboGroup)
			{
				if(spr == null) continue;

				comboGroup.remove(spr);
				spr.destroy();
			}
		}

		var placement:Float = FlxG.width * 0.35;
		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if(daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if(!cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		var uiFolder:String = "";
		var antialias:Bool = ClientPrefs.data.antialiasing;
		if (stageUI != "normal")
		{
			uiFolder = uiPrefix + "UI/";
			antialias = !isPixelStage;
		}

		if (ClientPrefs.data.popUpRating)
		{
			rating.loadGraphic(Paths.image(uiFolder + daRating.image + uiPostfix));
			rating.screenCenter();
			rating.x = placement - 40;
			rating.y -= 60;
			rating.acceleration.y = 550 * playbackRate * playbackRate;
			rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
			rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
			rating.visible = (!ClientPrefs.data.hideHud && showRating);
			rating.x += ClientPrefs.data.comboOffset[0];
			rating.y -= ClientPrefs.data.comboOffset[1];
			rating.antialiasing = antialias;

			var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'combo' + uiPostfix));
			comboSpr.screenCenter();
			comboSpr.x = placement;
			comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
			comboSpr.x += ClientPrefs.data.comboOffset[0];
			comboSpr.y -= ClientPrefs.data.comboOffset[1];
			comboSpr.antialiasing = antialias;
			comboSpr.y += 60;
			comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
			comboGroup.add(rating);

			if (!PlayState.isPixelStage)
			{
				rating.setGraphicSize(Std.int(rating.width * 0.7));
				comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			}
			else
			{
				rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
				comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
			}

			comboSpr.updateHitbox();
			rating.updateHitbox();

			var daLoop:Int = 0;
			var xThing:Float = 0;
			if (showCombo)
				comboGroup.add(comboSpr);

			var separatedScore:String = Std.string(combo).lpad('0', 3);
			for (i in 0...separatedScore.length)
			{
				var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'num' + Std.parseInt(separatedScore.charAt(i)) + uiPostfix));
				numScore.screenCenter();
				numScore.x = placement + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
				numScore.y += 80 - ClientPrefs.data.comboOffset[3];

				if (!PlayState.isPixelStage)
					numScore.setGraphicSize(Std.int(numScore.width * 0.5));
				else
					numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
				numScore.updateHitbox();

				numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
				numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
				numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
				numScore.visible = !ClientPrefs.data.hideHud;
				numScore.antialiasing = antialias;

				// if (combo >= 10 || combo == 0)
				if (showComboNum)
					comboGroup.add(numScore);

				FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
					onComplete: function(tween:FlxTween)
					{
						backend.SafeDestroy.afterUpdate(numScore);
					},
					startDelay: Conductor.crochet * 0.002 / playbackRate
				});

				daLoop++;
				if (numScore.x > xThing)
					xThing = numScore.x;
			}
			comboSpr.x = xThing + 50;
			FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
				startDelay: Conductor.crochet * 0.001 / playbackRate
			});

			FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: function(tween:FlxTween)
				{
					backend.SafeDestroy.afterUpdate(comboSpr);
					backend.SafeDestroy.afterUpdate(rating);
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});
		}
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{

		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			//Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return;
			#end

			if(FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		if(cpuControlled || paused || inCutscene || key < 0 || key >= playerStrums.length || !generatedMusic || endingSong || boyfriend.stunned) return;

		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if(Conductor.songPosition >= 0 && FlxG.sound.music != null) Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool {
			var canHit:Bool = n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			return canHit && !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		if (plrInputNotes.length != 0) { // slightly faster than doing `> 0` lol
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1) {
				var doubleNote:Note = plrInputNotes[1];

				if (doubleNote.noteData == funnyNote.noteData) {
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
						invalidateNote(doubleNote);
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
			}
			goodNoteHit(funnyNote);
		}
		else
		{
			if (ClientPrefs.data.ghostTapping)
				callOnScripts('onGhostTap', [key]);
			else
				noteMissPress(key);
		}

		// Needed for the  "Just the Two of Us" achievement.
		if(!keysPressed.contains(key)) keysPressed.push(key);

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		var spr:StrumNote = playerStrums.members[key];
		if(strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
			#if FURTHER_ONLINE
			PlayStateSync.sendStrumPressed(key);
			#end
		}
		callOnScripts('onKeyPress', [key]);
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}
	
	inline function isLastFivePercentOfSustain(note:Note):Bool
	{
		if (note == null || !note.isSustainNote || note.parent == null || note.parent.tail == null || note.parent.tail.length < 1)
			return false;

		var endNote:Note = note.parent.tail[note.parent.tail.length - 1];
		if (endNote == null)
			return false;

		var startTime:Float = note.parent.strumTime;
		var endTime:Float = endNote.strumTime;
		var totalLen:Float = endTime - startTime;

		if (totalLen <= 0)
			return false;

		var progress:Float = (Conductor.songPosition - startTime) / totalLen;
		return progress >= 0.95;
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if(cpuControlled || !startedCountdown || paused || key < 0 || key >= playerStrums.length) return;

		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		var spr:StrumNote = playerStrums.members[key];
		if(spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
			#if FURTHER_ONLINE
			PlayStateSync.sendStrumStatic(key);
			#end
		}
		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if(key == noteKey)
						return i;
			}
		}
		return -1;
	}

	private function onButtonPress(button:TouchButton):Void
	{
		if (button.inputIDs.filter(id -> id.toString().startsWith("EXTRA")).length > 0)
			return;

		var buttonCode:Int = (button.inputIDs[0].toString().startsWith('NOTE')) ? button.inputIDs[0] : button.inputIDs[1];
		if (buttonCode >= 44 && buttonCode <= 48) buttonCode -= 40; // NOTE_5(44)..NOTE_9(48) → mania şeridi 4-8
		callOnScripts('onButtonPressPre', [buttonCode]);
		if (button.justPressed) keyPressed(buttonCode);
		callOnScripts('onButtonPress', [buttonCode]);
	}

	private function onButtonRelease(button:TouchButton):Void
	{
		if (button.inputIDs.filter(id -> id.toString().startsWith("EXTRA")).length > 0)
			return;

		var buttonCode:Int = (button.inputIDs[0].toString().startsWith('NOTE')) ? button.inputIDs[0] : button.inputIDs[1];
		if (buttonCode >= 44 && buttonCode <= 48) buttonCode -= 40; // NOTE_5(44)..NOTE_9(48) → mania şeridi 4-8
		callOnScripts('onButtonReleasePre', [buttonCode]);
		if(buttonCode > -1) keyReleased(buttonCode);
		callOnScripts('onButtonRelease', [buttonCode]);
	}

	private function keysCheck():Void
	{
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		if (startedCountdown && !inCutscene && boyfriend != null && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0) {
				for (n in notes) {
					var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit
						&& n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;

					if (canHit && n.isSustainNote)
					{
						if (holdArray[n.noteData])
						{
							goodNoteHit(n);
						}
						else
						{
							var spr:StrumNote = playerStrums.members[n.noteData];
							if (spr != null && spr.animation.curAnim != null && spr.animation.curAnim.name != 'static')
							{
								spr.playAnim('static');
								spr.resetAnim = 0;
							}
						}
					}
				}
			}

			if (!holdArray.contains(true) || endingSong)
				playerDance();

			#if ACHIEVEMENTS_ALLOWED
			else checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note);
		});

		noteMissCommon(daNote.noteData, daNote);
		stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
		#if HSC_ALLOWED
		if (cneScripts != null && daNote != null)
		{
			var cneEv = EventManager.get(NoteHitEvent);
			cneEv.recycleBase();
			cneEv.note = daNote;
			cneEv.characters = [boyfriend];
			cneEv.player = true;
			cneEv.noteType = daNote.noteType;
			cneEv.direction = daNote.noteData;
			cneEv.score = songScore;
			cneEv.rating = 'miss';
			cneEv.healthGain = -0.0475;
			cneEv.misses = true;
			cneScripts.call('onNoteMiss', [cneEv]);
			cneScripts.call('onPlayerMiss', [cneEv]);
		}
		#end
		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void
	{
		if(ClientPrefs.data.ghostTapping) return;

		noteMissCommon(direction);
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		#if HSC_ALLOWED
		if (cneScripts != null)
		{
			var cneEv = EventManager.get(NoteHitEvent);
			cneEv.recycleBase();
			cneEv.note = null;
			cneEv.characters = [boyfriend];
			cneEv.player = true;
			cneEv.noteType = '';
			cneEv.direction = direction;
			cneEv.score = songScore;
			cneEv.rating = 'miss';
			cneEv.healthGain = -0.0475;
			cneEv.misses = true;
			cneScripts.call('onNoteMissPress', [cneEv]);
		}
		#end
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, note:Note = null)
	{
		var subtract:Float = pressMissDamage;
		if(note != null) subtract = note.missHealth;

		if (note != null && note.isSustainNote && note.parent != null && note.parent.wasGoodHit)
		{
			subtract *= 0.25;
		}

		if (note != null && guitarHeroSustains && note.parent == null) {
			if(note.tail.length > 0) {
				note.alpha = 0.35;
				for(childNote in note.tail) {
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				//subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -[REDACTED]
			}

			if (note.missed)
				return;
		}
		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote) {
			if (note.missed)
				return;

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0) {
				for (child in parentNote.tail) if (child != note) {
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		if(instakillOnMiss)
		{
			vocals.volume = 0;
			opponentVocals.volume = 0;
			doDeathCheck(true);
		}

		var lastCombo:Int = combo;

		// Sustain note kombo kırmıyor yeeey
		var breakCombo:Bool = true;
		if (note != null && note.isSustainNote && note.parent != null && note.parent.wasGoodHit)
			breakCombo = false;

		if (breakCombo)
			combo = 0;

			#if FURTHER_ONLINE
		if (!PlayStateSync.suppressLocalHealth())
		#end
			health -= subtract * healthLoss;
		#if FURTHER_ONLINE
		PlayStateSync.sendNoteMiss(note, direction);
		#end
		songScore -= 10;
		if(!endingSong) songMisses++;
		totalPlayed++;
		RecalculateRating(true);

		var char:Character = getOnlineSelfChar();
		if((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection)) char = gf;

		if(char != null && (note == null || !note.noMissAnimation) && char.hasMissAnimations)
		{
			var postfix:String = '';
			if(note != null) postfix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, direction)))] + 'miss' + postfix;
			char.playAnim(animToPlay, true);

			if(char != gf && lastCombo > 5 && gf != null && gf.hasAnimation('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		vocals.volume = 0;
	}


	/** Online: character you control (BF if host/BF side, Dad if guest/OPP side) */
	public inline function getOnlineSelfChar():Character
	{
		#if FURTHER_ONLINE
		if (GameClient.isConnected() && !GameClient.playsAsBF())
			return dad;
		#end
		return boyfriend;
	}

	/** Online: the other player's character */
	public inline function getOnlineOtherChar():Character
	{
		#if FURTHER_ONLINE
		if (GameClient.isConnected() && !GameClient.playsAsBF())
			return boyfriend;
		#end
		return dad;
	}

	public function opponentNoteHit(note:Note):Void
	{
		var result:Dynamic = callOnLuas('opponentNoteHitPre', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('opponentNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		if (songName != 'tutorial')
			camZooming = true;

		var otherChar:Character = getOnlineOtherChar();
		if(note.noteType == 'Hey!' && otherChar != null && otherChar.hasAnimation('hey'))
		{
			otherChar.playAnim('hey', true);
			otherChar.specialAnim = true;
			otherChar.heyTimer = 0.6;
		}
		else if(!note.noAnimation)
		{
			var char:Character = otherChar;
			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;
			if(note.gfNote) char = gf;

			if(char != null)
			{
				var canPlay:Bool = true;
				if(note.isSustainNote)
				{
					var holdAnim:String = animToPlay + '-hold';
					if(char.animation.exists(holdAnim)) animToPlay = holdAnim;
					if(char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
				}

				if(canPlay) char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		if(opponentVocals.length <= 0) vocals.volume = 1;
		// Glow strums on the lane this note belongs to (after online side flip)
		#if FURTHER_ONLINE
		var glowDadLane = true;
		if (GameClient.isConnected())
			glowDadLane = GameClient.playsAsBF(); // host: remote on dad lane; guest: remote on bf lane → player strums
		strumPlayAnim(glowDadLane, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		#else
		strumPlayAnim(true, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		#end
		note.hitByOpponent = true;
		
		stagesFunc(function(stage:BaseStage) stage.opponentNoteHit(note));
		#if HSC_ALLOWED
		if (cneScripts != null)
		{
			var cneEv = EventManager.get(NoteHitEvent);
			cneEv.recycleBase();
			cneEv.note = note;
			cneEv.characters = [dad];
			cneEv.player = false;
			cneEv.noteType = note.noteType;
			cneEv.direction = Math.abs(note.noteData);
			cneEv.score = songScore;
			cneEv.rating = 'sick';
			cneEv.healthGain = 0.023;
			cneScripts.call('onNoteHit', [cneEv]);
		}
		#end
		var result:Dynamic = callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('opponentNoteHit', [note]);

		spawnHoldSplashOnNote(note);

		if (!note.isSustainNote) invalidateNote(note);
	}

	public function goodNoteHit(note:Note):Void
	{
		if(note.wasGoodHit) return;
		if(cpuControlled && note.ignoreNote) return;

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		var result:Dynamic = callOnLuas('goodNoteHitPre', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('goodNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		note.wasGoodHit = true;

		if (note.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);

		if(!note.hitCausesMiss) //Common notes
		{
			if(!note.noAnimation)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;

				var char:Character = getOnlineSelfChar();
				var animCheck:String = 'hey';
				if(note.gfNote)
				{
					char = gf;
					animCheck = 'cheer';
				}

				if(char != null)
				{
					var canPlay:Bool = true;
					if(note.isSustainNote)
					{
						var holdAnim:String = animToPlay + '-hold';
						if(char.animation.exists(holdAnim)) animToPlay = holdAnim;
						if(char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
					}
	
					if(canPlay) char.playAnim(animToPlay, true);
					char.holdTimer = 0;

					if(note.noteType == 'Hey!')
					{
						if(char.hasAnimation(animCheck))
						{
							char.playAnim(animCheck, true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
					}
				}
			}

			if(!cpuControlled)
			{
				var spr = playerStrums.members[note.noteData];
				if(spr != null) spr.playAnim('confirm', true);
			}
			else strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			vocals.volume = 1;

			if (!note.isSustainNote)
			{
				combo++;
				if(combo > 9999) combo = 9999;
				popUpScore(note);
			}
			var gainHealth:Bool = true; // prevent health gain, *if* sustains are treated as a singular note
			if (guitarHeroSustains && note.isSustainNote) gainHealth = false;
			if (gainHealth)
			{
				#if FURTHER_ONLINE
				if (!PlayStateSync.suppressLocalHealth())
				#end
					health += note.hitHealth * healthGain;
			}
			#if FURTHER_ONLINE
			PlayStateSync.sendNoteHit(note, note.rating);
			#end

		}
		else //Notes that count as a miss if you hit them (Hurt notes for example)
		{
			if(!note.noMissAnimation)
			{
				switch(note.noteType)
				{
					case 'Hurt Note':
						if(boyfriend.hasAnimation('hurt'))
						{
							var hurtChar = getOnlineSelfChar();
							if (hurtChar != null) {
								hurtChar.playAnim('hurt', true);
								hurtChar.specialAnim = true;
							}
						}
				}
			}

			noteMiss(note);
			if(!note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(note);
		}

		stagesFunc(function(stage:BaseStage) stage.goodNoteHit(note));
		#if HSC_ALLOWED
		if (cneScripts != null)
		{
			var cneEv = EventManager.get(NoteHitEvent);
			cneEv.recycleBase();
			cneEv.note = note;
			cneEv.characters = [boyfriend];
			cneEv.player = true;
			cneEv.noteType = note.noteType;
			cneEv.direction = note.noteData;
			cneEv.score = songScore;
			cneEv.rating = note.rating;
			cneEv.accuracy = note.isSustainNote ? null : ratingPercent;
			cneEv.healthGain = 0.023;
			cneEv.countAsCombo = !note.isSustainNote;
			cneEv.countScore = !note.isSustainNote;
			cneEv.deleteNote = !note.isSustainNote;
			cneEv.animCancelled = false;
			cneScripts.call('onNoteHit', [cneEv]);
		}
		#end
		var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('goodNoteHit', [note]);
		spawnHoldSplashOnNote(note);
		if(!note.isSustainNote) invalidateNote(note);
	}

	public function invalidateNote(note:Note):Void {
		if (note == null) return;
		note.kill();
		notes.remove(note, true);
		backend.SafeDestroy.afterUpdate(note);
	}

	public function spawnHoldSplashOnNote(note:Note)
	{
		if (ClientPrefs.data.holdSplashAlpha <= 0)
			return;

		if (note != null)
		{
			var strum:StrumNote = (note.mustPress ? playerStrums : opponentStrums).members[note.noteData];
			if (strum != null && note.tail.length > 1)
				spawnHoldSplash(note);
		}
	}

	public function spawnHoldSplash(note:Note)
	{
		var end:Note = note.isSustainNote ? note.parent.tail[note.parent.tail.length - 1] : note.tail[note.tail.length - 1];
		var strum:StrumNote = (note.mustPress ? playerStrums : opponentStrums).members[note.noteData];
		var splash:SustainSplash = null;
		#if mobile
		for (candidate in grpHoldSplashes.members)
		{
			if (candidate != null && candidate.alive && candidate.strumNote == strum)
			{
				splash = candidate;
				break;
			}
		}
		#end
		if (splash == null) splash = grpHoldSplashes.recycle(SustainSplash);
		splash.setupSusSplash(strum, note, playbackRate);
		grpHoldSplashes.add(end.noteHoldSplash = splash);
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null)
				spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
		}
	}

	public function spawnNoteSplash(x:Float = 0, y:Float = 0, ?data:Int = 0, ?note:Note, ?strum:StrumNote) {
		var splash:NoteSplash = null;
		#if mobile
		for (candidate in grpNoteSplashes.members)
		{
			if (candidate != null && candidate.alive && candidate.noteData % Note.colArray.length == data % Note.colArray.length)
			{
				splash = candidate;
				break;
			}
		}
		#end
		if (splash == null) splash = grpNoteSplashes.recycle(NoteSplash);
		splash.revive();
		splash.babyArrow = strum;
		splash.spawnSplashNote(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	override function destroy() {
		#if FURTHER_ONLINE
		PlayStateSync.unbind();
		#end
		PinnedNotes.restorePrefs();
		PinnedNotes.clear();

		if (psychlua.CustomSubstate.instance != null)
		{
			closeSubState();
			resetSubState();
		}

		#if LUA_ALLOWED
		for (lua in luaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if(script != null)
			{
				if(script.exists('onDestroy')) script.call('onDestroy');
				script.destroy();
			}

		hscriptArray = null;
		#end
		stagesFunc(function(stage:BaseStage) stage.destroy());

		#if VIDEOS_ALLOWED
		if(videoCutscene != null)
		{
			videoCutscene.destroy();
			videoCutscene = null;
		}
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.camera.setFilters([]);

		#if FLX_PITCH FlxG.sound.music.pitch = 1; #end
		FlxG.animationTimeScale = 1;

		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		NoteSplash.configs.clear();
		instance = null;
		shutdownThread = true;
		FlxG.signals.preUpdate.remove(checkForResync);
		super.destroy();
	}

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();

		if(curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		if(lastBeatHit >= curBeat) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}
		
		if (ClientPrefs.data.petwatermark && petLogo != null && curBeat % 2 == 0) {
			petLogo.scale.set(0.45, 0.45);
			FlxTween.tween(petLogo.scale, {x: 0.4, y: 0.4}, 0.5, {ease: FlxEase.circOut});
		}

		if (generatedMusic)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		characterBopper(curBeat);

		super.beatHit();
		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}
	
	function createPETWatermark():Void {
		var logoPath:String = 'pet/petlogos/';
		switch (ClientPrefs.data.petwatermarklogo.toUpperCase()) {
			case 'V1':
				logoPath += 'V1';
			case 'V2':
				logoPath += 'V2';
			case 'V2U':
				logoPath += 'V2U';
			case 'ONLINE':
				logoPath += 'online';
			case 'FURTHER': // Fuh yeah baby
				logoPath += 'further';
			default: // ONLINE
				logoPath += 'varsayilan';
		}
		// P.E.T Logo
		petLogo = new FlxSprite(-200, 20);
		try {
			petLogo.loadGraphic(Paths.image(logoPath));
			petLogo.setGraphicSize(Std.int(petLogo.width * 0.4));
			petLogo.updateHitbox();
			petLogo.antialiasing = ClientPrefs.data.antialiasing;
			petLogo.cameras = [camHUD];
			add(petLogo);
		} catch (e:Dynamic) {
			trace("PET LOGO HATASI: " + e);
			return;
		}
		try {	// Yedek
			petText = new FlxText(-200, 35, 0, "Psych Engine Türkiye");
			petText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			petText.borderSize = 2;
			petText.cameras = [camHUD];
			add(petText);
		} catch (e:Dynamic) {
			return;
		}
		if (petLogo != null && petText != null) {
			FlxTween.tween(petLogo, {x: 10}, 1.5, {ease: FlxEase.elasticOut});
			FlxTween.tween(petText, {x: 10 + 75}, 1.5, {ease: FlxEase.elasticOut});
		}
	}

	public function characterBopper(beat:Int):Void
	{
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
			gf.dance();
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();
	}

	inline function currentMusicPitch():Float
	{
		#if FLX_PITCH
		if (FlxG.sound.music != null && FlxG.sound.music.pitch > 0)
			return FlxG.sound.music.pitch;
		#end
		return playbackRate > 0 ? playbackRate : 1;
	}

	public function playerDance():Void
	{
		if (boyfriend == null) return;
		var anim:String = boyfriend.getAnimationName();
		if (anim == null) return;
		if(boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / currentMusicPitch()) * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
			boyfriend.dance();
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		super.sectionHit();

		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	#if LUA_ALLOWED
	function pushFunkinLua(luaPath:String):Void
	{
		try
		{
			new FunkinLua(luaPath);
		}
		catch (e:Dynamic)
		{
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			if (luaDebugGroup != null)
				addTextToDebug('Lua yüklenemedi ($luaPath): ' + e, FlxColor.RED);
			#end
			trace('[PlayState] Lua yüklenemedi: ' + luaPath + ' -> ' + e);
		}
	}

	public function startLuasNamed(luaFile:String)
	{
		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getSharedPath(luaFile);

		if(FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getSharedPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if(script.scriptName == luaToLoad) return false;

			pushFunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
		#if MODS_ALLOWED
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if(!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getSharedPath(scriptFile);
		#else
		var scriptToLoad:String = Paths.getSharedPath(scriptFile);
		#end

		if(FileSystem.exists(scriptToLoad))
		{
			if (Iris.instances.exists(scriptToLoad)) return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	public function initHScript(file:String)
	{
		var newScript:HScript = null;
		try
		{
			newScript = new HScript(null, file);
			if (newScript.exists('onCreate')) newScript.call('onCreate');
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
		}
		catch(e:IrisError)
		{
			var pos:HScriptInfos = cast {fileName: file, showLine: false};
			Iris.error(Printer.errorToString(e, false), pos);
			var newScript:HScript = cast (Iris.instances.get(file), HScript);
			if(newScript != null)
				newScript.destroy();
		}
	}
	#end

	#if HSC_ALLOWED
	function loadCneHScripts()
	{
		if (cneScripts == null)
		{
			cneScripts = new ScriptPack('cneSongScripts');
			cneScripts.setParent(this);
		}

		var mods:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			mods.push(Mods.currentModDirectory);
		for (g in Mods.getGlobalMods())
			if (!mods.contains(g)) mods.push(g);

		for (mod in mods)
		{
			var songDir:String = cne.compatibility.CNECompat.songDir(mod, Song.loadedSongName);
			if (songDir == null) continue;
			ScriptLoader.addAllFromFolder(songDir + '/scripts', cneScripts);
		}
		ScriptLoader.addAllFromFolder('codenameScripts', cneScripts);

		cneScripts.load();
	}

	function buildCneStrumLines():StrumLineCompat
	{
		var sl = new StrumLineCompat();
		sl.members.push(new StrumLineCompatMember(0, 'dad', [dad]));
		sl.members.push(new StrumLineCompatMember(1, 'boyfriend', [boyfriend]));
		sl.members.push(new StrumLineCompatMember(2, 'girlfriend', [gf]));
		return sl;
	}

	static final CNE_SCRIPT_ALIASES:Map<String, String> = [
		'onBeatHit' => 'beatHit',
		'onStepHit' => 'stepHit',
		'onUpdate' => 'update',
		'onUpdatePost' => 'updatePost',
		'onCreatePost' => 'createPost',
	];

	function callCneScripts(funcToCall:String, args:Array<Dynamic>):Dynamic
	{
		if (cneScripts == null) return null;

		// Psych bazı çağrılara argüman vermiyor; CNE bekliyor
		var cneArgs:Array<Dynamic> = args;
		if ((cneArgs == null || cneArgs.length == 0) && funcToCall == 'onStepHit')
			cneArgs = [curStep];
		else if ((cneArgs == null || cneArgs.length == 0) && funcToCall == 'onBeatHit')
			cneArgs = [curBeat];

		var v:Dynamic = cneScripts.call(funcToCall, cneArgs);
		var alias:String = CNE_SCRIPT_ALIASES.get(funcToCall);
		if (alias != null && alias != funcToCall)
		{
			var v2:Dynamic = cneScripts.call(alias, cneArgs);
			if (v == null) v = v2;
		}
		return v;
	}
	#end

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if(result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		#if HSC_ALLOWED
		if (result == null || excludeValues.contains(result)) result = callCneScripts(funcToCall, args);
		#end
		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var arr:Array<FunkinLua> = [];
		for (script in luaArray)
		{
			if(script.closed)
			{
				arr.push(script);
				continue;
			}

			if(exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(funcToCall, args);
			if((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if(myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if(script.closed) arr.push(script);
		}

		if(arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = new Array();
		if(excludeValues == null) excludeValues = new Array();
		excludeValues.push(LuaUtils.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1)
			return returnVal;

		for(script in hscriptArray)
		{
			@:privateAccess
			if(script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var callValue = script.call(funcToCall, args);
			if(callValue != null)
			{
				var myValue:Dynamic = callValue.returnValue;

				if((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if(myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if(exclusions == null) exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
		#if HSC_ALLOWED
		if (cneScripts != null) cneScripts.set(variable, arg);
		#end
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in hscriptArray) {
			if(exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = opponentStrums.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating(badHit:Bool = false, scoreBop:Bool = true) {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if(ret != LuaUtils.Function_Stop)
		{
			ratingName = '?';
			if(totalPlayed != 0) //Prevent divide by 0
			{
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				if(ratingPercent < 1)
					for (i in 0...ratingStuff.length-1)
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		setOnScripts('totalPlayed', totalPlayed);
		setOnScripts('totalNotesHit', totalNotesHit);
		updateScore(badHit, scoreBop); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if(chartingMode) return;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice') || ClientPrefs.getGameplaySetting('botplay'));
		if(cpuControlled) return;

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !practiceMode);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

					#if BASE_GAME_FILES
					case 'debugger':
						unlock = (songName == 'test' && !usedPractice);
					#end
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == 'HARD'
					&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end
	public function createRuntimeShader(shaderName:String):ErrorHandledRuntimeShader
	{
		#if (!flash && sys)
		if(!ClientPrefs.data.shaders) return new ErrorHandledRuntimeShader(shaderName);

		if(!runtimeShaders.exists(shaderName) && !initLuaShader(shaderName))
		{
			FlxG.log.warn('Shader $shaderName kayıp!');
			return new ErrorHandledRuntimeShader(shaderName);
		}

		var arr:Array<String> = runtimeShaders.get(shaderName);
		return new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform Shader Desteklemiyor!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if(runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders/'))
		{
			var frag:String = folder + name + '.frag';
			var vert:String = folder + name + '.vert';
			var found:Bool = false;
			if(FileSystem.exists(frag))
			{
				frag = File.getContent(frag);
				found = true;
			}
			else frag = null;

			if(FileSystem.exists(vert))
			{
				vert = File.getContent(vert);
				found = true;
			}
			else vert = null;

			if(found)
			{
				runtimeShaders.set(name, [frag, vert]);
				//trace('Found shader $name!');
				return true;
			}
		}
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			addTextToDebug('Missing shader $name .frag AND .vert files!', FlxColor.RED);
			#else
			FlxG.log.warn('Missing shader $name .frag AND .vert files!');
			#end
		#else
		FlxG.log.warn('This platform doesn\'t support Runtime Shaders!');
		#end
		return false;
	}

	public function makeLuaTouchPad(DPadMode:String, ActionMode:String) {
		if(members.contains(luaTouchPad)) return;

		if(!variables.exists("luaTouchPad"))
			variables.set("luaTouchPad", luaTouchPad);

		luaTouchPad = new TouchPad(DPadMode, ActionMode, NONE);
		luaTouchPad.alpha = ClientPrefs.data.controlsAlpha;
	}
	
	public function addLuaTouchPad() {
		if(luaTouchPad == null || members.contains(luaTouchPad)) return;

		var target = LuaUtils.getTargetInstance();
		target.insert(target.members.length + 1, luaTouchPad);
	}

	public function addLuaTouchPadCamera() {
		if(luaTouchPad != null)
			luaTouchPad.cameras = [luaTpadCam];
	}

	public function removeLuaTouchPad() {
		if (luaTouchPad != null) {
			luaTouchPad.kill();
			luaTouchPad.destroy();
			remove(luaTouchPad);
			luaTouchPad = null;
		}
	}

	public function luaTouchPadPressed(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonPressed(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button; // haxe said "You Can't Iterate On A Dyanmic Value Please Specificy Iterator or Iterable *insert nerd emoji*" so that's the only i foud to fix
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyPressed(idArray);
			} else
				return false;
		}
		return false;
	}

	public function luaTouchPadJustPressed(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonJustPressed(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyJustPressed(idArray);
			} else
				return false;
		}
		return false;
	}
	
	public function luaTouchPadJustReleased(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonJustReleased(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyJustReleased(idArray);
			} else
				return false;
		}
		return false;
	}

	public function luaTouchPadReleased(button:Dynamic):Bool {
		if(luaTouchPad != null) {
			if(Std.isOfType(button, String))
				return luaTouchPad.buttonJustReleased(MobileInputID.fromString(button));
			else if(Std.isOfType(button, Array)){
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for(strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyReleased(idArray);
			} else
				return false;
		}
		return false;
	}

	public var customManagers:Map<String, Array<Dynamic>> = [];
	public var lastGettedManager:MobileControlManager;
	public var lastGettedManagerName:String;
	public static function checkManager(?managerName:String):MobileControlManager {
		if (managerName == null || managerName == '') {
			instance.lastGettedManagerName = 'default';
			instance.lastGettedManager = MusicBeatState.getState().mobileManager;
		}
		else if (instance.lastGettedManagerName != managerName) {
			instance.lastGettedManagerName = managerName;
			instance.lastGettedManager = instance.customManagers.get(managerName)[0];
		}
		return instance.lastGettedManager;
	}

	public function createNewManager(name:String, keyDetectionAllowed:Bool) {
		var mobileManagerNew = new MobileControlManager(this);
		var managerShit:Array<Dynamic> = [mobileManagerNew, keyDetectionAllowed];
		customManagers.set(name, managerShit);
		if(!variables.exists(name))
			variables.set(name, mobileManagerNew);
		if(!variables.exists(name + '_mobilePad'))
			variables.set(name + '_mobilePad', mobileManagerNew.mobilePad);
		if(!variables.exists(name + '_hitbox'))
			variables.set(name + '_hitbox', mobileManagerNew.hitbox);
		if(!variables.exists(name + '_joyStick'))
			variables.set(name + '_joyStick', mobileManagerNew.joyStick);
	}

	public static function checkMPadPress(buttonName:String, type = 'justPressed', ?managerName:String) {
		var manager = checkManager(managerName);

		var button:MobileButton = null;
		if (manager.mobilePad != null) button = manager.mobilePad.getButton(buttonName);
		if (button != null) return Reflect.getProperty(button, type);
		return false;
	}

	public static function checkHBoxPress(button:String, type = 'justPressed', ?managerName:String) {
		var manager = checkManager(managerName);

		var buttonObject:MobileButton = null;
		if (manager.hitbox != null) buttonObject = manager.hitbox.getButton(button);
		if (buttonObject != null) return Reflect.getProperty(buttonObject, type);
		return false;
	}
	
	public static var hitboxPositions:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0, 0];
	public var defaultPlayerNotePositions:Array<Dynamic> = [-360, -140, 140, 360];

	public function getVSliceSpacing():Float
	{
		if (ClientPrefs.data.vSliceCustomX) return 0;
		var spacing:Float = ClientPrefs.data.vSliceSpacing;
		if (spacing < 0) spacing = 0;
		if (spacing > 1) spacing = 1;
		return spacing;
	}

	public function enableVSliceControls() {
		var spacing:Float = getVSliceSpacing();

		if (totalColumns <= 4)
		{
			var orig:Array<Float> = [-360, -140, 140, 360];
			for (i in 0...4) {
				var strum = playerStrums.members[i];
				if (strum == null) continue;
				if (ClientPrefs.data.vSliceCustomX && ClientPrefs.data.vSliceButtonX != null && ClientPrefs.data.vSliceButtonX.length >= 4)
				{
					var center = ClientPrefs.data.vSliceButtonX[i] * FlxG.width;
					strum.x = center - strum.width * 0.5;
				}
				else
				{
					strum.screenCenter(X);
					var maxOff:Float = (FlxG.width * 0.5) - (strum.width * 0.5) - 8;
					if (maxOff < 1) maxOff = 1;
					var baseScale:Float = Math.min(1, maxOff / 360);
					var scale:Float = baseScale + (maxOff / 360 - baseScale) * spacing;
					strum.x += orig[i] * scale;
				}
			}
			for (i in 0...4) {
				var strum = opponentStrums.members[i];
				if (strum == null) continue;
				strum.y = 40;
				strum.x = 10 + (i * 65);
				strum.scale.x = strum.scale.x / 1.75;
				strum.scale.y = strum.scale.y / 1.75;
			}
			for (note in unspawnNotes) {
				if (!note.mustPress) note.visible = false;
			}
			fixHitboxPos(playerStrums, true);
		}
		else
		{
			applyVSliceSpacingToMania(spacing);
			for (i in 0...totalColumns) {
				if (playerStrums.members[i] != null)
					hitboxPositions[i] = playerStrums.members[i].x + (playerStrums.members[i].width * 0.5);
			}
		}

		for (i in 0...playerStrums.length) {
			if (playerStrums.members[i] != null)
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
		}

		reloadPlayStateHitbox("V Slice");
	}

	function applyVSliceSpacingToMania(spacing:Float):Void
	{
		if (spacing <= 0 || playerStrums.length < 2) return;

		var first = playerStrums.members[0];
		var last = playerStrums.members[playerStrums.length - 1];
		if (first == null || last == null) return;

		var curLeft:Float = first.x;
		var curRight:Float = last.x + last.width;
		var targetLeft:Float = 8;
		var targetRight:Float = FlxG.width - 8;
		var curSpan:Float = curRight - curLeft;
		var targetSpan:Float = targetRight - targetLeft;
		if (curSpan <= 1) return;

		var newSpan:Float = curSpan + (targetSpan - curSpan) * spacing;
		var newLeft:Float = ((curLeft + curRight) * 0.5) - (newSpan * 0.5);
		var scale:Float = newSpan / curSpan;

		for (i in 0...playerStrums.length) {
			var strum = playerStrums.members[i];
			if (strum == null) continue;
			strum.x = newLeft + (strum.x - curLeft) * scale;
		}
	}

	public function fixHitboxPos(strumGroup:FlxTypedGroup<StrumNote>, ?keyCountIsDefault:Bool) {
		if (keyCountIsDefault) {
			for (i in 0...4) {
				if (strumGroup.members[i] != null)
					hitboxPositions[i] = strumGroup.members[i].x + (strumGroup.members[i].width * 0.5);
			}
		}
	}

	//Lua Stuff for Mobile Controls
	public function reloadPlayStateHitbox(?mode:String)
	{
		removePlayStateHitbox();
		addPlayStateHitbox(mode);
	}

	public function addPlayStateHitbox(?mode:String, ?makeInvinsibleFirst:Bool, ?hints:Null<Bool>)
	{
		if (hints == null)
			hints = ClientPrefs.data.hitboxHint;

		mobileManager.addHitbox(mode, hints);
		mobileManager.addHitboxCamera();
		if (!cpuControlled) connectControlToNotes(null, 'hitbox');
		if (makeInvinsibleFirst) mobileManager.hitbox.visible = false;
	}

	public function addHitboxDeadZone(?managerName:String, deadZoneButtons:Array<String>) {
		var manager = checkManager(managerName);
		if (manager.hitbox == null) return;
		manager.hitbox.forEachAlive((button) ->
		{
			for (deadButton in deadZoneButtons) {
				if (manager.mobilePad != null && manager.mobilePad.getButton(deadButton) != null)
					button.deadZones.push(manager.mobilePad.getButton(deadButton));
			}
		});
	}

	public function connectControlToNotes(?managerName:String, ?control:String) {
		var manager = checkManager(managerName);

		switch(control) {
			case 'mobilePad':
				manager.mobilePad?.onButtonDown?.add((button:MobileButton, ids:Array<String>, unique:Int) -> mobileKeyFromIDs(ids, true));
				manager.mobilePad?.onButtonUp?.add((button:MobileButton, ids:Array<String>, unique:Int) -> mobileKeyFromIDs(ids, false));
			case 'hitbox':
				manager.hitbox?.onButtonDown?.add((button:MobileButton, ids:Array<String>, unique:Int) -> mobileKeyFromIDs(ids, true));
				manager.hitbox?.onButtonUp?.add((button:MobileButton, ids:Array<String>, unique:Int) -> mobileKeyFromIDs(ids, false));
		}
	}
	function mobileKeyFromIDs(ids:Array<String>, pressed:Bool):Void
	{
		if (ids == null || ids.length == 0) return;
		if (ids[0].toString().startsWith('EXTRA')) return;

		var buttonCode:Int = MobileInputID.fromString(ids[0].toString());
		if (buttonCode >= 44 && buttonCode <= 48) buttonCode -= 40; // Fak yu Bradar
		if (buttonCode == MobileInputID.NONE && ids.length > 1) buttonCode = MobileInputID.fromString(ids[1].toString());
		if (buttonCode == MobileInputID.NONE) return;

		callOnScripts(pressed ? 'onButtonPressPre' : 'onButtonReleasePre', [buttonCode]);
		if (pressed) keyPressed(buttonCode); else keyReleased(buttonCode);
		callOnScripts(pressed ? 'onButtonPress' : 'onButtonRelease', [buttonCode]);
	}

	public function removePlayStateHitbox()
	{
		if (mobileManager.hitbox == null) return;
		mobileManager.hitbox.forEachAlive((button) ->
		{
			button.deadZones = [];
		});
		mobileManager.removeHitbox();
	}

	function checkForResync()
	{
		if (endingSong || paused || shutdownThread)
			return;

		if (requiresSyncing)
		{
			requiresSyncing = false;
			setSongTime(lastCorrectSongPos);
		}

		gameFroze = false;
	}

	public function runSongSyncThread()
	{
		Thread.create(function()
		{
			while (!endingSong && !paused && !shutdownThread)
			{
				if (requiresSyncing)
					continue;

				if (gameFroze)
				{
					lastCorrectSongPos = Conductor.songPosition;
					requiresSyncing = true;
					continue;
				}
				gameFroze = true;

				Sys.sleep(0.25);
			}
		});

		if (!FlxG.signals.preUpdate.has(checkForResync))
			FlxG.signals.preUpdate.add(checkForResync);
	}
}

/** Mania şerit eşlemesi: standart chart şeridi → {kolon, oyuncu mu} */
typedef ManiaLane = {
	var column:Int;
	var isPlayer:Bool;
}
