package vslice.menus.freeplay;

#if TOUCH_CONTROLS_ALLOWED
import mobile.objects.TouchButton;
import mobile.objects.TouchZone;
import mobile.objects.ScrollableObject;
#end

import objects.HealthIcon;
import flixel.sound.FlxSound;
import flixel.util.FlxDestroyUtil;
import openfl.events.KeyboardEvent;
import lime.system.Clipboard;
import backend.Highscore;
import vslice.menus.freeplay.capsule.SongMenuItem;
import vslice.menus.freeplay.capsule.SongCapsuleGroup;
import vslice.funkin.custom.mobile.MobileScaleMode;
import flixel.math.FlxRect;
import vslice.menus.freeplay.backcards.LuaCard;
import vslice.menus.freeplay.obj.CapsuleOptionsMenu;
import vslice.compatibility.funkin.FunkinControls;
import vslice.menus.charSelect.CharSelectSubState;
import openfl.filters.ShaderFilter;
import vslice.menus.freeplay.backcards.PicoCard;
import vslice.funkin.freeplay.FreeplayStyleRegistry;
import vslice.funkin.players.PlayableCharacter;
import vslice.menus.freeplay.backcards.BoyfriendCard;
import shaders.BlueFade;
import vslice.funkin.freeplay.FreeplayStyle;
import vslice.menus.freeplay.backcards.BackingCard;
import vslice.menus.freeplay.DJBoyfriend.FreeplayDJ;
import vslice.compatibility.ModsHelper;
import vslice.compatibility.VsliceOptions;
import vslice.compatibility.funkin.FunkinCamera;
import vslice.menus.freeplay.pslice.BPMCache;
import vslice.compatibility.freeplay.FreeplaySongData;
import vslice.compatibility.freeplay.FreeplayHelpers;
import vslice.compatibility.funkin.FunkinPath as Paths;
import vslice.funkin.custom.VsliceSubState as MusicBeatSubstate;
import openfl.utils.AssetCache;
import vslice.funkin.AtlasText;
import shaders.PureColor;
import shaders.HSVShader;
import shaders.StrokeShader;
import shaders.AngleMask;
import vslice.funkin.IntervalShake;
import vslice.menus.StickerSubState;
import vslice.funkin.Scoring.ScoringRank;
import flixel.addons.transition.FlxTransitionableState;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.util.FlxSpriteUtil;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxPoint;
import openfl.display.BlendMode;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.events.KeyboardEvent;
import lime.system.Clipboard;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

typedef FreeplayStateParams =
{
	?fromCharSelect:Bool,
	?fromResults:FromResultsParams,
};

typedef FromResultsParams =
{
	var ?oldRank:ScoringRank;
	var playRankAnim:Bool;
	var newRank:ScoringRank;
	var songId:String;
	var difficultyId:String;
};

typedef SearchDropdownItem =
{
	var type:SearchItemType;
	var text:String;
	var songData:Null<FreeplaySongData>;
	var color:FlxColor;
};

enum SearchItemType
{
	HEADER;
	SONG;
}

class FreeplayState extends MusicBeatSubstate
{
	final currentCharacterId:String;
	final currentCharacter:PlayableCharacter;

	public static final FADE_IN_DURATION:Float = 2;
	public static final FADE_OUT_DURATION:Float = 0.25;
	public static final FADE_IN_START_VOLUME:Float = 0;
	public static final FADE_IN_END_VOLUME:Float = 0.7;
	public static final FADE_IN_DELAY:Float = 0.25;
	public static final FADE_OUT_END_VOLUME:Float = 0.0;
	public static var CUTOUT_WIDTH:Float = MobileScaleMode.gameCutoutSize.x / 1.5;
	public static final DJ_POS_MULTI:Float = 0.44;
	public static final SONGS_POS_MULTI:Float = 0.75;

	var songs:Array<Null<FreeplaySongData>> = [];
	var diffIdsCurrent:Array<String> = [];
	var diffIdsTotal:Array<String> = ['easy', "normal", "hard"];
	var curSelected:Int = 0;
	var curSelectedFractal:Float = 0;
	var currentDifficulty:String = Constants.DEFAULT_DIFFICULTY;

	var fp:FreeplayScore;
	var txtCompletion:AtlasText;
	var lerpCompletion:Float = 0;
	var intendedCompletion:Float = 0;
	var lerpScore:Float = 0;
	var intendedScore:Int = 0;

	var grpDifficulties:FlxTypedSpriteGroup<DifficultySprite>;
	var grpSongs:FlxTypedGroup<Alphabet>;
	var grpCapsules:SongCapsuleGroup;
	var curCapsule(get, never):SongMenuItem;

	function get_curCapsule()
	{
		return grpCapsules.activeSongItems[curSelected];
	}

	var curPlaying:Bool = false;
	var dj:Null<FreeplayDJ> = null;
	var ostName:FlxText;
	var albumRoll:AlbumRoll;
	var charSelectHint:FlxText;
	var letterSort:LetterSort;
	var exitMovers:ExitMoverData = new Map();
	var exitMoversCharSel:ExitMoverData = new Map();
	var diffSelLeft:DifficultySelector;
	var diffSelRight:DifficultySelector;
	var stickerSubState:Null<StickerSubState> = null;

	public static var rememberedDifficulty:String = Constants.DEFAULT_DIFFICULTY;
	public static var rememberedSongId:Null<String> = 'tutorial';
	public static var instance:FreeplayState;

	var funnyCam:FunkinCamera;
	var rankCamera:FunkinCamera;
	var overlayCam:FunkinCamera;
	var rankBg:FunkinSprite;
	var rankVignette:FlxSprite;
	var backingCard:Null<BackingCard> = null;
	public var backingImage:FlxSprite;
	var fromResultsParams:Null<FromResultsParams> = null;
	var prepForNewRank:Bool = false;
	var styleData:Null<FreeplayStyle> = null;
	var fromCharSelect:Null<Bool> = null;

	var searchOpen:Bool = false;
	var searchInputActive:Bool = false;
	var blockInputFrames:Int = 0;
	static var searchString:String = '';

	var searchBarBG:FlxSprite;
	var searchBarOutline:FlxSprite;
	var searchBarText:FlxText;
	var searchBarHint:FlxText;
	var searchBarCursor:FlxText;
	var searchIcon:FlxSprite;
	var cursorTimer:Float = 0;
	
	var rankAnimPlaying:Bool = false;

	var dropdownBG:FlxSprite;
	var dropdownHighlight:FlxSprite;
	var dropdownTextGroup:FlxTypedGroup<FlxText>;
	var dropdownIconGroup:FlxTypedGroup<HealthIcon>;
	var dropdownItems:Array<SearchDropdownItem> = [];
	var dropdownSelected:Int = 0;
	var dropdownMaxVisible:Int = 8;
	var dropdownScrollOffset:Int = 0;

	static inline var SEARCH_BAR_WIDTH:Int = 640;
	static inline var SEARCH_BAR_HEIGHT:Int = 52;
	static inline var SEARCH_BAR_MARGIN:Int = 10;
	static inline var DROPDOWN_ITEM_HEIGHT:Int = 40;
	static inline var DROPDOWN_ICON_SIZE:Int = 28;

	public static var recentlyPlayed:Array<String> = [];

	var holdTime:Float = 0;
	var _previewTimer:Null<FlxTimer> = null;

	#if TOUCH_CONTROLS_ALLOWED
	inline function isDirectionalTouchButton(button:TouchButton):Bool
	{
		return button != null && (
			button.tag == 'UP'
			|| button.tag == 'DOWN'
			|| button.tag == 'LEFT'
			|| button.tag == 'RIGHT'
		);
	}

	function addFreeplayTouchPad(?skipAnim:Bool):Void
	{
		addTouchPad('LEFT_FULL', 'A_B_C_P_X_Y_Z');
		addTouchPadCamera();

		if (skipAnim == true)
			return;

		if (prepForNewRank)
		{
			final lastAlpha:Float = touchPad.alpha;
			touchPad.alpha = 0;
			FlxTween.tween(touchPad, {alpha: lastAlpha}, 1.6, {ease: FlxEase.circOut});
		}
		else if (fromCharSelect != true)
		{
			touchPad.forEachAlive(function(button:TouchButton)
			{
				if (isDirectionalTouchButton(button))
				{
					button.x -= 350;
					FlxTween.tween(button, {x: button.x + 350}, 0.6, {ease: FlxEase.backInOut});
				}
				else
				{
					button.x += 450;
					FlxTween.tween(button, {x: button.x - 450}, 0.6, {ease: FlxEase.backInOut});
				}
			});
		}
	}
	#end

	public function new(?params:FreeplayStateParams, ?stickers:StickerSubState)
	{
		instance = this;
		controls.isInSubstate = true;
		super();

		var saveBox = VsliceOptions.LAST_MOD;
		var resolvedCharacterId:String = saveBox.char_name;

		if (resolvedCharacterId == null || resolvedCharacterId.length < 1)
			resolvedCharacterId = Constants.DEFAULT_CHARACTER;

		if (ModsHelper.isModDirEnabled(saveBox.mod_dir))
			ModsHelper.loadModDir(saveBox.mod_dir);

		CUTOUT_WIDTH = MobileScaleMode.gameCutoutSize.x / 1.5;

		var result:PlayableCharacter = PlayerRegistry.instance.fetchEntry(resolvedCharacterId);
		if (result == null)
		{
			resolvedCharacterId = Constants.DEFAULT_CHARACTER;
			result = PlayerRegistry.instance.fetchEntry(resolvedCharacterId);
		}

		currentCharacterId = resolvedCharacterId;
		currentCharacter = result;

		var styleId:String = currentCharacterId;
		if (styleId == null || styleId.length < 1)
			styleId = "bf";

		if (currentCharacter != null)
		{
			var charStyleId:String = currentCharacter.getFreeplayStyleID();
			if (charStyleId != null && charStyleId.length > 0)
				styleId = charStyleId;
		}

		styleData = FreeplayStyleRegistry.instance.fetchEntry(styleId);
		if (styleData == null)
			styleData = FreeplayStyleRegistry.instance.fetchEntry("bf");

		fromCharSelect = params?.fromCharSelect;
		fromResultsParams = params?.fromResults;

		if (fromResultsParams?.playRankAnim == true)
			prepForNewRank = true;

		if (stickers?.members != null)
			stickerSubState = stickers;
	}

	var fadeShader:BlueFade = new BlueFade();
	public var angleMaskShader:AngleMask = new AngleMask();

	override function create():Void
	{
		SongMenuItem.reloadGlobalItemData();
		var saveBox = VsliceOptions.LAST_MOD;
		if (ModsHelper.isModDirEnabled(saveBox.mod_dir))
			ModsHelper.loadModDir(saveBox.mod_dir);

		var safeCharacterId:String = currentCharacterId;
		if (safeCharacterId == null || safeCharacterId.length < 1)
			safeCharacterId = "bf";

		if (VsliceOptions.FP_CARDS)
		{
			switch (currentCharacterId)
			{
				case (VsliceOptions.LOW_QUALITY) => true:
					backingCard = null;
				#if (!LEGACY_PSYCH && HSCRIPT_ALLOWED)
				case (LuaCard.hasCustomCard(currentCharacterId)) => true:
					backingCard = new LuaCard(currentCharacter, currentCharacterId, stickerSubState == null);
				#end
				case 'bf':
					backingCard = new BoyfriendCard(currentCharacter);
				case 'pico':
					backingCard = new PicoCard(currentCharacter);
				default:
					backingCard = new BoyfriendCard(currentCharacter);
			}
		}
		else
			backingCard = new BoyfriendCard(currentCharacter);

		albumRoll = new AlbumRoll();
		fp = new FreeplayScore(FlxG.width - (MobileScaleMode.gameNotchSize.x + 353), 60, 7, 100, styleData);
		rankCamera = new FunkinCamera('rankCamera', 0, 0, FlxG.width, FlxG.height);
		funnyCam = new FunkinCamera('freeplayFunny', 0, 0, FlxG.width, FlxG.height);
		grpCapsules = new SongCapsuleGroup(styleData);
		grpCapsules.onRandomSelected.add(capsuleOnConfirmRandom);
		grpCapsules.onSongSelected.add(capsuleOnOpenDefault);

		grpDifficulties = new FlxTypedSpriteGroup<DifficultySprite>(-300, 80);
		letterSort = new LetterSort((CUTOUT_WIDTH * SONGS_POS_MULTI) + 400, 75);
		grpSongs = new FlxTypedGroup<Alphabet>();
		rankBg = new FunkinSprite(0, 0);
		rankVignette = new FlxSprite(0, 0).loadGraphic(Paths.image('freeplay/rankVignette'));
		sparks = new FlxSprite(0, 0);
		sparksADD = new FlxSprite(0, 0);
		txtCompletion = new AtlasText(FlxG.width - (MobileScaleMode.gameNotchSize.x + 95), 87, '69', AtlasFont.FREEPLAY_CLEAR);

		ostName = new FlxText(8 - MobileScaleMode.gameNotchSize.x, 8, FlxG.width - 8 - 8, Language.getPhrase('freeplay_ost', 'RESMİ ŞARKI'), 48);
		charSelectHint = new FlxText(-40, 18, FlxG.width - 8 - 8, 'Press [ LOL ] to change characters', 32);

		backingImage = new FlxSprite((backingCard?.pinkBack.width ?? 0) * 0.74,
			0).loadGraphic(styleData == null ? 'freeplay/freeplayBGdad' : styleData.getBgAssetGraphic());

		BPMCache.instance.clearCache();

		super.create();
		var diffIdsTotalModBinds:Map<String, String> = ["easy" => "", "normal" => "", "hard" => ""];

		FlxG.state.persistentUpdate = false;
		FlxTransitionableState.skipNextTransIn = true;

		var fadeShaderFilter:ShaderFilter = new ShaderFilter(fadeShader);
		ModsHelper.setFiltersOnCam(funnyCam, [fadeShaderFilter]);
		funnyCam.filtersEnabled = false;

		if (stickerSubState != null)
		{
			this.persistentUpdate = true;
			this.persistentDraw = true;
			openSubState(stickerSubState);
			stickerSubState.degenStickers();
		}

		#if discord_rpc
		DiscordClient.changePresence(Language.getPhrase('freeplay_rpc', 'Menülerde'), null);
		#end

		var isDebug:Bool = false;
		#if debug
		isDebug = true;
		#end

		busy = true;

		songs.push(null);
		PlayState.isStoryMode = false;
		for (sngCard in FreeplayHelpers.loadSongs())
		{
			if (currentCharacter.shouldShowUnownedChars() || ClientPrefs.data.quickFreeplay)
			{
				if (sngCard.songPlayer != '' && sngCard.songPlayer != currentCharacterId)
					continue;
			}
			else
			{
				if (sngCard.songPlayer == '' || sngCard.songPlayer != currentCharacterId)
					continue;
			}
			songs.push(sngCard);
			for (difficulty in sngCard.songDifficulties)
			{
				diffIdsTotal.pushUnique(difficulty);
				if (!diffIdsTotalModBinds.exists(difficulty))
					diffIdsTotalModBinds.set(difficulty, sngCard.folder);
			}
		}

		if (backingCard != null)
		{
			add(backingCard);
			backingCard.init();
			backingCard.applyExitMovers(exitMovers, exitMoversCharSel);
			backingCard.instance = this;
		}

		if (currentCharacter?.getFreeplayDJData() != null)
		{
			ModsHelper.loadModDir(VsliceOptions.LAST_MOD.mod_dir);
			dj = new FreeplayDJ(100, 100, currentCharacter);
		}

		if (!VsliceOptions.LOW_QUALITY)
			backingImage.shader = angleMaskShader;
		backingImage.visible = false;

		var blackOverlayBullshitLOLXD:FlxSprite = new FlxSprite(FlxG.width).makeGraphic(Std.int(backingImage.width), Std.int(backingImage.height),
			FlxColor.BLACK);
		add(blackOverlayBullshitLOLXD);
		blackOverlayBullshitLOLXD.shader = backingImage.shader;

		if (VsliceOptions.LOW_QUALITY)
			backingImage.setGraphicSize(FlxG.width, FlxG.height);
		else
			backingImage.setGraphicSize(0, FlxG.height);
		blackOverlayBullshitLOLXD.setGraphicSize(0, FlxG.height);

		backingImage.updateHitbox();
		blackOverlayBullshitLOLXD.updateHitbox();

		exitMovers.set([blackOverlayBullshitLOLXD, backingImage], {
			x: FlxG.width * 1.5,
			speed: 0.4,
			wait: 0
		});

		exitMoversCharSel.set([blackOverlayBullshitLOLXD, backingImage], {
			y: -100,
			speed: 0.8,
			wait: 0.1
		});

		if (VsliceOptions.LOW_QUALITY)
			add(backingImage);

		grpDifficulties = new FlxTypedSpriteGroup<DifficultySprite>(-300, 80);
		add(grpDifficulties);

		if (!VsliceOptions.LOW_QUALITY)
			add(backingImage);

		blackOverlayBullshitLOLXD.shader = backingImage.shader;

		rankBg.makeSolidColor(FlxG.width, FlxG.height, 0xD3000000);
		add(rankBg);

		add(grpSongs);
		add(grpCapsules);

		exitMovers.set([grpDifficulties], {
			x: -300,
			speed: 0.25,
			wait: 0
		});

		exitMoversCharSel.set([grpDifficulties], {
			y: -270,
			speed: 0.8,
			wait: 0.1
		});

		for (diffId in diffIdsTotal)
		{
			ModsHelper.loadModDir(diffIdsTotalModBinds.get(diffId));

			if (!hasDifficultySprite(diffId))
			{
				trace('Skipping difficulty without sprite: ' + diffId);
				continue;
			}

			var diffSprite:DifficultySprite = new DifficultySprite(diffId);
			diffSprite.difficultyId = diffId;
			grpDifficulties.add(diffSprite);
		}
		ModsHelper.loadModDir(VsliceOptions.LAST_MOD.mod_dir);

		grpDifficulties.group.forEach(function(spr)
		{
			spr.visible = false;
		});

		for (diffSprite in grpDifficulties.group.members)
		{
			if (diffSprite == null)
				continue;
			if (diffSprite.difficultyId == currentDifficulty)
				diffSprite.visible = true;
		}

		albumRoll.albumId = null;
		@:privateAccess
		albumRoll.updateAlbum();
		add(albumRoll);

		var overhangStuff:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 164, FlxColor.BLACK);
		overhangStuff.y -= overhangStuff.height;

		if (fromCharSelect == true)
		{
			blackOverlayBullshitLOLXD.visible = false;
			overhangStuff.y = -100;
			backingCard?.skipIntroTween();
		}
		else
		{
			albumRoll.applyExitMovers(exitMovers, exitMoversCharSel);
			FlxTween.tween(overhangStuff, {y: -100}, 0.3, {ease: FlxEase.quartOut});
			FlxTween.tween(blackOverlayBullshitLOLXD, {x: backingImage.x}, 0.7, {ease: FlxEase.quintOut});
		}

		var topLeftCornerText:FlxText = new FlxText(Math.max(MobileScaleMode.gameNotchSize.x, 8), 8, 0, Language.getPhrase('freeplay_title', 'SERBEST OYUN'), 48);
		topLeftCornerText.font = 'VCR OSD Mono';
		topLeftCornerText.visible = false;

		var freeplayTxtBg:FlxSprite = new FlxSprite().makeGraphic(Math.round(topLeftCornerText.width + 16), Math.round(topLeftCornerText.height + 16),
			FlxColor.BLACK);
		freeplayTxtBg.x = topLeftCornerText.x - 8;
		freeplayTxtBg.visible = false;

		ostName.font = 'VCR OSD Mono';
		ostName.alignment = RIGHT;
		ostName.visible = false;

		charSelectHint.alignment = CENTER;
		charSelectHint.font = "5by7";
		charSelectHint.color = 0xFF5F5F5F;
		charSelectHint.text = controls.mobileC
			? Language.getPhrase('freeplay_char_hint_mobile', '[ Z ] ile karakter değiştirin')
			: Language.getPhrase('freeplay_char_hint_pc', '[ {1} ] ile karakter değiştirin').replace('{1}', FunkinControls.FREEPLAY_CHAR_name());
		charSelectHint.y -= 100;
		FlxTween.tween(charSelectHint, {y: charSelectHint.y + 100}, 0.8, {ease: FlxEase.quartOut});

		exitMovers.set([overhangStuff, freeplayTxtBg, topLeftCornerText, ostName, charSelectHint], {
			y: -overhangStuff.height,
			x: 0,
			speed: 0.2,
			wait: 0
		});

		exitMoversCharSel.set([overhangStuff, freeplayTxtBg, topLeftCornerText, ostName, charSelectHint], {
			y: -300,
			speed: 0.8,
			wait: 0.1
		});

		var sillyStroke:StrokeShader = new StrokeShader(0xFFFFFFFF, 2, 2);
		topLeftCornerText.shader = sillyStroke;
		ostName.shader = sillyStroke;

		var fnfHighscoreSpr:FlxSprite = new FlxSprite(FlxG.width - MobileScaleMode.gameNotchSize.x - 420, 70);
		fnfHighscoreSpr.frames = Paths.getSparrowAtlas('freeplay/highscore');
		fnfHighscoreSpr.animation.addByPrefix('highscore', 'highscore small instance 1', 24, false);
		fnfHighscoreSpr.visible = false;
		fnfHighscoreSpr.setGraphicSize(0, Std.int(fnfHighscoreSpr.height * 1));
		fnfHighscoreSpr.updateHitbox();
		add(fnfHighscoreSpr);

		new FlxTimer().start(FlxG.random.float(12, 50), function(tmr)
		{
			fnfHighscoreSpr?.animation?.play('highscore');
			tmr.time = FlxG.random.float(20, 60);
		}, 0);

		fp.visible = false;
		fp.camera = funnyCam;
		add(fp);

		var clearBoxSprite:FlxSprite = new FlxSprite(FlxG.width - MobileScaleMode.gameNotchSize.x - 115, 65).loadGraphic(Paths.image('freeplay/clearBox'));
		clearBoxSprite.visible = false;
		add(clearBoxSprite);

		txtCompletion.visible = false;
		add(txtCompletion);

		add(letterSort);
		letterSort.visible = false;

		exitMovers.set([letterSort], {
			y: -100,
			speed: 0.3
		});

		exitMoversCharSel.set([letterSort], {
			y: -270,
			speed: 0.8,
			wait: 0.1
		});

		letterSort.changeSelectionCallback = (str) ->
		{
			switch (str)
			{
				case 'fav':
					generateSongList({filterType: FAVORITE}, true);
				case 'ALL':
					generateSongList(null, true);
				case '#':
					generateSongList({filterType: REGEXP, filterData: '0-9'}, true);
				default:
					generateSongList({filterType: REGEXP, filterData: str}, true);
			}

			if (grpCapsules.activeSongItems.length > 0)
			{
				FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
				curSelected = 1;
				curSelectedFractal = 1;
				changeSelection();
			}
		};

		exitMovers.set([fp, txtCompletion, fnfHighscoreSpr, clearBoxSprite], {
			x: FlxG.width,
			speed: 0.3
		});

		exitMoversCharSel.set([fp, txtCompletion, fnfHighscoreSpr, clearBoxSprite], {
			y: -270,
			speed: 0.8,
			wait: 0.1
		});

		diffSelLeft = new DifficultySelector(this, (CUTOUT_WIDTH * DJ_POS_MULTI) + 20, grpDifficulties.y - 10, false, controls, styleData);
		diffSelRight = new DifficultySelector(this, (CUTOUT_WIDTH * DJ_POS_MULTI) + 325, grpDifficulties.y - 10, true, controls, styleData);
		diffSelLeft.visible = false;
		diffSelRight.visible = false;
		add(diffSelLeft);
		add(diffSelRight);

		add(overhangStuff);
		add(freeplayTxtBg);
		add(topLeftCornerText);
		add(ostName);

		#if (BASE_GAME_FILES || MODS_ALLOWED)
		add(charSelectHint);
		#end

		if (dj != null)
		{
			remove(dj, true);
			var capsuleIndex:Int = members.indexOf(grpCapsules);
			if (capsuleIndex > -1)
				insert(capsuleIndex, dj);
			else
				add(dj);
		}

		var onDJIntroDone = function()
		{
			busy = false;

			if (curCapsule != null)
			{
				albumRoll.playIntro();
				var daSong = curCapsule.songData;
				albumRoll.albumId = daSong?.albumId;
			}
			else
				albumRoll.albumId = '';

			if (fromCharSelect == null)
			{
				if (_parentState != null)
					_parentState.persistentDraw = false;

				FlxTween.color(backingImage, 0.6, 0xFF000000, 0xFFFFFFFF, {
					ease: FlxEase.expoOut,
					onUpdate: function(_)
					{
						angleMaskShader.extraColor = backingImage.color;
					},
					onComplete: function(_)
					{
						blackOverlayBullshitLOLXD.visible = false;
					}
				});
			}

			FlxTween.cancelTweensOf(grpDifficulties);
			for (diff in grpDifficulties.group.members)
			{
				if (diff == null)
					continue;
				FlxTween.cancelTweensOf(diff);
				FlxTween.tween(diff, {x: (CUTOUT_WIDTH * DJ_POS_MULTI) + 90}, 0.6, {ease: FlxEase.quartOut});
				diff.y = 80;
				diff.visible = diff.difficultyId == currentDifficulty;
			}
			FlxTween.tween(grpDifficulties, {x: (CUTOUT_WIDTH * DJ_POS_MULTI) + 90}, 0.6, {ease: FlxEase.quartOut});

			diffSelLeft.visible = true;
			diffSelRight.visible = true;
			letterSort.visible = true;

			exitMovers.set([diffSelLeft, diffSelRight], {
				x: -diffSelLeft.width * 2,
				speed: 0.26
			});

			exitMoversCharSel.set([diffSelLeft, diffSelRight], {
				y: -270,
				speed: 0.8,
				wait: 0.1
			});

			new FlxTimer().start(1 / 24, function(handShit)
			{
				fnfHighscoreSpr.visible = true;
				freeplayTxtBg.visible = true;
				topLeftCornerText.visible = true;
				ostName.visible = true;
				fp.visible = true;
				fp.updateScore(0);

				clearBoxSprite.visible = true;
				txtCompletion.visible = true;
				intendedCompletion = 0;

				new FlxTimer().start(1.5 / 24, function(bold)
				{
					sillyStroke.width = 0;
					sillyStroke.height = 0;
					changeSelection();
				});
			});

			backingImage.visible = true;
			backingCard?.introDone();

			if (prepForNewRank && fromResultsParams != null)
			{
				rankAnimStart(fromResultsParams);
			}
		};

		if (dj != null)
		{
			dj.onIntroDone.add(onDJIntroDone);
		}
		else
		{
			TimerUtil.wait(0.5, () -> onDJIntroDone());
		}

		currentDifficulty = rememberedDifficulty;
		generateSongList(null, false);

		funnyCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(funnyCam, false);

		rankVignette.scale.set(2 * MobileScaleMode.wideScale.x, 2 * MobileScaleMode.wideScale.y);
		rankVignette.updateHitbox();
		rankVignette.blend = BlendMode.ADD;
		add(rankVignette);
		rankVignette.alpha = 0;

		forEach(function(bs)
		{
			bs.cameras = [funnyCam];
		});

		rankCamera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(rankCamera, false);
		rankBg.cameras = [rankCamera];
		rankBg.alpha = 0;

		overlayCam = new FunkinCamera('freeplayOverlay', 0, 0, FlxG.width, FlxG.height);
		overlayCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overlayCam, false);

		if (prepForNewRank)
		{
			rankCamera.fade(0xFF000000, 0, false, null, true);
		}

		createSearchBar();

		#if TOUCH_CONTROLS_ALLOWED
		addFreeplayTouchPad();
		
		#if !LEGACY_PSYCH
		var button = new TouchZone((CUTOUT_WIDTH * SONGS_POS_MULTI) + 420, 260, 450, 95);
		button.cameras = [funnyCam];

		var scroll = new ScrollableObject(-0.02, (CUTOUT_WIDTH * SONGS_POS_MULTI) + 150, 100, FlxG.width - 400, FlxG.height, button);
		scroll.cameras = [funnyCam];
		scroll.onPartialScroll.add(delta ->
		{
			if (busy)
				return;
			changeSelectionFractal(delta);
		});
		scroll.onFullScrollSnap.add(() -> changeSelectionFractal(curSelected - curSelectedFractal));
		scroll.onFullScroll.add(delta ->
		{
			if (busy)
				return;
			changeSelection(delta, false);
		});
		scroll.onTap.add(() ->
		{
			if (busy)
				return;

			var daSongCapsule:SongMenuItem = curCapsule;
			if (daSongCapsule == null)
				return;

			daSongCapsule.onConfirm();
		});
		add(scroll);
		add(button);
		#end
		#end

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		if (fromCharSelect == true)
		{
			enterFromCharSel();
			onDJIntroDone();
		}
	}

	function createSearchBar():Void
	{
		var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
		var barY:Int = SEARCH_BAR_MARGIN;

		searchBarOutline = new FlxSprite(barX - 2, barY - 2).makeGraphic(SEARCH_BAR_WIDTH + 4, SEARCH_BAR_HEIGHT + 4, FlxColor.TRANSPARENT);
		flixel.util.FlxSpriteUtil.drawRoundRect(searchBarOutline, 0, 0, SEARCH_BAR_WIDTH + 4, SEARCH_BAR_HEIGHT + 4, 16, 16, FlxColor.WHITE);
		searchBarOutline.alpha = 0;
		searchBarOutline.scrollFactor.set();
		searchBarOutline.cameras = [funnyCam];
		add(searchBarOutline);

		searchBarBG = new FlxSprite(barX, barY).makeGraphic(SEARCH_BAR_WIDTH, SEARCH_BAR_HEIGHT, FlxColor.TRANSPARENT);
		flixel.util.FlxSpriteUtil.drawRoundRect(searchBarBG, 0, 0, SEARCH_BAR_WIDTH, SEARCH_BAR_HEIGHT, 12, 12, FlxColor.fromRGB(30, 30, 40));
		searchBarBG.alpha = 0.85;
		searchBarBG.scrollFactor.set();
		searchBarBG.cameras = [funnyCam];
		add(searchBarBG);

		searchIcon = new FlxSprite(barX + 8, barY + 12);
		if (Paths.image('freeplay/search') != null)
		{
			searchIcon.loadGraphic(Paths.image('freeplay/search'));
			searchIcon.setGraphicSize(28, 28);
			searchIcon.updateHitbox();
		}
		else
		{
			searchIcon.makeGraphic(28, 28, FlxColor.TRANSPARENT);
		}
		searchIcon.antialiasing = ClientPrefs.data.antialiasing;
		searchIcon.scrollFactor.set();
		searchIcon.alpha = 0.7;
		searchIcon.cameras = [funnyCam];
		add(searchIcon);

		var hintText:String = controls.mobileC
			? Language.getPhrase('freeplay_search_tap', 'X butonu veya dokunarak arayın')
			: Language.getPhrase('freeplay_search_key', 'Aramak için C tuşuna basın');
		searchBarHint = new FlxText(barX + 44, barY + 16, SEARCH_BAR_WIDTH - 60, hintText, 20);
		searchBarHint.setFormat("VCR OSD Mono", 16, FlxColor.fromRGB(150, 150, 170), LEFT);
		searchBarHint.scrollFactor.set();
		searchBarHint.cameras = [funnyCam];
		add(searchBarHint);

		searchBarText = new FlxText(barX + 44, barY + 16, SEARCH_BAR_WIDTH - 60, "", 20);
		searchBarText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT);
		searchBarText.scrollFactor.set();
		searchBarText.cameras = [funnyCam];
		add(searchBarText);

		searchBarCursor = new FlxText(barX + 44, barY + 16, 20, "|", 20);
		searchBarCursor.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT);
		searchBarCursor.scrollFactor.set();
		searchBarCursor.visible = false;
		searchBarCursor.cameras = [funnyCam];
		add(searchBarCursor);

		dropdownBG = new FlxSprite(barX, barY + SEARCH_BAR_HEIGHT).makeGraphic(SEARCH_BAR_WIDTH,
			DROPDOWN_ITEM_HEIGHT * dropdownMaxVisible + 10, FlxColor.fromRGB(25, 25, 35));
		dropdownBG.alpha = 0;
		dropdownBG.scrollFactor.set();
		dropdownBG.cameras = [funnyCam];
		add(dropdownBG);

		dropdownHighlight = new FlxSprite(barX + 4, 0).makeGraphic(SEARCH_BAR_WIDTH - 8, DROPDOWN_ITEM_HEIGHT, FlxColor.fromRGB(60, 60, 90));
		dropdownHighlight.alpha = 0;
		dropdownHighlight.scrollFactor.set();
		dropdownHighlight.cameras = [funnyCam];
		add(dropdownHighlight);

		dropdownTextGroup = new FlxTypedGroup<FlxText>();
		dropdownTextGroup.cameras = [funnyCam];
		add(dropdownTextGroup);

		dropdownIconGroup = new FlxTypedGroup<HealthIcon>();
		dropdownIconGroup.cameras = [funnyCam];
		add(dropdownIconGroup);
	}

	function openSearchBar():Void
	{
		if (searchOpen || busy)
			return;

		searchOpen = true;
		searchInputActive = true;
		blockInputFrames = 0;
		FlxG.stage.window.textInputEnabled = true;
		dropdownSelected = 0;
		dropdownScrollOffset = 0;

		FlxTween.cancelTweensOf(searchBarOutline);
		FlxTween.tween(searchBarOutline, {alpha: 0.8}, 0.2);

		FlxTween.cancelTweensOf(searchBarBG);
		FlxTween.tween(searchBarBG, {alpha: 0.95}, 0.2);

		searchBarHint.visible = (searchString.length == 0);
		searchBarText.text = searchString;
		searchBarCursor.visible = true;
		cursorTimer = 0;

		buildDropdownItems();
		showDropdown();
	}

	function closeSearchBar():Void
	{
		if (!searchOpen)
			return;

		searchOpen = false;
		searchInputActive = false;
		blockInputFrames = 5;
		FlxG.stage.window.textInputEnabled = false;

		FlxTween.cancelTweensOf(searchBarOutline);
		FlxTween.tween(searchBarOutline, {alpha: 0}, 0.3);

		FlxTween.cancelTweensOf(searchBarBG);
		FlxTween.tween(searchBarBG, {alpha: 0.85}, 0.3);

		searchBarCursor.visible = false;

		if (searchString.length > 0)
		{
			searchBarHint.visible = false;
			searchBarText.text = searchString;
		}
		else
		{
			searchBarHint.visible = true;
			searchBarText.text = "";
		}

		hideDropdown();
	}

	function updateSearchBarDisplay():Void
	{
		searchBarText.text = searchString;
		searchBarHint.visible = (searchString.length == 0);

		if (searchOpen)
		{
			searchBarCursor.x = searchBarText.x + searchBarText.textField.textWidth + 2;
			searchBarCursor.visible = true;
		}
	}

	function buildDropdownItems():Void
	{
		dropdownItems = [];

		if (searchString.length == 0)
		{
			if (recentlyPlayed.length > 0)
			{
				dropdownItems.push({
					type: HEADER,
					text: Language.getPhrase('freeplay_recent', '── SON OYNANAN ──'),
					songData: null,
					color: FlxColor.fromRGB(255, 200, 60)
				});

				var lastPlayed:String = recentlyPlayed[recentlyPlayed.length - 1];
				for (song in songs)
				{
					if (song != null && song.songName.toLowerCase() == lastPlayed.toLowerCase())
					{
						dropdownItems.push({
							type: SONG,
							text: song.songName,
							songData: song,
							color: song.color
						});
						break;
					}
				}
			}

			var favSongs:Array<FreeplaySongData> = [];
			for (song in songs)
			{
				if (song != null && song.isFav)
					favSongs.push(song);
			}

			if (favSongs.length > 0)
			{
				dropdownItems.push({
					type: HEADER,
					text: Language.getPhrase('freeplay_favorites', '── FAVORİLER ──'),
					songData: null,
					color: FlxColor.fromRGB(255, 100, 100)
				});

				for (fav in favSongs)
				{
					dropdownItems.push({
						type: SONG,
						text: fav.songName,
						songData: fav,
						color: fav.color
					});
				}
			}

			if (dropdownItems.length == 0)
			{
				dropdownItems.push({
					type: HEADER,
					text: Language.getPhrase('freeplay_search_hint', 'ŞARKI ARAMAK İÇİN YAZIN...'),
					songData: null,
					color: FlxColor.fromRGB(150, 150, 170)
				});
			}
		}
		else
		{
			var searchLower:String = searchString.toLowerCase();
			var resultCount:Int = 0;

			dropdownItems.push({
				type: HEADER,
				text: Language.getPhrase('freeplay_search_results', 'SONUÇLAR: "{1}"').replace('{1}', searchString),
				songData: null,
				color: FlxColor.fromRGB(100, 200, 255)
			});

			for (song in songs)
			{
				if (song == null)
					continue;
				var songNameLower:String = song.songName.toLowerCase().replace('-', ' ');
				var searchTermClean:String = searchLower.replace('-', ' ');
				if (songNameLower.contains(searchTermClean))
				{
					var diffInfo:String = '';
					if (song.songDifficulties != null && song.songDifficulties.length > 0)
					{
						var diffs:Array<String> = [];
						for (d in song.songDifficulties)
							diffs.push(d.toUpperCase().charAt(0) + d.substr(1));
						diffInfo = ' [' + diffs.join(', ') + ']';
					}

					dropdownItems.push({
						type: SONG,
						text: song.songName + diffInfo,
						songData: song,
						color: song.color
					});
					resultCount++;
					if (resultCount >= 20)
						break;
				}
			}

			if (resultCount == 0)
			{
				dropdownItems.push({
					type: HEADER,
					text: Language.getPhrase('freeplay_no_results', 'SONUÇ BULUNAMADI'),
					songData: null,
					color: FlxColor.fromRGB(255, 80, 80)
				});
			}
		}

		dropdownSelected = -1;
		for (di in 0...dropdownItems.length)
		{
			if (dropdownItems[di].type == SONG)
			{
				dropdownSelected = di;
				break;
			}
		}
	}

	function showDropdown():Void
	{
		clearDropdownVisuals();

		var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
		var barY:Int = SEARCH_BAR_MARGIN + SEARCH_BAR_HEIGHT;

		var visibleCount:Int = Std.int(Math.min(dropdownItems.length, dropdownMaxVisible));
		var dropdownHeight:Int = visibleCount * DROPDOWN_ITEM_HEIGHT + 10;

		dropdownBG.makeGraphic(SEARCH_BAR_WIDTH, Std.int(Math.max(dropdownHeight, 50)), FlxColor.TRANSPARENT);
			flixel.util.FlxSpriteUtil.drawRoundRect(dropdownBG, 0, 0, SEARCH_BAR_WIDTH, Std.int(Math.max(dropdownHeight, 50)), 12, 12, FlxColor.fromRGB(25, 25, 35));
		dropdownBG.setPosition(barX, barY);

		FlxTween.cancelTweensOf(dropdownBG);
		FlxTween.tween(dropdownBG, {alpha: 0.92}, 0.25);

		refreshDropdownVisuals();
	}

	function clearDropdownVisuals():Void
	{
		for (t in dropdownTextGroup.members)
		{
			if (t != null)
			{
				t.visible = false;
				t.active = false;
				t.kill();
			}
		}
		for (i in dropdownIconGroup.members)
		{
			if (i != null)
			{
				i.visible = false;
				i.active = false;
				i.kill();
			}
		}
		dropdownHighlight.alpha = 0;
	}

	function refreshDropdownVisuals():Void
	{
		clearDropdownVisuals();

		var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
		var startY:Float = dropdownBG.y + 5;

		var visibleStart:Int = dropdownScrollOffset;
		var visibleEnd:Int = Std.int(Math.min(dropdownItems.length, dropdownScrollOffset + dropdownMaxVisible));

		var visibleCount:Int = visibleEnd - visibleStart;
		var dropdownHeight:Int = visibleCount * DROPDOWN_ITEM_HEIGHT + 10;
		var targetHeight:Int = Std.int(Math.max(dropdownHeight, 50));

		// makeGraphic her çağrıda yeni bitmap üretir — boyut değişmediyse atla
		if (Std.int(dropdownBG.height) != targetHeight)
			dropdownBG.makeGraphic(SEARCH_BAR_WIDTH, targetHeight, FlxColor.TRANSPARENT);
			flixel.util.FlxSpriteUtil.drawRoundRect(dropdownBG, 0, 0, SEARCH_BAR_WIDTH, targetHeight, 12, 12, FlxColor.fromRGB(25, 25, 35));

		for (vi in visibleStart...visibleEnd)
		{
			var item:SearchDropdownItem = dropdownItems[vi];
			var slotIndex:Int = vi - visibleStart;
			var itemY:Float = startY + slotIndex * DROPDOWN_ITEM_HEIGHT;

			if (item.type == HEADER)
			{
				var headerText:FlxText = recycleText();
				headerText.setFormat("VCR OSD Mono", 18, item.color, LEFT);
				headerText.text = item.text;
				headerText.setPosition(barX + 12, itemY + Std.int((DROPDOWN_ITEM_HEIGHT - 18) / 2));
				headerText.fieldWidth = SEARCH_BAR_WIDTH - 24;
				headerText.scrollFactor.set();
				headerText.cameras = [funnyCam];
				headerText.alpha = 0.9;
				headerText.visible = true;
				headerText.revive();
				dropdownTextGroup.add(headerText);
			}
			else if (item.type == SONG)
			{
				var isSelected:Bool = (vi == dropdownSelected);
				var isFav:Bool = item.songData != null && item.songData.isFav;

				var displayName:String = item.text;
				if (isFav)
					displayName = "♥ " + displayName;

				var songText:FlxText = recycleText();
				songText.setFormat("VCR OSD Mono", 15, isSelected ? FlxColor.WHITE : FlxColor.fromRGB(200, 200, 210), LEFT);
				songText.text = displayName;
				songText.setPosition(barX + 14 + DROPDOWN_ICON_SIZE + 15, itemY + Std.int((DROPDOWN_ITEM_HEIGHT - 20) / 2));
				songText.fieldWidth = SEARCH_BAR_WIDTH - (14 + DROPDOWN_ICON_SIZE + 20);
				songText.scrollFactor.set();
				songText.cameras = [funnyCam];
				songText.alpha = isSelected ? 1 : 0.7;
				songText.visible = true;
				songText.revive();
				dropdownTextGroup.add(songText);

				if (item.songData != null)
				{
					ModsHelper.loadModDir(item.songData.folder);
					var songIcon:HealthIcon = recycleIcon(item.songData.songCharacter);
					songIcon.setGraphicSize(DROPDOWN_ICON_SIZE, DROPDOWN_ICON_SIZE);
					songIcon.updateHitbox();
					songIcon.centerOffsets();
					songIcon.scrollFactor.set();
					songIcon.cameras = [funnyCam];
					songIcon.x = barX + 14;
					songIcon.y = itemY + Std.int((DROPDOWN_ITEM_HEIGHT - songIcon.height) / 2);
					songIcon.alpha = isSelected ? 1 : 0.6;
					songIcon.visible = true;
					songIcon.active = true;
					songIcon.revive();
					dropdownIconGroup.add(songIcon);
				}
			}
		}
		ModsHelper.loadModDir(VsliceOptions.LAST_MOD.mod_dir);

		if (dropdownSelected >= visibleStart && dropdownSelected < visibleEnd && dropdownSelected >= 0
			&& dropdownItems[dropdownSelected].type == SONG)
		{
			var highlightSlot:Int = dropdownSelected - visibleStart;
			var highlightY:Float = startY + highlightSlot * DROPDOWN_ITEM_HEIGHT;
			dropdownHighlight.makeGraphic(SEARCH_BAR_WIDTH - 8, DROPDOWN_ITEM_HEIGHT, FlxColor.TRANSPARENT);
			flixel.util.FlxSpriteUtil.drawRoundRect(dropdownHighlight, 0, 0, SEARCH_BAR_WIDTH - 8, DROPDOWN_ITEM_HEIGHT, 8, 8, FlxColor.fromRGB(60, 60, 90));
			dropdownHighlight.setPosition(barX + 4, highlightY);
			dropdownHighlight.scrollFactor.set();
			dropdownHighlight.alpha = 0.5;
		}
		else
		{
			dropdownHighlight.alpha = 0;
		}
	}

	function hideDropdown():Void
	{
		FlxTween.cancelTweensOf(dropdownBG);
		FlxTween.tween(dropdownBG, {alpha: 0}, 0.2, {
			onComplete: function(_)
			{
				clearDropdownVisuals();
			}
		});
		dropdownHighlight.alpha = 0;
	}

	function recycleText():FlxText
	{
		for (t in dropdownTextGroup.members)
		{
			if (t != null && !t.alive)
				return t;
		}
		var txt = new FlxText(0, 0, SEARCH_BAR_WIDTH, "", 20);
		txt.scrollFactor.set();
		txt.cameras = [funnyCam];
		return txt;
	}

	function recycleIcon(charName:String):HealthIcon
	{
		for (i in dropdownIconGroup.members)
		{
			if (i != null && !i.alive)
			{
				i.changeIcon(charName);
				return i;
			}
		}
		var icon = new HealthIcon(charName);
		icon.scrollFactor.set();
		icon.cameras = [funnyCam];
		return icon;
	}

	function selectDropdownItem():Void
	{
		if (dropdownSelected < 0 || dropdownSelected >= dropdownItems.length)
			return;

		var item:SearchDropdownItem = dropdownItems[dropdownSelected];
		if (item.type != SONG || item.songData == null)
			return;

		var targetSongData:FreeplaySongData = item.songData;

		searchString = '';
		if (targetSongData.songDifficulties != null
			&& !targetSongData.songDifficulties.contains(currentDifficulty))
		{
			var preferredDiffs:Array<String> = ['normal', 'hard', 'easy'];
			var foundDiff:Bool = false;

			for (pref in preferredDiffs)
			{
				if (targetSongData.songDifficulties.contains(pref))
				{
					currentDifficulty = pref;
					rememberedDifficulty = currentDifficulty;
					foundDiff = true;
					break;
				}
			}

			if (!foundDiff && targetSongData.songDifficulties.length > 0)
			{
				currentDifficulty = targetSongData.songDifficulties[0];
				rememberedDifficulty = currentDifficulty;
			}
		}

		generateSongList(null, true, false, true);
		var foundIndex:Int = -1;
		for (ci in 0...grpCapsules.activeSongItems.length)
		{
			var cap = grpCapsules.activeSongItems[ci];
			if (cap != null && cap.songData != null && cap.songData.songId == targetSongData.songId)
			{
				foundIndex = ci;
				break;
			}
		}

		if (foundIndex != -1)
		{
			curSelected = foundIndex;
			curSelectedFractal = curSelected;
			changeSelection();
		}

		generateSongList(null, true);
		foundIndex = -1;
		for (ci in 0...grpCapsules.activeSongItems.length)
		{
			var cap = grpCapsules.activeSongItems[ci];
			if (cap != null && cap.songData != null && cap.songData.songId == targetSongData.songId)
			{
				foundIndex = ci;
				break;
			}
		}

		if (foundIndex != -1)
		{
			curSelected = foundIndex;
			curSelectedFractal = curSelected;
			changeSelection();
		}
		changeDiff(0, true);

		closeSearchBar();
		updateSearchBarDisplay();
		FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
	}

	function navigateDropdown(direction:Int):Void
	{
		FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.3);

		var startPos:Int = dropdownSelected + direction;
		while (startPos >= 0 && startPos < dropdownItems.length)
		{
			if (dropdownItems[startPos].type == SONG)
			{
				dropdownSelected = startPos;

				if (dropdownSelected < dropdownScrollOffset)
					dropdownScrollOffset = dropdownSelected;
				if (dropdownSelected >= dropdownScrollOffset + dropdownMaxVisible)
					dropdownScrollOffset = dropdownSelected - dropdownMaxVisible + 1;

				refreshDropdownVisuals();
				return;
			}
			startPos += direction;
		}
	}

	function checkSearchBarClick():Bool
	{
		var justClicked:Bool = FlxG.mouse.justPressed;

		#if TOUCH_CONTROLS_ALLOWED
		if (!justClicked && FlxG.touches.list.length > 0)
		{
			for (touch in FlxG.touches.list)
			{
				if (touch.justPressed)
				{
					justClicked = true;
					break;
				}
			}
		}
		#end

		if (justClicked)
		{
			var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
			var barY:Int = SEARCH_BAR_MARGIN;
			var mx:Float = FlxG.mouse.screenX;
			var my:Float = FlxG.mouse.screenY;

			#if TOUCH_CONTROLS_ALLOWED
			for (touch in FlxG.touches.list)
			{
				if (touch.justPressed)
				{
					mx = touch.screenX;
					my = touch.screenY;
					break;
				}
			}
			#end

			if (mx >= barX && mx <= barX + SEARCH_BAR_WIDTH && my >= barY && my <= barY + SEARCH_BAR_HEIGHT)
			{
				if (!searchOpen)
					openSearchBar();
				return true;
			}
			if (searchOpen && dropdownBG.alpha > 0.5)
			{
				var dropStartY:Float = dropdownBG.y + 5;
				if (mx >= barX && mx <= barX + SEARCH_BAR_WIDTH && my >= dropdownBG.y && my <= dropdownBG.y + dropdownBG.height)
				{
					var clickedIndex:Int = Std.int((my - dropStartY) / DROPDOWN_ITEM_HEIGHT) + dropdownScrollOffset;
					if (clickedIndex >= 0 && clickedIndex < dropdownItems.length)
					{
						if (dropdownItems[clickedIndex].type == SONG)
						{
							dropdownSelected = clickedIndex;
							selectDropdownItem();
							return true;
						}
					}
				}
			}
			if (searchOpen)
			{
				closeSearchBar();
				return true;
			}
		}
		return false;
	}

	function onKeyDown(e:KeyboardEvent):Void
	{
		if (!searchInputActive)
			return;

		var key = e.keyCode;

		if (key == 27)
		{
			closeSearchBar();
			return;
		}

		if (key == 13)
		{
			if (dropdownSelected >= 0 && dropdownSelected < dropdownItems.length && dropdownItems[dropdownSelected].type == SONG)
				selectDropdownItem();
			else
				closeSearchBar();
			return;
		}

		if (key == 38)
		{
			navigateDropdown(-1);
			return;
		}

		if (key == 40)
		{
			navigateDropdown(1);
			return;
		}

		if (e.charCode == 0)
			return;
		if (key == 46)
			return;

		if (key == 8)
		{
			searchString = searchString.substring(0, searchString.length - 1);
			updateSearchBarDisplay();
			buildDropdownItems();
			dropdownScrollOffset = 0;
			refreshDropdownVisuals();
			applySearchFilter();
			return;
		}

		var newText:String = String.fromCharCode(e.charCode);

		if (key == 86 && e.ctrlKey)
		{
			var clipText = Clipboard.text;
			if (clipText != null && clipText.length > 0)
				newText = clipText;
		}

		if (newText.length > 0)
		{
			searchString += newText;
			updateSearchBarDisplay();
			buildDropdownItems();
			dropdownScrollOffset = 0;
			refreshDropdownVisuals();
			applySearchFilter();
		}
	}

	function applySearchFilter():Void
	{
		if (searchString.length > 0)
		{
			// onlyIfChanged=true: sonuç aynıysa capsule'ları yeniden kurma
			// (arama yazarken her tuşta komple yeniden üretim yavaşlatıyordu)
			generateSongList({filterType: STARTSWITH, filterData: searchString.toLowerCase()}, true, true, true);
		}
		else
		{
			generateSongList(currentFilter, true, true);
		}
	}

	public static function addToRecentlyPlayed(songName:String):Void
	{
		var lowerName:String = songName.toLowerCase();
		recentlyPlayed.remove(lowerName);
		recentlyPlayed.push(lowerName);
		while (recentlyPlayed.length > 10)
			recentlyPlayed.shift();
	}

	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
			vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if (opponentVocals != null)
			opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	var currentFilter:SongFilter = null;
	var currentFilteredSongs:Array<FreeplaySongData> = [];

	public function generateSongList(filterStuff:Null<SongFilter>, force:Bool = false, onlyIfChanged:Bool = true, ?skipDiffFilter:Bool = false):Void
	{
		var tempSongs:Array<Null<FreeplaySongData>> = songs;

		if (filterStuff != null)
			tempSongs = sortSongs(tempSongs, filterStuff);

		if (currentDifficulty != null && !skipDiffFilter)
		{
			tempSongs = tempSongs.filter(song ->
			{
				if (song == null || song.isCategoryHeader)
					return true;
				return song.songDifficulties.contains(currentDifficulty);
			});
		}

		tempSongs = FreeplayHelpers.withCategoryHeaders(tempSongs, searchString);

		if (onlyIfChanged)
		{
			if (tempSongs.isEqualUnordered(currentFilteredSongs))
				return;
		}

		if (grpCapsules != null && curCapsule != null && curCapsule.songData != null
			&& !curCapsule.isCategoryHeader && !curCapsule.songData.isCategoryHeader)
			rememberedSongId = curCapsule.songData.songId ?? rememberedSongId;

		currentFilter = filterStuff;
		currentFilteredSongs = tempSongs;
		curSelected = 0;
		curSelectedFractal = 0;

		grpCapsules.generateFullSongList(tempSongs, currentDifficulty, difficultyLastChange > 0 ? SLIDE_RIGHT : SLIDE_LEFT,
			fromCharSelect ? SLIDE_LEFT : JUMPIN_FORCE);

		rememberSelection();

		changeSelection();
		changeDiff(0);
		grpCapsules.setInitialAnimPosition();
	}

	// Regex karakter sınıfı ([...]) içinde güvenli hale getirme.
	// filterData kullanıcı girdisi olabileceği için özel karakterler kaçırılır.
	// NOT: backslash kaçışı EN SON yapılmalı — yoksa diğer kaçışlar bozulur.
	static function escapeRegexClass(input:String):String
	{
		if (input == null || input.length == 0)
			return '';
		var escaped:String = input;
		escaped = escaped.replace('[', '\\[');
		escaped = escaped.replace(']', '\\]');
		escaped = escaped.replace('^', '\\^');
		escaped = escaped.replace('-', '\\-');
		escaped = escaped.replace('\\', '\\\\');
		return escaped;
	}

	public function sortSongs(songsToFilter:Array<Null<FreeplaySongData>>, songFilter:SongFilter):Array<Null<FreeplaySongData>>
	{
		var filterAlphabetically = function(a:Null<FreeplaySongData>, b:Null<FreeplaySongData>):Int
		{
			return SortUtil.alphabetically(a?.songName ?? '', b?.songName ?? '');
		};

		switch (songFilter.filterType)
		{
			case REGEXP:
				// filterData kullanıcı girdisi olabilir ([, \, ] içerebilir) —
				// EReg çökerterek oyunu kilitlemesin diye kaçış + try/catch.
				var rawFilter:String = songFilter.filterData != null ? Std.string(songFilter.filterData) : "";
				var safeFilter:String = escapeRegexClass(rawFilter);

				try
				{
					var filterRegexp:EReg = new EReg('^[' + safeFilter + '].*', 'i');
					songsToFilter = songsToFilter.filter(str ->
					{
						if (str == null)
							return true;
						return filterRegexp.match(str.songName);
					});
				}
				catch (e:Dynamic)
				{
					// Geçersiz regex → filtreyi güvenli şekilde atla
					trace('[FreeplayState] Geçersiz REGEXP filtresi: "$rawFilter" — ${Std.string(e)}');
				}
				songsToFilter.sort(filterAlphabetically);

			case STARTSWITH:
				var term:String = (songFilter.filterData ?? '').toLowerCase().replace('-', ' ');
				songsToFilter = songsToFilter.filter(str ->
				{
					if (str == null || str.isCategoryHeader)
						return true;
					return str.songName.toLowerCase().replace('-', ' ').contains(term);
				});

			case ALL:

			case FAVORITE:
				songsToFilter = songsToFilter.filter(str ->
				{
					if (str == null)
						return true;
					return str.isFav;
				});
				songsToFilter.sort(filterAlphabetically);

			default:
		}

		return songsToFilter;
	}

	var sparks:FlxSprite;
	var sparksADD:FlxSprite;

	function rankAnimStart(fromResults:FromResultsParams):Void
	{
		if (curCapsule == null)
		{
			busy = false;
			return;
		}
		busy = true;
		curCapsule.sparkle.alpha = 0;

		rememberedSongId = fromResults.songId;
		rememberedDifficulty = fromResults.difficultyId;
		changeSelection();
		changeDiff();

		if (fromResultsParams?.newRank == SHIT)
		{
			if (dj != null)
				dj.fistPumpLossIntro();
		}
		else
		{
			if (dj != null)
				dj.fistPumpIntro();
		}

		rankCamera.fade(0xFF000000, 0.5, true, null, true);
		if (FlxG.sound.music != null)
			FlxG.sound.music.volume = 0;
		rankBg.alpha = 0.6;

		if (fromResults.oldRank != null)
		{
			curCapsule.setFakeRanking(fromResults.oldRank);

			sparks.frames = Paths.getSparrowAtlas('freeplay/sparks');
			sparks.animation.addByPrefix('sparks', 'sparks', 24, false);
			sparks.visible = false;
			sparks.blend = BlendMode.ADD;
			sparks.setPosition(517, 134);
			sparks.scale.set(0.5, 0.5);
			add(sparks);
			sparks.cameras = [rankCamera];

			sparksADD.visible = false;
			sparksADD.frames = Paths.getSparrowAtlas('freeplay/sparksadd');
			sparksADD.animation.addByPrefix('sparks add', 'sparks add', 24, false);
			sparksADD.setPosition(498, 116);
			sparksADD.blend = BlendMode.ADD;
			sparksADD.scale.set(0.5, 0.5);
			add(sparksADD);
			sparksADD.cameras = [rankCamera];

			switch (fromResults.oldRank)
			{
				case SHIT:
					sparksADD.color = 0xFF6044FF;
				case GOOD:
					sparksADD.color = 0xFFEF8764;
				case GREAT:
					sparksADD.color = 0xFFEAF6FF;
				case EXCELLENT:
					sparksADD.color = 0xFFFDCB42;
				case PERFECT:
					sparksADD.color = 0xFFFF58B4;
				case PERFECT_GOLD:
					sparksADD.color = 0xFFFFB619;
			}
		}

		curCapsule.doLerp = false;

		originalPos.x = (CUTOUT_WIDTH * SONGS_POS_MULTI) + 320.488;
		originalPos.y = 235.6;

		curCapsule.ranking.visible = false;
		curCapsule.blurredRanking.visible = false;

		HapticUtil.increasingVibrate(Constants.MIN_VIBRATION_AMPLITUDE, Constants.MAX_VIBRATION_AMPLITUDE, 0.6);

		rankCamera.zoom = 1.85;
		FlxTween.tween(rankCamera, {"zoom": 1.8}, 0.6, {ease: FlxEase.sineIn});

		funnyCam.zoom = 1.15;
		FlxTween.tween(funnyCam, {"zoom": 1.1}, 0.6, {ease: FlxEase.sineIn});

		curCapsule.cameras = [rankCamera];
		curCapsule.initPosition((FlxG.width / 2) - (curCapsule.capsule.width / 2), (FlxG.height / 2) - (curCapsule.height / 2));

		new FlxTimer().start(0.5, _ ->
		{
			rankDisplayNew(fromResults);
		});
	}

	function rankDisplayNew(fromResults:Null<FromResultsParams>):Void
	{
		curCapsule.ranking.visible = true;
		curCapsule.blurredRanking.visible = true;
		curCapsule.ranking.scale.set(20, 20);
		curCapsule.blurredRanking.scale.set(20, 20);

		if (fromResults != null && fromResults.newRank != null)
			curCapsule.ranking.animation.play(fromResults.newRank.getFreeplayRankIconAsset(), true);

		FlxTween.tween(curCapsule.ranking, {"scale.x": 1, "scale.y": 1}, 0.1);

		if (fromResults != null && fromResults.newRank != null)
			curCapsule.blurredRanking.animation.play(fromResults.newRank.getFreeplayRankIconAsset(), true);

		FlxTween.tween(curCapsule.blurredRanking, {"scale.x": 1, "scale.y": 1}, 0.1);

		new FlxTimer().start(0.1, _ ->
		{
			if (fromResults?.oldRank != null)
			{
				curCapsule.setFakeRanking(null);
				sparks.visible = true;
				sparksADD.visible = true;
				sparks.animation.play('sparks', true);
				sparksADD.animation.play('sparks add', true);

				sparks.animation.finishCallback = anim ->
				{
					sparks.visible = false;
					sparksADD.visible = false;
				};
			}

			switch (fromResultsParams?.newRank)
			{
				case SHIT:
					FunkinSound.playOnce(Paths.sound('ranks/rankinbad'));
				case PERFECT:
					FunkinSound.playOnce(Paths.sound('ranks/rankinperfect'));
				case PERFECT_GOLD:
					FunkinSound.playOnce(Paths.sound('ranks/rankinperfect'));
				default:
					FunkinSound.playOnce(Paths.sound('ranks/rankinnormal'));
			}
			rankCamera.zoom = 1.3;

			FlxTween.tween(rankCamera, {"zoom": 1.5}, 0.3, {ease: FlxEase.backInOut});

			curCapsule.x -= 10;
			curCapsule.y -= 20;

			FlxTween.tween(funnyCam, {"zoom": 1.05}, 0.3, {ease: FlxEase.elasticOut});

			curCapsule.capsule.angle = -3;
			FlxTween.tween(curCapsule.capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});

			IntervalShake.shake(curCapsule.capsule, 0.3, 1 / 30, 0.1, 0, FlxEase.quadOut);
		});

		new FlxTimer().start(0.4, _ ->
		{
			FlxTween.tween(funnyCam, {"zoom": 1}, 0.8, {ease: FlxEase.sineIn});
			FlxTween.tween(rankCamera, {"zoom": 1.2}, 0.8, {ease: FlxEase.backIn});
			FlxTween.tween(curCapsule, {x: originalPos.x - 7, y: originalPos.y - 80}, 0.8 + 0.5, {ease: FlxEase.quartIn});
		});

		new FlxTimer().start(0.6, _ ->
		{
			rankAnimSlam(fromResults);
		});
	}

	function rankAnimSlam(fromResultsParams:Null<FromResultsParams>)
	{
		FlxTween.tween(rankBg, {alpha: 0}, 0.5, {ease: FlxEase.expoIn});

		switch (fromResultsParams?.newRank)
		{
			case SHIT:
				FunkinSound.playOnce(Paths.sound('ranks/loss'));
			case GOOD:
				FunkinSound.playOnce(Paths.sound('ranks/good'));
			case GREAT:
				FunkinSound.playOnce(Paths.sound('ranks/great'));
			case EXCELLENT:
				FunkinSound.playOnce(Paths.sound('ranks/excellent'));
			case PERFECT:
				FunkinSound.playOnce(Paths.sound('ranks/perfect'));
			case PERFECT_GOLD:
				FunkinSound.playOnce(Paths.sound('ranks/perfect'));
			default:
				FunkinSound.playOnce(Paths.sound('ranks/loss'));
		}

		FlxTween.tween(curCapsule, {"targetPos.x": originalPos.x, "targetPos.y": originalPos.y}, 0.5, {ease: FlxEase.expoOut});
		new FlxTimer().start(0.5, _ ->
		{
			HapticUtil.vibrate(Constants.DEFAULT_VIBRATION_PERIOD, Constants.DEFAULT_VIBRATION_DURATION, Constants.MAX_VIBRATION_AMPLITUDE);

			funnyCam.shake(0.0045, 0.35);

			if (fromResultsParams?.newRank == SHIT)
			{
				if (dj != null)
					dj.fistPumpLoss();
			}
			else
			{
				if (dj != null)
					dj.fistPump();
			}

			rankCamera.zoom = 0.8;
			funnyCam.zoom = 0.8;
			#if TOUCH_CONTROLS_ALLOWED
			IntervalShake.shake(touchPad, 0.6, 1 / 24, 0.24, 0, FlxEase.quadOut);
			#end
			FlxTween.tween(rankCamera, {"zoom": 1}, 1, {ease: FlxEase.elasticOut});
			FlxTween.tween(funnyCam, {"zoom": 1}, 0.8, {ease: FlxEase.elasticOut});

			for (index => capsule in grpCapsules.activeSongItems)
			{
				var distFromSelected:Float = Math.abs(index - curSelected) - 1;

				if (distFromSelected < 5)
				{
					if (index == curSelected)
					{
						FlxTween.cancelTweensOf(capsule);
						capsule.fadeAnim();

						rankVignette.color = capsule.getTrailColor();
						rankVignette.alpha = 1;
						FlxTween.tween(rankVignette, {alpha: 0}, 0.6, {ease: FlxEase.expoOut});

						capsule.doLerp = false;
						capsule.setPosition(originalPos.x, originalPos.y);
						IntervalShake.shake(capsule, 0.6, 1 / 24, 0.12, 0, FlxEase.quadOut, function(_)
						{
							capsule.doLerp = true;
							capsule.cameras = [funnyCam];
							busy = false;
							capsule.sparkle.alpha = 0.7;
							playCurSongPreview(capsule);
						}, null);

						FlxTween.tween(capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});
					}
					if (index > curSelected)
					{
						new FlxTimer().start(distFromSelected / 20, _ ->
						{
							capsule.doLerp = false;
							capsule.capsule.angle = FlxG.random.float(-10 + (distFromSelected * 2), 10 - (distFromSelected * 2));
							FlxTween.tween(capsule.capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});
							IntervalShake.shake(capsule, 0.6, 1 / 24, 0.12 / (distFromSelected + 1), 0, FlxEase.quadOut, function(_)
							{
								capsule.doLerp = true;
							});
						});
					}
					if (index < curSelected)
					{
						new FlxTimer().start(distFromSelected / 20, _ ->
						{
							capsule.doLerp = false;
							capsule.capsule.angle = FlxG.random.float(-10 + (distFromSelected * 2), 10 - (distFromSelected * 2));
							FlxTween.tween(capsule.capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});
							IntervalShake.shake(capsule, 0.6, 1 / 24, 0.12 / (distFromSelected + 1), 0, FlxEase.quadOut, function(_)
							{
								capsule.doLerp = true;
							});
						});
					}
				}
				index += 1;
			}
		});

		new FlxTimer().start(2, _ ->
		{
			prepForNewRank = false;
		});
	}

	override function closeSubState()
	{
		restoreOverlayCameras();
		var saveBox = VsliceOptions.LAST_MOD;
		if (saveBox != null && ModsHelper.isModDirEnabled(saveBox.mod_dir))
			ModsHelper.loadModDir(saveBox.mod_dir);
		else
			ModsHelper.loadModDir('');
		controls.isInSubstate = true;
		super.closeSubState();
		
		// Kamerayı ve görüşünü sıfırla ki Freeplay menüsü kafayı yemesin
		if (funnyCam != null) funnyCam.visible = true;
		if (rankCamera != null) rankCamera.visible = true;
		if (overlayCam != null) overlayCam.visible = false;

		busy = false;
		persistentUpdate = true;
		#if TOUCH_CONTROLS_ALLOWED
		#if LEGACY_PSYCH
		MusicBeatSubstate.instance = this;
		#else
		backend.MusicBeatSubstate.instance = this;
		#end
		persistentUpdate = true;
		removeTouchPad();
		addFreeplayTouchPad(true);
		addTouchPadCamera();
		blockInputFrames = 12;
		#end

		if (backend.freeplay.FreeplayCatalog.consumePendingApply())
			reloadFreeplayListing();
	}

	function reloadFreeplayListing():Void
	{
		var keepId:String = rememberedSongId;
		songs = [null];
		for (sngCard in FreeplayHelpers.loadSongs())
		{
			if (currentCharacter.shouldShowUnownedChars() || ClientPrefs.data.quickFreeplay)
			{
				if (sngCard.songPlayer != '' && sngCard.songPlayer != currentCharacterId)
					continue;
			}
			else
			{
				if (sngCard.songPlayer == '' || sngCard.songPlayer != currentCharacterId)
					continue;
			}
			songs.push(sngCard);
		}
		rememberedSongId = keepId;
		generateSongList(currentFilter, true, false);
	}

	function toggleCategoryHeader(cap:SongMenuItem):Void
	{
		if (cap == null || cap.songData == null)
			return;
		var id:String = cap.songData.categoryId;
		backend.freeplay.FreeplayCatalog.toggleCollapsed(id);
		FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
		generateSongList(currentFilter, true, false);
		for (i in 0...grpCapsules.activeSongItems.length)
		{
			var item = grpCapsules.activeSongItems[i];
			if (item != null && item.songData != null && item.songData.isCategoryHeader && item.songData.categoryId == id)
			{
				curSelected = i;
				curSelectedFractal = i;
				break;
			}
		}
		changeSelection(0);
	}

	public function openOverlaySubState(sub:FlxSubState):Void
	{
		if (sub == null)
			return;

		if (funnyCam != null)
			funnyCam.visible = false;
		if (rankCamera != null)
			rankCamera.visible = false;

		if (overlayCam != null)
		{
			overlayCam.visible = true;
			overlayCam.scroll.set();
			sub.cameras = [overlayCam];
		}

		openSubState(sub);

		if (sub.members != null)
		{
			for (member in sub.members)
				assignOverlayCamera(member);
		}
	}

	function assignOverlayCamera(obj:FlxBasic):Void
	{
		if (obj == null || overlayCam == null)
			return;

		if (Std.isOfType(obj, FlxObject))
		{
			var spr:FlxObject = cast obj;
			var cams = spr.cameras;
			if (cams != null && cams.length == 1)
			{
				var cam = cams[0];
				if (cam != null && cam != FlxG.camera && cam != funnyCam && cam != rankCamera && cam != overlayCam)
					return;
			}
			spr.cameras = [overlayCam];
		}

		var members:Array<Dynamic> = Reflect.field(obj, 'members');
		if (members != null)
		{
			for (child in members)
			{
				if (Std.isOfType(child, FlxBasic))
					assignOverlayCamera(cast child);
			}
		}
	}

	function restoreOverlayCameras():Void
	{
		if (funnyCam != null)
			funnyCam.visible = true;
		if (rankCamera != null)
			rankCamera.visible = true;
		if (overlayCam != null)
		{
			overlayCam.scroll.set();
			overlayCam.visible = true;
		}
	}

	function openFreeplaySettings():Void
	{
		if (busy || searchOpen)
			return;
		ModsHelper.loadModDir('');
		persistentUpdate = false;
		busy = true;
		#if TOUCH_CONTROLS_ALLOWED
		removeTouchPad();
		#end
		openOverlaySubState(new options.FreeplaySettingsSubState());
	}

	function tryOpenCharSelect():Void
	{
		trace('Is Pico unlocked? ${PlayerRegistry.instance.fetchEntry('pico')?.isUnlocked()}');
		trace('Number of characters: ${PlayerRegistry.instance.countUnlockedCharacters()}');

		if (PlayerRegistry.instance.countUnlockedCharacters() > 1)
		{
			trace('Opening character select!');
		}
		else
		{
			trace('Not enough characters unlocked to open character select!');
			FunkinSound.playOnce(Paths.sound('cancelMenu'));
			return;
		}

		busy = true;
		FunkinSound.playOnce(Paths.sound('confirmMenu'));

		if (dj != null)
			dj.toCharSelect();

		var transitionDelay:Float = currentCharacter.getFreeplayDJData()?.getCharSelectTransitionDelay() ?? 0.25;

		new FlxTimer().start(transitionDelay, _ ->
		{
			transitionToCharSelect();
		});
	}

	function transitionToCharSelect():Void
	{
		var transitionGradient = new FlxSprite(0, 720).loadGraphic(Paths.image('freeplay/transitionGradient'));
		transitionGradient.scale.set(1280, 1);
		transitionGradient.updateHitbox();
		transitionGradient.cameras = [rankCamera];
		exitMoversCharSel.set([transitionGradient], {
			y: -720,
			speed: 0.8,
			wait: 0.1
		});
		add(transitionGradient);
		for (index => capsule in grpCapsules.activeSongItems)
		{
			var distFromSelected:Float = Math.abs(index - curSelected) - 1;
			if (distFromSelected < 5)
			{
				capsule.doLerp = false;
				exitMoversCharSel.set([capsule], {
					y: -250,
					speed: 0.8,
					wait: 0.1
				});
			}
		}
		funnyCam.filtersEnabled = true;

		fadeShader.fade(1.0, 0.0, 0.8, {ease: FlxEase.quadIn});
		FlxG.sound.music?.fadeOut(0.9, 0);
		new FlxTimer().start(0.9, _ ->
		{
			FlxG.switchState(new CharSelectSubState());
		});
		for (grpSpr in exitMoversCharSel.keys())
		{
			var moveData:Null<MoveData> = exitMoversCharSel.get(grpSpr);
			if (moveData == null)
				continue;

			for (spr in grpSpr)
			{
				if (spr == null)
					continue;

				var funnyMoveShit:MoveData = moveData;
				var moveDataY = funnyMoveShit.y ?? spr.y;
				var moveDataSpeed = funnyMoveShit.speed ?? 0.2;

				FlxTween.tween(spr, {y: moveDataY + spr.y}, moveDataSpeed, {ease: FlxEase.backIn});
			}
		}
		#if TOUCH_CONTROLS_ALLOWED
		FlxTween.tween(touchPad, {alpha: 0}, 0.6, {ease: FlxEase.backIn});
		#end
		backingCard?.enterCharSel();
	}

	function enterFromCharSel():Void
	{
		busy = true;
		if (_parentState != null)
			_parentState.persistentDraw = false;

		var transitionGradient = new FlxSprite(0, 720).loadGraphic(Paths.image('freeplay/transitionGradient'));
		transitionGradient.scale.set(1280, 1);
		transitionGradient.updateHitbox();
		transitionGradient.cameras = [rankCamera];
		exitMoversCharSel.set([transitionGradient], {
			y: -720,
			speed: 1.5,
			wait: 0.1
		});
		add(transitionGradient);
		changeDiff(0, true);

		funnyCam.filtersEnabled = true;
		fadeShader.fade(0.0, 1.0, 0.8, {ease: FlxEase.quadIn, onComplete: (twn) -> funnyCam.filtersEnabled = false});
		for (grpSpr in exitMoversCharSel.keys())
		{
			var moveData:Null<MoveData> = exitMoversCharSel.get(grpSpr);
			if (moveData == null)
				continue;

			for (spr in grpSpr)
			{
				if (spr == null)
					continue;

				var funnyMoveShit:MoveData = moveData;
				var moveDataY = funnyMoveShit.y ?? spr.y;
				var moveDataSpeed = funnyMoveShit.speed ?? 0.2;

				spr.y += moveDataY;
				FlxTween.tween(spr, {y: spr.y - moveDataY}, moveDataSpeed * 1.2, {
					ease: FlxEase.expoOut,
					onComplete: function(_)
					{
						for (index => capsule in grpCapsules.activeSongItems)
						{
							capsule.doLerp = true;
							fromCharSelect = false;
							busy = false;
							albumRoll.applyExitMovers(exitMovers, exitMoversCharSel);
						}
					}
				});
			}
			#if TOUCH_CONTROLS_ALLOWED
			touchPad.alpha = 0;
			#if LEGACY_PSYCH
			FlxTween.tween(touchPad, {alpha: ClientPrefs.controlsAlpha}, 0.8, {ease: FlxEase.backIn});
			#else
			FlxTween.tween(touchPad, {alpha: ClientPrefs.data.controlsAlpha}, 0.8, {ease: FlxEase.backIn});
			#end
			#end
		}
	}

	var touchY:Float = 0;
	var touchX:Float = 0;
	var dxTouch:Float = 0;
	var dyTouch:Float = 0;
	var velTouch:Float = 0;
	var touchTimer:Float = 0;
	var initTouchPos:FlxPoint = new FlxPoint();
	var spamTimer:Float = 0;
	var spamming:Bool = false;
	public var busy:Bool = false;
	var originalPos:FlxPoint = new FlxPoint();
	var hintTimer:Float = 0;

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (blockInputFrames > 0)
		{
			if (controls.BACK || (touchPad != null && touchPad.buttonB != null && touchPad.buttonB.pressed))
				return;
			blockInputFrames--;
			return;
		}

		if (charSelectHint != null)
		{
			hintTimer += elapsed * 2;
			var targetAmt:Float = (Math.sin(hintTimer) + 1) / 2;
			charSelectHint.alpha = FlxMath.lerp(0.3, 0.9, targetAmt);
		}

		if (searchOpen)
		{
			cursorTimer += elapsed;
			if (cursorTimer >= 0.5)
			{
				cursorTimer = 0;
				searchBarCursor.visible = !searchBarCursor.visible;
			}
		}

		checkSearchBarClick();

		if (searchOpen && FlxG.mouse.wheel != 0)
		{
			dropdownScrollOffset -= FlxG.mouse.wheel;
			dropdownScrollOffset = Std.int(FlxMath.bound(dropdownScrollOffset, 0, Math.max(0, dropdownItems.length - dropdownMaxVisible)));
			refreshDropdownVisuals();
		}

		if (searchInputActive)
		{
			var mobileUp:Bool = false;
			var mobileDown:Bool = false;
			var mobileAccept:Bool = false;
			var mobileBack:Bool = false;
			var mobileSearchClose:Bool = false;

			#if TOUCH_CONTROLS_ALLOWED
			if (touchPad != null)
			{
				mobileUp = touchPad.buttonUp.justPressed;
				mobileDown = touchPad.buttonDown.justPressed;
				mobileAccept = touchPad.buttonA.justPressed;
				mobileBack = touchPad.buttonB.justPressed;
				mobileSearchClose = touchPad.buttonX.justPressed;
			}
			#end

			if (controls.UI_UP_P || mobileUp)
				navigateDropdown(-1);

			if (controls.UI_DOWN_P || mobileDown)
				navigateDropdown(1);

			if (controls.ACCEPT || mobileAccept)
			{
				if (dropdownSelected >= 0 && dropdownSelected < dropdownItems.length
					&& dropdownItems[dropdownSelected].type == SONG)
					selectDropdownItem();
				else
					closeSearchBar();
			}

			if (controls.BACK || mobileBack || mobileSearchClose)
			{
				closeSearchBar();
				lerpScoreDisplays(elapsed);
				return;
			}

			lerpScoreDisplays(elapsed);
			return;
		}

		#if FEATURE_DEBUG_FUNCTIONS
		if (FlxG.keys.justPressed.T)
		{
			rankAnimStart(fromResultsParams ?? {
				playRankAnim: true,
				newRank: PERFECT_GOLD,
				songId: "tutorial",
				oldRank: SHIT,
				difficultyId: "hard"
			});
		}
		if (FlxG.keys.justPressed.Y)
		{
			rankAnimStart(fromResultsParams ?? {
				playRankAnim: true,
				newRank: PERFECT_GOLD,
				songId: "tutorial",
				difficultyId: "hard"
			});
		}
		if (FlxG.keys.justPressed.H)
			rankDisplayNew(fromResultsParams);
		if (FlxG.keys.justPressed.G)
			rankAnimSlam(fromResultsParams);
		#end

		if (!busy)
		{
			if (!searchOpen && (FlxG.keys.justPressed.ALT #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonP.justPressed #end))
			{
				openFreeplaySettings();
			}
			else if (FunkinControls.FREEPLAY_CHAR #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonZ.justPressed #end)
			{
				tryOpenCharSelect();
			}
			else if (FlxG.keys.justPressed.CONTROL #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonC.justPressed #end)
			{
				ModsHelper.loadModDir('');
				persistentUpdate = false;
				busy = true;
				#if TOUCH_CONTROLS_ALLOWED
				removeTouchPad();
				#end
				openOverlaySubState(new GameplayChangersSubstate());
			}
			else if ((controls.RESET #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonY.justPressed #end) && curSelected != 0
				&& curCapsule != null && curCapsule.songData != null && !curCapsule.isCategoryHeader && !curCapsule.songData.isCategoryHeader)
			{
				persistentUpdate = false;
				var curSng = curCapsule;
				#if TOUCH_CONTROLS_ALLOWED
				removeTouchPad();
				#end
				FreeplayHelpers.openResetScoreState(this, curSng.songData, () ->
				{
					curSng.songData.scoringRank = null;
					intendedScore = 0;
					intendedCompletion = 0;
					curSng.songData.updateIsNewTag();
					curSng.refreshDisplayDifficulty();
				});
				FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
			}
			else if (!searchOpen && (
				FlxG.keys.justPressed.C
				#if TOUCH_CONTROLS_ALLOWED
				|| (touchPad != null && touchPad.buttonX.justPressed)
				#end
			))
			{
				openSearchBar();
			}
		}

		if ((controls.FAVORITE #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonF.justPressed #end) && !busy)
		{
			var targetSong = curCapsule?.songData;
			if (targetSong != null && !targetSong.isCategoryHeader && (curCapsule == null || !curCapsule.isCategoryHeader))
			{
				var realShit:Int = curSelected;
				var isFav = targetSong.toggleFavorite();
				if (isFav)
				{
					curCapsule.favIcon.visible = true;
					curCapsule.favIconBlurred.visible = true;
					curCapsule.favIcon.animation.play('fav');
					curCapsule.favIconBlurred.animation.play('fav');
					FunkinSound.playOnce(Paths.sound('fav'), 1);
					curCapsule.checkClip();
					curCapsule.selected = curCapsule.selected;
					busy = true;

					curCapsule.doLerp = false;
					FlxTween.tween(curCapsule, {y: curCapsule.y - 5}, 0.1, {ease: FlxEase.expoOut});
					FlxTween.tween(curCapsule, {y: curCapsule.y + 5}, 0.1, {
						ease: FlxEase.expoIn,
						startDelay: 0.1,
						onComplete: function(_)
						{
							curCapsule.doLerp = true;
							busy = false;
						}
					});
				}
				else
				{
					curCapsule.favIcon.animation.play('fav', true, true, 9);
					curCapsule.favIconBlurred.animation.play('fav', true, true, 9);
					FunkinSound.playOnce(Paths.sound('unfav'), 1);
					new FlxTimer().start(0.2, _ ->
					{
						curCapsule.favIcon.visible = false;
						curCapsule.favIconBlurred.visible = false;
						curCapsule.checkClip();
					});

					busy = true;
					curCapsule.doLerp = false;
					FlxTween.tween(curCapsule, {y: curCapsule.y + 5}, 0.1, {ease: FlxEase.expoOut});
					FlxTween.tween(curCapsule, {y: curCapsule.y - 5}, 0.1, {
						ease: FlxEase.expoIn,
						startDelay: 0.1,
						onComplete: function(_)
						{
							curCapsule.doLerp = true;
							busy = false;
						}
					});
				}
			}
		}

		if (FlxG.keys.justPressed.HOME && !busy)
			changeSelection(-curSelected);

		if (FlxG.keys.justPressed.END && !busy)
			changeSelection(grpCapsules.countLiving() - curSelected - 1);

		lerpScoreDisplays(elapsed);
		handleInputs(elapsed);

		#if debug
		if (dj != null)
			FlxG.watch.addQuick('dj-anim', dj.getCurrentAnimation());
		#end
	}

	var lastShownScore:Int = -1;
	var lastShownCompletion:Int = -1;

	function lerpScoreDisplays(elapsed:Float):Void
	{
		lerpScore = MathUtil.smoothLerp(lerpScore, intendedScore, elapsed, 0.5);
		lerpCompletion = MathUtil.smoothLerp(lerpCompletion, intendedCompletion, elapsed, 0.5);

		if (Math.isNaN(lerpScore))
			lerpScore = intendedScore;
		if (Math.isNaN(lerpCompletion))
			lerpCompletion = intendedCompletion;

		// Değer değişmediyse her frame UI güncellemesi yapma (string alloc + hitbox yenileme)
		var scoreInt:Int = Std.int(lerpScore);
		var completionInt:Int = Math.floor(lerpCompletion * 100);

		if (scoreInt != lastShownScore)
		{
			lastShownScore = scoreInt;
			fp.updateScore(scoreInt);
		}

		if (completionInt != lastShownCompletion)
		{
			lastShownCompletion = completionInt;

			txtCompletion.text = '${completionInt}';

			switch (txtCompletion.text.length)
			{
				case 3:
					txtCompletion.offset.x = 10;
				case 2:
					txtCompletion.offset.x = 0;
				case 1:
					txtCompletion.offset.x = -24;
				default:
					txtCompletion.offset.x = 0;
			}
		}
	}

	function handleInputs(elapsed:Float):Void
	{
		if (busy)
			return;

		var upP:Bool = controls.UI_UP_P #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonUp.justPressed #end;
		var downP:Bool = controls.UI_DOWN_P #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonDown.justPressed #end;
		var accepted:Bool = controls.ACCEPT #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonA.justPressed #end;
		var up = controls.UI_UP #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonUp.pressed #end;
		var down = controls.UI_DOWN #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonDown.pressed #end;

		var shiftMult:Int = 1;
		if (FlxG.keys.pressed.SHIFT #if TOUCH_CONTROLS_ALLOWED || (touchPad != null && touchPad.buttonZ.pressed) #end)
			shiftMult = 3;

		if ((up || down))
		{
			if (spamming)
			{
				if (spamTimer >= 0.07)
				{
					spamTimer = 0;
					if (up)
						changeSelection(-1 * shiftMult);
					else
						changeSelection(1 * shiftMult);
				}
			}
			else if (spamTimer >= 0.9)
			{
				spamming = true;
			}
			else if (spamTimer <= 0)
			{
				if (up)
					changeSelection(-1 * shiftMult);
				else
					changeSelection(1 * shiftMult);
			}

			spamTimer += elapsed;
			if (dj != null)
				dj.resetAFKTimer();
		}
		else
		{
			spamming = false;
			spamTimer = 0;
		}

		#if !html5
		if (FlxG.mouse.wheel != 0 && !searchOpen)
		{
			if (dj != null)
				dj.resetAFKTimer();
			changeSelection(-Math.round(FlxG.mouse.wheel) * shiftMult);
		}
		#else
		if (FlxG.mouse.wheel < 0 && !searchOpen)
		{
			if (dj != null)
				dj.resetAFKTimer();
			changeSelection(-Math.round(FlxG.mouse.wheel / 8) * shiftMult);
		}
		else if (FlxG.mouse.wheel > 0 && !searchOpen)
		{
			if (dj != null)
				dj.resetAFKTimer();
			changeSelection(-Math.round(FlxG.mouse.wheel / 8) * shiftMult);
		}
		#end

		var leftDiff:Bool = controls.UI_LEFT_P
			#if TOUCH_CONTROLS_ALLOWED
			|| (touchPad != null && touchPad.buttonLeft.justPressed)
			#end;

		var rightDiff:Bool = controls.UI_RIGHT_P
			#if TOUCH_CONTROLS_ALLOWED
			|| (touchPad != null && touchPad.buttonRight.justPressed)
			#end;

		if (leftDiff || (TouchUtil.overlapsComplex(diffSelLeft) && TouchUtil.justPressed))
		{
			if (dj != null)
				dj.resetAFKTimer();
			changeDiff(-1);
			rememberedDifficulty = currentDifficulty;
			if (diffSelLeft != null)
				diffSelLeft.setPress(true);
		}
		else if (rightDiff || (TouchUtil.overlapsComplex(diffSelRight) && TouchUtil.justPressed))
		{
			if (dj != null)
				dj.resetAFKTimer();
			changeDiff(1);
			rememberedDifficulty = currentDifficulty;
			if (diffSelRight != null)
				diffSelRight.setPress(true);
		}

		if (diffSelLeft != null && diffSelRight != null && TouchUtil.justReleased)
		{
			diffSelRight.setPress(false);
			diffSelLeft.setPress(false);
		}

		if (controls.BACK #if TOUCH_CONTROLS_ALLOWED || touchPad?.buttonB.justPressed #end && !busy)
		{
			if (searchOpen)
			{
				closeSearchBar();
				return;
			}

			if (searchString.length > 0)
			{
				searchString = '';
				updateSearchBarDisplay();
				generateSongList(null, true);
				FunkinSound.playOnce(Paths.sound('cancelMenu'));
				return;
			}

			busy = true;
			FlxTween.globalManager.clear();
			FlxTimer.globalManager.clear();
			if (dj != null)
				dj.onIntroDone.removeAll();

			FunkinSound.playOnce(Paths.sound('cancelMenu'));
			FreeplayHelpers.exitFreeplay();

			var longestTimer:Float = 0;

			backingCard?.disappear();

			#if TOUCH_CONTROLS_ALLOWED
			if (touchPad != null)
			{
				touchPad.forEachAlive(function(button:TouchButton)
				{
					if (isDirectionalTouchButton(button))
						FlxTween.tween(button, {x: button.x - 350}, 1.2, {ease: FlxEase.backOut});
					else
						FlxTween.tween(button, {x: button.x + 450}, 1.2, {ease: FlxEase.backOut});
				});
			}
			#end

			for (grpSpr in exitMovers.keys())
			{
				var moveData:Null<MoveData> = exitMovers.get(grpSpr);
				if (moveData == null)
					continue;

				for (spr in grpSpr)
				{
					if (spr == null)
						continue;

					var funnyMoveShit:MoveData = moveData;
					var moveDataX = funnyMoveShit.x ?? spr.x;
					var moveDataY = funnyMoveShit.y ?? spr.y;
					var moveDataSpeed = funnyMoveShit.speed ?? 0.2;

					FlxTween.tween(spr, {x: moveDataX, y: moveDataY}, moveDataSpeed, {ease: FlxEase.expoIn});
					longestTimer = Math.max(longestTimer, moveDataSpeed);
				}
			}

			for (caps in grpCapsules.activeSongItems)
				caps.playJumpOut();

			new FlxTimer().start(longestTimer, (_) ->
			{
				funnyCam.fade(FlxColor.BLACK, 0.4, false, function()
				{
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					if (MenuStyleRouter.isNewStyle())
					{
						controls.isInSubstate = true;
						persistentUpdate = true;
						persistentDraw = true;

						openSubState(new StickerSubState(null, function(sticker:StickerSubState)
						{
							return cast new vslice.menus.states.MainMenuState(sticker);
						}));
					}
					else
					{
						FlxTransitionableState.skipNextTransIn = false;
						FlxTransitionableState.skipNextTransOut = false;
						controls.isInSubstate = false;
						FlxG.switchState(MenuStyleRouter.getMainMenu());
					}
				});
			});
		}
		else if (accepted)
		{
			curCapsule.onConfirm();
		}
	}

	override function beatHit()
	{
		backingCard?.beatHit(curBeat);
		super.beatHit();
	}

	public override function destroy():Void
	{
		controls.isInSubstate = false;

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		// super.destroy()'dan ÖNCE ihtiyaç duyulan verileri al
		var daSong:Null<FreeplaySongData> = (curSelected >= 0 && curSelected < currentFilteredSongs.length) ? currentFilteredSongs[curSelected] : null;
		var camToRemove:FunkinCamera = funnyCam;
		var rankCamToRemove:FunkinCamera = rankCamera;
		var overlayCamToRemove:FunkinCamera = overlayCam;

		instance = null;

		super.destroy();

		if (daSong != null)
			clearDaCache(daSong.songName);

		// Hem funnyCam hem rankCamera kaldırılmalı — aksi halde kamera birikir
		if (camToRemove != null)
			FlxG.cameras.remove(camToRemove);
		if (rankCamToRemove != null)
			FlxG.cameras.remove(rankCamToRemove);
		if (overlayCamToRemove != null)
			FlxG.cameras.remove(overlayCamToRemove);
	}

	var difficultyLastChange:Int = 0;
	
	var _diffAnimTimer:Null<FlxTimer> = null;
	var _diffAnimToken:Int = 0;
	
	static final _difficultySpriteCache:Map<String, Bool> = [];

	function hasDifficultySprite(diffId:String):Bool
	{
		if (diffId == null || diffId.length < 1)
			return false;

		// Türkçe zorluk adlarını İngilizce sprite dosyasına eşle:
		// "kolay" → freeplay-easy, "zor" → freeplay-hard ...
		var spriteId:String = backend.Difficulty.getSpriteDiffId(diffId);

		// Aynı diff için Paths.image'ı tekrar tekrar deneme — sonucu cache'le
		if (_difficultySpriteCache.exists(spriteId))
			return _difficultySpriteCache.get(spriteId);

		var found:Bool = false;
		try
		{
			found = Paths.image('freeplay/freeplayDifficulties/freeplay' + spriteId) != null;
		}
		catch (e:Dynamic) {}

		_difficultySpriteCache.set(spriteId, found);
		return found;
	}

	function getDifficultySpriteById(diffId:String):Null<DifficultySprite>
	{
		if (grpDifficulties == null || grpDifficulties.group == null || diffId == null)
			return null;

		// Türkçe adlar da İngilizce sprite'larla eşleşsin:
		// "zor" → spriteDiffId "hard" olan sprite bulunur
		var wantedSpriteId:String = backend.Difficulty.getSpriteDiffId(diffId);

		for (diffSprite in grpDifficulties.group.members)
		{
			if (diffSprite != null && diffSprite.spriteDiffId == wantedSpriteId)
				return diffSprite;
		}

		return null;
	}

	function getUsableDifficultyList():Array<String>
	{
		var result:Array<String> = [];

		var source:Array<String> = null;

		if (curCapsule != null && curCapsule.songData != null && !curCapsule.isCategoryHeader
			&& !curCapsule.songData.isCategoryHeader
			&& curCapsule.songData.songDifficulties != null && curCapsule.songData.songDifficulties.length > 0)
			source = curCapsule.songData.songDifficulties.copy();
		else
			source = diffIdsTotal.copy();

		for (diff in source)
		{
			if (diff != null && diff.length > 0 && !result.contains(diff) && hasDifficultySprite(diff))
				result.push(diff);
		}

		if (result.length == 0)
		{
			for (diff in diffIdsTotal)
			{
				if (diff != null && diff.length > 0 && !result.contains(diff) && hasDifficultySprite(diff))
					result.push(diff);
			}
		}

		if (result.length == 0)
			result.push(Constants.DEFAULT_DIFFICULTY);

		return result;
	}

	function changeDiff(change:Int = 0, forceUpdateSongList:Bool = false):Void
	{
		touchTimer = 0;
		difficultyLastChange = change;

		diffIdsCurrent = getUsableDifficultyList();

		if (diffIdsCurrent == null || diffIdsCurrent.length == 0)
		{
			currentDifficulty = Constants.DEFAULT_DIFFICULTY;
			intendedScore = 0;
			intendedCompletion = 0;
			busy = false;
			return;
		}

		if (!diffIdsCurrent.contains(currentDifficulty))
		{
			if (rememberedDifficulty != null && diffIdsCurrent.contains(rememberedDifficulty))
				currentDifficulty = rememberedDifficulty;
			else
				currentDifficulty = diffIdsCurrent[0];
		}

		var currentDifficultyIndex:Int = diffIdsCurrent.indexOf(currentDifficulty);
		if (currentDifficultyIndex < 0)
			currentDifficultyIndex = 0;

		currentDifficultyIndex += change;

		while (currentDifficultyIndex < 0)
			currentDifficultyIndex += diffIdsCurrent.length;
		while (currentDifficultyIndex >= diffIdsCurrent.length)
			currentDifficultyIndex -= diffIdsCurrent.length;

		var previousDifficulty:String = currentDifficulty;
		var nextDifficulty:String = diffIdsCurrent[currentDifficultyIndex];

		if (nextDifficulty == null || nextDifficulty.length < 1)
			nextDifficulty = previousDifficulty != null ? previousDifficulty : diffIdsCurrent[0];

		var didDifficultyChange:Bool = previousDifficulty != nextDifficulty;
		var token:Int = ++_diffAnimToken;

		if (_diffAnimTimer != null)
		{
			_diffAnimTimer.cancel();
			_diffAnimTimer = null;
		}

		if (didDifficultyChange)
		{
			busy = true;
			swipeDiffSprById(previousDifficulty, false, change, token);
		}

		if (change != 0)
		{
			HapticUtil.vibrate(0, 0.01, 0.5, 0.1);
			FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
		}

		currentDifficulty = nextDifficulty;

		var daSong:Null<FreeplaySongData> = curCapsule != null ? curCapsule.songData : null;
		if (daSong != null)
		{
			daSong.currentDifficulty = currentDifficulty;
			var diffId = daSong.loadAndGetDiffId();
			var songScore:Int = Highscore.getScore(daSong.getNativeSongId(), diffId);

			intendedScore = songScore ?? 0;
			intendedCompletion = Highscore.getRating(daSong.getNativeSongId(), diffId);
		}
		else
		{
			intendedScore = 0;
			intendedCompletion = 0.0;
		}

		rememberedDifficulty = currentDifficulty;

		if (intendedCompletion == Math.POSITIVE_INFINITY || intendedCompletion == Math.NEGATIVE_INFINITY || Math.isNaN(intendedCompletion))
			intendedCompletion = 0;

		if (didDifficultyChange)
			swipeDiffSprById(currentDifficulty, true, change, token);
		else
			busy = false;

		if (change != 0 || forceUpdateSongList)
			updateCapsuleDifficulties();

		var newAlbumId:Null<String> = daSong?.albumId;
		if (albumRoll != null && albumRoll.albumId != newAlbumId)
		{
			albumRoll.albumId = newAlbumId;
			albumRoll.skipIntro();
		}
		albumRoll?.setDifficultyStars(daSong?.difficultyRating);
	}

	function updateCapsuleDifficulties()
	{
		if (grpCapsules == null)
			return;
		var tempSongs:Array<Null<FreeplaySongData>> = songs;

		if (currentFilter != null)
			tempSongs = sortSongs(tempSongs, currentFilter);

		if (currentDifficulty != null)
		{
			tempSongs = tempSongs.filter(song ->
			{
				if (song == null || song.isCategoryHeader)
					return true;
				return song.songDifficulties.contains(currentDifficulty);
			});
		}
		tempSongs = FreeplayHelpers.withCategoryHeaders(tempSongs, searchString);
		var areSongsTheSame = tempSongs.isEqualUnordered(currentFilteredSongs);

		if (areSongsTheSame)
			grpCapsules.updateSongDifficulties(currentDifficulty);
		else
			generateSongList(currentFilter, true);
	}

	function swipeDiffSprById(diffId:String, transIn:Bool, change:Int, token:Int):Void
	{
		var diffSprite = getDifficultySpriteById(diffId);
		if (diffSprite == null)
		{
			if (transIn && token == _diffAnimToken)
				busy = false;
			return;
		}

		FlxTween.cancelTweensOf(diffSprite);

		if (transIn)
		{
			diffSprite.visible = true;
			diffSprite.alpha = 0.5;
			diffSprite.offset.y += 5;
			diffSprite.x = (change > 0) ? 500 : -320;
			diffSprite.x += (CUTOUT_WIDTH * DJ_POS_MULTI);

			FlxTween.tween(diffSprite, {x: diffSprite.widthOffset + (CUTOUT_WIDTH * DJ_POS_MULTI)}, 0.2, {
				ease: FlxEase.circInOut
			});

			_diffAnimTimer = new FlxTimer().start(1 / 24, function(_)
			{
				if (token != _diffAnimToken || diffSprite == null)
					return;

				_diffAnimTimer = null;
				busy = false;
				diffSprite.alpha = 1;
				diffSprite.updateHitbox();
				diffSprite.visible = true;
			});
		}
		else
		{
			diffSprite.visible = true;
			final newX:Int = (change > 0) ? -320 : 500;

			FlxTween.tween(diffSprite, {x: newX + (CUTOUT_WIDTH * DJ_POS_MULTI)}, 0.2, {
				ease: FlxEase.circInOut,
				onComplete: function(_)
				{
					if (token != _diffAnimToken || diffSprite == null)
						return;

					diffSprite.x = diffSprite.widthOffset + (CUTOUT_WIDTH * DJ_POS_MULTI);
					diffSprite.visible = false;
				}
			});
		}
	}

	function clearDaCache(actualSongTho:String):Void
	{
		trace("Purging song previews!");
		var cacheObj = cast(openfl.Assets.cache, AssetCache);
		@:privateAccess
		var list = cacheObj.sound.keys();
		for (song in list)
		{
			if (song == null)
				continue;
			if (!song.contains(actualSongTho) && song.contains(".partial"))
			{
				trace('trying to remove: ' + song);
				var snd = cacheObj.sound.get(song);
				openfl.Assets.cache.clear(song);
			}
		}
	}

	function capsuleOnConfirmRandom(randomCapsule:SongMenuItem):Void
	{
		trace('RANDOM SELECTED');

		busy = true;
		letterSort.inputEnabled = false;

		var availableSongCapsules:Array<SongMenuItem> = grpCapsules.activeSongItems.filter(function(cap:SongMenuItem)
		{
			return cap.alive && cap.songData != null && !cap.songData.isCategoryHeader && !cap.isCategoryHeader;
		});

		if (availableSongCapsules.length == 0)
		{
			trace('No songs available!');
			busy = false;
			letterSort.inputEnabled = true;
			FunkinSound.playOnce(Paths.sound('cancelMenu'));
			return;
		}

		var targetSong:SongMenuItem = FlxG.random.getObject(availableSongCapsules);

		curSelected = grpCapsules.activeSongItems.indexOf(targetSong);
		curSelectedFractal = curSelected;
		changeSelection(0);

		capsuleOnConfirmDefault(targetSong);
	}

	function capsuleOnOpenDefault(cap:SongMenuItem):Void
	{
		if (cap == null)
			return;
		if (cap.isCategoryHeader || (cap.songData != null && cap.songData.isCategoryHeader))
		{
			toggleCategoryHeader(cap);
			return;
		}
		if (cap.songData != null && cap.songData.instVariants != null && cap.songData.instVariants.length > 0 && cap.songData.instVariants[0] != "")
		{
			var instrumentalIds = ["default"].concat(cap.songData.instVariants);
			openInstrumentalList(cap, instrumentalIds);
		}
		else
		{
			trace('NO ALTS');
			capsuleOnConfirmDefault(cap);
		}
	}

	public function getControls():Controls
	{
		return controls;
	}

	function openInstrumentalList(cap:SongMenuItem, instrumentalIds:Array<String>):Void
	{
		busy = true;

		capsuleOptionsMenu = new CapsuleOptionsMenu(this, cap.x + 175, cap.y + 115, instrumentalIds);
		capsuleOptionsMenu.cameras = [funnyCam];
		add(capsuleOptionsMenu);

		capsuleOptionsMenu.onConfirm = function(targetInstId:String)
		{
			capsuleOnConfirmDefault(cap, targetInstId);
		};
	}

	var capsuleOptionsMenu:Null<CapsuleOptionsMenu> = null;

	public function cleanupCapsuleOptionsMenu():Void
	{
		this.busy = false;

		if (capsuleOptionsMenu != null)
		{
			remove(capsuleOptionsMenu);
			capsuleOptionsMenu = null;
		}
	}

	function capsuleOnConfirmDefault(cap:SongMenuItem, ?targetInstId:String):Void
	{
		busy = true;
		letterSort.inputEnabled = false;

		PlayState.isStoryMode = false;

		var targetSong = cap != null ? cap.songData : null;
		if (cap == null || cap.isCategoryHeader || targetSong == null || targetSong.isCategoryHeader)
		{
			busy = false;
			letterSort.inputEnabled = true;
			return;
		}

		if (targetSong.hydrateChartsIfNeeded())
		{
			cap.refreshDisplayDifficulty();
			if (targetSong.songDifficulties != null && targetSong.songDifficulties.length > 0
				&& !targetSong.songDifficulties.contains(currentDifficulty))
			{
				currentDifficulty = targetSong.songDifficulties[0];
				rememberedDifficulty = currentDifficulty;
			}
		}

		addToRecentlyPlayed(targetSong.songName);

		var targetDifficultyId:String = currentDifficulty;
		PlayState.storyWeek = cap.songData.levelId;

		PlayState.storyDifficultyColor = FlxColor.GRAY;
		for (diffSprite in grpDifficulties.group.members)
		{
			if (diffSprite == null)
				continue;
			if (diffSprite.difficultyId == currentDifficulty)
			{
				PlayState.storyDifficultyColor = diffSprite.difficultyColor;
				break;
			}
		}

		FunkinSound.playOnce(Paths.sound('confirmMenu'));
		if (dj != null)
			dj.confirm();

		if (curCapsule != null)
		{
			curCapsule.animBox.forcePosition();
			curCapsule.confirm();
		}

		backingCard?.confirm();

		HapticUtil.vibrate(0, 0.01, 0.5);

		new FlxTimer().start(styleData?.getStartDelay(), function(tmr:FlxTimer)
		{
			FreeplayHelpers.moveToPlaystate(this, cap.songData, currentDifficulty, targetInstId);
		});
	}

	function rememberSelection():Void
	{
		if (rememberedSongId != null)
		{
			curSelected = currentFilteredSongs.findIndex(function(song)
			{
				if (song == null || song.isCategoryHeader)
					return false;
				return song.songId == rememberedSongId;
			});

			if (curSelected == -1)
				curSelected = 0;
			curSelectedFractal = curSelected;
		}

		if (rememberedDifficulty != null)
			currentDifficulty = rememberedDifficulty;
	}

	function changeSelectionFractal(change:Float)
	{
		curSelectedFractal = FlxMath.bound(curSelectedFractal + change, 0, grpCapsules.countLiving() - 1);
		for (index => capsule in grpCapsules.activeSongItems)
		{
			index += 1;

			capsule.selected = index == curSelected + 1;

			var capsuleIndex = index - curSelected;
			var yOffset:Float = 0;

			if (capsuleIndex < 0)
				yOffset += 50;
			else if (capsuleIndex > 4)
				yOffset -= 10;

			capsule.targetPos.y = capsule.intendedY(index - curSelectedFractal) - yOffset;
			capsule.targetPos.x = capsule.intendedX(index - curSelectedFractal) + (CUTOUT_WIDTH * SONGS_POS_MULTI);

			if (index < curSelected)
				capsule.targetPos.y -= 100;
		}
	}

	function changeSelection(change:Int = 0, updateCardPosition:Bool = true):Void
	{
		var prevSelected:Int = curSelected;
		if (updateCardPosition)
			curSelectedFractal = curSelected;
		curSelected += change;

		// countLiving() her çağrıda tüm listeyi tarar — bir kez al
		var totalSongs:Int = grpCapsules.countLiving();

		if (curSelected < 0)
			if (updateCardPosition)
			{
				curSelected = totalSongs - 1;
				change = 0;
				curSelectedFractal = curSelected;
			}
			else
			{
				curSelected = prevSelected;
				return;
			}
		if (curSelected >= totalSongs)
			if (updateCardPosition)
			{
				curSelected = 0;
				change = 0;
				curSelectedFractal = 0;
			}
			else
			{
				curSelected = prevSelected;
				return;
			}

		if (!prepForNewRank && curSelected != prevSelected && change != 0)
		{
			HapticUtil.vibrate(0, 0.01, 0.5);
			FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
		}

		var daSongCapsule:SongMenuItem = curCapsule;
		if (daSongCapsule != null && daSongCapsule.songData != null && !daSongCapsule.songData.isCategoryHeader && !daSongCapsule.isCategoryHeader)
		{
			if (daSongCapsule.songData.hydrateChartsIfNeeded())
				daSongCapsule.refreshDisplayDifficulty();
			diffIdsCurrent = daSongCapsule.songData.songDifficulties;
			rememberedSongId = daSongCapsule.songData.songId;
			changeDiff();
		}
		else
		{
			intendedScore = 0;
			intendedCompletion = 0.0;
			diffIdsCurrent = diffIdsTotal;
			rememberedSongId = null;
			rememberedDifficulty = Constants.DEFAULT_DIFFICULTY;
			albumRoll.albumId = null;
		}
		if (updateCardPosition)
			changeSelectionFractal(change);

		if (totalSongs > 0 && !prepForNewRank)
		{
			if (daSongCapsule != null && daSongCapsule.songData != null && !daSongCapsule.isCategoryHeader && !daSongCapsule.songData.isCategoryHeader)
				FreeplayHelpers.loadDiffsFromWeek(daSongCapsule.songData);
			if (FlxG.sound.music != null)
				FlxG.sound.music.pause();

			if (_previewTimer != null)
				_previewTimer.cancel();

			_previewTimer = new FlxTimer().start(0.35, _ -> {
				_previewTimer = null;
				playCurSongPreview(daSongCapsule);
			});

			tweenCurSongColor(daSongCapsule);
			curCapsule.selected = true;
		}
		else if (prepForNewRank)
			tweenCurSongColor(daSongCapsule);
	}

	public function playCurSongPreview(?daSongCapsule:SongMenuItem):Void
	{
		if (daSongCapsule == null)
			daSongCapsule = curCapsule;

		if (daSongCapsule == null)
			return;

		if (busy || rankAnimPlaying)
			return;

		if (curSelected == 0 || daSongCapsule.songData == null || daSongCapsule.isCategoryHeader || daSongCapsule.songData.isCategoryHeader)
		{
			FunkinSound.playMusic('freeplayRandom', {
				startingVolume: 0.0,
				overrideExisting: true,
				restartTrack: false
			});
			FlxG.sound.music.fadeIn(2, 0, 0.7);
		}
		else
		{
			if (!daSongCapsule.selected)
				return;

			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
				FlxG.sound.music = null;
			}
			var potentiallyErect:String = (currentDifficulty == "erect") || (currentDifficulty == "nightmare") ? "-erect" : "";
			var songData = daSongCapsule.songData;
			ModsHelper.loadModDir(songData.folder);
			FunkinSound.playMusic(daSongCapsule.songData.getNativeSongId(), {
				startingVolume: 0.0,
				overrideExisting: true,
				restartTrack: false,
				pathsFunction: INST,
				suffix: potentiallyErect,
				partialParams: {
					loadPartial: true,
					start: songData.freeplayPrevStart,
					end: songData.freeplayPrevEnd
				},
				onLoad: function()
				{
					var endVolume = dj?.playingCartoon ? 0.1 : FADE_IN_END_VOLUME;
					FlxG.sound.music.fadeIn(FADE_IN_DURATION, FADE_IN_START_VOLUME, endVolume);
					var newBPM = daSongCapsule.songData.songStartingBpm;
					FreeplayHelpers.BPM = newBPM;
				}
			});
			var saveBox = VsliceOptions.LAST_MOD;
			if (saveBox != null && ModsHelper.isModDirEnabled(saveBox.mod_dir))
				ModsHelper.loadModDir(saveBox.mod_dir);
			else
				ModsHelper.loadModDir('');
		}
	}

	var _colorTween:FlxTween = null;

	public function tweenCurSongColor(daSongCapsule:SongMenuItem)
	{
		if (Std.isOfType(backingCard, BoyfriendCard))
		{
			var newColor:FlxColor = (curSelected == 0 || daSongCapsule.songData == null) ? 0xFFFFD863 : daSongCapsule.songData.color;
			var bfCard = cast(backingCard, BoyfriendCard);

			if (_colorTween != null)
				_colorTween.cancel();

			if (bfCard.colorEngine != null)
				bfCard.colorEngine.tweenColor(newColor);
		}
	}

	public static function build(?params:FreeplayStateParams, ?stickers:StickerSubState):MusicBeatState
	{
		return cast new FreeplayHostState(params, stickers);
	}
}

typedef SongFilter =
{
	var filterType:FilterType;
	var ?filterData:Dynamic;
}

enum abstract FilterType(String)
{
	public var STARTSWITH;
	public var REGEXP;
	public var FAVORITE;
	public var ALL;
}

typedef ExitMoverData = Map<Array<FlxSprite>, MoveData>;

typedef MoveData =
{
	var ?x:Float;
	var ?y:Float;
	var ?speed:Float;
	var ?wait:Float;
}