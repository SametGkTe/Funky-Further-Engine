package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.input.touch.FlxTouch;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import backend.Paths;
import backend.ClientPrefs;
import backend.InputFormatter;
import backend.Language;
import backend.PerformanceProfiler;
import backend.PerformanceProfile;
import backend.AudioMixer;
import backend.Log;
import objects.ProfileBox;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Shape;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.media.Sound;

class SetupWizardState extends MusicBeatState
{
	static inline var SIDE_PAD:Float = 80;
	static inline var SECTION_GAP:Float = 60;
	static inline var TITLE_GAP:Float = 22;
	static inline var CARD_GAP:Float = 24;
	static inline var LANG_CARD_W:Float = 300;
	static inline var LANG_CARD_H:Float = 180;
	static inline var PERF_CARD_W:Float = 300;
	static inline var PERF_CARD_H:Float = 220;
	static inline var LOGIN_CARD_H:Float = 130;
	static inline var SKIP_CARD_W:Float = 200;
	static inline var FINISH_BTN_H:Float = 90;
	static inline var SCROLLBAR_W:Int = 8;
	static inline var SCROLL_SPEED:Float = 80.0;
	static inline var SCROLL_LERP:Float = 0.14;
	static inline var SCROLLBAR_FADE:Float = 0.6;
	static inline var CARD_RADIUS:Float = 22;
	static inline var BORDER_W:Float = 4;
	static inline var DRAG_THRESHOLD:Float = 12;
	static inline var FLING_STRENGTH:Float = 14;
	static inline var CTRL_CARD_W:Float = 480;
	static inline var CTRL_CARD_H:Float = 300;
	static inline var PAD_SCROLL_SPEED:Float = 420;
	static inline var BG_DARKEN:Int = 0x96000000;
	static inline var WIZ_FONT:String = 'assets/fonts/vcr.ttf';
	static inline var PROFILE_BOX_W:Float = 330;
	static inline var PROFILE_BOX_H:Float = 108;

	public static var returnToWizard:Bool = false;
	public static var debugMode:Bool = false;
	static var wizardMusicActive:Bool = false;

	static var LANG_DEFS:Array<{code:String, name:String, flag:String, ?flagImg:String}> = [
		{code: 'tr-TR', name: 'TÜRKÇE',    flag: '🇹🇷', flagImg: 'further/wizard/flag_tr'},
		{code: 'en-US', name: 'ENGLISH',   flag: '🇺🇸', flagImg: 'further/wizard/flag_us'},
		{code: 'pt-BR', name: 'PORTUGUÊS', flag: '🇧🇷', flagImg: 'further/wizard/flag_br'}
	];

	static var PERF_DEFS:Array<{id:PerformanceProfile, name:String, sub:String, color:Int, icon:String, ?iconImg:String}> = [
		{id: PERFORMANCE, name: 'DÜŞÜK KALİTE',  sub: 'Genel cihazlar, Eski Telefonlar\nGölgeler ve anti-aliasing kapalı', color: 0xFFE74C3C, icon: '⚡', iconImg: 'further/wizard/perf_low'},
		{id: BALANCED,    name: 'ORTA KALİTE',   sub: 'Ortalama bilgisayar / telefon\nGölgeler kapalı', color: 0xFFF39C12, icon: '⚖', iconImg: 'further/wizard/perf_medium'},
		{id: HIGH,        name: 'YÜKSEK KALİTE', sub: 'Güçlü PC / Yeni telefon\nTüm Kalite ayarları açık', color: 0xFF2ECC71, icon: '✨', iconImg: 'further/wizard/perf_high'}
	];

	static inline var FLAG_ICON_SIZE:Float = 80;
	static inline var PERF_ICON_SIZE:Float = 56;
	static inline var PERF_IMG_OVERLAY:Int = 0x660F0A1E;

	static var CTRL_DEFS:Array<{name:String, img:String}> = [
		{name: 'HİTBOX', img: 'further/wizard/ctrl_hitbox'},
		{name: 'V-SLICE KONTROLÜ', img: 'further/wizard/ctrl_vslice'}
	];

	static var TOUCH_DEFS:Array<{name:String, sub:String, color:Int, icon:String, ?iconImg:String}> = [
		{name: 'TUŞLU',      sub: 'Menülerde mobil tuşlar\nbutonlar ve ok padleri', color: 0xFF3498DB, icon: '⌨', iconImg: 'further/wizard/ui_buttons'},
		{name: 'DOKUNMATİK', sub: 'Komple dokunmatik. Kaydırma vs.\nBazı Mobil Tuşlar korunur\nSadece GERİ butonu', color: 0xFF2ECC71, icon: '👆', iconImg: 'further/wizard/ui_touch'}
	];

	var selectedLang:Int = 0;
	var selectedPerf:Int = 1;
	var selectedTouch:Int = 0;
	var selectedCtrl:Int = 0;
	var loggedIn:Bool = false;
	var loginSkipped:Bool = false;

	var bg:FlxSprite;
	var bgDark:FlxSprite;
	var glow:FlxSprite;

	var scrollY:Float = 0;
	var targetScrollY:Float = 0;
	var maxScrollY:Float = 0;
	var totalContentHeight:Float = 0;
	var scrollBar:FlxSprite;
	var scrollBarBg:FlxSprite;
	var scrollHintText:FlxText;
	var scrollHintArrow:FlxSprite;
	var scrollHintArrowY:Float = 0;
	var scrollBarAlpha:Float = 0;
	var scrollBarTimer:Float = 0;
	var scrollBarVisible:Bool = false;
	var scrollBarFading:Bool = false;
	var scrollBarTween:FlxTween;
	var clipTop:Float = 0;
	var clipBottom:Float;

	var ptrWasDown:Bool = false;
	var ptrX:Float = 0;
	var ptrY:Float = 0;
	var dragStartY:Float = 0;
	var dragLastY:Float = 0;
	var dragMoved:Bool = false;
	var dragVel:Float = 0;

	var allElements:Array<ContentElement> = [];
	var introFade:Float = 0;

	var langCards:Array<Card> = [];
	var perfCards:Array<Card> = [];
	var touchCards:Array<Card> = [];
	var ctrlCards:Array<Card> = [];
	var ctrlDots:Array<{on:FlxSprite, off:FlxSprite}> = [];
	var keyBoxes:Array<{action:String, border:FlxSprite, hit:FlxSprite, keyText:FlxText}> = [];
	var listeningKey:Int = -1;
	var profileBox:ProfileBox;
	var profileBoxY:Float = 0;
	var loginCard:Card;
	var skipCard:Card;
	var finishCard:Card;

	var taglineText:FlxText;
	var sectionTexts:Array<FlxText> = [];
	var loginTitleText:FlxText;
	var loginSubText:FlxText;
	var skipText:FlxText;
	var skipSubText:FlxText;
	var finishTitleText:FlxText;
	var finishSubText:FlxText;

	var closing:Bool = false;

	override function create():Void
	{
		super.create();
		flixel.FlxG.mouse.visible = true;
		clipBottom = FlxG.height;
		returnToWizard = false;

		bg = new FlxSprite();
		var bgLoaded:Bool = false;
		try
		{
			bg.loadGraphic(Paths.image('further/wizard/blurred'));
			bgLoaded = true;
		}
		catch (e:Dynamic) { bgLoaded = false; }
		if (bgLoaded && bg.width > 0)
		{
			var bgScale:Float = Math.max(FlxG.width / bg.width, FlxG.height / bg.height);
			bg.scale.set(bgScale, bgScale);
			bg.updateHitbox();
			bg.screenCenter();
		}
		else
		{
			bg.makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), 0xFF0F0A1E);
		}
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		add(bg);

		bgDark = new FlxSprite().makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), BG_DARKEN);
		bgDark.scrollFactor.set();
		add(bgDark);

		glow = new FlxSprite().makeGraphic(Std.int(FlxG.width), 400, 0x33A05AFF);
		glow.scrollFactor.set();
		add(glow);

		selectedPerf = 0;
		selectedLang = detectInitialLang();
		selectedCtrl = ClientPrefs.data.ogGameControls ? 1 : 0;

		loggedIn = backend.AuthManager.isLoggedIn;

		if (!wizardMusicActive)
		{
			var wizMusic:Sound = Paths.returnSound('music/breakfast', null, true, false);
			if (wizMusic == null)
			{
				Log.warn('wizard', 'Müzik bulunamadi: assets/shared/music/further/wizard_theme.ogg');
				wizMusic = Paths.returnSound('music/freakyMenu', null, true, false);
			}
			if (wizMusic != null)
			{
				FlxG.sound.playMusic(wizMusic, 0.7, true);
				wizardMusicActive = true;
			}
		}

		buildContent();

		if (profileBox != null)
		{
			remove(profileBox);
			add(profileBox);
			profileBox.alpha = 0;
			FlxTween.num(0, 1, 0.5, {ease: FlxEase.quadOut}, function(v)
			{
				if (profileBox != null) profileBox.alpha = v;
			});
		}

		scrollBarBg = new FlxSprite().makeGraphic(SCROLLBAR_W, Std.int(FlxG.height - 40), 0x55302A3A);
		scrollBarBg.scrollFactor.set();
		scrollBarBg.x = FlxG.width - SCROLLBAR_W - 12;
		scrollBarBg.y = 20;
		scrollBarBg.alpha = 0;
		add(scrollBarBg);

		scrollBar = new FlxSprite().makeGraphic(SCROLLBAR_W, 60, 0xFFCA66FF);
		scrollBar.scrollFactor.set();
		scrollBar.x = scrollBarBg.x;
		scrollBar.y = 20;
		scrollBar.alpha = 0;
		add(scrollBar);

		scrollHintText = new FlxText(0, 24, 0, tl('wizard_scroll_hint', 'Aşağı Kaydır'));
		scrollHintText.setFormat(WIZ_FONT, 18, FlxColor.WHITE, RIGHT);
		scrollHintText.antialiasing = ClientPrefs.data.antialiasing;
		scrollHintText.x = FlxG.width - scrollHintText.width - 40;
		add(scrollHintText);

		var arrowGraphic = Paths.image('further/wizard/arrow');
		if (arrowGraphic != null)
		{
			scrollHintArrow = new FlxSprite();
			scrollHintArrow.loadGraphic(arrowGraphic);
			var arrowScale:Float = 40 / scrollHintArrow.height;
			scrollHintArrow.setGraphicSize(Std.int(scrollHintArrow.width * arrowScale), 40);
			scrollHintArrow.updateHitbox();
			scrollHintArrow.antialiasing = ClientPrefs.data.antialiasing;
			scrollHintArrow.x = scrollHintText.x + (scrollHintText.width - scrollHintArrow.width) / 2;
			scrollHintArrowY = scrollHintText.y + scrollHintText.height + 8;
			scrollHintArrow.y = scrollHintArrowY;
			add(scrollHintArrow);
			FlxTween.tween(scrollHintArrow, {y: scrollHintArrowY + 14}, 0.7, {type: PINGPONG, ease: FlxEase.sineInOut});
		}
		else
			Log.warn('wizard', 'PNG bulunamadi: images/further/wizard/arrow.png');

		updatePositions();
		updateCardVisuals();

		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('UP_DOWN', 'NONE');
		addTouchPadCamera();
		#end

		for (el in allElements)
			el.sprite.alpha = 0;
		FlxTween.num(0, 1, 0.5, {ease: FlxEase.quadOut}, function(v)
		{
			introFade = v;
			for (el in allElements)
				el.sprite.alpha = el.baseAlpha * v;
		});
	}

	function detectInitialLang():Int
	{
		var curLang = ClientPrefs.data.language;
		if (curLang != null && curLang.length > 0)
		{
			for (i in 0...LANG_DEFS.length)
				if (LANG_DEFS[i].code == curLang) return i;
		}
		#if sys
		var sysLang = Sys.getEnv("LANG");
		if (sysLang != null)
		{
			var low = sysLang.toLowerCase();
			if (low.startsWith('tr')) return 0;
			if (low.startsWith('pt')) return 2;
			if (low.startsWith('en')) return 1;
		}
		#end
		return 0;
	}


	function buildContent():Void
	{
		allElements = [];
		langCards = [];
		perfCards = [];
		touchCards = [];
		ctrlCards = [];
		ctrlDots = [];
		keyBoxes = [];
		listeningKey = -1;
		sectionTexts = [];

		var cx:Float = FlxG.width / 2;
		var curY:Float = 50;

		var logo:FlxSprite = null;
		try { logo = new FlxSprite().loadGraphic(Paths.image('fe')); }
		catch (e:Dynamic) { logo = null; }
		if (logo == null)
			logo = new FlxSprite().makeGraphic(120, 120, 0xFFB14AFF);
		var logoScale = Math.min(160 / logo.width, 160 / logo.height);
		if (logoScale > 1) logoScale = 1;
		logo.scale.set(logoScale, logoScale);
		logo.updateHitbox();
		logo.antialiasing = ClientPrefs.data.antialiasing;
		addAt(logo, curY, cx - logo.width / 2);
		curY += logo.height + 20;

		var furtherText = new FlxText(0, 0, FlxG.width, 'FURTHER');
		furtherText.setFormat(WIZ_FONT, 88, 0xFFB14AFF, CENTER);
		furtherText.antialiasing = ClientPrefs.data.antialiasing;
		addAt(furtherText, curY, 0);
		curY += 100;

		var engineText = new FlxText(0, 0, FlxG.width, 'ENGINE');
		engineText.setFormat(WIZ_FONT, 72, FlxColor.WHITE, CENTER);
		engineText.antialiasing = ClientPrefs.data.antialiasing;
		addAt(engineText, curY, 0);
		curY += 82;

		taglineText = new FlxText(0, 0, FlxG.width, '');
		taglineText.setFormat(WIZ_FONT, 24, 0xFFB0B0C0, CENTER);
		taglineText.antialiasing = ClientPrefs.data.antialiasing;
		taglineText.text = tl('wizard_tagline', 'Engine\'i sana göre ayarlayalım!');
		addAt(taglineText, curY, 0);
		curY += 40;

		var sep = new FlxSprite().makeGraphic(Std.int(FlxG.width - 300), 3, 0x446B46C1);
		addAt(sep, curY, cx - sep.width / 2);
		curY += 3 + SECTION_GAP;

		curY = addSectionTitle('wizard_lang_title', '1.  DİLİNİZİ SEÇİN', curY);

		var langCardY:Float = curY;
		var totalCardsW = LANG_DEFS.length * LANG_CARD_W + (LANG_DEFS.length - 1) * CARD_GAP;
		var startX = cx - totalCardsW / 2;
		for (i in 0...LANG_DEFS.length)
		{
			var def = LANG_DEFS[i];
			var cardX = startX + i * (LANG_CARD_W + CARD_GAP);

			var cardBg = buildRoundedCard(LANG_CARD_W, LANG_CARD_H, 0xFF241A3C);
			var cardBorder = buildRoundedCard(LANG_CARD_W + BORDER_W * 2, LANG_CARD_H + BORDER_W * 2, 0xFFea71fd);
			cardBorder.alpha = 0;
			addAt(cardBorder, langCardY - BORDER_W, cardX - BORDER_W);
			addAt(cardBg, langCardY, cardX);

			var flagIcon = buildCardIcon(def.flagImg, def.flag, FLAG_ICON_SIZE, FlxColor.WHITE, 64);
			addAt(flagIcon, langCardY + 20 + (110 - 20 - flagIcon.height) / 2, cardX + (LANG_CARD_W - flagIcon.width) / 2);

			var nameText = new FlxText(0, 0, LANG_CARD_W, def.name);
			nameText.setFormat(WIZ_FONT, 26, FlxColor.WHITE, CENTER);
			nameText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(nameText, langCardY + 110, cardX);

			var hit = new FlxSprite(cardX, langCardY).makeGraphic(Std.int(LANG_CARD_W), Std.int(LANG_CARD_H), 0x00FFFFFF);
			addAt(hit, langCardY, cardX);

			langCards.push({bg: cardBg, border: cardBorder, hit: hit});
		}
		curY = langCardY + LANG_CARD_H + SECTION_GAP;

		curY = addSectionTitle('wizard_perf_title', '1.2  PERFORMANS PROFİLİ', curY);

		totalCardsW = PERF_DEFS.length * PERF_CARD_W + (PERF_DEFS.length - 1) * CARD_GAP;
		startX = cx - totalCardsW / 2;
		var perfCardY:Float = curY;
		for (i in 0...PERF_DEFS.length)
		{
			var def = PERF_DEFS[i];
			var cardX = startX + i * (PERF_CARD_W + CARD_GAP);

			var perfImg = def.iconImg != null ? Paths.image(def.iconImg, null, false) : null;
			if (perfImg != null)
				trace('[wizard] perf gorsel OK: ${def.iconImg} ${perfImg.bitmap.width}x${perfImg.bitmap.height}');
			else
				trace('[wizard] perf gorsel YUKLENEMEDI: ${def.iconImg}');
			var cardBg:FlxSprite;
			if (perfImg != null)
			{
				cardBg = buildImageCard(PERF_CARD_W, PERF_CARD_H, perfImg, PERF_IMG_OVERLAY);
			}
			else
			{
				if (def.iconImg != null)
					Log.warn('wizard', 'Performans gorseli bulunamadi: images/${def.iconImg}.png');
				cardBg = buildRoundedCard(PERF_CARD_W, PERF_CARD_H, 0xFF241A3C);
			}

			var cardBorder = buildRoundedCard(PERF_CARD_W + BORDER_W * 2, PERF_CARD_H + BORDER_W * 2, def.color);
			cardBorder.alpha = 0;
			addAt(cardBorder, perfCardY - BORDER_W, cardX - BORDER_W);
			addAt(cardBg, perfCardY, cardX);

			if (perfImg == null)
			{
				var perfIcon = buildCardIcon(def.iconImg, def.icon, PERF_ICON_SIZE, FlxColor.fromInt(def.color), 48);
				addAt(perfIcon, perfCardY + 22 + (90 - 22 - perfIcon.height) / 2, cardX + (PERF_CARD_W - perfIcon.width) / 2);
			}

			var nameText = new FlxText(0, 0, PERF_CARD_W, def.name);
			nameText.setFormat(WIZ_FONT, 22, FlxColor.WHITE, CENTER);
			nameText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(nameText, perfCardY + 90, cardX);

			var subText = new FlxText(0, 0, PERF_CARD_W - 40, def.sub);
			subText.setFormat(WIZ_FONT, 14, 0xFFC0C0D0, CENTER);
			subText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(subText, perfCardY + 125, cardX + 20);

			var hit = new FlxSprite(cardX, perfCardY).makeGraphic(Std.int(PERF_CARD_W), Std.int(PERF_CARD_H), 0x00FFFFFF);
			addAt(hit, perfCardY, cardX);

			perfCards.push({bg: cardBg, border: cardBorder, hit: hit});
		}
		curY = perfCardY + PERF_CARD_H + SECTION_GAP;

		#if mobile
		curY = addSectionTitle('wizard_ctouch_title', '1.3  KONTROLLER', curY);

		totalCardsW = TOUCH_DEFS.length * PERF_CARD_W + (TOUCH_DEFS.length - 1) * CARD_GAP;
		startX = cx - totalCardsW / 2;
		var touchCardY:Float = curY;
		for (i in 0...TOUCH_DEFS.length)
		{
			var def = TOUCH_DEFS[i];
			var cardX = startX + i * (PERF_CARD_W + CARD_GAP);

			var cardBg = buildRoundedCard(PERF_CARD_W, PERF_CARD_H, 0xFF241A3C);
			var cardBorder = buildRoundedCard(PERF_CARD_W + BORDER_W * 2, PERF_CARD_H + BORDER_W * 2, def.color);
			cardBorder.alpha = 0;
			addAt(cardBorder, touchCardY - BORDER_W, cardX - BORDER_W);
			addAt(cardBg, touchCardY, cardX);

			var touchIcon = buildCardIcon(def.iconImg, def.icon, PERF_ICON_SIZE, FlxColor.fromInt(def.color), 48);
			addAt(touchIcon, touchCardY + 22 + (90 - 22 - touchIcon.height) / 2, cardX + (PERF_CARD_W - touchIcon.width) / 2);

			var nameText = new FlxText(0, 0, PERF_CARD_W, def.name);
			nameText.setFormat(WIZ_FONT, 22, FlxColor.WHITE, CENTER);
			nameText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(nameText, touchCardY + 90, cardX);

			var subText = new FlxText(0, 0, PERF_CARD_W - 40, def.sub);
			subText.setFormat(WIZ_FONT, 14, 0xFFC0C0D0, CENTER);
			subText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(subText, touchCardY + 125, cardX + 20);

			var hit = new FlxSprite(cardX, touchCardY).makeGraphic(Std.int(PERF_CARD_W), Std.int(PERF_CARD_H), 0x00FFFFFF);
			addAt(hit, touchCardY, cardX);

			touchCards.push({bg: cardBg, border: cardBorder, hit: hit});
		}
		curY = touchCardY + PERF_CARD_H + SECTION_GAP;

		curY = addSectionTitle('wizard_ctrl_title', '1.4  OYUN-İÇİ KONTROL', curY);

		totalCardsW = CTRL_DEFS.length * CTRL_CARD_W + (CTRL_DEFS.length - 1) * CARD_GAP;
		startX = cx - totalCardsW / 2;
		var ctrlDotY:Float = curY;
		var ctrlCardY:Float = curY + 64;
		for (i in 0...CTRL_DEFS.length)
		{
			var def = CTRL_DEFS[i];
			var cardX = startX + i * (CTRL_CARD_W + CARD_GAP);
			var dotCenterX:Float = cardX + CTRL_CARD_W / 2;

			var dotOn = buildCircle(26, 0xFFCA66FF, true);
			var dotOff = buildCircle(26, 0xFF6B46C1, false);
			addAt(dotOn, ctrlDotY, dotCenterX - 13);
			addAt(dotOff, ctrlDotY, dotCenterX - 13);

			var link = new FlxSprite().makeGraphic(3, 24, 0xFF6B46C1);
			addAt(link, ctrlDotY + 32, dotCenterX - 1.5);

			var cardBg = buildRoundedCard(CTRL_CARD_W, CTRL_CARD_H, 0xFF241A3C);
			var cardBorder = buildRoundedCard(CTRL_CARD_W + BORDER_W * 2, CTRL_CARD_H + BORDER_W * 2, 0xFFCA66FF);
			cardBorder.alpha = 0;
			addAt(cardBorder, ctrlCardY - BORDER_W, cardX - BORDER_W);
			addAt(cardBg, ctrlCardY, cardX);

			var shotW:Float = CTRL_CARD_W - 60;
			var shotH:Float = CTRL_CARD_H - 104;
			var shotGraphic = Paths.image(def.img);
			var shot:FlxSprite;
			if (shotGraphic != null)
			{
				shot = new FlxSprite();
				shot.loadGraphic(shotGraphic);
				var shotScale:Float = Math.min(shotW / shot.width, shotH / shot.height);
				shot.scale.set(shotScale, shotScale);
				shot.updateHitbox();
				shot.antialiasing = ClientPrefs.data.antialiasing;
			}
			else
			{
				Log.warn('wizard', 'Onizleme PNG bulunamadi: images/${def.img}.png');
				shot = buildRoundedCard(shotW, shotH, 0xFF1A1230);
			}
			addAt(shot, ctrlCardY + 24, cardX + (CTRL_CARD_W - shot.width) / 2);

			if (shotGraphic == null)
			{
				var phText = new FlxText(0, 0, shotW, def.name);
				phText.setFormat(WIZ_FONT, 20, 0xFF808090, CENTER);
				phText.antialiasing = ClientPrefs.data.antialiasing;
				addAt(phText, ctrlCardY + 24 + (shotH - 30) / 2, cardX + 30);
			}

			var ctrlName = new FlxText(0, 0, CTRL_CARD_W, def.name);
			ctrlName.setFormat(WIZ_FONT, 26, FlxColor.WHITE, CENTER);
			ctrlName.antialiasing = ClientPrefs.data.antialiasing;
			addAt(ctrlName, ctrlCardY + CTRL_CARD_H - 64, cardX);

			var ctrlHit = new FlxSprite(cardX, ctrlCardY).makeGraphic(Std.int(CTRL_CARD_W), Std.int(CTRL_CARD_H), 0x00FFFFFF);
			addAt(ctrlHit, ctrlCardY, cardX);

			ctrlCards.push({bg: cardBg, border: cardBorder, hit: ctrlHit});
			ctrlDots.push({on: dotOn, off: dotOff});
		}
		curY = ctrlCardY + CTRL_CARD_H + SECTION_GAP;
		#else
		curY = addSectionTitle('wizard_keys_title', '1.3  TUŞ AYARLARI', curY);

		var keysCardH:Float = 150;
		var keysBg = buildRoundedCard(FlxG.width - SIDE_PAD * 2, keysCardH, 0xFF241A3C);
		addAt(keysBg, curY, SIDE_PAD);

		var keyActions:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];
		var keyLabels:Array<String> = ['SOL', 'AŞAĞI', 'YUKARI', 'SAĞ'];
		var keyBoxW:Float = 200;
		var keyBoxH:Float = 90;
		var keyGapX:Float = (FlxG.width - SIDE_PAD * 2 - keyBoxW * 4) / 5;
		for (i in 0...4)
		{
			var keyBoxX:Float = SIDE_PAD + keyGapX + i * (keyBoxW + keyGapX);
			var keyBoxY:Float = curY + 30;

			var kBg = buildRoundedCard(keyBoxW, keyBoxH, 0xFF1A1230);
			var kBorder = buildRoundedCard(keyBoxW + BORDER_W * 2, keyBoxH + BORDER_W * 2, 0xFFCA66FF);
			kBorder.alpha = 0;
			addAt(kBorder, keyBoxY - BORDER_W, keyBoxX - BORDER_W);
			addAt(kBg, keyBoxY, keyBoxX);

			var dirText = new FlxText(0, 0, keyBoxW, keyLabels[i]);
			dirText.setFormat(WIZ_FONT, 14, 0xFFB0B0C0, CENTER);
			dirText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(dirText, keyBoxY + 12, keyBoxX);

			var keyText = new FlxText(0, 0, keyBoxW, '');
			keyText.setFormat(WIZ_FONT, 24, FlxColor.WHITE, CENTER);
			keyText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(keyText, keyBoxY + 38, keyBoxX);

			var kHit = new FlxSprite(keyBoxX, keyBoxY).makeGraphic(Std.int(keyBoxW), Std.int(keyBoxH), 0x00FFFFFF);
			addAt(kHit, keyBoxY, keyBoxX);

			keyBoxes.push({action: keyActions[i], border: kBorder, hit: kHit, keyText: keyText});
		}
		refreshKeyTexts();
		curY += keysCardH + SECTION_GAP;
		#end

		curY = addSectionTitle('wizard_account_title', '2.  OYUNA GİRİŞ YAP', curY);

		var loginCardW:Float = FlxG.width - SIDE_PAD * 2 - SKIP_CARD_W - CARD_GAP;
		var loginCardX:Float = SIDE_PAD;
		var loginCardY:Float = curY;

		if (loggedIn)
		{
			var pbX:Float = SIDE_PAD + (FlxG.width - SIDE_PAD * 2 - PROFILE_BOX_W) / 2;
			profileBoxY = loginCardY + (LOGIN_CARD_H - PROFILE_BOX_H) / 2;
			profileBox = new ProfileBox(pbX, profileBoxY);
			profileBox.noStateSwitch = true;
			add(profileBox);
		}
		else
		{
			var loginBg = buildRoundedCard(loginCardW, LOGIN_CARD_H, loggedIn ? 0xFF1E7A3C : 0xFF241A3C);
			addAt(loginBg, loginCardY, loginCardX);

			loginTitleText = new FlxText(0, 0, loginCardW - 60, '');
			loginTitleText.setFormat(WIZ_FONT, 26, 0xFFCA66FF, LEFT);
			loginTitleText.antialiasing = ClientPrefs.data.antialiasing;
			loginTitleText.text = loggedIn ? tl('wizard_logged_in', '✓  GİRİŞ YAPILDI') : tl('wizard_login_btn', 'GİRİŞ YAPIN  /  KAYIT OLUN');
			addAt(loginTitleText, loginCardY + 22, loginCardX + 30);

			loginSubText = new FlxText(0, 0, loginCardW - 60, '');
			loginSubText.setFormat(WIZ_FONT, 15, 0xFFC0C0D0, LEFT);
			loginSubText.antialiasing = ClientPrefs.data.antialiasing;
			loginSubText.text = loggedIn ? tl('wizard_logged_in_sub', 'Başarımlar ve skorlar senkronize olacak.')
				: tl('wizard_login_sub', 'Başarımları eşitle, liderlik tablosuna gir, modları ve skorları bulutla.');
			addAt(loginSubText, loginCardY + 62, loginCardX + 30);

			var loginHit = new FlxSprite(loginCardX, loginCardY).makeGraphic(Std.int(loginCardW), Std.int(LOGIN_CARD_H), 0x00FFFFFF);
			addAt(loginHit, loginCardY, loginCardX);
			loginCard = {bg: loginBg, border: null, hit: loginHit};

			var skipCardX = loginCardX + loginCardW + CARD_GAP;
			var skipBg = buildRoundedCard(SKIP_CARD_W, LOGIN_CARD_H, 0xFF241A3C);
			addAt(skipBg, loginCardY, skipCardX);

			skipText = new FlxText(0, 0, SKIP_CARD_W, '');
			skipText.setFormat(WIZ_FONT, 24, 0xFFB0B0C0, CENTER);
			skipText.antialiasing = ClientPrefs.data.antialiasing;
			skipText.text = tl('wizard_skip', 'ATLA');
			addAt(skipText, loginCardY + LOGIN_CARD_H / 2 - 22, skipCardX);

			skipSubText = new FlxText(0, 0, SKIP_CARD_W, tl('wizard_skip_sub', 'çevrimdışı'));
			skipSubText.setFormat(WIZ_FONT, 13, 0xFF808090, CENTER);
			skipSubText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(skipSubText, loginCardY + LOGIN_CARD_H / 2 + 10, skipCardX);

			var skipHit = new FlxSprite(skipCardX, loginCardY).makeGraphic(Std.int(SKIP_CARD_W), Std.int(LOGIN_CARD_H), 0x00FFFFFF);
			addAt(skipHit, loginCardY, skipCardX);
			skipCard = {bg: skipBg, border: null, hit: skipHit};
		}

		curY = loginCardY + LOGIN_CARD_H + SECTION_GAP;

		var finishW:Float = FlxG.width - SIDE_PAD * 2;
		var finishBg = buildRoundedCard(finishW, FINISH_BTN_H, 0xFF6B46C1);
		addAt(finishBg, curY, SIDE_PAD);

		finishTitleText = new FlxText(0, 0, finishW, '');
		finishTitleText.setFormat(WIZ_FONT, 44, FlxColor.WHITE, CENTER);
		finishTitleText.antialiasing = ClientPrefs.data.antialiasing;
		finishTitleText.text = tl('wizard_finish', 'BAŞLA');
		addAt(finishTitleText, curY + 12, SIDE_PAD);

		finishSubText = new FlxText(0, 0, finishW, '');
		finishSubText.setFormat(WIZ_FONT, 16, 0xFFFFFFFF, CENTER);
		finishSubText.antialiasing = ClientPrefs.data.antialiasing;
		finishSubText.text = tl('wizard_finish_sub', 'Ayarları kaydedip menüye geç');
		addAt(finishSubText, curY + 62, SIDE_PAD);

		var finishHit = new FlxSprite(SIDE_PAD, curY).makeGraphic(Std.int(finishW), Std.int(FINISH_BTN_H), 0x00FFFFFF);
		addAt(finishHit, curY, SIDE_PAD);
		finishCard = {bg: finishBg, border: null, hit: finishHit};

		curY += FINISH_BTN_H + 60;

		var footerText = new FlxText(0, 0, FlxG.width, 'Further Engine  •  Psych Engine Türkiye');
		footerText.setFormat(WIZ_FONT, 14, 0xFF6B46C1, CENTER);
		addAt(footerText, curY, 0);
		curY += 50;

		totalContentHeight = curY;
		maxScrollY = Math.max(0, totalContentHeight - FlxG.height + 20);
	}

	function buildCardIcon(?imageKey:String, fallbackEmoji:String, size:Float, color:FlxColor, fontSize:Int):FlxSprite
	{
		if (imageKey != null)
		{
			var graphic = Paths.image(imageKey);
			if (graphic != null)
			{
				var spr = new FlxSprite();
				spr.loadGraphic(graphic);
				var scale:Float = Math.min(size / spr.width, size / spr.height);
				spr.scale.set(scale, scale);
				spr.updateHitbox();
				spr.antialiasing = ClientPrefs.data.antialiasing;
				return spr;
			}
			Log.warn('wizard', 'Ikon PNG bulunamadi: images/$imageKey.png — emoji fallback');
		}

		var t = new FlxText(0, 0, 0, fallbackEmoji);
		t.setFormat(WIZ_FONT, fontSize, color, CENTER);
		t.antialiasing = ClientPrefs.data.antialiasing;
		return t;
	}


	function addAt(spr:FlxSprite, y:Float, x:Float):Void
	{
		spr.x = x;
		spr.y = y;
		add(spr);
		allElements.push({sprite: spr, offsetY: y, baseX: x, baseAlpha: spr.alpha});
	}


	function addSectionTitle(key:String, fallback:String, y:Float):Float
	{
		var t = new FlxText(0, 0, FlxG.width, '');
		t.setFormat(WIZ_FONT, 36, FlxColor.WHITE, CENTER);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.text = tl(key, fallback);
		addAt(t, y, 0);
		sectionTexts.push(t);
		return y + 50 + TITLE_GAP;
	}


	function buildRoundedCard(w:Float, h:Float, color:Int):FlxSprite
	{
		var card = new FlxSprite();
		var radius = CARD_RADIUS;
		var success = false;
		try
		{
			var shape = new Shape();
			shape.graphics.beginFill(color, 1);
			shape.graphics.drawRoundRect(0, 0, w, h, radius, radius);
			shape.graphics.endFill();
			var bmd = new BitmapData(Std.int(w), Std.int(h), true, 0x00000000);
			bmd.draw(shape);
			card.pixels = bmd;
			card.antialiasing = ClientPrefs.data.antialiasing;
			success = true;
		}
		catch (e:Dynamic)
		{
			Log.warn('wizard', 'Rounded card çizilemedi, düz dikdörtgene düşülüyor: ' + e);
		}
		if (!success)
		{
			card.makeGraphic(Std.int(w), Std.int(h), color);
		}
		card.scrollFactor.set();
		return card;
	}


	function buildCircle(d:Float, color:Int, filled:Bool):FlxSprite
	{
		var spr = new FlxSprite();
		var success = false;
		try
		{
			var shape = new Shape();
			if (filled)
			{
				shape.graphics.beginFill(color, 1);
				shape.graphics.drawCircle(d / 2, d / 2, d / 2 - 1);
				shape.graphics.endFill();
			}
			else
			{
				shape.graphics.lineStyle(3, color, 1);
				shape.graphics.drawCircle(d / 2, d / 2, d / 2 - 3);
			}
			var bmd = new BitmapData(Std.int(d), Std.int(d), true, 0x00000000);
			bmd.draw(shape);
			spr.pixels = bmd;
			spr.antialiasing = ClientPrefs.data.antialiasing;
			success = true;
		}
		catch (e:Dynamic)
		{
			Log.warn('wizard', 'Daire cizilemedi: ' + e);
		}
		if (!success)
			spr.makeGraphic(Std.int(d), Std.int(d), color);
		spr.scrollFactor.set();
		return spr;
	}


	function buildImageCard(w:Float, h:Float, graphic:FlxGraphic, overlayColor:Int):FlxSprite
	{
		var spr = new FlxSprite();
		var success:Bool = false;
		var bmp:BitmapData = graphic != null ? graphic.bitmap : null;

		if (bmp != null && bmp.image != null)
		{
			try
			{
				var scale:Float = Math.max(w / bmp.width, h / bmp.height);
				var matrix = new Matrix();
				matrix.scale(scale, scale);
				matrix.translate(-(bmp.width * scale - w) / 2, -(bmp.height * scale - h) / 2);

				var flat = new BitmapData(Std.int(w), Std.int(h), true, 0x00000000);
				var src = new Bitmap(bmp);
				flat.draw(src, matrix, null, null, null, true);

				var maskShape = new Shape();
				maskShape.graphics.beginFill(0xFFFFFFFF, 1);
				maskShape.graphics.drawRoundRect(0, 0, w, h, CARD_RADIUS, CARD_RADIUS);
				maskShape.graphics.endFill();
				var maskBmd = new BitmapData(Std.int(w), Std.int(h), true, 0x00000000);
				maskBmd.draw(maskShape);

				var bmd = new BitmapData(Std.int(w), Std.int(h), true, 0x00000000);
				bmd.copyPixels(flat, flat.rect, new Point(0, 0), maskBmd, new Point(0, 0), true);

				if (overlayColor != 0)
				{
					var ov = new Shape();
					ov.graphics.beginFill(overlayColor & 0xFFFFFF, ((overlayColor >>> 24) & 0xFF) / 255);
					ov.graphics.drawRoundRect(0, 0, w, h, CARD_RADIUS, CARD_RADIUS);
					ov.graphics.endFill();
					bmd.draw(ov);
				}

				spr.pixels = bmd;
				spr.antialiasing = ClientPrefs.data.antialiasing;
				success = true;
			}
			catch (e:Dynamic)
			{
				Log.warn('wizard', 'Gorsel kart cizilemedi: ' + e);
			}
		}
		else if (graphic != null)
		{
			Log.warn('wizard', 'Gorsel piksel verisi yok (GPU cache), clipRect fallback');
		}

		if (!success && graphic != null)
		{
			try
			{
				spr.loadGraphic(graphic);
				var sc:Float = Math.max(w / spr.frameWidth, h / spr.frameHeight);
				var cropW:Float = w / sc;
				var cropH:Float = h / sc;
				spr.clipRect = FlxRect.get((spr.frameWidth - cropW) / 2, (spr.frameHeight - cropH) / 2, cropW, cropH);
				spr.scale.set(sc, sc);
				spr.updateHitbox();
				spr.antialiasing = ClientPrefs.data.antialiasing;
				success = true;
			}
			catch (e:Dynamic)
			{
				Log.warn('wizard', 'Gorsel kart clipRect fallback basarisiz: ' + e);
			}
		}

		if (!success)
			spr.makeGraphic(Std.int(w), Std.int(h), 0xFF241A3C);
		spr.scrollFactor.set();
		return spr;
	}


	#if !mobile
	function refreshKeyTexts():Void
	{
		for (box in keyBoxes)
		{
			var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(box.action);
			var name:String = tl('wizard_key_empty', 'BOŞ');
			if (keys != null)
			{
				for (k in keys)
				{
					if (k != FlxKey.NONE)
					{
						name = InputFormatter.getKeyName(k);
						break;
					}
				}
			}
			box.keyText.text = name;
		}
	}

	function updateKeyVisuals():Void
	{
		for (i in 0...keyBoxes.length)
		{
			var box = keyBoxes[i];
			var active:Bool = (i == listeningKey);
			if (box.border != null)
			{
				FlxTween.tween(box.border, {alpha: active ? 1 : 0}, 0.15, {ease: FlxEase.quadOut});
			}
			if (active && box.keyText != null)
			{
				box.keyText.text = tl('wizard_key_press', 'BİR TUŞA BAS');
				box.keyText.color = 0xFFCA66FF;
			}
			else if (box.keyText != null)
			{
				box.keyText.color = FlxColor.WHITE;
			}
		}
		if (listeningKey < 0)
			refreshKeyTexts();
	}

	function handleKeyListening():Void
	{
		if (listeningKey < 0 || listeningKey >= keyBoxes.length)
		{
			listeningKey = -1;
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			listeningKey = -1;
			updateKeyVisuals();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		if (FlxG.keys.justPressed.ANY)
		{
			var keyPressed:Int = FlxG.keys.firstJustPressed();
			if (keyPressed > -1)
			{
				var box = keyBoxes[listeningKey];
				var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(box.action);
				if (keys == null)
					keys = [FlxKey.NONE, FlxKey.NONE];
				while (keys.length < 2)
					keys.push(FlxKey.NONE);
				keys[0] = keyPressed;
				if (keys[1] == keyPressed)
					keys[1] = FlxKey.NONE;
				ClientPrefs.keyBinds.set(box.action, keys);
				ClientPrefs.clearInvalidKeys(box.action);
				listeningKey = -1;
				updateKeyVisuals();
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
		}
	}
	#end


	function tl(key:String, fallback:String):String
	{
		return Language.getPhrase(key, fallback);
	}

	function applyLanguageLive():Void
	{
		ClientPrefs.data.language = LANG_DEFS[selectedLang].code;
		Language.reloadPhrases();

		taglineText.text = tl('wizard_tagline', 'Engine\'i sana göre ayarlayalım!');
		sectionTexts[0].text = tl('wizard_lang_title', '1.  DİLİNİZİ SEÇİN');
		sectionTexts[1].text = tl('wizard_perf_title', '1.2  PERFORMANS PROFİLİ');
		#if mobile
		sectionTexts[2].text = tl('wizard_ctouch_title', '1.3  KONTROLLER');
		sectionTexts[3].text = tl('wizard_ctrl_title', '1.4  OYUN-İÇİ KONTROL');
		sectionTexts[4].text = tl('wizard_account_title', '2.  OYUNA GİRİŞ YAP');
		#else
		sectionTexts[2].text = tl('wizard_keys_title', '1.3  TUŞ AYARLARI');
		sectionTexts[3].text = tl('wizard_account_title', '2.  OYUNA GİRİŞ YAP');
		#end

		if (loginTitleText != null)
		{
			if (loggedIn)
			{
				loginTitleText.text = tl('wizard_logged_in', '✓  GİRİŞ YAPILDI');
				loginSubText.text = tl('wizard_logged_in_sub', 'Başarımlar ve skorlar senkronize olacak.');
			}
			else if (loginSkipped)
			{
				loginTitleText.text = tl('wizard_skipped', 'ATLANDI');
				loginSubText.text = tl('wizard_skipped_sub', 'Çevrimdışı olarak devam edeceksin. (Tekrar tıklayarak giriş yapabilirsin)');
			}
			else
			{
				loginTitleText.text = tl('wizard_login_btn', 'GİRİŞ YAPIN  /  KAYIT OLUN');
				loginSubText.text = tl('wizard_login_sub', 'Başarımları eşitle, liderlik tablosuna gir, modları ve skorları bulutla.');
			}
		}
		if (skipText != null)
		{
			skipText.text = tl('wizard_skip', 'ATLA');
			skipSubText.text = tl('wizard_skip_sub', 'çevrimdışı');
		}
		finishTitleText.text = tl('wizard_finish', 'BAŞLA');
		finishSubText.text = tl('wizard_finish_sub', 'Ayarları kaydedip menüye geç');

		FlxG.sound.play(Paths.sound('scrollMenu'));
	}


	function updateCardVisuals():Void
	{
		for (i in 0...langCards.length)
		{
			var c = langCards[i];
			var sel = (i == selectedLang);
			if (c.border != null)
				tweenCardAlpha(c.border, sel ? 1 : 0);
			if (c.bg != null)
				tweenCardAlpha(c.bg, sel ? 1 : 0.7);
		}
		for (i in 0...perfCards.length)
		{
			var c = perfCards[i];
			var sel = (i == selectedPerf);
			if (c.border != null)
				tweenCardAlpha(c.border, sel ? 1 : 0);
			if (c.bg != null)
				tweenCardAlpha(c.bg, sel ? 1 : 0.7);
		}
		for (i in 0...touchCards.length)
		{
			var c = touchCards[i];
			var sel = (i == selectedTouch);
			if (c.border != null)
				tweenCardAlpha(c.border, sel ? 1 : 0);
			if (c.bg != null)
				tweenCardAlpha(c.bg, sel ? 1 : 0.7);
		}
		for (i in 0...ctrlCards.length)
		{
			var c = ctrlCards[i];
			var sel = (i == selectedCtrl);
			if (c.border != null)
				tweenCardAlpha(c.border, sel ? 1 : 0);
			if (c.bg != null)
				tweenCardAlpha(c.bg, sel ? 1 : 0.7);
			if (ctrlDots[i] != null)
			{
				ctrlDots[i].on.visible = sel;
				ctrlDots[i].off.visible = !sel;
			}
		}
	}


	function elementOf(spr:FlxSprite):Null<ContentElement>
	{
		for (el in allElements)
		{
			if (el.sprite == spr)
				return el;
		}
		return null;
	}


	function tweenCardAlpha(spr:FlxSprite, target:Float):Void
	{
		var el = elementOf(spr);
		if (el == null)
		{
			FlxTween.tween(spr, {alpha: target}, 0.18, {ease: FlxEase.quadOut});
			return;
		}
		FlxTween.num(el.baseAlpha, target, 0.18, {ease: FlxEase.quadOut}, function(v)
		{
			el.baseAlpha = v;
			el.sprite.alpha = v * introFade;
		});
	}


	function autodetectPerfIndex():Int
	{
		var threads = CoolUtil.getCPUThreadsCount();
		#if mobile
		if (threads <= 4) return 0;
		if (threads <= 6) return 1;
		return 2;
		#elseif desktop
		if (threads <= 2) return 0;
		if (threads <= 6) return 1;
		return 2;
		#else
		return 1;
		#end
	}


	function updatePositions():Void
	{
		for (elem in allElements)
		{
			var newY = elem.offsetY - scrollY;
			elem.sprite.y = newY;
			elem.sprite.x = elem.baseX;

			var sprH:Float = elem.sprite.frameHeight;
			if (sprH <= 0) sprH = elem.sprite.height;
			if (sprH <= 0) { elem.sprite.visible = true; elem.sprite.clipRect = null; continue; }

			if (newY + sprH <= clipTop || newY >= clipBottom)
			{
				elem.sprite.visible = false;
				elem.sprite.clipRect = null;
			}
			else
			{
				elem.sprite.visible = true;
				applyClip(elem.sprite, newY, sprH);
			}
		}

		if (profileBox != null)
		{
			var pbY:Float = profileBoxY - scrollY;
			profileBox.y = pbY;
			profileBox.visible = (pbY + LOGIN_CARD_H > clipTop && pbY < clipBottom);
		}
	}

	function applyClip(spr:FlxSprite, screenY:Float, sprH:Float):Void
	{
		var sprW:Float = spr.frameWidth;
		if (sprW <= 0) sprW = spr.width;
		if (sprW <= 0 || sprH <= 0) { spr.clipRect = null; return; }

		var cropTop:Float = 0;
		var cropBottom:Float = sprH;
		var needsClip = false;

		if (screenY < clipTop)
		{
			cropTop = (clipTop - screenY) / spr.scale.y;
			needsClip = true;
		}
		if (screenY + spr.height > clipBottom)
		{
			cropBottom = (clipBottom - screenY) / spr.scale.y;
			needsClip = true;
		}

		if (needsClip && cropTop < cropBottom)
			spr.clipRect = FlxRect.get(0, cropTop, sprW, cropBottom - cropTop);
		else if (needsClip)
		{
			spr.visible = false;
			spr.clipRect = null;
		}
		else
			spr.clipRect = null;
	}

	function getScrollBarH():Float
	{
		if (totalContentHeight <= 0) return FlxG.height - 40;
		var ratio = FlxG.height / totalContentHeight;
		if (ratio >= 1) return FlxG.height - 40;
		return Math.max(40, (FlxG.height - 40) * ratio);
	}

	function updateScrollBar():Void
	{
		if (maxScrollY <= 0)
		{
			scrollBar.alpha = 0;
			scrollBarBg.alpha = 0;
			return;
		}
		var barH = getScrollBarH();
		scrollBar.height = barH;
		var trackH = FlxG.height - 40 - barH;
		var ratio = (maxScrollY > 0) ? scrollY / maxScrollY : 0;
		scrollBar.y = 20 + trackH * ratio;
		scrollBar.alpha = scrollBarAlpha;
		scrollBarBg.alpha = scrollBarAlpha * 0.35;

		if (scrollBarVisible && !scrollBarFading)
		{
			scrollBarTimer += FlxG.elapsed;
			if (scrollBarTimer >= SCROLLBAR_FADE) startScrollBarFade();
		}
	}

	function showScrollBar():Void
	{
		if (maxScrollY <= 0) return;
		scrollBarVisible = true;
		scrollBarFading = false;
		scrollBarTimer = 0;
		scrollBarAlpha = 1;
		if (scrollBarTween != null) { scrollBarTween.cancel(); scrollBarTween = null; }
	}

	function startScrollBarFade():Void
	{
		if (scrollBarFading) return;
		scrollBarFading = true;
		if (scrollBarTween != null) scrollBarTween.cancel();
		scrollBarTween = FlxTween.num(scrollBarAlpha, 0, 0.3, {ease: FlxEase.quadOut, onComplete: function(_) {
			scrollBarVisible = false; scrollBarFading = false; scrollBarTween = null;
		}}, function(v) { scrollBarAlpha = v; });
	}


	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (closing) return;

		#if !mobile
		if (listeningKey >= 0)
		{
			handleKeyListening();
			return;
		}
		#end

		if (profileBox != null && !backend.AuthManager.isLoggedIn && !closing)
		{
			closing = true;
			FlxG.switchState(new SetupWizardState());
			return;
		}

		var scrolled = false;

		var wheel = FlxG.mouse.wheel;
		if (wheel != 0)
		{
			targetScrollY -= wheel * SCROLL_SPEED;
			targetScrollY = FlxMath.bound(targetScrollY, 0, maxScrollY);
			showScrollBar();
			scrolled = true;
		}
		var keyUp = FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W;
		var keyDown = FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S;
		#if TOUCH_CONTROLS_ALLOWED
		if (touchPad != null)
		{
			if (touchPad.buttonUp.pressed)
			{
				targetScrollY -= PAD_SCROLL_SPEED * elapsed;
				showScrollBar();
				scrolled = true;
			}
			if (touchPad.buttonDown.pressed)
			{
				targetScrollY += PAD_SCROLL_SPEED * elapsed;
				showScrollBar();
				scrolled = true;
			}
		}
		#end
		if (keyUp)   { targetScrollY -= SCROLL_SPEED * 0.6; showScrollBar(); scrolled = true; }
		if (keyDown) { targetScrollY += SCROLL_SPEED * 0.6; showScrollBar(); scrolled = true; }
		targetScrollY = FlxMath.bound(targetScrollY, 0, maxScrollY);

		var pointerDown:Bool = false;
		var pointerJustStarted:Bool = false;
		#if mobile
		var dragTouch:FlxTouch = null;
		for (touch in FlxG.touches.list)
		{
			if (touchOverlapsPad(touch)) continue;
			if (touch.justPressed) { dragTouch = touch; break; }
			if (dragTouch == null && touch.pressed) dragTouch = touch;
		}
		if (dragTouch != null)
		{
			pointerDown = true;
			pointerJustStarted = dragTouch.justPressed;
			ptrX = dragTouch.x;
			ptrY = dragTouch.y;
		}
		#else
		pointerDown = FlxG.mouse.pressed;
		pointerJustStarted = FlxG.mouse.justPressed;
		if (pointerDown)
		{
			ptrX = FlxG.mouse.x;
			ptrY = FlxG.mouse.y;
		}
		#end

		var clicked:Bool = false;
		if (pointerDown)
		{
			if (!ptrWasDown || pointerJustStarted)
			{
				ptrWasDown = true;
				dragStartY = ptrY;
				dragLastY = ptrY;
				dragMoved = false;
				dragVel = 0;
				targetScrollY = scrollY;
			}
			else
			{
				var dragDy:Float = ptrY - dragLastY;
				if (dragDy > 100) dragDy = 100;
				if (dragDy < -100) dragDy = -100;
				dragLastY = ptrY;
				if (!dragMoved && Math.abs(ptrY - dragStartY) > DRAG_THRESHOLD)
					dragMoved = true;
				if (dragMoved && maxScrollY > 0)
				{
					targetScrollY -= dragDy;
					scrollY -= dragDy;
					targetScrollY = FlxMath.bound(targetScrollY, 0, maxScrollY);
					scrollY = FlxMath.bound(scrollY, 0, maxScrollY);
					dragVel = dragVel * 0.5 + dragDy * 0.5;
					showScrollBar();
					scrolled = true;
				}
			}
		}
		else if (ptrWasDown)
		{
			ptrWasDown = false;
			if (dragMoved)
			{
				targetScrollY -= dragVel * FLING_STRENGTH;
				targetScrollY = FlxMath.bound(targetScrollY, 0, maxScrollY);
				showScrollBar();
				scrolled = true;
			}
			else
			{
				clicked = true;
			}
		}

		if (Math.abs(scrollY - targetScrollY) > 0.5)
		{
			scrollY = FlxMath.lerp(scrollY, targetScrollY, SCROLL_LERP);
			scrolled = true;
		}
		else if (scrollY != targetScrollY)
		{
			scrollY = targetScrollY;
			scrolled = true;
		}

		if (scrolled)
		{
			updatePositions();
		}

		updateScrollBar();

		var hintAlpha:Float = (maxScrollY > 2 && scrollY < 24) ? 1 : 0;
		scrollHintText.alpha = FlxMath.lerp(scrollHintText.alpha, hintAlpha, 0.12);
		if (scrollHintArrow != null)
			scrollHintArrow.alpha = scrollHintText.alpha;

		if (scrollBarVisible && !scrollBarFading && wheel == 0 && !keyUp && !keyDown && !pointerDown)
		{
			scrollBarTimer += elapsed;
			if (scrollBarTimer >= SCROLLBAR_FADE) startScrollBarFade();
		}

		if (clicked)
		{
			var mx:Float = ptrX;
			var my:Float = ptrY;
			for (c in langCards)
			{
				if (hitTest(c.hit, mx, my))
				{
					if (selectedLang != langCards.indexOf(c))
					{
						selectedLang = langCards.indexOf(c);
						applyLanguageLive();
						updateCardVisuals();
					}
					else FlxG.sound.play(Paths.sound('scrollMenu'));
					return;
				}
			}
			for (c in perfCards)
			{
				if (hitTest(c.hit, mx, my))
				{
					var idx = perfCards.indexOf(c);
					if (selectedPerf != idx)
					{
						selectedPerf = idx;
						FlxG.sound.play(Paths.sound('scrollMenu'));
						updateCardVisuals();
					}
					return;
				}
			}
			for (c in touchCards)
			{
				if (hitTest(c.hit, mx, my))
				{
					var idx = touchCards.indexOf(c);
					if (selectedTouch != idx)
					{
						selectedTouch = idx;
						FlxG.sound.play(Paths.sound('scrollMenu'));
						updateCardVisuals();
						#if TOUCH_CONTROLS_ALLOWED
						ClientPrefs.data.mobileControlType = selectedTouch == 1 ? 'Touch' : 'Buttons';
						refreshTouchPad();
						#end
					}
					return;
				}
			}
			for (c in ctrlCards)
			{
				if (hitTest(c.hit, mx, my))
				{
					var idx = ctrlCards.indexOf(c);
					if (selectedCtrl != idx)
					{
						selectedCtrl = idx;
						FlxG.sound.play(Paths.sound('scrollMenu'));
						updateCardVisuals();
					}
					return;
				}
			}
			#if !mobile
			for (box in keyBoxes)
			{
				if (hitTest(box.hit, mx, my))
				{
					listeningKey = keyBoxes.indexOf(box);
					updateKeyVisuals();
					FlxG.sound.play(Paths.sound('scrollMenu'));
					return;
				}
			}
			#end
			if (loginCard != null && hitTest(loginCard.hit, mx, my) && !loggedIn)
			{
				openLogin();
				return;
			}
			if (skipCard != null && hitTest(skipCard.hit, mx, my))
			{
				skipLogin();
				return;
			}
			if (finishCard != null && hitTest(finishCard.hit, mx, my))
			{
				finishWizard();
				return;
			}
		}
	}

	function touchOverlapsPad(touch:FlxTouch):Bool
	{
		#if TOUCH_CONTROLS_ALLOWED
		if (touchPad == null) return false;
		for (btn in touchPad.members)
		{
			if (btn == null || !btn.visible) continue;
			if (touch.x >= btn.x && touch.x <= btn.x + btn.width
				&& touch.y >= btn.y && touch.y <= btn.y + btn.height)
				return true;
		}
		#end
		return false;
	}

	function hitTest(h:FlxSprite, mx:Float, my:Float):Bool
	{
		if (h == null) return false;
		return mx >= h.x && mx <= h.x + h.width && my >= h.y && my <= h.y + h.height;
	}


	function openLogin():Void
	{
		if (closing) return;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		returnToWizard = true;
		FlxG.switchState(new LoginState());
	}


	function skipLogin():Void
	{
		FlxG.sound.play(Paths.sound('cancelMenu'));
		loginSkipped = true;
		loggedIn = false;
		loginTitleText.text = tl('wizard_skipped', 'ATLANDI');
		loginTitleText.color = 0xFF808090;
		loginSubText.text = tl('wizard_skipped_sub', 'Çevrimdışı olarak devam edeceksin. (Tekrar tıklayarak giriş yapabilirsin)');
		loginCard.bg.color = 0xFF1A1530;
		skipCard.bg.alpha = 0.4;
		skipText.color = 0xFF606070;
		if (skipSubText != null) skipSubText.color = 0xFF404050;
	}

	function finishWizard():Void
	{
		if (closing) return;
		closing = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		if (FlxG.sound.music != null)
			FlxG.sound.music.fadeOut(0.4);

		var langCode = LANG_DEFS[selectedLang].code;
		if (langCode != ClientPrefs.data.language)
		{
			ClientPrefs.data.language = langCode;
			Language.reloadPhrases();
		}

		PerformanceProfiler.apply(PERF_DEFS[selectedPerf].id);
		AudioMixer.init();
		AudioMixer.syncFromPrefs();
		PerformanceProfiler.applyRuntimeSettings();

		#if mobile
		ClientPrefs.data.mobileControlType = selectedTouch == 1 ? 'Touch' : 'Buttons';

		if (selectedCtrl == 1)
		{
			ClientPrefs.data.ogGameControls = true;
		}
		else
		{
			ClientPrefs.data.ogGameControls = false;
			MobileData.mode = 3;
		}
		ClientPrefs.data.ogAutoPinDone = false;
		#end

		ClientPrefs.data.setupWizardCompleted = true;
		ClientPrefs.saveSettings();
		returnToWizard = false;

		Log.infoLazy('wizard', function() return 'Kurulum tamamlandı: lang=' + langCode + ', perf=' + PERF_DEFS[selectedPerf].id);

		FlxTween.num(1, 0, 0.4, {ease: FlxEase.quadIn, onComplete: function(_)
		{
			wizardMusicActive = false;
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
				FlxG.sound.music = null;
			}
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new TitleState());
		}}, function(v)
		{
			for (el in allElements) el.sprite.alpha = v;
			if (profileBox != null) profileBox.alpha = v;
			bg.alpha = v;
			bgDark.alpha = v;
			glow.alpha = v * 0.4;
			scrollBar.alpha = 0;
			scrollBarBg.alpha = 0;
		});
	}

	override function destroy():Void
	{
		if (scrollBarTween != null) { scrollBarTween.cancel(); scrollBarTween = null; }
		for (el in allElements) el.sprite.clipRect = null;
		super.destroy();
	}
}

typedef Card = {
	var bg:FlxSprite;
	var border:Null<FlxSprite>;
	var hit:FlxSprite;
};

typedef ContentElement = {
	var sprite:FlxSprite;
	var offsetY:Float;
	var baseX:Float;
	var baseAlpha:Float;
};
