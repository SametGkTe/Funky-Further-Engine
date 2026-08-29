package states;

import backend.AuthManager;
import backend.Log;
import backend.ui.PsychUIInputText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import openfl.display.BitmapData;
import openfl.display.Shape;

class LoginState extends MusicBeatState
{
	static inline var BG_DARKEN:Int = 0x96000000;
	static inline var C_BG_FALLBACK:Int = 0xFF0F0A1E;
	static inline var C_CARD:Int = 0xFF241A3C;
	static inline var C_INNER:Int = 0xFF1A1230;
	static inline var C_BORDER:Int = 0xFF6B46C1;
	static inline var C_ACCENT:Int = 0xFFCA66FF;
	static inline var C_BRAND:Int = 0xFFB14AFF;
	static inline var C_TEXT:Int = 0xFFFFFFFF;
	static inline var C_MUTED:Int = 0xFFB0B0C0;
	static inline var C_FAINT:Int = 0xFF808090;
	static inline var C_GREEN:Int = 0xFF2ECC71;
	static inline var C_RED:Int = 0xFFE74C3C;
	static inline var C_BTN:Int = 0xFF6B46C1;
	static inline var C_BTN_HOVER:Int = 0xFF8355D9;
	static inline var C_BTN_BUSY:Int = 0xFF4A3570;
	static inline var C_LOGOUT:Int = 0xFFFF6B81;
	static inline var C_SEP:Int = 0x446B46C1;

	static inline var MODE_LOGIN:Int = 0;
	static inline var MODE_REGISTER:Int = 1;
	static inline var MODE_PROFILE:Int = 2;

	static inline var CARD_W:Float = 460;
	static inline var CARD_H:Float = 560;
	static inline var FIELD_W:Float = 370;
	static inline var FIELD_H:Float = 46;
	static inline var BTN_H:Float = 54;
	static inline var RADIUS:Float = 22;
	static inline var RING_W:Float = 2;

	var cardX:Float;
	var cardY:Float;
	var fieldX:Float;

	var bg:FlxSprite;
	var bgDark:FlxSprite;
	var cardBorderSpr:FlxSprite;
	var card:FlxSprite;

	var brandText:FlxText;
	var titleText:FlxText;
	var subtitleText:FlxText;
	var statusText:FlxText;

	var userLabel:FlxText;
	var emailLabel:FlxText;
	var passLabel:FlxText;
	var userFieldBg:FlxSprite;
	var userFieldRing:FlxSprite;
	var emailFieldBg:FlxSprite;
	var emailFieldRing:FlxSprite;
	var passFieldBg:FlxSprite;
	var passFieldRing:FlxSprite;
	var userInput:PsychUIInputText;
	var emailInput:PsychUIInputText;
	var passInput:PsychUIInputText;

	var forgotText:FlxText;
	var submitBtn:FlxSprite;
	var submitBtnRing:FlxSprite;
	var submitText:FlxText;
	var sepLine:FlxSprite;
	var toggleText:FlxText;
	var backText:FlxText;

	var avatarRing:FlxSprite;
	var avatarBg:FlxSprite;
	var avatarLetter:FlxText;
	var profSubText:FlxText;
	var profNameText:FlxText;
	var statBoxes:Array<FlxSprite> = [];
	var statValues:Array<FlxText> = [];
	var statLabels:Array<FlxText> = [];
	var continueBtn:FlxSprite;
	var continueText:FlxText;
	var logoutText:FlxText;

	var mode:Int = MODE_LOGIN;
	var _ready:Bool = false;
	var _busy:Bool = false;
	var _switching:Bool = false;
	var _btnHovered:Bool = false;
	var _continueHovered:Bool = false;
	var _toggleHovered:Bool = false;
	var _forgotHovered:Bool = false;
	var _backHovered:Bool = false;
	var _logoutHovered:Bool = false;
	var _dotTime:Float = 0;
	var _focusedRing:String = '';

	var formSprites:Array<FlxSprite> = [];
	var formInputs:Array<PsychUIInputText> = [];
	var profileSprites:Array<FlxSprite> = [];
	var busyDots:Array<FlxSprite> = [];

	override function create()
	{
		super.create();
		FlxG.mouse.visible = true;

		cardX = (FlxG.width - CARD_W) / 2;
		cardY = (FlxG.height - CARD_H) / 2;
		fieldX = cardX + (CARD_W - FIELD_W) / 2;

		bg = new FlxSprite();
		var bgLoaded:Bool = false;
		try
		{
			bg.loadGraphic(Paths.image('funkay'));
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
			bg.makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), C_BG_FALLBACK);
		}
		bg.scrollFactor.set();
		add(bg);

		bgDark = new FlxSprite().makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), BG_DARKEN);
		bgDark.scrollFactor.set();
		add(bgDark);

		cardBorderSpr = buildRoundedCard(CARD_W + RING_W * 2, CARD_H + RING_W * 2, C_BORDER);
		cardBorderSpr.scrollFactor.set();
		addAt(cardBorderSpr, cardY - RING_W, cardX - RING_W);

		card = buildRoundedCard(CARD_W, CARD_H, C_CARD);
		card.scrollFactor.set();
		addAt(card, cardY, cardX);

		brandText = makeText(cardX, cardY + 24, CARD_W, tl('login_brand', 'FURTHER ENGINE'), 13, CENTER);
		brandText.color = C_BRAND;
		add(brandText);

		titleText = makeText(cardX, cardY + 50, CARD_W, '', 34, CENTER);
		add(titleText);

		subtitleText = makeText(cardX, cardY + 96, CARD_W, '', 15, CENTER);
		subtitleText.color = C_MUTED;
		add(subtitleText);

		userLabel = makeText(fieldX, 0, FIELD_W, tl('login_username_label', 'KULLANICI ADI'), 12);
		userLabel.color = C_FAINT;
		add(userLabel);

		userFieldBg = buildRoundedCard(FIELD_W, FIELD_H, C_INNER);
		add(userFieldBg);
		userFieldRing = buildRoundedCard(FIELD_W + RING_W * 2, FIELD_H + RING_W * 2, C_ACCENT);
		userFieldRing.alpha = 0;
		add(userFieldRing);

		userInput = makeInput(20);
		add(userInput);

		emailLabel = makeText(fieldX, 0, FIELD_W, '', 12);
		emailLabel.color = C_FAINT;
		add(emailLabel);

		emailFieldBg = buildRoundedCard(FIELD_W, FIELD_H, C_INNER);
		add(emailFieldBg);
		emailFieldRing = buildRoundedCard(FIELD_W + RING_W * 2, FIELD_H + RING_W * 2, C_ACCENT);
		emailFieldRing.alpha = 0;
		add(emailFieldRing);

		emailInput = makeInput(50);
		add(emailInput);

		passLabel = makeText(fieldX, 0, FIELD_W, tl('login_password_label', 'ŞİFRE'), 12);
		passLabel.color = C_FAINT;
		add(passLabel);

		passFieldBg = buildRoundedCard(FIELD_W, FIELD_H, C_INNER);
		add(passFieldBg);
		passFieldRing = buildRoundedCard(FIELD_W + RING_W * 2, FIELD_H + RING_W * 2, C_ACCENT);
		passFieldRing.alpha = 0;
		add(passFieldRing);

		passInput = makeInput(50);
		passInput.passwordMask = true;
		add(passInput);

		forgotText = makeText(fieldX, 0, FIELD_W, tl('login_forgot', 'Şifremi unuttum'), 12, RIGHT);
		forgotText.color = C_FAINT;
		add(forgotText);

		submitBtn = buildRoundedCard(FIELD_W, BTN_H, 0xFFFFFFFF);
		submitBtn.color = C_BTN;
		add(submitBtn);
		submitBtnRing = buildRoundedCard(FIELD_W + RING_W * 2, BTN_H + RING_W * 2, C_ACCENT);
		submitBtnRing.alpha = 0;
		add(submitBtnRing);

		submitText = makeText(fieldX, 0, FIELD_W, '', 20, CENTER);
		add(submitText);

		for (i in 0...3)
		{
			var dot = buildCircle(8, C_ACCENT, true);
			dot.visible = false;
			busyDots.push(dot);
			add(dot);
		}

		sepLine = new FlxSprite().makeGraphic(Std.int(FIELD_W - 80), 1, C_SEP);
		sepLine.scrollFactor.set();
		add(sepLine);

		toggleText = makeText(cardX, 0, CARD_W, '', 13, CENTER);
		toggleText.color = C_ACCENT;
		add(toggleText);

		backText = makeText(cardX, 0, CARD_W, tl('login_skip', 'Atla'), 13, CENTER);
		backText.color = C_FAINT;
		add(backText);

		var avatarCx:Float = cardX + CARD_W / 2;
		avatarRing = buildCircle(94, C_ACCENT, false);
		addAt(avatarRing, 0, avatarCx - 47);
		avatarBg = buildCircle(88, C_INNER, true);
		addAt(avatarBg, 0, avatarCx - 44);
		avatarLetter = makeText(avatarCx - 44, 0, 88, 'P', 36, CENTER);
		avatarLetter.color = C_ACCENT;
		add(avatarLetter);

		profSubText = makeText(cardX, 0, CARD_W, tl('login_profile_hi', 'HOŞ GELDİN'), 13, CENTER);
		profSubText.color = C_FAINT;
		add(profSubText);

		profNameText = makeText(cardX, 0, CARD_W, 'Player', 30, CENTER);
		add(profNameText);

		for (i in 0...3)
		{
			var box = buildRoundedCard(112, 64, C_INNER);
			statBoxes.push(box);
			add(box);
			var val = makeText(0, 0, 112, '0', 22, CENTER);
			val.color = C_ACCENT;
			statValues.push(val);
			add(val);
			var lab = makeText(0, 0, 112, '', 11, CENTER);
			lab.color = C_FAINT;
			statLabels.push(lab);
			add(lab);
		}
		statLabels[0].text = tl('login_stat_level', 'SEVİYE');
		statLabels[1].text = tl('login_stat_points', 'ULTRA PUAN');
		statLabels[2].text = tl('login_stat_streak', 'SERİ');

		continueBtn = buildRoundedCard(FIELD_W, BTN_H, 0xFFFFFFFF);
		continueBtn.color = C_BTN;
		add(continueBtn);
		continueText = makeText(fieldX, 0, FIELD_W, tl('login_btn_continue', 'DEVAM ET'), 20, CENTER);
		add(continueText);

		logoutText = makeText(cardX, 0, CARD_W, tl('login_btn_logout', 'ÇIKIŞ YAP'), 14, CENTER);
		logoutText.color = C_LOGOUT;
		add(logoutText);

		statusText = makeText(cardX, 0, CARD_W, '', 13, CENTER);
		statusText.color = C_RED;
		add(statusText);

		formSprites = [userLabel, userFieldBg, emailLabel, emailFieldBg, passLabel, passFieldBg, forgotText, submitBtn, submitText, sepLine, toggleText, backText];
		formInputs = [userInput, emailInput, passInput];
		profileSprites = [avatarRing, avatarBg, avatarLetter, profSubText, profNameText];
		for (s in statBoxes) profileSprites.push(s);
		for (s in statValues) profileSprites.push(s);
		for (s in statLabels) profileSprites.push(s);
		profileSprites.push(continueBtn);
		profileSprites.push(continueText);
		profileSprites.push(logoutText);

		mode = AuthManager.isLoggedIn ? MODE_PROFILE : MODE_LOGIN;
		fillProfileValues();
		updateModeTexts();
		applyLayout();
		setModeVisibility();

		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('NONE', 'A_B');
		addTouchPadCamera();
		#end

		playEntryAnimation();
	}

	function makeInput(maxLen:Int):PsychUIInputText
	{
		var inp = new PsychUIInputText(fieldX + 12, 0, Std.int(FIELD_W - 24), '', 16);
		inp.maxLength = maxLen;
		inp.bg.visible = false;
		inp.behindText.visible = false;
		inp.textObj.setFormat(Paths.font('vcr.ttf'), 16, C_TEXT);
		inp.scrollFactor.set();
		return inp;
	}

	function makeText(x:Float, y:Float, w:Float, content:String, size:Int, ?align:FlxTextAlign):FlxText
	{
		var t = new FlxText(x, y, Std.int(w), content, size);
		t.setFormat(Paths.font('vcr.ttf'), size, C_TEXT, align != null ? align : LEFT);
		t.scrollFactor.set();
		return t;
	}

	function buildRoundedCard(w:Float, h:Float, color:Int):FlxSprite
	{
		var spr = new FlxSprite();
		var success = false;
		try
		{
			var shape = new Shape();
			shape.graphics.beginFill(color, 1);
			shape.graphics.drawRoundRect(0, 0, w, h, RADIUS, RADIUS);
			shape.graphics.endFill();
			var bmd = new BitmapData(Std.int(w), Std.int(h), true, 0x00000000);
			bmd.draw(shape);
			spr.pixels = bmd;
			success = true;
		}
		catch (e:Dynamic)
		{
			Log.warn('login', 'Rounded card cizilemedi: ' + e);
		}
		if (!success)
			spr.makeGraphic(Std.int(w), Std.int(h), color);
		spr.scrollFactor.set();
		return spr;
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
			success = true;
		}
		catch (e:Dynamic)
		{
			Log.warn('login', 'Daire cizilemedi: ' + e);
		}
		if (!success)
			spr.makeGraphic(Std.int(d), Std.int(d), color);
		spr.scrollFactor.set();
		return spr;
	}

	function addAt(spr:FlxSprite, y:Float, x:Float):Void
	{
		spr.x = x;
		spr.y = y;
		add(spr);
	}

	function tl(key:String, fallback:String):String
	{
		return Language.getPhrase(key, fallback);
	}

	function applyLayout():Void
	{
		if (mode == MODE_PROFILE)
			applyProfileLayout();
		else
			applyFormLayout();
		statusText.x = cardX;
		statusText.y = cardY + (mode == MODE_PROFILE ? 486 : (mode == MODE_REGISTER ? 536 : 490));
	}

	function applyFormLayout():Void
	{
		var isReg:Bool = (mode == MODE_REGISTER);

		var userLabelY:Float = 124;
		var userFieldY:Float = 146;
		var emailLabelY:Float = isReg ? 210 : 136;
		var emailFieldY:Float = isReg ? 232 : 158;
		var passLabelY:Float = isReg ? 296 : 222;
		var passFieldY:Float = isReg ? 318 : 244;
		var forgotY:Float = 300;
		var submitY:Float = isReg ? 384 : 334;

		userLabel.y = cardY + userLabelY;
		userFieldBg.y = cardY + userFieldY;
		userFieldBg.x = fieldX;
		userFieldRing.y = cardY + userFieldY - RING_W;
		userFieldRing.x = fieldX - RING_W;
		userInput.y = cardY + userFieldY + 13;

		emailLabel.y = cardY + emailLabelY;
		emailFieldBg.y = cardY + emailFieldY;
		emailFieldBg.x = fieldX;
		emailFieldRing.y = cardY + emailFieldY - RING_W;
		emailFieldRing.x = fieldX - RING_W;
		emailInput.y = cardY + emailFieldY + 13;

		passLabel.y = cardY + passLabelY;
		passFieldBg.y = cardY + passFieldY;
		passFieldBg.x = fieldX;
		passFieldRing.y = cardY + passFieldY - RING_W;
		passFieldRing.x = fieldX - RING_W;
		passInput.y = cardY + passFieldY + 13;

		forgotText.y = cardY + forgotY;

		submitBtn.y = cardY + submitY;
		submitBtn.x = fieldX;
		submitBtnRing.y = cardY + submitY - RING_W;
		submitBtnRing.x = fieldX - RING_W;
		submitText.y = cardY + submitY + 17;
		for (i in 0...busyDots.length)
		{
			busyDots[i].x = fieldX + FIELD_W / 2 - 22 + i * 18;
			busyDots[i].y = cardY + submitY + BTN_H / 2 - 4;
		}

		sepLine.y = cardY + (isReg ? 460 : 412);
		sepLine.x = cardX + (CARD_W - (FIELD_W - 80)) / 2;
		toggleText.y = cardY + (isReg ? 474 : 426);
		backText.y = cardY + (isReg ? 504 : 456);
	}

	function applyProfileLayout():Void
	{
		var avatarCx:Float = cardX + CARD_W / 2;

		avatarRing.y = cardY + 92;
		avatarRing.x = avatarCx - 47;
		avatarBg.y = cardY + 95;
		avatarBg.x = avatarCx - 44;
		avatarLetter.y = cardY + 117;
		avatarLetter.x = avatarCx - 44;

		profSubText.y = cardY + 200;
		profNameText.y = cardY + 222;

		for (i in 0...statBoxes.length)
		{
			var bx:Float = fieldX + i * 129;
			statBoxes[i].x = bx;
			statBoxes[i].y = cardY + 272;
			statValues[i].x = bx;
			statValues[i].y = cardY + 284;
			statLabels[i].x = bx;
			statLabels[i].y = cardY + 312;
		}

		continueBtn.x = fieldX;
		continueBtn.y = cardY + 356;
		continueText.y = cardY + 373;
		logoutText.y = cardY + 438;
	}

	function fillProfileValues():Void
	{
		var name:String = AuthManager.currentUsername;
		if (name == null || name.length == 0)
			name = 'Player';
		profNameText.text = name;
		avatarLetter.text = name.substr(0, 1).toUpperCase();
		statValues[0].text = Std.string(AuthManager.currentLevel);
		statValues[1].text = Std.string(Math.round(AuthManager.currentUltraPoints));
		statValues[2].text = Std.string(AuthManager.currentUltraStreak);
	}

	function updateModeTexts():Void
	{
		if (mode == MODE_PROFILE)
		{
			titleText.text = tl('login_profile_title', 'HESABIN');
			subtitleText.text = tl('login_profile_sub', 'Başarımların ve skorların senkronize');
			return;
		}
		var isReg:Bool = (mode == MODE_REGISTER);
		titleText.text = isReg ? tl('login_title_register', 'Kayıt Ol') : tl('login_title', 'Giriş Yapın');
		subtitleText.text = isReg ? tl('login_subtitle_register', 'Yeni hesap oluştur') : tl('login_subtitle', 'Hesabına bağlan');
		submitText.text = isReg ? tl('login_btn_register', 'KAYIT OL') : tl('login_btn_login', 'GİRİŞ YAP');
		toggleText.text = isReg ? tl('login_toggle_to_login', 'Zaten hesabın var mı? Giriş yap') : tl('login_toggle_to_register', 'Hesabın yok mu? Kayıt ol');
		emailLabel.text = isReg ? tl('login_email_label', 'E-POSTA') : tl('login_email_or_username', 'E-POSTA VEYA KULLANICI ADI');
	}

	function setModeVisibility():Void
	{
		var form:Bool = (mode != MODE_PROFILE);
		for (spr in formSprites)
			spr.visible = form;
		for (inp in formInputs)
			inp.active = form;

		var isReg:Bool = (mode == MODE_REGISTER);
		userLabel.visible = isReg;
		userFieldBg.visible = isReg;
		userFieldRing.visible = isReg;
		userInput.visible = isReg;
		userInput.active = isReg;
		forgotText.visible = (mode == MODE_LOGIN);
		emailFieldRing.visible = form;
		passFieldRing.visible = form;
		submitBtnRing.visible = form;

		for (spr in profileSprites)
			spr.visible = (mode == MODE_PROFILE);

		if (mode == MODE_PROFILE)
		{
			for (inp in formInputs)
				inp.visible = false;
		}
		else
		{
			emailInput.visible = true;
			passInput.visible = true;
		}

		for (dot in busyDots)
			dot.visible = false;
		_focusedRing = '';
	}

	function playEntryAnimation():Void
	{
		card.alpha = 0;
		cardBorderSpr.alpha = 0;
		card.scale.set(0.95, 0.95);
		FlxTween.tween(card, {alpha: 1}, 0.25);
		FlxTween.tween(card.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.backOut});
		FlxTween.tween(cardBorderSpr, {alpha: 0.6}, 0.25, {startDelay: 0.05});

		var entryList:Array<FlxSprite> = [brandText, titleText, subtitleText];
		var modeList:Array<FlxSprite> = (mode == MODE_PROFILE) ? profileSprites : formSprites;
		for (spr in modeList)
			entryList.push(spr);

		for (i in 0...entryList.length)
		{
			var spr = entryList[i];
			spr.alpha = 0;
			FlxTween.tween(spr, {alpha: 1}, 0.2, {startDelay: 0.08 + i * 0.02});
		}

		if (mode != MODE_PROFILE)
		{
			for (i in 0...formInputs.length)
			{
				var inp = formInputs[i];
				if (!inp.visible) continue;
				inp.alpha = 0;
				FlxTween.tween(inp, {alpha: 1}, 0.2, {startDelay: 0.1 + i * 0.02});
			}
		}

		var endDelay:Float = 0.1 + entryList.length * 0.02;
		statusText.alpha = 0;
		FlxTween.tween(statusText, {alpha: 1}, 0.2, {startDelay: endDelay, onComplete: function(_) { _ready = true; }});
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		_dotTime += elapsed;
		if (_busy)
			animateBusyDots();
		if (!_ready || _busy || _switching) return;

		var pressAccept:Bool = FlxG.keys.justPressed.ENTER
			#if TOUCH_CONTROLS_ALLOWED
			|| (touchPad != null && touchPad.buttonA.justPressed)
			#end
		;
		if (pressAccept)
		{
			if (mode == MODE_PROFILE) goBack();
			else doSubmit();
			return;
		}

		var pressBack:Bool = FlxG.keys.justPressed.ESCAPE || controls.BACK
			#if TOUCH_CONTROLS_ALLOWED
			|| (touchPad != null && touchPad.buttonB.justPressed)
			#end
		;
		if (pressBack)
		{
			if (mode == MODE_PROFILE)
			{
				goBack();
				return;
			}
			var inputActive:Bool = (PsychUIInputText.focusOn == emailInput
				|| PsychUIInputText.focusOn == passInput
				|| PsychUIInputText.focusOn == userInput);
			if (inputActive)
			{
				PsychUIInputText.focusOn = null;
				return;
			}
			goBack();
			return;
		}

		if (mode != MODE_PROFILE)
		{
			if (FlxG.keys.justPressed.TAB)
				cycleFocus();
			updateFocusRings();
		}

		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;

		if (mode == MODE_PROFILE)
		{
			var ch = isOver(continueBtn, mx, my);
			if (ch != _continueHovered)
			{
				_continueHovered = ch;
				continueBtn.color = ch ? C_BTN_HOVER : C_BTN;
			}
			var lh = isOver(logoutText, mx, my);
			if (lh != _logoutHovered)
			{
				_logoutHovered = lh;
				logoutText.color = lh ? C_RED : C_LOGOUT;
			}
		}
		else
		{
			var bh = isOver(submitBtn, mx, my);
			if (bh != _btnHovered)
			{
				_btnHovered = bh;
				submitBtn.color = bh ? C_BTN_HOVER : C_BTN;
			}
			var th = isOver(toggleText, mx, my);
			if (th != _toggleHovered)
			{
				_toggleHovered = th;
				toggleText.color = th ? FlxColor.WHITE : C_ACCENT;
			}
			if (mode == MODE_LOGIN)
			{
				var fh = isOver(forgotText, mx, my);
				if (fh != _forgotHovered)
				{
					_forgotHovered = fh;
					forgotText.color = fh ? C_ACCENT : C_FAINT;
				}
			}
		}
		var bk = isOver(backText, mx, my);
		if (bk != _backHovered)
		{
			_backHovered = bk;
			backText.color = bk ? C_MUTED : C_FAINT;
		}

		if (FlxG.mouse.justPressed)
		{
			if (handleClick(mx, my)) return;
		}

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (!touch.justPressed) continue;
			if (handleClick(touch.screenX, touch.screenY)) return;
		}
		#end
	}

	function handleClick(mx:Float, my:Float):Bool
	{
		if (mode == MODE_PROFILE)
		{
			if (isOver(continueBtn, mx, my)) { goBack(); return true; }
			if (isOver(logoutText, mx, my)) { doLogout(); return true; }
		}
		else
		{
			if (isOver(submitBtn, mx, my)) { doSubmit(); return true; }
			if (isOver(toggleText, mx, my)) { toggleMode(); return true; }
			if (mode == MODE_LOGIN && isOver(forgotText, mx, my)) { doForgot(); return true; }
		}
		if (isOver(backText, mx, my)) { goBack(); return true; }
		return false;
	}

	function isOver(obj:FlxSprite, mx:Float, my:Float):Bool
	{
		if (obj == null || !obj.visible) return false;
		return mx >= obj.x && mx <= obj.x + obj.width
			&& my >= obj.y && my <= obj.y + obj.height;
	}

	function updateFocusRings():Void
	{
		var tag:String = '';
		if (PsychUIInputText.focusOn == userInput) tag = 'user';
		else if (PsychUIInputText.focusOn == emailInput) tag = 'email';
		else if (PsychUIInputText.focusOn == passInput) tag = 'pass';
		if (tag == _focusedRing) return;
		_focusedRing = tag;
		FlxTween.tween(userFieldRing, {alpha: tag == 'user' ? 1 : 0}, 0.15, {ease: FlxEase.quadOut});
		FlxTween.tween(emailFieldRing, {alpha: tag == 'email' ? 1 : 0}, 0.15, {ease: FlxEase.quadOut});
		FlxTween.tween(passFieldRing, {alpha: tag == 'pass' ? 1 : 0}, 0.15, {ease: FlxEase.quadOut});
	}

	function animateBusyDots():Void
	{
		for (i in 0...busyDots.length)
			busyDots[i].alpha = 0.25 + 0.75 * (0.5 + 0.5 * Math.sin(_dotTime * 8 - i * 0.9));
	}

	function cycleFocus():Void
	{
		if (mode == MODE_REGISTER)
		{
			if (PsychUIInputText.focusOn == userInput)
				PsychUIInputText.focusOn = emailInput;
			else if (PsychUIInputText.focusOn == emailInput)
				PsychUIInputText.focusOn = passInput;
			else
				PsychUIInputText.focusOn = userInput;
		}
		else
		{
			if (PsychUIInputText.focusOn == emailInput)
				PsychUIInputText.focusOn = passInput;
			else
				PsychUIInputText.focusOn = emailInput;
		}
	}

	function toggleMode():Void
	{
		if (_busy || _switching) return;
		_switching = true;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		PsychUIInputText.focusOn = null;

		for (spr in formSprites)
			FlxTween.tween(spr, {alpha: 0}, 0.12);
		for (inp in formInputs)
			FlxTween.tween(inp, {alpha: 0}, 0.12);

		new FlxTimer().start(0.15, function(_:FlxTimer)
		{
			mode = (mode == MODE_REGISTER) ? MODE_LOGIN : MODE_REGISTER;
			updateModeTexts();
			applyLayout();
			setModeVisibility();
			statusText.text = '';
			for (spr in formSprites)
			{
				spr.alpha = 0;
				FlxTween.tween(spr, {alpha: 1}, 0.15);
			}
			for (inp in formInputs)
			{
				if (!inp.visible) continue;
				inp.alpha = 0;
				FlxTween.tween(inp, {alpha: 1}, 0.15);
			}
			new FlxTimer().start(0.17, function(_:FlxTimer) { _switching = false; });
		});
	}

	function doForgot():Void
	{
		if (_busy || _switching) return;
		var email = emailInput.text.trim();
		if (email.indexOf('@') == -1)
		{
			showError(tl('login_forgot_need_email', 'Sıfırlama için e-posta alanına geçerli bir e-posta yaz'));
			return;
		}
		_busy = true;
		setBtnBusy(true);
		showStatus(tl('login_forgot_sending', 'Gönderiliyor...'), C_MUTED);
		AuthManager.forgotPassword(email, function(ok:Bool, msg:String)
		{
			_busy = false;
			setBtnBusy(false);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			showStatus(tl('login_forgot_sent', 'Sıfırlama e-postası gönderildi!'), C_GREEN);
		});
	}

	function doLogout():Void
	{
		if (_busy || _switching) return;
		AuthManager.logout();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		PsychUIInputText.focusOn = null;
		_switching = true;

		for (spr in profileSprites)
			FlxTween.tween(spr, {alpha: 0}, 0.15);

		new FlxTimer().start(0.18, function(_:FlxTimer)
		{
			mode = MODE_LOGIN;
			updateModeTexts();
			applyLayout();
			setModeVisibility();
			for (spr in formSprites)
			{
				spr.alpha = 0;
				FlxTween.tween(spr, {alpha: 1}, 0.18);
			}
			for (inp in formInputs)
			{
				if (!inp.visible) continue;
				inp.alpha = 0;
				FlxTween.tween(inp, {alpha: 1}, 0.18);
			}
			showStatus(tl('login_logged_out', 'Çıkış yapıldı. Giriş yapabilirsin.'), C_MUTED);
			new FlxTimer().start(0.2, function(_:FlxTimer) { _switching = false; });
		});
	}

	function doSubmit():Void
	{
		if (_busy || _switching) return;

		var email = emailInput.text.trim();
		var pass = passInput.text;

		if (mode == MODE_REGISTER)
		{
			var user = userInput.text.trim();
			if (user.length < 4) { showError(tl('login_err_username_short', 'Kullanıcı adı en az 4 karakter olmalı')); return; }
			if (email == "" || email.indexOf("@") == -1) { showError(tl('login_err_invalid_email', 'Geçerli bir e-posta girin')); return; }
			if (pass.length < 6) { showError(tl('login_err_password_short', 'Şifre en az 6 karakter olmalı')); return; }

			_busy = true;
			setBtnBusy(true);
			showStatus(tl('login_status_registering', 'Kayıt olunuyor, lütfen bekle...'), C_MUTED);

			AuthManager.register(email, pass, user, "Unknown", function(ok:Bool, msg:String) {
				_busy = false;
				setBtnBusy(false);
				if (ok) {
					showStatus(tl('login_status_register_success', 'Kayıt başarılı!'), C_GREEN);
					FlxG.sound.play(Paths.sound('confirmMenu'));
					#if ACHIEVEMENTS_ALLOWED
					backend.AchievementSync.flushQueue();
					#end
					new FlxTimer().start(0.8, function(_) { goBack(); });
				} else showError(msg);
			});
		}
		else
		{
			if (email == "") { showError(tl('login_err_email_empty', 'E-posta veya kullanıcı adı girin')); return; }
			if (pass.length < 1) { showError(tl('login_err_password_empty', 'Şifre girin')); return; }

			_busy = true;
			setBtnBusy(true);
			showStatus(tl('login_status_logging_in', 'Giriş yapılıyor...'), C_MUTED);

			var callback = function(success:Bool, msg:String) {
				_busy = false;
				setBtnBusy(false);
				if (success) {
					showStatus(tl('login_status_login_success', 'Giriş başarılı!'), C_GREEN);
					FlxG.sound.play(Paths.sound('confirmMenu'));
					#if ACHIEVEMENTS_ALLOWED
					backend.AchievementSync.flushQueue();
					#end
					new FlxTimer().start(0.8, function(_) { goBack(); });
				} else showError(msg);
			};

			if (email.indexOf("@") != -1)
				AuthManager.login(email, pass, callback);
			else
				AuthManager.loginWithUsername(email, pass, callback);
		}
	}

	function showError(msg:String):Void
	{
		FlxG.sound.play(Paths.sound('cancelMenu'));
		showStatus(msg, C_RED);
	}

	function showStatus(msg:String, color:FlxColor):Void
	{
		statusText.text = msg;
		statusText.color = color;
		statusText.alpha = 0;
		FlxTween.cancelTweensOf(statusText);
		FlxTween.tween(statusText, {alpha: 1}, 0.15);
	}

	function setBtnBusy(busy:Bool):Void
	{
		submitBtn.color = busy ? C_BTN_BUSY : C_BTN;
		submitText.text = busy ? '' : (mode == MODE_REGISTER ? tl('login_btn_register', 'KAYIT OL') : tl('login_btn_login', 'GİRİŞ YAP'));
		for (dot in busyDots)
			dot.visible = busy;
		_btnHovered = false;
	}

	function goBack():Void
	{
		if (_busy || _switching) return;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		PsychUIInputText.focusOn = null;
		if (SetupWizardState.returnToWizard) {
			SetupWizardState.returnToWizard = false;
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new SetupWizardState());
			return;
		}
		MenuStyleRouter.goToMainMenu();
	}
}