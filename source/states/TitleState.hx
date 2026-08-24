package states;

import backend.WeekData;

import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import haxe.Json;

import backend.AchievementSync;
import backend.AuthManager;

import backend.update.UpdateChecker;
import backend.update.UpdateConfig;
import states.UpdateState;
import StringTools;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import shaders.ColorSwap;

import states.StoryMenuState;
import states.MainMenuState;
import backend.modpack.StoreTypes.StoreModpackEntry;

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Float;
	
	@:optional var animation:String;
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	@:optional var idle:Bool;
}

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var titleBackground:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;
	
	var checkingUpdates:Bool = false;
	var updateCheckDone:Bool = false;
	var waitingForUpdateCheck:Bool = false;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	#if TITLE_SCREEN_EASTER_EGG
	final easterEggKeys:Array<String> = [
		'SHADOW', 'RIVEREN', 'BBPANZU', 'PESSY'
	];
	final allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	override public function create():Void
	{
		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();
		try {
			new FlxTimer().start(0.25, function(_) {
				try {
					startUnifiedUpdateCheck();
				} catch (e:Dynamic) {
					checkingUpdates = false;
					updateCheckDone = true;
					trace('[TitleState] Güncelleme kontrolü çökmeden atlandı: ' + e);
				}
				backend.modpack.ModImportQueue.poll();
				backend.modpack.ModImportQueue.considerPresenting();
			});
		} catch (e:Dynamic) {
			checkingUpdates = false;
			updateCheckDone = true;
			trace('[TitleState] Güncelleme zamanlayıcısı kurulamadı: ' + e);
		}

		if(!initialized)
		{
			ClientPrefs.loadPrefs();
			Language.reloadPhrases();
		}

		// AlertMgr, Main tarafından FlxGame'den sonra eklenir. Kısa gecikme hem
		// güvenli mod bildirimini hem pack.json uyumluluk uyarılarını garanti eder.
		new FlxTimer().start(0.55, function(_)
		{
			if (backend.SafeMode.consumeNotice())
			{
				objects.AlertMgr.AlertMsg.show(
					'Dikkat',
					'Oyunu Güvenli Mod (Shift) ile açtınız, oyun Modları yüklemeyecek, Çoğu özellik çalışmayacaktır,',
					10,
					objects.AlertMgr.AlertMessage.COLOR_WARNING
				);
			}
			else
				backend.ModCompatibility.checkEnabledMods();
		});

		curWacky = FlxG.random.getObject(getIntroTextShit());

		if(!initialized)
		{
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
				//trace('LOADED FULLSCREEN SETTING!!');
			}
			persistentUpdate = true;
			persistentDraw = true;
			MobileConfig.initDefault();
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}
		
		AuthManager.autoLogin(function(ok:Bool) {
			if (ok) {
				trace('[TitleState] Auto-login successful: ${AuthManager.currentUsername}');
			} else {
				trace('[TitleState] Auto-login failed or no saved session');
			}
		});

		FlxG.mouse.visible = false;
		#if FREEPLAY
		MenuStyleRouter.goToFreeplay();
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if (HelloState.shouldShow())
		{
			controls.isInSubstate = false;
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new HelloState());
		}
		else if(FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			controls.isInSubstate = false;
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
			startIntro();
		#end
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		persistentUpdate = true;
		if (!initialized && FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music(getMenuMusicName()), 0);

		loadJsonData();
		#if TITLE_SCREEN_EASTER_EGG easterEggData(); #end
		Conductor.bpm = musicBPM;

		// Intro starts from black, then Further Engine's title background fades in.
		// Both sprites stay alive after the intro so titlebg remains behind the
		// logo, GF and the "Press Enter" prompt.
		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		add(blackScreen);

		if (Paths.fileExists('images/further/titlebg.png', IMAGE))
		{
			titleBackground = new FlxSprite().loadGraphic(Paths.image('further/titlebg'));
			titleBackground.antialiasing = ClientPrefs.data.antialiasing;

			// Cover the whole screen without distorting the image.
			var bgScale:Float = Math.max(FlxG.width / titleBackground.width, FlxG.height / titleBackground.height);
			titleBackground.scale.set(bgScale, bgScale);
			titleBackground.updateHitbox();
			titleBackground.screenCenter();
			titleBackground.alpha = 0;
			add(titleBackground);
			FlxTween.tween(titleBackground, {alpha: 1}, 1.2, {ease: FlxEase.quadOut});
		}
		else
			trace('[TitleState] Missing assets/shared/images/further/titlebg.png; using black background.');

		logoBl = new FlxSprite(logoPosition.x, logoPosition.y);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.data.antialiasing;

		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		gfDance = new FlxSprite(gfPosition.x, gfPosition.y);
		gfDance.antialiasing = ClientPrefs.data.antialiasing;
		
		if(ClientPrefs.data.shaders)
		{
			swagShader = new ColorSwap();
			gfDance.shader = swagShader.shader;
			logoBl.shader = swagShader.shader;
		}
		
		gfDance.frames = Paths.getSparrowAtlas(characterImage);
		if(!useIdle)
		{
			gfDance.animation.addByIndices('danceLeft', animationName, danceLeftFrames, "", 24, false);
			gfDance.animation.addByIndices('danceRight', animationName, danceRightFrames, "", 24, false);
			gfDance.animation.play('danceRight');
		}
		else
		{
			gfDance.animation.addByPrefix('idle', animationName, 24, false);
			gfDance.animation.play('idle');
		}

		var animFrames:Array<FlxFrame> = [];
		titleText = new FlxSprite(enterPosition.x, enterPosition.y);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (newTitle = animFrames.length > 0)
		{
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		titleText.animation.play('idle');
		titleText.updateHitbox();

		// The actual title screen stays hidden while the intro credits play.
		// Previously the opaque black member of credGroup handled this.
		gfDance.visible = false;
		logoBl.visible = false;
		titleText.visible = false;

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.alpha = 0;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.antialiasing;

		add(gfDance);
		add(logoBl); //FNF Logo
		add(titleText); //"Press Enter to Begin" text
		add(credGroup);
		add(ngSpr);

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);
	}

	var characterImage:String = 'gfDanceTitle';
	var animationName:String = 'gfDance';

	var gfPosition:FlxPoint = FlxPoint.get(512, 40);
	var logoPosition:FlxPoint = FlxPoint.get(-150, -100);
	var enterPosition:FlxPoint = FlxPoint.get(100, 576);
	
	var useIdle:Bool = false;
	var musicBPM:Float = 102;
	var danceLeftFrames:Array<Int> = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29];
	var danceRightFrames:Array<Int> = [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

	function loadJsonData()
	{
		if(Paths.fileExists('images/gfDanceTitle.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('images/gfDanceTitle.json');
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:TitleData = tjson.TJSON.parse(titleRaw);
					gfPosition.set(titleJSON.gfx, titleJSON.gfy);
					logoPosition.set(titleJSON.titlex, titleJSON.titley);
					enterPosition.set(titleJSON.startx, titleJSON.starty);
					musicBPM = titleJSON.bpm;
					
					if(titleJSON.animation != null && titleJSON.animation.length > 0) animationName = titleJSON.animation;
					if(titleJSON.dance_left != null && titleJSON.dance_left.length > 0) danceLeftFrames = titleJSON.dance_left;
					if(titleJSON.dance_right != null && titleJSON.dance_right.length > 0) danceRightFrames = titleJSON.dance_right;
					useIdle = (titleJSON.idle == true);
	
					if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.trim().length > 0)
					{
						var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(titleJSON.backgroundSprite));
						bg.antialiasing = ClientPrefs.data.antialiasing;
						add(bg);
					}
				}
				catch(e:haxe.Exception)
				{
					trace('[WARN] Title JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else trace('[WARN] No Title JSON detected, using default values.');
		}
		//else trace('[WARN] No Title JSON detected, using default values.');
	}

	function easterEggData()
	{
		if (FlxG.save.data.psychDevsEasterEgg == null) FlxG.save.data.psychDevsEasterEgg = ''; //Crash prevention
		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		switch(easterEgg.toUpperCase())
		{
			case 'SHADOW':
				characterImage = 'ShadowBump';
				animationName = 'Shadow Title Bump';
				gfPosition.x += 210;
				gfPosition.y += 40;
				useIdle = true;
			case 'RIVEREN':
				characterImage = 'ZRiverBump';
				animationName = 'River Title Bump';
				gfPosition.x += 180;
				gfPosition.y += 40;
				useIdle = true;
			case 'BBPANZU':
				characterImage = 'BBBump';
				animationName = 'BB Title Bump';
				danceLeftFrames = [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27];
				danceRightFrames = [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
				gfPosition.x += 45;
				gfPosition.y += 100;
			case 'PESSY':
				characterImage = 'PessyBump';
				animationName = 'Pessy Title Bump';
				gfPosition.x += 165;
				gfPosition.y += 60;
				danceLeftFrames = [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
				danceRightFrames = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28];
		}
	}

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT || TouchUtil.justPressed;

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}
		
		if (newTitle) {
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		// EASTER EGG

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;
				
				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			
			if(pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;
				
				if(titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					if (updateCheckDone)
					{
						// Güncelleme kontrolü bitti, sonuca göre geç
						goToNextState();
					}
					else
					{
						// Güncelleme kontrolü hala devam ediyor, bekle
						waitingForUpdateCheck = true;
						trace('[TitleState] Güncelleme kontrolü bekleniyor...');
						// Timeout koruması (1.5 saniye) — Yavaş internetli oyuncuların takılı kalmasını önler!
						new FlxTimer().start(1.5, function(timeoutTmr:FlxTimer)
						{
							if (waitingForUpdateCheck)
							{
								waitingForUpdateCheck = false;
								trace('[TitleState] Güncelleme kontrolü zaman aşımına uğradı, ana menüye geçiliyor...');
								goToNextState();
							}
						});
					}
				});
			}
			#if TITLE_SCREEN_EASTER_EGG
			else if (FlxG.keys.firstJustPressed() != FlxKey.NONE)
			{
				var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
				var keyName:String = Std.string(keyPressed);
				if(allowedKeys.contains(keyName)) {
					easterEggKeysBuffer += keyName;
					if(easterEggKeysBuffer.length >= 32) easterEggKeysBuffer = easterEggKeysBuffer.substring(1);
					//trace('Test! Allowed Key pressed!!! Buffer: ' + easterEggKeysBuffer);

					for (wordRaw in easterEggKeys)
					{
						var word:String = wordRaw.toUpperCase(); //just for being sure you're doing it right
						if (easterEggKeysBuffer.contains(word))
						{
							//trace('YOOO! ' + word);
							if (FlxG.save.data.psychDevsEasterEgg == word)
								FlxG.save.data.psychDevsEasterEgg = '';
							else
								FlxG.save.data.psychDevsEasterEgg = word;
							FlxG.save.flush();

							FlxG.sound.play(Paths.sound('secret'));

							var black:FlxSprite = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
							black.scale.set(FlxG.width, FlxG.height);
							black.updateHitbox();
							black.alpha = 0;
							add(black);

							FlxTween.tween(black, {alpha: 1}, 1, {onComplete:
								function(twn:FlxTween) {
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									MusicBeatState.switchState(new TitleState());
								}
							});
							FlxG.sound.music.fadeOut();
							if(FreeplayState.vocals != null)
							{
								FreeplayState.vocals.fadeOut();
							}
							closedState = true;
							transitioning = true;
							playJingle = true;
							easterEggKeysBuffer = '';
							break;
						}
					}
				}
			}
			#end
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}
	
	function startUnifiedUpdateCheck():Void
	{
		if (checkingUpdates || updateCheckDone)
			return;

		if (!UpdateConfig.CHECK_ON_STARTUP)
		{
			updateCheckDone = true;
			return;
		}

		checkingUpdates = true;
		trace('[TitleState] Güncelleme kontrolü başlatılıyor...');
		try {
			backend.update.ReleaseChecker.check();
		} catch (e:Dynamic) {
			trace('[TitleState] ReleaseChecker atlandı: ' + e);
		}

		UpdateChecker.instance.onError = function(error:String)
		{
			checkingUpdates = false;
			updateCheckDone = true;
			// Ağ yoksa sessiz geç; sadece gerçek hataları yaz.
			if (error != null && error.indexOf("resolve host") == -1 && error.indexOf("Çevrimdışı") == -1)
				trace('[TitleState] Güncelleme kontrolü başarısız: $error');

			// Eğer kullanıcı enter'a basıp bekliyorsa, artık geçebilir
			if (waitingForUpdateCheck)
			{
				waitingForUpdateCheck = false;
				goToNextState();
			}
		};

		try {
		UpdateChecker.instance.fetchModpackList(function(result:backend.update.UpdateChecker.CheckResult)
		{
			checkingUpdates = false;
			updateCheckDone = true;

			if (result != null && result.hasUpdates)
			{
				trace('[TitleState] ${result.availableUpdates.length} güncelleme bulundu!');

				// Further Engine: otomatik popup YOK — rozet için bayrağı sakla
				UpdateChecker.instance.hasPendingModpackUpdates = true;
			}
			else if (!UpdateChecker.instance.lastFetchOk)
			{
				trace('[TitleState] Mağaza listesi alınamadı: ' + UpdateChecker.instance.lastError);
				UpdateChecker.instance.hasPendingModpackUpdates = false;
			}
			else
			{
				trace('[TitleState] Güncelleme yok.');
				UpdateChecker.instance.hasPendingModpackUpdates = false;
			}

			// Eğer kullanıcı enter'a basıp bekliyorsa, artık geçebilir
			if (waitingForUpdateCheck)
			{
				waitingForUpdateCheck = false;
				goToNextState();
			}
		});
		} catch (e:Dynamic) {
			checkingUpdates = false;
			updateCheckDone = true;
			trace('[TitleState] fetchModpackList atlandı: ' + e);
			if (waitingForUpdateCheck)
			{
				waitingForUpdateCheck = false;
				goToNextState();
			}
		}
	}
	
	function goToNextState():Void
	{
		// Further Engine: otomatik UpdatePromptState kaldırıldı —
		// güncelleme varsa MainMenuState'teki rozet haber verir, kurulum mağazadan yapılır.
		MenuStyleRouter.goToMainMenu();
		closedState = true;
	}

	static inline var INTRO_TEXT_SIZE:Int = 72;
	static inline var INTRO_TEXT_MIN_SIZE:Int = 40;
	static inline var INTRO_TEXT_SIDE_PADDING:Float = 48;
	static inline var INTRO_TEXT_GAP:Float = 12;
	static inline var INTRO_TEXT_TOP_PAD_MULT:Float = 1.1;
	static inline var INTRO_TEXT_LINE_HEIGHT_MULT:Float = 1.3;
	static inline var INTRO_TEXT_FADE_IN:Float = 0.45;
	static inline var INTRO_TEXT_FADE_OUT:Float = 0.35;

	function makeIntroText(text:String):FlxText
	{
		// title.ttf reports incorrect ascender metrics on some targets. A real
		// blank line above the text keeps the glyphs away from TextField's upper
		// clipping boundary; layoutIntroText compensates for this invisible pad.
		var introText:FlxText = new FlxText(0, 0, FlxG.width, '\n' + text, INTRO_TEXT_SIZE);
		introText.setFormat(Paths.font('AvantGuard-Bold.ttf'), INTRO_TEXT_SIZE, FlxColor.WHITE, CENTER);
		introText.antialiasing = ClientPrefs.data.antialiasing;
		introText.wordWrap = false;
		introText.autoSize = false;
		while (introText.textField.textWidth > FlxG.width - (INTRO_TEXT_SIDE_PADDING * 2)
			&& introText.size > INTRO_TEXT_MIN_SIZE)
		{
			introText.size -= 4;
		}

		// Enough room for both the invisible padding line and the visible line.
		introText.fieldHeight = Math.ceil(introText.size * 2.6);
		introText.updateHitbox();
		introText.alpha = 0;
		credGroup.add(introText);
		textGroup.add(introText);
		FlxTween.tween(introText, {alpha: 1}, INTRO_TEXT_FADE_IN, {ease: FlxEase.quadOut});
		return introText;
	}

	function layoutIntroText(?offset:Float = 0):Void
	{
		var texts:Array<FlxText> = [];
		var totalHeight:Float = 0;

		for (member in textGroup.members)
		{
			if (member == null) continue;
			var text:FlxText = cast member;
			texts.push(text);
			// Ignore the transparent safety area in fieldHeight while laying out.
			totalHeight += text.size * INTRO_TEXT_LINE_HEIGHT_MULT;
		}

		if (texts.length > 1)
			totalHeight += (texts.length - 1) * INTRO_TEXT_GAP;

		var nextY:Float = (FlxG.height - totalHeight) * 0.5 + offset;
		for (text in texts)
		{
			// Pull the padded TextField upward so its visible second line starts
			// at nextY. The glyph itself still has a full blank line above it.
			text.y = nextY - (text.size * INTRO_TEXT_TOP_PAD_MULT);
			nextY += (text.size * INTRO_TEXT_LINE_HEIGHT_MULT) + INTRO_TEXT_GAP;
		}
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		if (credGroup == null || textGroup == null) return;
		for (text in textArray) makeIntroText(text);
		layoutIntroText(offset);
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if (textGroup == null || credGroup == null) return;
		makeIntroText(text);
		layoutIntroText(offset);
	}

	function deleteCoolText()
	{
		if (textGroup == null || credGroup == null) return;

		// Stop tracking immediately so the next beat can create a fresh set,
		// while the previous set finishes fading out visually.
		var oldTexts:Array<FlxText> = [];
		for (member in textGroup.members)
			if (member != null) oldTexts.push(cast member);
		textGroup.clear();

		for (text in oldTexts)
		{
			FlxTween.cancelTweensOf(text);
			FlxTween.tween(text, {alpha: 0}, INTRO_TEXT_FADE_OUT, {
				ease: FlxEase.quadIn,
				onComplete: function(_)
				{
					credGroup.remove(text, true);
					text.destroy();
				}
			});
		}
	}

	function showNewgroundsLogo():Void
	{
		if (ngSpr == null) return;
		FlxTween.cancelTweensOf(ngSpr);
		ngSpr.alpha = 0;
		ngSpr.visible = true;
		FlxTween.tween(ngSpr, {alpha: 1}, INTRO_TEXT_FADE_IN, {ease: FlxEase.quadOut});
	}

	function hideNewgroundsLogo():Void
	{
		if (ngSpr == null || !ngSpr.visible) return;
		FlxTween.cancelTweensOf(ngSpr);
		FlxTween.tween(ngSpr, {alpha: 0}, INTRO_TEXT_FADE_OUT, {
			ease: FlxEase.quadIn,
			onComplete: function(_)
			{
				ngSpr.visible = false;
			}
		});
	}

	private var sickBeats:Int = 0;
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		if(gfDance != null)
		{
			danceLeft = !danceLeft;
			if(!useIdle)
			{
				if (danceLeft)
					gfDance.animation.play('danceRight');
				else
					gfDance.animation.play('danceLeft');
			}
			else if(curBeat % 2 == 0) gfDance.animation.play('idle', true);
		}

		if(!closedState)
		{
			sickBeats++;
			var isTR:Bool = ClientPrefs.data.language == 'tr-TR';
			
			switch (sickBeats)
			{
				case 1:
					FlxG.sound.playMusic(Paths.music(getMenuMusicName()), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					createCoolText([isTR ? 'PSYCH ENGİNE YAPIMCILARI' : 'Psych Engine by'], 40);
				case 4:
					addMoreText('SHADOW MARİO', 40);
					addMoreText('RİVEREN', 40);
				case 5:
					deleteCoolText();
				case 6:
					if (isTR)
						createCoolText(['NEWGROUNDS', 'İLE'], -40);
					else
						createCoolText(['NOT ASSOCIATED', 'WITH'], -40);
				case 8:
					addMoreText(isTR ? 'ALAKASI YOKTUR' : 'newgrounds', -40);
					showNewgroundsLogo();
				case 9:
					deleteCoolText();
					hideNewgroundsLogo();
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('FURTHER');
				case 15:
					addMoreText('ENGİNE');
				case 16:
					addMoreText('FUH YEAHH');
				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;

	function revealTitleScreen():Void
	{
		if (gfDance != null) gfDance.visible = true;
		if (logoBl != null) logoBl.visible = true;
		if (titleText != null) titleText.visible = true;
	}

	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			#if TITLE_SCREEN_EASTER_EGG
			if (playJingle) //Ignore deez
			{
				playJingle = false;
				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:FlxSound = null;
				switch(easteregg)
				{
					case 'RIVEREN':
						sound = FlxG.sound.play(Paths.sound('JingleRiver'));
					case 'SHADOW':
						FlxG.sound.play(Paths.sound('JingleShadow'));
					case 'BBPANZU':
						sound = FlxG.sound.play(Paths.sound('JingleBB'));
					case 'PESSY':
						sound = FlxG.sound.play(Paths.sound('JinglePessy'));

					default: //Go back to normal ugly ass boring GF
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 2);
						skippedIntro = true;

						FlxG.sound.playMusic(Paths.music(getMenuMusicName()), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						revealTitleScreen();
						return;
				}

				transitioning = true;
				if(easteregg == 'SHADOW')
				{
					new FlxTimer().start(3.2, function(tmr:FlxTimer)
					{
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 0.6);
						transitioning = false;
					});
				}
				else
				{
					remove(ngSpr);
					remove(credGroup);
					FlxG.camera.flash(FlxColor.WHITE, 3);
					sound.onComplete = function() {
						FlxG.sound.playMusic(Paths.music(getMenuMusicName()), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						transitioning = false;
						#if ACHIEVEMENTS_ALLOWED
						if(easteregg == 'PESSY') Achievements.unlock('pessy_easter_egg');
						#end
					};
				}
			}
			else #end //Default! Edit this one!!
			{
				remove(ngSpr);
				remove(credGroup);
				FlxG.camera.flash(FlxColor.WHITE, 4);

				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();
				#if TITLE_SCREEN_EASTER_EGG
				if(easteregg == 'SHADOW')
				{
					FlxG.sound.music.fadeOut();
					if(FreeplayState.vocals != null)
					{
						FreeplayState.vocals.fadeOut();
					}
				}
				#end
			}
			revealTitleScreen();
			skippedIntro = true;
		}
	}
	
	public static function getMenuMusicName():String
	{
		var selected:String = ClientPrefs.data.menuMusic;
		if (selected == null || selected.length == 0 || selected == 'Varsayılan')
			return 'freakyMenu';

		if (selected == 'nothing')
			return null;

		if (StringTools.startsWith(selected, 'mod:'))
		{
			var modName:String = selected.substr(4);
			#if MODS_ALLOWED
			Mods.currentModDirectory = modName;
			#end
			return 'freakyMenu';
		}

		return selected;
	}

	public static function playFreakyMusic(?vol:Float = 0, ?fadeIn:Bool = true)
	{
		var musicName:String = getMenuMusicName();

		if (musicName == null)
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();

			#if MODS_ALLOWED
			Mods.loadTopMod();
			#end
			return;
		}

		if (StringTools.startsWith(ClientPrefs.data.menuMusic, 'mod:'))
		{
			var modName:String = ClientPrefs.data.menuMusic.substr(4);
			#if MODS_ALLOWED
			Mods.currentModDirectory = modName;
			#end
		}

		FlxG.sound.playMusic(Paths.music(musicName), vol);

		if (fadeIn)
			FlxG.sound.music.fadeIn(4, 0, 0.7);

		#if MODS_ALLOWED
		Mods.loadTopMod();
		#end
	}
}
