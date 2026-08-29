package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.Language;
import backend.freeplay.FreeplayCatalog;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;
import openfl.events.KeyboardEvent;
import lime.system.Clipboard;

import haxe.Json;

import vslice.menus.StickerSubState;
import vslice.funkin.Scoring;
import vslice.funkin.Scoring.ScoringRank;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.text.FlxText.FlxTextBorderStyle;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];
	var initSongs:Array<SongMetadata> = [];
	var songAlphabets:Array<Alphabet> = [];
	var songIcons:Array<HealthIcon> = [];
	var headerAlphabets:Map<String, Alphabet> = new Map();
	var displayIcons:Array<HealthIcon> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var grpIcons:FlxTypedGroup<HealthIcon>;
	private var curPlaying:Bool = false;

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	var randomText:Alphabet;
	var randomIcon:HealthIcon;

	var searchBarBG:FlxSprite;
	var searchBarOutline:FlxSprite;
	var searchIcon:FlxSprite;
	var searchBarText:FlxText;
	var searchBarHint:FlxText;
	var searchBarCursor:FlxText;
	var cursorTimer:Float = 0;

	var dropdownBG:FlxSprite;
	var dropdownTextGroup:FlxTypedGroup<FlxText>;
	var dropdownIconGroup:FlxTypedGroup<HealthIcon>;
	var dropdownHighlight:FlxSprite;

	var searchOpen:Bool = false;
	var searchInputWait:Bool = false;
	var blockInputFrames:Int = 0;
	static var searchString:String = '';
	var dropdownItems:Array<DropdownItem> = [];
	var dropdownSelected:Int = 0;
	var dropdownMaxVisible:Int = 8;
	var dropdownScrollOffset:Int = 0;
	var dropdownTargetY:Float = 0;
	var dropdownCurrentY:Float = 0;

	public static var recentlyPlayed:Array<String> = [];
	public static var favoriteSongs:Array<String> = [];

	static inline var SEARCH_BAR_HEIGHT:Int = 44;
	static inline var SEARCH_BAR_MARGIN:Int = 10;
	static inline var DROPDOWN_ITEM_HEIGHT:Int = 44;
	static inline var SEARCH_BAR_WIDTH:Int = 640;
	static inline var DROPDOWN_ICON_SIZE:Int = 30;

	var rankLabelText:FlxText;
	var rankValueText:FlxText;
	var rankPopupText:FlxText;
	var rankAnimOverlay:FlxSprite;

	var stickerSubState:Null<StickerSubState> = null;
	var fromResultsParams:Null<OriginalFromResultsParams> = null;
	var pendingRankAnim:Bool = false;
	var rankAnimPlaying:Bool = false;
	var rankAnimDone:Bool = false;

	static inline var SCORE_PANEL_WIDTH:Int = 430;
	static inline var SCORE_PANEL_HEIGHT:Int = 160;

	public function new(?params:OriginalFreeplayStateParams, ?stickers:StickerSubState)
	{
		super();

		fromResultsParams = params != null ? params.fromResults : null;
		pendingRankAnim = fromResultsParams != null && fromResultsParams.playRankAnim == true;

		if (stickers != null && stickers.members != null)
			stickerSubState = stickers;

		if (pendingRankAnim)
			searchString = '';
	}

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(Language.getPhrase("freeplay_discord", "Menülerde"), null);
		#end

		final accept:String = (controls.mobileC) ? "A" : "ACCEPT";
		final reject:String = (controls.mobileC) ? "B" : "BACK";

		if (WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState(Language.getPhrase("freeplay_no_weeks",
				"SERBEST OYUN İÇİN HAFTA EKLENMEMİŞ\n\nHafta Düzenleyici Menüsüne gitmek için {1} tuşuna basın.\nAna Menüye dönmek için {2} tuşuna basın.",
				[accept, reject]),
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		loadInitFromCatalog();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		grpIcons = new FlxTypedGroup<HealthIcon>();
		add(grpIcons);

		randomText = new Alphabet(90, 320, Language.getPhrase("freeplay_random", "RASTGELE"), true);
		randomText.scaleX = Math.min(1, 980 / randomText.width);
		randomText.targetY = -1;
		randomText.snapToPosition();
		add(randomText);

		randomIcon = new HealthIcon('bf');
		randomIcon.sprTracker = randomText;
		add(randomIcon);

		search(true);

		scoreBG = new FlxSprite().makeGraphic(SCORE_PANEL_WIDTH, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		scoreText = new FlxText(0, 0, SCORE_PANEL_WIDTH - 20, "", 28);
		scoreText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, RIGHT);
		add(scoreText);

		diffText = new FlxText(0, 0, SCORE_PANEL_WIDTH - 20, "", 20);
		diffText.setFormat(Paths.font("vcr.ttf"), 20, 0xFFD0D0D0, CENTER);
		add(diffText);

		rankLabelText = new FlxText(0, 0, SCORE_PANEL_WIDTH - 20, "RANK", 24);
		rankLabelText.setFormat(Paths.font("5by7_b.ttf"), 24, FlxColor.WHITE, CENTER);
		add(rankLabelText);

		rankValueText = new FlxText(0, 0, SCORE_PANEL_WIDTH - 20, "-", 64);
		rankValueText.setFormat(Paths.font("5by7_b.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(rankValueText);

		rankAnimOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		rankAnimOverlay.alpha = 0;
		rankAnimOverlay.visible = false;
		add(rankAnimOverlay);

		rankPopupText = new FlxText(0, 0, 280, "", 148);
		rankPopupText.setFormat(Paths.font("5by7_b.ttf"), 148, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rankPopupText.visible = false;
		add(rankPopupText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if (curSelected >= songs.length)
			curSelected = -1;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = getFreeplayTipText();
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);

		player = new MusicPlayer(this);
		add(player);

		createSearchBar();

		changeSelection();
		updateTexts();

		addTouchPad('LEFT_FULL', 'A_B_C_O_X_Y_Z');

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		if (stickerSubState != null)
		{
			persistentDraw = true;
			persistentUpdate = true;
			openSubState(stickerSubState);
			stickerSubState.degenStickers();
		}
		else if (pendingRankAnim)
		{
			new FlxTimer().start(0.15, _ -> maybeStartResultsRankAnim());
		}

		if (fromResultsParams != null && (FlxG.sound.music == null || !FlxG.sound.music.playing))
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
		}

		super.create();
	}

	inline function getRankLetter(rank:Null<ScoringRank>):String
	{
		return switch (rank)
		{
			case PERFECT_GOLD: "S+";
			case PERFECT: "S";
			case EXCELLENT: "A";
			case GREAT: "B";
			case GOOD: "C";
			case SHIT: "D";
			default: "-";
		}
	}

	inline function getRankColor(rank:Null<ScoringRank>):FlxColor
	{
		return switch (rank)
		{
			case PERFECT_GOLD: 0xFFFFD44D;
			case PERFECT: 0xFFFF77C8;
			case EXCELLENT: 0xFFFFC94A;
			case GREAT: 0xFF9BE1FF;
			case GOOD: 0xFF8CFF9E;
			case SHIT: 0xFFC68AE6;
			default: FlxColor.GRAY;
		}
	}

	function getCurrentSongRank():Null<ScoringRank>
	{
		if (!isSongSelected())
			return null;

		var formatted:String = Highscore.formatSong(songs[curSelected].songName, curDifficulty);
		return Scoring.calculateRankForSong(formatted);
	}

	function updateRankDisplay():Void
	{
		var rank = getCurrentSongRank();
		var hasRank:Bool = (curSelected >= 0 && rank != null);

		rankLabelText.visible = hasRank;
		rankValueText.visible = hasRank;

		if (hasRank)
		{
			rankValueText.text = getRankLetter(rank);
			rankValueText.color = getRankColor(rank);
			rankLabelText.alpha = 1;
			scoreBG.scale.y = SCORE_PANEL_HEIGHT / 66;
		}
		else
		{
			scoreBG.scale.y = 1;
		}

		scoreBG.updateHitbox();
		positionHighscore();
	}
	
	function findDifficultyIndex(diffId:String):Int
	{
		if (diffId == null)
			return -1;
		var target:String = diffId.toLowerCase();

		for (i in 0...Difficulty.list.length)
		{
			if (Difficulty.getString(i, false).toLowerCase() == target)
				return i;

			if (Difficulty.getString(i).toLowerCase() == target)
				return i;

			if (Difficulty.list[i].toLowerCase() == target)
				return i;
		}

		return -1;
	}

	function applyFromResultsSelection():Void
	{
		if (fromResultsParams == null || songs.length < 1)
			return;

		var targetSongId:String = Paths.formatToSongPath(fromResultsParams.songId);

		for (i in 0...songs.length)
		{
			if (!songs[i].isCategoryHeader && Paths.formatToSongPath(songs[i].songName) == targetSongId)
			{
				curSelected = i;
				break;
			}
		}

		changeSelection(0, false);

		var diffIndex:Int = findDifficultyIndex(fromResultsParams.difficultyId);
		if (diffIndex > -1)
		{
			curDifficulty = diffIndex;
			changeDiff(0);
			_updateSongLastDifficulty();
		}
	}

	function playRankIntroSound(rank:ScoringRank):Void
	{
		switch (rank)
		{
			case SHIT:
				FlxG.sound.play(Paths.sound('ranks/rankinbad'));
			case PERFECT | PERFECT_GOLD:
				FlxG.sound.play(Paths.sound('ranks/rankinperfect'));
			default:
				FlxG.sound.play(Paths.sound('ranks/rankinnormal'));
		}
	}

	function playRankFinalSound(rank:ScoringRank):Void
	{
		switch (rank)
		{
			case SHIT:
				FlxG.sound.play(Paths.sound('ranks/loss'));
			case GOOD:
				FlxG.sound.play(Paths.sound('ranks/good'));
			case GREAT:
				FlxG.sound.play(Paths.sound('ranks/great'));
			case EXCELLENT:
				FlxG.sound.play(Paths.sound('ranks/excellent'));
			case PERFECT | PERFECT_GOLD:
				FlxG.sound.play(Paths.sound('ranks/perfect'));
		}
	}

	function maybeStartResultsRankAnim():Void
	{
		if (!pendingRankAnim || rankAnimDone || fromResultsParams == null)
			return;

		applyFromResultsSelection();
		rankAnimDone = true;
		startResultsRankAnim(fromResultsParams);
	}

	function startResultsRankAnim(data:OriginalFromResultsParams):Void
	{
		rankAnimPlaying = true;

		if (data.oldRank != null)
		{
			rankValueText.text = getRankLetter(data.oldRank);
			rankValueText.color = getRankColor(data.oldRank);
		}
		else
		{
			updateRankDisplay();
		}

		rankAnimOverlay.visible = true;
		rankAnimOverlay.alpha = 0;

		rankPopupText.visible = true;
		rankPopupText.text = getRankLetter(data.newRank);
		rankPopupText.setFormat(Paths.font("5by7_b.ttf"), 148, getRankColor(data.newRank), CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rankPopupText.fieldWidth = 280;
		rankPopupText.x = (FlxG.width - rankPopupText.fieldWidth) / 2;
		rankPopupText.y = (FlxG.height - rankPopupText.height) / 2 - 50;
		rankPopupText.alpha = 0;
		rankPopupText.scale.set(0.25, 0.25);

		FlxTween.tween(rankAnimOverlay, {alpha: 0.45}, 0.18);
		playRankIntroSound(data.newRank);

		FlxTween.tween(rankPopupText, {alpha: 1, "scale.x": 1.3, "scale.y": 1.3}, 0.22, {ease: FlxEase.backOut});

		new FlxTimer().start(0.48, function(_)
		{
			playRankFinalSound(data.newRank);

			var targetX:Float = rankValueText.x + (rankValueText.fieldWidth - rankPopupText.fieldWidth) / 2;
			var targetY:Float = rankValueText.y - 8;

			FlxTween.tween(rankPopupText, {x: targetX, y: targetY, "scale.x": 1, "scale.y": 1}, 0.55, {
				ease: FlxEase.expoInOut,
				onComplete: function(_)
				{
					rankPopupText.visible = false;
					rankAnimOverlay.visible = false;
					rankAnimOverlay.alpha = 0;
					updateRankDisplay();
					rankAnimPlaying = false;
					pendingRankAnim = false;
				}
			});
		});
	}

	inline function getSearchHintText():String
	{
		if (controls.mobileC)
			return Language.getPhrase("freeplay_search_hint_mobile", "Aramak için Tıklayın");

		return Language.getPhrase("freeplay_search_hint_pc", "Aramak için C tuşuna basın");
	}

	inline function getFreeplayTipText():String
	{
		final space:String = controls.mobileC ? "X" : "SPACE";
		final control:String = controls.mobileC ? "C" : "CTRL";
		final reset:String = controls.mobileC ? "Y" : "RESET";

		if (controls.mobileC)
		{
			return Language.getPhrase("freeplay_tip_mobile",
				"Dinlemek için {1} / Değiştiriciler için {2} / Sıfırlamak için {3} / Aramak için Tıklayın / Ayarlar için P",
				[space, control, reset]);
		}

		return Language.getPhrase("freeplay_tip_pc",
			"Dinlemek için {1} / Değiştiriciler için {2} / Sıfırlamak için {3} / Aramak için C / Favori için F / Ayarlar için ALT",
			[space, control, reset]);
	}

	function createSearchBar()
	{
		var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
		var barY:Int = SEARCH_BAR_MARGIN;

		searchBarOutline = new FlxSprite(barX - 2, barY - 2).makeGraphic(SEARCH_BAR_WIDTH + 4, SEARCH_BAR_HEIGHT + 4, FlxColor.TRANSPARENT);
		flixel.util.FlxSpriteUtil.drawRoundRect(searchBarOutline, 0, 0, SEARCH_BAR_WIDTH + 4, SEARCH_BAR_HEIGHT + 4, 16, 16, FlxColor.WHITE);
		searchBarOutline.alpha = 0;
		searchBarOutline.scrollFactor.set();
		add(searchBarOutline);

		searchBarBG = new FlxSprite(barX, barY).makeGraphic(SEARCH_BAR_WIDTH, SEARCH_BAR_HEIGHT, FlxColor.TRANSPARENT);
		flixel.util.FlxSpriteUtil.drawRoundRect(searchBarBG, 0, 0, SEARCH_BAR_WIDTH, SEARCH_BAR_HEIGHT, 12, 12, FlxColor.fromRGB(30, 30, 40));
		searchBarBG.alpha = 0.85;
		searchBarBG.scrollFactor.set();
		add(searchBarBG);

		searchIcon = new FlxSprite(barX + 8, barY + 8);
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
		add(searchIcon);

		searchBarHint = new FlxText(barX + 44, barY + 16, SEARCH_BAR_WIDTH - 60, getSearchHintText(), 20);
		searchBarHint.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.fromRGB(150, 150, 170), LEFT);
		searchBarHint.scrollFactor.set();
		add(searchBarHint);

		searchBarText = new FlxText(barX + 44, barY + 16, SEARCH_BAR_WIDTH - 60, "", 20);
		searchBarText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		searchBarText.scrollFactor.set();
		add(searchBarText);

		searchBarCursor = new FlxText(barX + 44, barY + 16, 20, "|", 20);
		searchBarCursor.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		searchBarCursor.scrollFactor.set();
		searchBarCursor.visible = false;
		add(searchBarCursor);

		dropdownBG = new FlxSprite(barX, barY + SEARCH_BAR_HEIGHT).makeGraphic(SEARCH_BAR_WIDTH,
			DROPDOWN_ITEM_HEIGHT * dropdownMaxVisible + 10, FlxColor.fromRGB(25, 25, 35));
		dropdownBG.alpha = 0;
		dropdownBG.scrollFactor.set();
		add(dropdownBG);

		dropdownHighlight = new FlxSprite(barX + 4, 0).makeGraphic(SEARCH_BAR_WIDTH - 8, DROPDOWN_ITEM_HEIGHT, FlxColor.fromRGB(60, 60, 90));
		dropdownHighlight.alpha = 0;
		dropdownHighlight.scrollFactor.set();
		add(dropdownHighlight);

		dropdownTextGroup = new FlxTypedGroup<FlxText>();
		add(dropdownTextGroup);

		dropdownIconGroup = new FlxTypedGroup<HealthIcon>();
		add(dropdownIconGroup);
	}

	function openSearchBar()
	{
		if (searchOpen)
			return;

		searchOpen = true;
		searchInputWait = true;
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

	function closeSearchBar()
	{
		if (!searchOpen)
			return;

		searchOpen = false;
		searchInputWait = false;
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

	function updateSearchBarDisplay()
	{
		searchBarText.text = searchString;
		searchBarHint.visible = (searchString.length == 0);

		if (searchOpen)
		{
			searchBarCursor.x = searchBarText.x + searchBarText.textField.textWidth + 2;
			searchBarCursor.visible = true;
		}
	}

	function buildDropdownItems()
	{
		dropdownItems = [];

		if (searchString.length == 0)
		{
			if (recentlyPlayed.length > 0)
			{
				dropdownItems.push({
					type: HEADER,
					text: Language.getPhrase("freeplay_last_played", "SON OYNANAN"),
					songIndex: -1,
					icon: "",
					color: FlxColor.fromRGB(255, 200, 60)
				});

				var lastPlayed:String = recentlyPlayed[recentlyPlayed.length - 1];
				for (si in 0...initSongs.length)
				{
					if (initSongs[si].songName.toLowerCase() == lastPlayed.toLowerCase())
					{
						dropdownItems.push({
							type: SONG,
							text: initSongs[si].songName,
							songIndex: si,
							icon: initSongs[si].songCharacter,
							color: initSongs[si].color
						});
						break;
					}
				}
			}

			if (favoriteSongs.length > 0)
			{
				dropdownItems.push({
					type: HEADER,
					text: Language.getPhrase("freeplay_favorites", "FAVORİLER"),
					songIndex: -1,
					icon: "",
					color: FlxColor.fromRGB(255, 100, 100)
				});

				for (favName in favoriteSongs)
				{
					for (si in 0...initSongs.length)
					{
						if (initSongs[si].songName.toLowerCase() == favName.toLowerCase())
						{
							dropdownItems.push({
								type: SONG,
								text: initSongs[si].songName,
								songIndex: si,
								icon: initSongs[si].songCharacter,
								color: initSongs[si].color
							});
							break;
						}
					}
				}
			}

			if (dropdownItems.length == 0)
			{
				dropdownItems.push({
					type: HEADER,
					text: Language.getPhrase("freeplay_type_to_search", "ŞARKI ARAMAK İÇİN YAZIN..."),
					songIndex: -1,
					icon: "",
					color: FlxColor.fromRGB(150, 150, 170)
				});
			}
		}
		else
		{
			var searchLower:String = searchString.toLowerCase().replace('-', ' ');
			var resultCount:Int = 0;

			dropdownItems.push({
				type: HEADER,
				text: Language.getPhrase("freeplay_results", "SONUÇLAR") + ': "$searchString"',
				songIndex: -1,
				icon: "",
				color: FlxColor.fromRGB(100, 200, 255)
			});

			for (si in 0...initSongs.length)
			{
				var songNameLower:String = initSongs[si].songName.toLowerCase().replace('-', ' ');
				if (songNameLower.contains(searchLower))
				{
					dropdownItems.push({
						type: SONG,
						text: initSongs[si].songName,
						songIndex: si,
						icon: initSongs[si].songCharacter,
						color: initSongs[si].color
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
					text: Language.getPhrase("freeplay_no_results", "SONUÇ BULUNAMADI"),
					songIndex: -1,
					icon: "",
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

	function showDropdown()
	{
		clearDropdownVisuals();

		var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
		var barY:Int = SEARCH_BAR_MARGIN + SEARCH_BAR_HEIGHT;

		var visibleCount:Int = Std.int(Math.min(dropdownItems.length, dropdownMaxVisible));
		var dropdownHeight:Int = visibleCount * DROPDOWN_ITEM_HEIGHT + 10;

		dropdownBG.makeGraphic(SEARCH_BAR_WIDTH, Std.int(Math.max(dropdownHeight, 50)), FlxColor.TRANSPARENT);
						flixel.util.FlxSpriteUtil.drawRoundRect(dropdownBG, 0, 0, SEARCH_BAR_WIDTH, Std.int(Math.max(dropdownHeight, 50)), 12, 12, FlxColor.fromRGB(25, 25, 35));
		dropdownBG.setPosition(barX, barY);

		dropdownTargetY = barY;
		dropdownCurrentY = barY - 20;
		dropdownBG.y = dropdownCurrentY;

		FlxTween.cancelTweensOf(dropdownBG);
		FlxTween.tween(dropdownBG, {alpha: 0.92}, 0.25);

		refreshDropdownVisuals();
	}

	function clearDropdownVisuals()
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

	function refreshDropdownVisuals()
	{
		clearDropdownVisuals();

		var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
		var startY:Float = dropdownBG.y + 5;

		var visibleStart:Int = dropdownScrollOffset;
		var visibleEnd:Int = Std.int(Math.min(dropdownItems.length, dropdownScrollOffset + dropdownMaxVisible));

		var visibleCount:Int = visibleEnd - visibleStart;
		var dropdownHeight:Int = visibleCount * DROPDOWN_ITEM_HEIGHT + 10;
		dropdownBG.makeGraphic(SEARCH_BAR_WIDTH, Std.int(Math.max(dropdownHeight, 50)), FlxColor.TRANSPARENT);
						flixel.util.FlxSpriteUtil.drawRoundRect(dropdownBG, 0, 0, SEARCH_BAR_WIDTH, Std.int(Math.max(dropdownHeight, 50)), 12, 12, FlxColor.fromRGB(25, 25, 35));

		for (vi in visibleStart...visibleEnd)
		{
			var item:DropdownItem = dropdownItems[vi];
			var slotIndex:Int = vi - visibleStart;
			var itemY:Float = startY + slotIndex * DROPDOWN_ITEM_HEIGHT;

			if (item.type == HEADER)
			{
				var headerText:FlxText = getOrCreateText();
				headerText.setFormat(Paths.font("vcr.ttf"), 18, item.color, LEFT);
				headerText.text = "── " + item.text + " ──";
				headerText.setPosition(barX + 12, itemY + Std.int((DROPDOWN_ITEM_HEIGHT - 18) / 2));
				headerText.fieldWidth = SEARCH_BAR_WIDTH - 24;
				headerText.scrollFactor.set();
				headerText.alpha = 0.9;
				headerText.visible = true;
				headerText.revive();
				dropdownTextGroup.add(headerText);
			}
			else if (item.type == SONG)
			{
				var isSelected:Bool = (vi == dropdownSelected);
				var isFav:Bool = favoriteSongs.contains(item.text.toLowerCase());

				var displayName:String = item.text;
				if (isFav)
					displayName = "♥ " + displayName;

				var songText:FlxText = getOrCreateText();
				songText.setFormat(Paths.font("vcr.ttf"), 20, isSelected ? FlxColor.WHITE : FlxColor.fromRGB(200, 200, 210), LEFT);
				songText.text = displayName;
				songText.setPosition(barX + 14 + DROPDOWN_ICON_SIZE + 15, itemY + Std.int((DROPDOWN_ITEM_HEIGHT - 20) / 2));
				songText.fieldWidth = SEARCH_BAR_WIDTH - (14 + DROPDOWN_ICON_SIZE + 20);
				songText.scrollFactor.set();
				songText.alpha = isSelected ? 1 : 0.7;
				songText.visible = true;
				songText.revive();
				dropdownTextGroup.add(songText);

				var songIcon:HealthIcon = null;
				Mods.useSongFolder(initSongs[item.songIndex].folder, function()
				{
					songIcon = getOrCreateIcon(item.icon);
				});
				songIcon.setGraphicSize(DROPDOWN_ICON_SIZE, DROPDOWN_ICON_SIZE);
				songIcon.updateHitbox();
				songIcon.centerOffsets();
				songIcon.scrollFactor.set();
				songIcon.x = barX + 14;
				songIcon.y = itemY + Std.int((DROPDOWN_ITEM_HEIGHT - songIcon.height) / 2);
				songIcon.alpha = isSelected ? 1 : 0.6;
				songIcon.visible = true;
				songIcon.active = true;
				songIcon.revive();
				dropdownIconGroup.add(songIcon);
			}
		}
		Mods.clearMenuMod();

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

	function hideDropdown()
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

	function getOrCreateText():FlxText
	{
		var txt:FlxText = null;
		for (t in dropdownTextGroup.members)
		{
			if (t != null && !t.alive)
			{
				txt = t;
				break;
			}
		}
		if (txt == null)
		{
			txt = new FlxText(0, 0, SEARCH_BAR_WIDTH, "", 20);
			txt.scrollFactor.set();
		}
		return txt;
	}

	function getOrCreateIcon(charName:String):HealthIcon
	{
		var icon:HealthIcon = null;
		for (i in dropdownIconGroup.members)
		{
			if (i != null && !i.alive)
			{
				icon = i;
				break;
			}
		}
		if (icon == null)
		{
			icon = new HealthIcon(charName);
			icon.scrollFactor.set();
		}
		else
		{
			icon.changeIcon(charName);
		}
		return icon;
	}

	function selectDropdownItem()
	{
		if (dropdownSelected < 0 || dropdownSelected >= dropdownItems.length)
			return;

		var item:DropdownItem = dropdownItems[dropdownSelected];
		if (item.type != SONG)
			return;

		var targetSong:SongMetadata = initSongs[item.songIndex];

		searchString = '';
		search();

		var foundIndex:Int = -1;
		for (si in 0...songs.length)
		{
			if (songs[si] != null && !songs[si].isCategoryHeader && songs[si].sourceIndex == targetSong.sourceIndex)
			{
				foundIndex = si;
				break;
			}
		}

		if (foundIndex != -1)
		{
			curSelected = foundIndex;
			changeSelection();
			lerpSelected = curSelected;
		}

		closeSearchBar();
		updateSearchBarDisplay();
		playUiSound('scrollMenu', 0.4);
	}

	function toggleFavorite()
	{
		if (!isSongSelected())
			return;

		var songName:String = songs[curSelected].songName.toLowerCase();

		if (favoriteSongs.contains(songName))
		{
			favoriteSongs.remove(songName);
			playUiSound('unfav', 0.8);
		}
		else
		{
			favoriteSongs.push(songName);
			playUiSound('fav', 0.8);
		}
	}

	public static function addToRecentlyPlayed(songName:String)
	{
		var lowerName:String = songName.toLowerCase();
		recentlyPlayed.remove(lowerName);
		recentlyPlayed.push(lowerName);
		while (recentlyPlayed.length > 10)
			recentlyPlayed.shift();
	}

	function checkSearchBarClick():Bool
	{
		if (FlxG.mouse.justPressed)
		{
			var barX:Int = Std.int((FlxG.width - SEARCH_BAR_WIDTH) / 2);
			var barY:Int = SEARCH_BAR_MARGIN;
			var mx:Float = FlxG.mouse.screenX;
			var my:Float = FlxG.mouse.screenY;

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

	function pickRandomSong()
	{
		if (songs.length < 1)
			return;

		var playable:Array<Int> = [];
		for (i in 0...songs.length)
		{
			if (songs[i] != null && !songs[i].isCategoryHeader)
				playable.push(i);
		}
		if (playable.length < 1)
			return;

		var randomSel:Int = playable[FlxG.random.int(0, playable.length - 1)];
		curSelected = randomSel;
		changeSelection();
		lerpSelected = curSelected;
		playUiSound('scrollMenu', 0.4);
	}

	override function closeSubState()
	{
		if (FreeplayCatalog.consumePendingApply())
			reloadFromCatalog();
		else
			changeSelection(0, false);
			
		// BaseOptionsMenu (Ayarlar menüsü) kamerayı kaydırıyor, onu eski yerine sıfırlayalım
		flixel.FlxG.camera.follow(null);
		flixel.FlxG.camera.scroll.set(0, 0);
			
		persistentUpdate = true;
		super.closeSubState();
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'A_B_C_O_X_Y_Z');
		blockInputFrames = 12;

		if (pendingRankAnim && !rankAnimDone)
		{
			new FlxTimer().start(0.05, _ -> maybeStartResultsRankAnim());
		}
	}

	function loadInitFromCatalog():Void
	{
		initSongs = [];
		songAlphabets = [];
		songIcons = [];
		headerAlphabets = new Map();
		var catalog = FreeplayCatalog.ensureLoaded();
		for (entry in catalog)
		{
			if (FreeplayCatalog.shouldHideFolder(entry.folder))
				continue;
			var meta = SongMetadata.fromEntry(entry);
			meta.sourceIndex = initSongs.length;
			initSongs.push(meta);
			songAlphabets.push(null);
			songIcons.push(null);
		}
		Mods.clearMenuMod();
	}

	function getSongAlphabet(index:Int):Alphabet
	{
		if (index < 0 || index >= initSongs.length)
			return null;
		if (songAlphabets[index] == null)
		{
			var songText = new Alphabet(90, 320, initSongs[index].songName, true);
			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();
			songText.visible = songText.active = songText.isMenuItem = false;
			songAlphabets[index] = songText;
		}
		return songAlphabets[index];
	}

	function getHeaderAlphabet(id:String, label:String, collapsed:Bool):Alphabet
	{
		var display:String = FreeplayCatalog.formatHeaderLabel(label, collapsed);
		var text = headerAlphabets.get(id);
		if (text == null)
		{
			text = new Alphabet(90, 320, display, true);
			text.scaleX = Math.min(1, 980 / text.width);
			text.snapToPosition();
			headerAlphabets.set(id, text);
		}
		else if (text.text != display)
		{
			text.text = display;
			text.scaleX = Math.min(1, 980 / text.width);
		}
		text.visible = text.active = text.isMenuItem = false;
		return text;
	}

	function ensureSongIcon(index:Int, tracker:Alphabet):HealthIcon
	{
		if (index < 0 || index >= initSongs.length || tracker == null)
			return null;
		if (songIcons[index] != null)
		{
			songIcons[index].sprTracker = tracker;
			return songIcons[index];
		}
		var icon:HealthIcon = null;
		Mods.useSongFolder(initSongs[index].folder, function()
		{
			icon = new HealthIcon(initSongs[index].songCharacter);
		});
		Mods.clearMenuMod();
		icon.sprTracker = tracker;
		icon.visible = icon.active = false;
		songIcons[index] = icon;
		return icon;
	}

	inline function isSongSelected():Bool
	{
		return curSelected >= 0 && curSelected < songs.length && songs[curSelected] != null && !songs[curSelected].isCategoryHeader;
	}

	inline function isHeaderSelected():Bool
	{
		return curSelected >= 0 && curSelected < songs.length && songs[curSelected] != null && songs[curSelected].isCategoryHeader;
	}

	inline function playUiSound(name:String, vol:Float = 1):Void
		FlxG.sound.play(Paths.sound(name, false), vol);

	inline function songFolderOf(index:Int):String
	{
		if (index < 0 || index >= songs.length || songs[index] == null)
			return '';
		var folder:String = songs[index].folder;
		return folder != null ? folder : '';
	}

	function toggleCategoryHeader():Void
	{
		if (!isHeaderSelected())
			return;
		var id:String = songs[curSelected].categoryId;
		FreeplayCatalog.toggleCollapsed(id);
		search();
		for (i in 0...songs.length)
		{
			if (songs[i].isCategoryHeader && songs[i].categoryId == id)
			{
				curSelected = i;
				break;
			}
		}
		changeSelection(0, false);
		lerpSelected = curSelected;
	}

	function openFreeplaySettings():Void
	{
		if (player != null && player.playingMusic)
			return;
		if (searchOpen)
			return;
		Mods.clearMenuMod();
		persistentUpdate = false;
		openSubState(new options.FreeplaySettingsSubState());
		removeTouchPad();
	}

	function reloadFromCatalog():Void
	{
		var keepName:String = isSongSelected() ? songs[curSelected].songName : null;
		var keepFolder:String = isSongSelected() ? songs[curSelected].folder : null;
		var keepHeader:String = isHeaderSelected() ? songs[curSelected].categoryId : null;
		loadInitFromCatalog();
		search();
		if (keepName != null)
		{
			for (i in 0...songs.length)
			{
				if (!songs[i].isCategoryHeader && songs[i].songName == keepName && songs[i].folder == keepFolder)
				{
					curSelected = i;
					break;
				}
			}
		}
		else if (keepHeader != null)
		{
			for (i in 0...songs.length)
			{
				if (songs[i].isCategoryHeader && songs[i].categoryId == keepHeader)
				{
					curSelected = i;
					break;
				}
			}
		}
		changeSelection(0, false);
		lerpSelected = curSelected;
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		var meta = new SongMetadata(songName, weekNum, songCharacter, color);
		meta.sourceIndex = initSongs.length;
		initSongs.push(meta);
		songAlphabets.push(null);
		songIcons.push(null);
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;

	override function update(elapsed:Float)
	{
		if (WeekData.weeksList.length < 1)
			return;

		if (blockInputFrames > 0)
		{
			updateTexts(elapsed);
			super.update(elapsed);
			if (controls.BACK || (touchPad != null && touchPad.buttonB != null && touchPad.buttonB.pressed))
				return;
			blockInputFrames--;
			return;
		}

		if (rankAnimPlaying)
		{
			updateTexts(elapsed);
			super.update(elapsed);
			return;
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

		if (searchOpen && dropdownBG.alpha > 0)
		{
			dropdownCurrentY = FlxMath.lerp(dropdownCurrentY, dropdownTargetY, Math.min(1, elapsed * 12));
			dropdownBG.y = dropdownCurrentY;
			refreshDropdownVisuals();
		}

		checkSearchBarClick();

		if (searchOpen && FlxG.mouse.wheel != 0)
		{
			dropdownScrollOffset -= FlxG.mouse.wheel;
			if (dropdownScrollOffset < 0)
				dropdownScrollOffset = 0;
			var maxScroll:Int = Std.int(Math.max(0, dropdownItems.length - dropdownMaxVisible));
			if (dropdownScrollOffset > maxScroll)
				dropdownScrollOffset = maxScroll;
			refreshDropdownVisuals();
		}

		if (searchInputWait)
		{
			if (controls.UI_UP_P)
				navigateDropdown(-1);
			if (controls.UI_DOWN_P)
				navigateDropdown(1);

			updateTexts(elapsed);
			super.update(elapsed);
			return;
		}

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2)
			ratingSplit.push('');
		while (ratingSplit[1].length < 2)
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if ((FlxG.keys.pressed.SHIFT || (touchPad != null && touchPad.buttonZ != null && touchPad.buttonZ.pressed)) && !player.playingMusic)
			shiftMult = 3;

		if (!player.playingMusic)
		{
			if (curSelected == -1)
				scoreText.text = Language.getPhrase("freeplay_random_hint", "RASTGELE ŞARKI SEÇMEK İÇİN SEÇİN!");
			else if (isHeaderSelected())
				scoreText.text = songs[curSelected].songName;
			else
				scoreText.text = Language.getPhrase('personal_best', 'EN İYİ SKOR: {1} (%{2})', [lerpScore, ratingSplit.join('.')]);

			positionHighscore();
			updateRankDisplay();

			if (songs.length > 0)
			{
				if (FlxG.keys.justPressed.HOME)
				{
					curSelected = -1;
					changeSelection();
					holdTime = 0;
				}
				else if (FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if (FlxG.mouse.wheel != 0 && !searchOpen)
				{
					playUiSound('scrollMenu', 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (isSongSelected())
			{
				if (controls.UI_LEFT_P)
				{
					changeDiff(-1);
					_updateSongLastDifficulty();
				}
				else if (controls.UI_RIGHT_P)
				{
					changeDiff(1);
					_updateSongLastDifficulty();
				}
			}
		}

		if ((FlxG.keys.justPressed.ALT || (touchPad != null && touchPad.buttonO != null && touchPad.buttonO.justPressed))
			&& !player.playingMusic && !searchOpen)
		{
			openFreeplaySettings();
			updateTexts(elapsed);
			super.update(elapsed);
			return;
		}

		if (FlxG.keys.justPressed.C && !player.playingMusic && !searchOpen)
		{
			openSearchBar();
		}

		if (FlxG.keys.justPressed.F && !player.playingMusic && !searchOpen && isSongSelected())
		{
			toggleFavorite();
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else if (searchOpen)
			{
				closeSearchBar();
			}
			else if (searchString.length > 0)
			{
				searchString = '';
				search();
				searchBarText.text = "";
				searchBarHint.visible = true;
			}
			else
			{
				persistentUpdate = false;
				playUiSound('cancelMenu');
				MenuStyleRouter.goToMainMenu();
			}
		}

		if ((FlxG.keys.justPressed.CONTROL || (touchPad != null && touchPad.buttonC != null && touchPad.buttonC.justPressed))
			&& !player.playingMusic && isSongSelected())
		{
			Mods.clearMenuMod();
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
			removeTouchPad();
			updateTexts(elapsed);
			super.update(elapsed);
			return;
		}
		else if ((FlxG.keys.justPressed.SPACE || (touchPad != null && touchPad.buttonX != null && touchPad.buttonX.justPressed)) && isSongSelected())
		{
			if (songs.length < 1)
			{
				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			if (instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.useSongFolder(songs[curSelected].folder, function()
				{
					PlayState.storyDifficulty = curDifficulty;
					var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
					Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
					if (PlayState.SONG.needsVoices)
					{
						vocals = new FlxSound();
						try
						{
							var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
							var loadedVocals = Paths.voices(PlayState.SONG.song,
								(playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
							if (loadedVocals == null)
								loadedVocals = Paths.voices(PlayState.SONG.song);

							if (loadedVocals != null && loadedVocals.length > 0)
							{
								vocals.loadEmbedded(loadedVocals);
								FlxG.sound.list.add(vocals);
								vocals.persist = vocals.looped = true;
								vocals.volume = 0.8;
								vocals.play();
								vocals.pause();
							}
							else
								vocals = FlxDestroyUtil.destroy(vocals);
						}
						catch (e:Dynamic)
						{
							vocals = FlxDestroyUtil.destroy(vocals);
						}

						opponentVocals = new FlxSound();
						try
						{
							var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
							var loadedVocals = Paths.voices(PlayState.SONG.song,
								(oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');

							if (loadedVocals != null && loadedVocals.length > 0)
							{
								opponentVocals.loadEmbedded(loadedVocals);
								FlxG.sound.list.add(opponentVocals);
								opponentVocals.persist = opponentVocals.looped = true;
								opponentVocals.volume = 0.8;
								opponentVocals.play();
								opponentVocals.pause();
							}
							else
								opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
						}
						catch (e:Dynamic)
						{
							opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
						}
					}

					FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
					FlxG.sound.music.pause();
				});
				Mods.clearMenuMod();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			if (curSelected == -1)
			{
				pickRandomSong();
			}
			else if (isHeaderSelected())
			{
				toggleCategoryHeader();
			}
			else if (isSongSelected())
			{
				persistentUpdate = false;
				var songFolder:String = songFolderOf(curSelected);
				if (songFolder.length > 0)
					Mods.currentModDirectory = songFolder;
				var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
				var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

				addToRecentlyPlayed(songs[curSelected].songName);

				try
				{
					PlayState.isStoryMode = false;
					PlayState.storyDifficulty = curDifficulty;
					Song.loadFromJson(poop, songLowercase);

					trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
				}
				catch (e:haxe.Exception)
				{
					trace('ERROR! ${e.message}');

					var errorStr:String = e.message;
					if (errorStr.contains('There is no TEXT asset with an ID of'))
						errorStr = Language.getPhrase("freeplay_missing_file", "Eksik dosya: ")
							+ errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length - 1);
					else
						errorStr += '\n\n' + e.stack;

					missingText.text = Language.getPhrase("freeplay_chart_error", "NOTA HARİTASI YÜKLENIRKEN HATA:") + '\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					Mods.clearMenuMod();
					playUiSound('cancelMenu');

					updateTexts(elapsed);
					super.update(elapsed);
					return;
				}

				@:privateAccess
				if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
				{
					trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
					Paths.freeGraphicsFromMemory();
				}
				LoadingState.prepareToSong();
				LoadingState.loadAndSwitchState(new PlayState());
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
				stopMusicPlay = true;

				destroyFreeplayVocals();
				#if (MODS_ALLOWED && DISCORD_ALLOWED)
				DiscordClient.loadModRPC();
				#end
			}
		}
		else if ((controls.RESET || (touchPad != null && touchPad.buttonY != null && touchPad.buttonY.justPressed))
			&& !player.playingMusic && isSongSelected())
		{
			if (songs.length < 1)
			{
				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			Mods.clearMenuMod();
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			removeTouchPad();
			playUiSound('scrollMenu');
			updateTexts(elapsed);
			super.update(elapsed);
			return;
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}

	function navigateDropdown(direction:Int)
	{
		playUiSound('scrollMenu', 0.3);

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

	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
			vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if (opponentVocals != null)
			opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);

		if (isSongSelected())
		{
			#if !switch
			intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
			intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
			#end
		}

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		updateRankDisplay();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		if (songs.length < 1)
		{
			curSelected = -1;
			return;
		}

		curSelected += change;

		if (curSelected < -1)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = -1;

		if (playSound)
			playUiSound('scrollMenu', 0.4);

		var newColor:Int;
		if (curSelected == -1)
			newColor = FlxColor.fromRGB(253, 113, 155);
		else
			newColor = songs[curSelected].color;

		if (newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			item.alpha = 0.6;
			if (num < displayIcons.length && displayIcons[num] != null)
				displayIcons[num].alpha = 0.6;

			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				if (num < displayIcons.length && displayIcons[num] != null)
					displayIcons[num].alpha = 1;
			}
		}

		if (curSelected == -1)
		{
			randomText.alpha = 1;
			randomIcon.alpha = 1;
		}
		else
		{
			randomText.alpha = 0.6;
			randomIcon.alpha = 0.6;
		}

		if (isHeaderSelected())
		{
			diffText.text = "";
			intendedScore = 0;
			intendedRating = 0;
			Mods.clearMenuMod();
		}
		else if (curSelected >= 0)
		{
			_updateSongLastDifficulty();

			Mods.useSongFolder(songs[curSelected].folder, function()
			{
				PlayState.storyWeek = songs[curSelected].week;
				var week:WeekData = null;
				if (songs[curSelected].week >= 0 && songs[curSelected].week < WeekData.weeksList.length)
				{
					var weekFile:String = WeekData.weeksList[songs[curSelected].week];
					week = WeekData.weeksLoaded.get(weekFile);
				}
				if (ClientPrefs.data.quickFreeplay)
				{
					var meta = songs[curSelected];
					if (!meta.chartsHydrated)
					{
						Difficulty.loadFromSong(meta.songName, week);
						meta.difficulties = Difficulty.list.copy();
						meta.chartsHydrated = true;
						FreeplayCatalog.updateHydratedSong(meta.songName, meta.folder, meta.difficulties, 0);
					}
					else if (meta.difficulties != null && meta.difficulties.length > 0)
						Difficulty.copyFrom(meta.difficulties);
					else
						Difficulty.loadFromSong(meta.songName, week);
				}
				else
					Difficulty.loadFromWeek(week);
			});
			Mods.clearMenuMod();

			var savedDiff:String = songs[curSelected].lastDifficulty;
			var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
			if (savedDiff != null && Difficulty.list.contains(savedDiff))
				curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
			else if (lastDiff > -1)
				curDifficulty = lastDiff;
			else if (Difficulty.list.contains(Difficulty.getDefault()))
				curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
			else
				curDifficulty = 0;

			changeDiff();
			_updateSongLastDifficulty();
		}
		else
		{
			diffText.text = "";
			intendedScore = 0;
			intendedRating = 0;
			Mods.clearMenuMod();
		}

		updateRankDisplay();
	}

	inline private function _updateSongLastDifficulty()
	{
		if (isSongSelected())
			songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
	}

	private function positionHighscore()
	{
		var panelX:Float = FlxG.width - SCORE_PANEL_WIDTH - 6;

		scoreBG.x = panelX;
		scoreBG.y = 0;

		scoreText.x = panelX + 10;
		scoreText.y = 8;
		scoreText.fieldWidth = SCORE_PANEL_WIDTH - 20;

		diffText.x = panelX + 10;
		diffText.y = scoreText.y + 32;
		diffText.fieldWidth = SCORE_PANEL_WIDTH - 20;

		if (rankLabelText.visible)
		{
			rankLabelText.x = panelX + 10;
			rankLabelText.y = diffText.y + 28;
			rankLabelText.fieldWidth = SCORE_PANEL_WIDTH - 20;

			rankValueText.x = panelX + 10;
			rankValueText.y = rankLabelText.y + 24;
			rankValueText.fieldWidth = SCORE_PANEL_WIDTH - 20;
		}
	}

	function search(?init:Bool = false)
	{
		grpSongs.clear();
		grpIcons.clear();
		_lastVisibles = [];
		songs = [];
		displayIcons = [];

		if (!init)
			instPlaying = -1;

		var filtered:Array<SongMetadata> = [];
		var sources:Array<backend.freeplay.FreeplayRowSource> = [];
		for (songID in 0...initSongs.length)
		{
			var song:SongMetadata = initSongs[songID];
			if (song == null || song.isCategoryHeader)
				continue;

			song.sourceIndex = songID;
			sources.push({index: filtered.length, name: song.songName, folder: song.folder});
			filtered.push(song);
		}

		var rows = FreeplayCatalog.buildRows(sources, searchString);
		var i:Int = 0;
		for (row in rows)
		{
			if (row.isHeader)
			{
				var header = SongMetadata.makeHeader(row.categoryId, row.categoryLabel, row.collapsed);
				var songText = getHeaderAlphabet(row.categoryId, row.categoryLabel, row.collapsed);
				songText.targetY = i;
				songText.snapToPosition();
				songText.visible = songText.active = songText.isMenuItem = false;
				grpSongs.add(songText);
				displayIcons.push(null);
				songs.push(header);
			}
			else
			{
				var song = filtered[row.sourceIndex];
				var songText = getSongAlphabet(song.sourceIndex);
				songText.targetY = i;
				songText.snapToPosition();
				songText.visible = songText.active = songText.isMenuItem = false;

				var icon:HealthIcon = songIcons[song.sourceIndex];
				if (icon == null && !ClientPrefs.data.quickFreeplay)
					icon = ensureSongIcon(song.sourceIndex, songText);
				if (icon != null)
				{
					icon.sprTracker = songText;
					icon.visible = icon.active = false;
					grpIcons.add(icon);
				}

				grpSongs.add(songText);
				displayIcons.push(icon);
				songs.push(song);
			}
			i++;
		}

		if (songs.length < 1)
			curSelected = -1;
		else
		{
			if (curSelected >= songs.length)
				curSelected = songs.length - 1;
		}

		if (!init)
		{
			changeSelection();
			updateTexts();
		}
	}

	function onKeyDown(e:KeyboardEvent)
	{
		if (!searchInputWait)
			return;

		var key = e.keyCode;

		if (key == 27)
		{
			closeSearchBar();
			return;
		}

		if (key == 13)
		{
			if (dropdownSelected >= 0 && dropdownSelected < dropdownItems.length
				&& dropdownItems[dropdownSelected].type == SONG)
			{
				selectDropdownItem();
			}
			else
			{
				closeSearchBar();
			}
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
			refreshDropdownVisuals();
			search();
			return;
		}

		var newText:String = String.fromCharCode(e.charCode);

		if (key == 86 && e.ctrlKey)
			newText = Clipboard.text;

		if (newText.length > 0)
		{
			searchString += newText;
			updateSearchBarDisplay();
			buildDropdownItems();
			refreshDropdownVisuals();
			search();
		}
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];

	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));

		randomText.x = ((randomText.targetY - lerpSelected) * randomText.distancePerItem.x) + randomText.startPosition.x;
		randomText.y = ((randomText.targetY - lerpSelected) * 1.3 * randomText.distancePerItem.y) + randomText.startPosition.y;

		var randomDist:Float = Math.abs(-1 - lerpSelected);
		randomText.visible = randomDist < _drawDistance;
		randomIcon.visible = randomText.visible;

		for (i in _lastVisibles)
		{
			if (i < grpSongs.members.length)
				grpSongs.members[i].visible = grpSongs.members[i].active = false;
			if (i < displayIcons.length && displayIcons[i] != null)
				displayIcons[i].visible = displayIcons[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			if (i >= grpSongs.members.length)
				continue;
			var item:Alphabet = grpSongs.members[i];
			if (item == null)
				continue;

			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = (i < displayIcons.length) ? displayIcons[i] : null;
			if (icon == null && i < songs.length && songs[i] != null && !songs[i].isCategoryHeader)
			{
				icon = ensureSongIcon(songs[i].sourceIndex, item);
				if (i < displayIcons.length)
					displayIcons[i] = icon;
				if (icon != null)
					grpIcons.add(icon);
			}
			if (icon != null)
			{
				icon.sprTracker = item;
				icon.visible = icon.active = true;
				icon.alpha = (i == curSelected) ? 1 : 0.6;
			}
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		FlxG.autoPause = ClientPrefs.data.autoPause;

		if (!stopMusicPlay && (FlxG.sound.music == null || !FlxG.sound.music.playing))
		{
			TitleState.playFreakyMusic();
		}

		super.destroy();
	}
}

typedef OriginalFreeplayStateParams =
{
	?fromResults:OriginalFromResultsParams
}

typedef OriginalFromResultsParams =
{
	var ?oldRank:ScoringRank;
	var playRankAnim:Bool;
	var newRank:ScoringRank;
	var songId:String;
	var difficultyId:String;
}

typedef DropdownItem =
{
	var type:DropdownItemType;
	var text:String;
	var songIndex:Int;
	var icon:String;
	var color:Int;
}

enum DropdownItemType
{
	HEADER;
	SONG;
}


class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;
	public var difficulties:Array<String> = null;
	public var chartsHydrated:Bool = false;
	public var isCategoryHeader:Bool = false;
	public var categoryId:String = "";
	public var collapsed:Bool = false;
	public var sourceIndex:Int = -1;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if (this.folder == null)
			this.folder = '';
	}

	public static function fromEntry(entry:backend.freeplay.FreeplayEntry):SongMetadata
	{
		var s = new SongMetadata(entry.songName, entry.weekIndex, entry.songCharacter, entry.color);
		s.folder = entry.folder != null ? entry.folder : '';
		if (entry.difficulties != null && entry.difficulties.length > 0)
			s.difficulties = entry.difficulties.copy();
		return s;
	}

	public static function makeHeader(id:String, label:String, collapsed:Bool):SongMetadata
	{
		var s = new SongMetadata(backend.freeplay.FreeplayCatalog.formatHeaderLabel(label, collapsed), 0, 'face', 0xFFFFD54A);
		s.isCategoryHeader = true;
		s.categoryId = id;
		s.collapsed = collapsed;
		s.folder = '';
		return s;
	}
}
