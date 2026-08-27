package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import backend.Paths;
import backend.ClientPrefs;
import backend.Language;
import backend.PerformanceProfiler;
import backend.PerformanceProfile;
import backend.AudioMixer;
import backend.Log;
import openfl.display.BitmapData;
import openfl.display.Shape;

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

	// LoginState'den geri dönüş bayrağı (static: state değişiminde korunur)
	public static var returnToWizard:Bool = false;
	public static var debugMode:Bool = true; // Her açılışta setup wizard çıkmasını sağlayan debug modu

	// ── Desteklenen diller ──────────────────────────────────────
	static var LANG_DEFS:Array<{code:String, name:String, flag:String}> = [
		{code: 'tr-TR', name: 'TÜRKÇE',    flag: '🇹🇷'},
		{code: 'en-US', name: 'ENGLISH',   flag: '🇺🇸'},
		{code: 'pt-BR', name: 'PORTUGUÊS', flag: '🇧🇷'}
	];

	// ── Performans profilleri ──────────────────────────────────
	static var PERF_DEFS:Array<{id:PerformanceProfile, name:String, sub:String, color:Int, icon:String}> = [
		{id: PERFORMANCE, name: 'DÜŞÜK KALİTE',  sub: 'Düşük uç cihazlar\nEmülatör / eski telefon\n30 FPS hedefli',         color: 0xFFE74C3C, icon: '⚡'},
		{id: BALANCED,    name: 'ORTA KALİTE',   sub: 'Çoğu bilgisayar / telefon\n60 FPS dengeli deneyim\nÖnerilen',        color: 0xFFF39C12, icon: '⚖'},
		{id: HIGH,        name: 'YÜKSEK KALİTE', sub: 'Güçlü PC / yeni telefon\nShaderlar ve efektler açık\n144+ FPS',      color: 0xFF2ECC71, icon: '✨'}
	];

	// ── State ───────────────────────────────────────────────────
	var selectedLang:Int = 0;
	var selectedPerf:Int = 1;
	var loggedIn:Bool = false;
	var loginSkipped:Bool = false;

	var bg:FlxSprite;
	var glow:FlxSprite;

	// Scroll değişkenleri
	var scrollY:Float = 0;
	var targetScrollY:Float = 0;
	var maxScrollY:Float = 0;
	var totalContentHeight:Float = 0;
	var scrollBar:FlxSprite;
	var scrollBarBg:FlxSprite;
	var scrollBarAlpha:Float = 0;
	var scrollBarTimer:Float = 0;
	var scrollBarVisible:Bool = false;
	var scrollBarFading:Bool = false;
	var scrollBarTween:FlxTween;
	var clipTop:Float = 0;
	var clipBottom:Float;

	// Tüm kaydırılabilir elemanlar
	var allElements:Array<ContentElement> = [];

	// Etkileşimli grup (kart arka planları + seçim border'ları)
	var langCards:Array<Card> = [];
	var perfCards:Array<Card> = [];
	var loginCard:Card;
	var skipCard:Card;
	var finishCard:Card;

	// Dinamik metinler
	var taglineText:FlxText;
	var sectionTexts:Array<FlxText> = [];
	var loginTitleText:FlxText;
	var loginSubText:FlxText;
	var skipText:FlxText;
	var skipSubText:FlxText;
	var finishTitleText:FlxText;
	var finishSubText:FlxText;

	var closing:Bool = false;

	// ────────────────────────────────────────────────────────────
	override function create():Void
	{
		super.create();
		flixel.FlxG.mouse.visible = true;
		clipBottom = FlxG.height;
		// Bu state'e LoginState'den dönülüyorsa return bayrağını temizle
		returnToWizard = false;

		// Tam ekran koyu arka plan
		bg = new FlxSprite().makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), 0xFF0F0A1E);
		bg.scrollFactor.set();
		add(bg);

		glow = new FlxSprite().makeGraphic(Std.int(FlxG.width), 400, 0x33A05AFF);
		glow.scrollFactor.set();
		add(glow);

		// Otomatik tespitler
		selectedPerf = autodetectPerfIndex();
		selectedLang = detectInitialLang();

		#if ACHIEVEMENTS_ALLOWED
		loggedIn = backend.AuthManager.isLoggedIn;
		#end

		buildContent();

		// Scrollbar
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

		updatePositions();
		updateCardVisuals();

		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('NONE', 'A_B');
		addTouchPadCamera();
		#end

		// Giriş animasyonu
		for (el in allElements)
			el.sprite.alpha = 0;
		FlxTween.num(0, 1, 0.5, {ease: FlxEase.quadOut}, function(v)
		{
			for (el in allElements) el.sprite.alpha = v;
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
		// Engine varsayılan dili Türkçe (tr-TR)
		return 0;
	}

	// ── İÇERİK OLUŞTURMA ────────────────────────────────────────

	function buildContent():Void
	{
		allElements = [];
		langCards = [];
		perfCards = [];
		sectionTexts = [];

		var cx:Float = FlxG.width / 2;
		var curY:Float = 50;

		// ── FE logosu ──────────────────────────────────────────
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
		furtherText.setFormat(Paths.font('vcr.ttf'), 88, 0xFFB14AFF, CENTER);
		furtherText.antialiasing = ClientPrefs.data.antialiasing;
		addAt(furtherText, curY, 0);
		curY += 100; // 88px font + satır boşluğu

		var engineText = new FlxText(0, 0, FlxG.width, 'ENGINE');
		engineText.setFormat(Paths.font('vcr.ttf'), 72, FlxColor.WHITE, CENTER);
		engineText.antialiasing = ClientPrefs.data.antialiasing;
		addAt(engineText, curY, 0);
		curY += 82; // 72px font + satır boşluğu

		taglineText = new FlxText(0, 0, FlxG.width, '');
		taglineText.setFormat(Paths.font('vcr.ttf'), 24, 0xFFB0B0C0, CENTER);
		taglineText.antialiasing = ClientPrefs.data.antialiasing;
		taglineText.text = tl('wizard_tagline', 'Engine\'i sana göre ayarlayalım!');
		addAt(taglineText, curY, 0);
		curY += 40;

		var sep = new FlxSprite().makeGraphic(Std.int(FlxG.width - 300), 3, 0x446B46C1);
		addAt(sep, curY, cx - sep.width / 2);
		curY += 3 + SECTION_GAP;

		// ── 1. DİL SEÇİMİ ─────────────────────────────────────
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

			var flagText = new FlxText(0, 0, LANG_CARD_W, def.flag);
			flagText.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER);
			flagText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(flagText, langCardY + 20, cardX);

			var nameText = new FlxText(0, 0, LANG_CARD_W, def.name);
			nameText.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, CENTER);
			nameText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(nameText, langCardY + 110, cardX);

			var hit = new FlxSprite(cardX, langCardY).makeGraphic(Std.int(LANG_CARD_W), Std.int(LANG_CARD_H), 0x00FFFFFF);
			addAt(hit, langCardY, cardX);

			langCards.push({bg: cardBg, border: cardBorder, hit: hit});
		}
		curY = langCardY + LANG_CARD_H + SECTION_GAP;

		// ── 1.2 PERFORMANS PROFİLİ ────────────────────────────
		curY = addSectionTitle('wizard_perf_title', '1.2  PERFORMANS PROFİLİ', curY);

		totalCardsW = PERF_DEFS.length * PERF_CARD_W + (PERF_DEFS.length - 1) * CARD_GAP;
		startX = cx - totalCardsW / 2;
		var perfCardY:Float = curY;
		for (i in 0...PERF_DEFS.length)
		{
			var def = PERF_DEFS[i];
			var cardX = startX + i * (PERF_CARD_W + CARD_GAP);

			var cardBg = buildRoundedCard(PERF_CARD_W, PERF_CARD_H, 0xFF241A3C);
			var cardBorder = buildRoundedCard(PERF_CARD_W + BORDER_W * 2, PERF_CARD_H + BORDER_W * 2, def.color);
			cardBorder.alpha = 0;
			addAt(cardBorder, perfCardY - BORDER_W, cardX - BORDER_W);
			addAt(cardBg, perfCardY, cardX);

			var iconText = new FlxText(0, 0, PERF_CARD_W, def.icon);
			iconText.setFormat(Paths.font('vcr.ttf'), 48, def.color, CENTER);
			iconText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(iconText, perfCardY + 22, cardX);

			var nameText = new FlxText(0, 0, PERF_CARD_W, def.name);
			nameText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER);
			nameText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(nameText, perfCardY + 90, cardX);

			var subText = new FlxText(0, 0, PERF_CARD_W - 40, def.sub);
			subText.setFormat(Paths.font('vcr.ttf'), 14, 0xFFC0C0D0, CENTER);
			subText.antialiasing = ClientPrefs.data.antialiasing;
			addAt(subText, perfCardY + 125, cardX + 20);

			var hit = new FlxSprite(cardX, perfCardY).makeGraphic(Std.int(PERF_CARD_W), Std.int(PERF_CARD_H), 0x00FFFFFF);
			addAt(hit, perfCardY, cardX);

			perfCards.push({bg: cardBg, border: cardBorder, hit: hit});
		}
		curY = perfCardY + PERF_CARD_H + SECTION_GAP;

		// ── 2. GİRİŞ YAP / KAYIT OL ───────────────────────────
		curY = addSectionTitle('wizard_account_title', '2.  HESAP (İSTEĞE BAĞLI)', curY);

		var loginCardW:Float = FlxG.width - SIDE_PAD * 2 - SKIP_CARD_W - CARD_GAP;
		var loginCardX:Float = SIDE_PAD;
		var loginCardY:Float = curY;

		var loginBg = buildRoundedCard(loginCardW, LOGIN_CARD_H, loggedIn ? 0xFF1E7A3C : 0xFF241A3C);
		addAt(loginBg, loginCardY, loginCardX);

		loginTitleText = new FlxText(0, 0, loginCardW - 60, '');
		loginTitleText.setFormat(Paths.font('vcr.ttf'), 26, 0xFFCA66FF, LEFT);
		loginTitleText.antialiasing = ClientPrefs.data.antialiasing;
		loginTitleText.text = loggedIn ? tl('wizard_logged_in', '✓  GİRİŞ YAPILDI') : tl('wizard_login_btn', 'GİRİŞ YAPIN  /  KAYIT OLUN');
		addAt(loginTitleText, loginCardY + 22, loginCardX + 30);

		loginSubText = new FlxText(0, 0, loginCardW - 60, '');
		loginSubText.setFormat(Paths.font('vcr.ttf'), 15, 0xFFC0C0D0, LEFT);
		loginSubText.antialiasing = ClientPrefs.data.antialiasing;
		loginSubText.text = loggedIn ? tl('wizard_logged_in_sub', 'Başarımlar ve skorlar senkronize olacak.')
			: tl('wizard_login_sub', 'Başarımları eşitle, liderlik tablosuna gir, modları ve skorları bulutla.');
		addAt(loginSubText, loginCardY + 62, loginCardX + 30);

		var loginHit = new FlxSprite(loginCardX, loginCardY).makeGraphic(Std.int(loginCardW), Std.int(LOGIN_CARD_H), 0x00FFFFFF);
		addAt(loginHit, loginCardY, loginCardX);
		loginCard = {bg: loginBg, border: null, hit: loginHit};

		// ATLA butonu
		var skipCardX = loginCardX + loginCardW + CARD_GAP;
		var skipBg = buildRoundedCard(SKIP_CARD_W, LOGIN_CARD_H, 0xFF241A3C);
		addAt(skipBg, loginCardY, skipCardX);

		skipText = new FlxText(0, 0, SKIP_CARD_W, '');
		skipText.setFormat(Paths.font('vcr.ttf'), 24, 0xFFB0B0C0, CENTER);
		skipText.antialiasing = ClientPrefs.data.antialiasing;
		skipText.text = tl('wizard_skip', 'ATLA');
		addAt(skipText, loginCardY + LOGIN_CARD_H / 2 - 22, skipCardX);

		skipSubText = new FlxText(0, 0, SKIP_CARD_W, tl('wizard_skip_sub', 'çevrimdışı'));
		skipSubText.setFormat(Paths.font('vcr.ttf'), 13, 0xFF808090, CENTER);
		skipSubText.antialiasing = ClientPrefs.data.antialiasing;
		addAt(skipSubText, loginCardY + LOGIN_CARD_H / 2 + 10, skipCardX);

		var skipHit = new FlxSprite(skipCardX, loginCardY).makeGraphic(Std.int(SKIP_CARD_W), Std.int(LOGIN_CARD_H), 0x00FFFFFF);
		addAt(skipHit, loginCardY, skipCardX);
		skipCard = {bg: skipBg, border: null, hit: skipHit};

		curY = loginCardY + LOGIN_CARD_H + SECTION_GAP;

		// ── BİTİR ──────────────────────────────────────────
		var finishW:Float = FlxG.width - SIDE_PAD * 2;
		var finishBg = buildRoundedCard(finishW, FINISH_BTN_H, 0xFF6B46C1);
		addAt(finishBg, curY, SIDE_PAD);

		finishTitleText = new FlxText(0, 0, finishW, '');
		finishTitleText.setFormat(Paths.font('vcr.ttf'), 44, FlxColor.WHITE, CENTER);
		finishTitleText.antialiasing = ClientPrefs.data.antialiasing;
		finishTitleText.text = tl('wizard_finish', 'BAŞLA');
		addAt(finishTitleText, curY + 12, SIDE_PAD);

		finishSubText = new FlxText(0, 0, finishW, '');
		finishSubText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFFFFFFF, CENTER);
		finishSubText.antialiasing = ClientPrefs.data.antialiasing;
		finishSubText.text = tl('wizard_finish_sub', 'Ayarları kaydedip menüye geç');
		addAt(finishSubText, curY + 62, SIDE_PAD);

		var finishHit = new FlxSprite(SIDE_PAD, curY).makeGraphic(Std.int(finishW), Std.int(FINISH_BTN_H), 0x00FFFFFF);
		addAt(finishHit, curY, SIDE_PAD);
		finishCard = {bg: finishBg, border: null, hit: finishHit};

		curY += FINISH_BTN_H + 60;

		var footerText = new FlxText(0, 0, FlxG.width, 'Further Engine  •  Psych Engine Türkiye');
		footerText.setFormat(Paths.font('vcr.ttf'), 14, 0xFF6B46C1, CENTER);
		addAt(footerText, curY, 0);
		curY += 50;

		totalContentHeight = curY;
		maxScrollY = Math.max(0, totalContentHeight - FlxG.height + 20);
	}

	/**
	 * Elemanı verilen (x, y) konumuna ekler. Yüksekliği hesaba katmaz;
	 * boşluklar manuel olarak buildContent içinde yönetilir (RehberSubState modeli).
	 */
	function addAt(spr:FlxSprite, y:Float, x:Float):Void
	{
		spr.x = x;
		spr.y = y;
		add(spr);
		allElements.push({sprite: spr, offsetY: y, baseX: x});
	}

	/**
	 * Bölüm başlığı ekler. Yerleştirildikten sonraki Y'yi döndürür.
	 */
	function addSectionTitle(key:String, fallback:String, y:Float):Float
	{
		var t = new FlxText(0, 0, FlxG.width, '');
		t.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.text = tl(key, fallback);
		addAt(t, y, 0);
		sectionTexts.push(t);
		return y + 50 + TITLE_GAP; // 36px font + ~14 line spacing + gap
	}

	/**
	 * Kenarları yumuşatılmış renkli kutu (rounded card).
	 * openfl.display.Shape.drawRoundRect ile tek çağrıda çizer.
	 */
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
			// Fallback: renk zaten ARGB olarak opaque (0xFF......), direkt kullan
			card.makeGraphic(Std.int(w), Std.int(h), color);
		}
		card.scrollFactor.set();
		return card;
	}

	// ── DİL YARDIMCILARI ────────────────────────────────────────

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
		sectionTexts[2].text = tl('wizard_account_title', '2.  HESAP (İSTEĞE BAĞLI)');

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
		skipText.text = tl('wizard_skip', 'ATLA');
		skipSubText.text = tl('wizard_skip_sub', 'çevrimdışı');
		finishTitleText.text = tl('wizard_finish', 'BAŞLA');
		finishSubText.text = tl('wizard_finish_sub', 'Ayarları kaydedip menüye geç');

		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	// ── SEÇİM GÖRSELLERİ ────────────────────────────────────────

	function updateCardVisuals():Void
	{
		for (i in 0...langCards.length)
		{
			var c = langCards[i];
			var sel = (i == selectedLang);
			if (c.border != null)
			{
				FlxTween.tween(c.border, {alpha: sel ? 1 : 0}, 0.18, {ease: FlxEase.quadOut});
			}
			if (c.bg != null)
			{
				FlxTween.tween(c.bg, {alpha: sel ? 1 : 0.7}, 0.18, {ease: FlxEase.quadOut});
			}
		}
		for (i in 0...perfCards.length)
		{
			var c = perfCards[i];
			var sel = (i == selectedPerf);
			if (c.border != null)
			{
				FlxTween.tween(c.border, {alpha: sel ? 1 : 0}, 0.18, {ease: FlxEase.quadOut});
			}
			if (c.bg != null)
			{
				FlxTween.tween(c.bg, {alpha: sel ? 1 : 0.7}, 0.18, {ease: FlxEase.quadOut});
			}
		}
	}

	// ── PERFORMANS TESPİTİ ─────────────────────────────────────

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

	// ── POZİSYON / CLIP / SCROLL ────────────────────────────────

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

	// ── UPDATE ─────────────────────────────────────────────────

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (closing) return;

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
			keyUp = keyUp || touchPad.buttonUp.justPressed;
			keyDown = keyDown || touchPad.buttonDown.justPressed;
		}
		#end
		if (keyUp)   { targetScrollY -= SCROLL_SPEED * 0.6; showScrollBar(); scrolled = true; }
		if (keyDown) { targetScrollY += SCROLL_SPEED * 0.6; showScrollBar(); scrolled = true; }
		targetScrollY = FlxMath.bound(targetScrollY, 0, maxScrollY);

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

		if (scrollBarVisible && !scrollBarFading && wheel == 0 && !keyUp && !keyDown)
		{
			scrollBarTimer += elapsed;
			if (scrollBarTimer >= SCROLLBAR_FADE) startScrollBarFade();
		}

		// Tıklamalar (fare + dokunma)
		var clicked = FlxG.mouse.justPressed;
		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;
		
		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed) {
				clicked = true;
				mx = touch.x;
				my = touch.y;
				break;
			}
		}
		#end
		
		if (clicked)
		{
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

		if (controls.ACCEPT) finishWizard();
	}

	function hitTest(h:FlxSprite, mx:Float, my:Float):Bool
	{
		if (h == null) return false;
		return mx >= h.x && mx <= h.x + h.width && my >= h.y && my <= h.y + h.height;
	}

	// ── GİRİŞ / BİTİR ───────────────────────────────────────────

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

		ClientPrefs.data.setupWizardCompleted = true;
		ClientPrefs.saveSettings();
		returnToWizard = false;

		Log.infoLazy('wizard', function() return 'Kurulum tamamlandi: lang=' + langCode + ', perf=' + PERF_DEFS[selectedPerf].id);
		
		FlxTween.num(1, 0, 0.4, {ease: FlxEase.quadIn, onComplete: function(_)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new TitleState());
		}}, function(v)
		{
			for (el in allElements) el.sprite.alpha = v;
			bg.alpha = v;
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
};
