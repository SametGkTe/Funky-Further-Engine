package states;

import backend.AuthManager;
import backend.ui.PsychUIInputText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;

class LoginState extends MusicBeatState {
	static inline var C_BG = 0xFF0a0a0a;
	static inline var C_CARD = 0xFF161616;
	static inline var C_FIELD = 0xFF111111;
	static inline var C_FIELD_LINE = 0xFF444444;
	static inline var C_ACCENT = 0xFF888888;
	static inline var C_ACCENT_LIGHT = 0xFFaaaaaa;
	static inline var C_TEXT = 0xFFe0e0e0;
	static inline var C_MUTED = 0xFF606060;
	static inline var C_RED = 0xFFef4444;
	static inline var C_GREEN = 0xFF22c55e;
	static inline var C_BTN = 0xFF2a2a2a;
	static inline var C_BTN_HOVER = 0xFF383838;
	static inline var C_BORDER = 0xFF222222;

	static inline var CARD_W = 440;
	static inline var CARD_H = 500;
	static inline var FIELD_W = 370;
	static inline var FIELD_H = 44;

	var cardX:Float;
	var cardY:Float;
	var fieldX:Float;

	var bg:FlxSprite;
	var card:FlxSprite;
	var accentLine:FlxSprite;
	var borderBottom:FlxSprite;
	var titleText:FlxText;
	var subtitleText:FlxText;
	var statusText:FlxText;
	var emailLabel:FlxText;
	var passLabel:FlxText;
	var userLabel:FlxText;
	var emailInput:PsychUIInputText;
	var passInput:PsychUIInputText;
	var userInput:PsychUIInputText;
	var loginBtn:FlxSprite;
	var loginBtnLine:FlxSprite;
	var loginBtnText:FlxText;
	var toggleText:FlxText;
	var skipText:FlxText;
	var sepLine:FlxSprite;

	var emailFieldBg:FlxSprite;
	var emailFieldLine:FlxSprite;
	var passFieldBg:FlxSprite;
	var passFieldLine:FlxSprite;
	var userFieldBg:FlxSprite;
	var userFieldLine:FlxSprite;

	var _isRegister:Bool = false;
	var _busy:Bool = false;
	var _btnHovered:Bool = false;
	var _toggleHovered:Bool = false;
	var _skipHovered:Bool = false;
	var _ready:Bool = false;

	var regElements:Array<flixel.FlxBasic> = [];

	override function create() {
		super.create();

		cardX = (FlxG.width - CARD_W) / 2;
		cardY = (FlxG.height - CARD_H) / 2;
		fieldX = cardX + (CARD_W - FIELD_W) / 2;

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, C_BG);
		bg.scrollFactor.set(0, 0);
		add(bg);

		card = new FlxSprite(cardX, cardY).makeGraphic(CARD_W, CARD_H, C_CARD);
		card.scrollFactor.set(0, 0);
		card.alpha = 0;
		add(card);

		accentLine = new FlxSprite(cardX, cardY).makeGraphic(CARD_W, 2, C_ACCENT);
		accentLine.scrollFactor.set(0, 0);
		accentLine.alpha = 0;
		add(accentLine);

		borderBottom = new FlxSprite(cardX, cardY + CARD_H - 1).makeGraphic(CARD_W, 1, C_BORDER);
		borderBottom.scrollFactor.set(0, 0);
		borderBottom.alpha = 0;
		add(borderBottom);

		var curY:Float = cardY + 30;

		titleText = makeText(cardX, curY, CARD_W, Language.getPhrase('login_title', 'Giriş Yapın'), 28, CENTER);
		titleText.alpha = 0;
		add(titleText);
		curY += 36;

		subtitleText = makeText(cardX, curY, CARD_W, Language.getPhrase('login_subtitle', 'Hesabınıza bağlanın'), 14, CENTER);
		subtitleText.color = C_MUTED;
		subtitleText.alpha = 0;
		add(subtitleText);
		curY += 44;

		userLabel = makeText(fieldX, curY, FIELD_W, Language.getPhrase('login_username_label', 'KULLANICI ADI'), 12);
		userLabel.color = C_MUTED;
		regElements.push(userLabel);
		add(userLabel);

		var uf = makeField(fieldX, curY + 18);
		userFieldBg = uf.bg;
		userFieldLine = uf.line;
		regElements.push(userFieldBg);
		regElements.push(userFieldLine);

		userInput = new PsychUIInputText(Std.int(fieldX + 12), Std.int(curY + 28), Std.int(FIELD_W - 24), "", 16);
		userInput.maxLength = 20;
		regElements.push(userInput);
		add(userInput);
		curY += FIELD_H + 30;

		emailLabel = makeText(fieldX, curY, FIELD_W, Language.getPhrase('login_email_or_username', 'E-POSTA VEYA KULLANICI ADI'), 12);
		emailLabel.color = C_MUTED;
		emailLabel.alpha = 0;
		add(emailLabel);

		var ef = makeField(fieldX, curY + 18);
		emailFieldBg = ef.bg;
		emailFieldLine = ef.line;
		emailFieldBg.alpha = 0;
		emailFieldLine.alpha = 0;

		emailInput = new PsychUIInputText(Std.int(fieldX + 12), Std.int(curY + 28), Std.int(FIELD_W - 24), "", 16);
		emailInput.maxLength = 50;
		add(emailInput);
		curY += FIELD_H + 30;

		passLabel = makeText(fieldX, curY, FIELD_W, Language.getPhrase('login_password_label', 'ŞİFRE'), 12);
		passLabel.color = C_MUTED;
		passLabel.alpha = 0;
		add(passLabel);

		var pf = makeField(fieldX, curY + 18);
		passFieldBg = pf.bg;
		passFieldLine = pf.line;
		passFieldBg.alpha = 0;
		passFieldLine.alpha = 0;

		passInput = new PsychUIInputText(Std.int(fieldX + 12), Std.int(curY + 28), Std.int(FIELD_W - 24), "", 16);
		passInput.maxLength = 50;
		passInput.passwordMask = true;
		add(passInput);
		curY += FIELD_H + 28;

		loginBtn = new FlxSprite(fieldX, curY).makeGraphic(FIELD_W, 46, C_BTN);
		loginBtn.scrollFactor.set(0, 0);
		loginBtn.alpha = 0;
		add(loginBtn);

		loginBtnLine = new FlxSprite(fieldX, curY).makeGraphic(FIELD_W, 2, C_ACCENT);
		loginBtnLine.scrollFactor.set(0, 0);
		loginBtnLine.alpha = 0;
		add(loginBtnLine);

		loginBtnText = makeText(fieldX, curY + 13, FIELD_W, Language.getPhrase('login_btn_login', 'GİRİŞ YAP'), 17, CENTER);
		loginBtnText.setFormat(Paths.font("vcr.ttf"));
		loginBtnText.alpha = 0;
		add(loginBtnText);
		curY += 58;

		sepLine = new FlxSprite(fieldX + 40, curY).makeGraphic(FIELD_W - 80, 1, C_BORDER);
		sepLine.scrollFactor.set(0, 0);
		sepLine.alpha = 0;
		add(sepLine);
		curY += 16;

		toggleText = makeText(cardX, curY, CARD_W, Language.getPhrase('login_toggle_to_register', 'Hesabınız yok mu? Kayıt olun'), 13, CENTER);
		toggleText.color = C_ACCENT_LIGHT;
		toggleText.alpha = 0;
		add(toggleText);
		curY += 26;

		skipText = makeText(cardX, curY, CARD_W, Language.getPhrase('login_skip', 'Atla'), 13, CENTER);
		skipText.color = C_MUTED;
		skipText.alpha = 0;
		add(skipText);
		curY += 28;

		statusText = makeText(cardX, curY, CARD_W, "", 13, CENTER);
		statusText.color = C_RED;
		statusText.alpha = 0;
		add(statusText);

		setRegisterVisible(false);
		playEntryAnimation();
		
		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('NONE', 'A_B');
		addTouchPadCamera();
		#end
	}

	function playEntryAnimation():Void {
		card.scale.set(0.95, 0.95);
		FlxTween.tween(card, {alpha: 1}, 0.25);
		FlxTween.tween(card.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.backOut});
		FlxTween.tween(accentLine, {alpha: 0.7}, 0.2, {startDelay: 0.05});
		FlxTween.tween(borderBottom, {alpha: 0.3}, 0.2, {startDelay: 0.05});
		FlxTween.tween(titleText, {alpha: 1}, 0.2, {startDelay: 0.08});
		FlxTween.tween(subtitleText, {alpha: 1}, 0.2, {startDelay: 0.1});
		FlxTween.tween(emailLabel, {alpha: 1}, 0.2, {startDelay: 0.12});
		FlxTween.tween(emailFieldBg, {alpha: 1}, 0.2, {startDelay: 0.14});
		FlxTween.tween(emailFieldLine, {alpha: 0.3}, 0.2, {startDelay: 0.14});
		FlxTween.tween(passLabel, {alpha: 1}, 0.2, {startDelay: 0.16});
		FlxTween.tween(passFieldBg, {alpha: 1}, 0.2, {startDelay: 0.18});
		FlxTween.tween(passFieldLine, {alpha: 0.3}, 0.2, {startDelay: 0.18});
		FlxTween.tween(loginBtn, {alpha: 1}, 0.2, {startDelay: 0.2});
		FlxTween.tween(loginBtnLine, {alpha: 0.5}, 0.2, {startDelay: 0.2});
		FlxTween.tween(loginBtnText, {alpha: 1}, 0.2, {startDelay: 0.2});
		FlxTween.tween(sepLine, {alpha: 0.15}, 0.2, {startDelay: 0.22});
		FlxTween.tween(toggleText, {alpha: 1}, 0.2, {startDelay: 0.24});
		FlxTween.tween(skipText, {alpha: 1}, 0.2, {startDelay: 0.26});
		FlxTween.tween(statusText, {alpha: 1}, 0.2, {
			startDelay: 0.28,
			onComplete: function(_) { _ready = true; }
		});
	}

	function makeText(x:Float, y:Float, w:Dynamic, content:String, size:Int, ?align:FlxTextAlign):FlxText {
		var t = new FlxText(x, y, Std.int(w), content, size);
		t.setFormat(Paths.font("vcr.ttf"), size, C_TEXT, align != null ? align : LEFT);
		t.scrollFactor.set(0, 0);
		return t;
	}

	function makeField(x:Float, y:Float):{bg:FlxSprite, line:FlxSprite} {
		var fbg = new FlxSprite(x, y).makeGraphic(FIELD_W, FIELD_H, C_FIELD);
		fbg.scrollFactor.set(0, 0);
		add(fbg);

		var fline = new FlxSprite(x, y + FIELD_H - 2).makeGraphic(FIELD_W, 2, C_FIELD_LINE);
		fline.scrollFactor.set(0, 0);
		fline.alpha = 0.3;
		add(fline);

		return {bg: fbg, line: fline};
	}

	function setRegisterVisible(show:Bool):Void {
		for (el in regElements)
			el.visible = show;
		userInput.active = show;
		emailLabel.text = show ? Language.getPhrase('login_email_label', 'E-POSTA') : Language.getPhrase('login_email_or_username', 'E-POSTA VEYA KULLANICI ADI');
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);

		if (!_ready || _busy) return;

		var inputActive = (PsychUIInputText.focusOn == emailInput
			|| PsychUIInputText.focusOn == passInput
			|| PsychUIInputText.focusOn == userInput);

		if (FlxG.keys.justPressed.ENTER
			#if TOUCH_CONTROLS_ALLOWED
			|| (touchPad != null && touchPad.buttonA.justPressed)
			#end
		) {
			doSubmit();
			return;
		}

		if (!inputActive) {
			if (FlxG.keys.justPressed.ESCAPE || controls.BACK
				#if TOUCH_CONTROLS_ALLOWED
				|| (touchPad != null && touchPad.buttonB.justPressed)
				#end
			) {
				goBack();
				return;
			}
		} else {
			if (FlxG.keys.justPressed.ESCAPE
				#if TOUCH_CONTROLS_ALLOWED
				|| (touchPad != null && touchPad.buttonB.justPressed)
				#end
			) {
				PsychUIInputText.focusOn = null;
				return;
			}
		}

		if (FlxG.keys.justPressed.TAB)
			cycleFocus();

		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;

		var bh = isOver(loginBtn, mx, my);
		if (bh != _btnHovered) {
			_btnHovered = bh;
			loginBtn.color = bh ? C_BTN_HOVER : C_BTN;
			loginBtnLine.alpha = bh ? 0.8 : 0.5;
		}

		var th = isOver(toggleText, mx, my);
		if (th != _toggleHovered) {
			_toggleHovered = th;
			toggleText.color = th ? FlxColor.WHITE : C_ACCENT_LIGHT;
		}

		var sh = isOver(skipText, mx, my);
		if (sh != _skipHovered) {
			_skipHovered = sh;
			skipText.color = sh ? C_ACCENT_LIGHT : C_MUTED;
		}

		if (FlxG.mouse.justPressed) {
			if (isOver(loginBtn, mx, my)) { doSubmit(); return; }
			if (isOver(toggleText, mx, my)) { toggleMode(); return; }
			if (isOver(skipText, mx, my)) { goBack(); return; }
		}

		#if mobile
		for (touch in FlxG.touches.list) {
			if (touch.justPressed) {
				var tx = touch.screenX;
				var ty = touch.screenY;
				if (isOver(loginBtn, tx, ty)) { doSubmit(); return; }
				if (isOver(toggleText, tx, ty)) { toggleMode(); return; }
				if (isOver(skipText, tx, ty)) { goBack(); return; }
			}
		}
		#end
	}

	function isOver(obj:FlxSprite, mx:Float, my:Float):Bool {
		return mx >= obj.x && mx <= obj.x + obj.width
			&& my >= obj.y && my <= obj.y + obj.height;
	}

	function cycleFocus():Void {
		if (_isRegister) {
			if (PsychUIInputText.focusOn == userInput)
				PsychUIInputText.focusOn = emailInput;
			else if (PsychUIInputText.focusOn == emailInput)
				PsychUIInputText.focusOn = passInput;
			else
				PsychUIInputText.focusOn = userInput;
		} else {
			if (PsychUIInputText.focusOn == emailInput)
				PsychUIInputText.focusOn = passInput;
			else
				PsychUIInputText.focusOn = emailInput;
		}
	}

	function toggleMode():Void {
		_isRegister = !_isRegister;
		FlxG.sound.play(Paths.sound('scrollMenu'));

		titleText.text = _isRegister ? Language.getPhrase('login_title_register', 'Kayıt Ol') : Language.getPhrase('login_title', 'Giriş Yapın');
		subtitleText.text = _isRegister ? Language.getPhrase('login_subtitle_register', 'Yeni hesap oluşturun') : Language.getPhrase('login_subtitle', 'Hesabınıza bağlanın');
		loginBtnText.text = _isRegister ? Language.getPhrase('login_btn_register', 'KAYIT OL') : Language.getPhrase('login_btn_login', 'GİRİŞ YAP');
		toggleText.text = _isRegister ? Language.getPhrase('login_toggle_to_login', 'Zaten hesabınız var mı? Giriş yapın') : Language.getPhrase('login_toggle_to_register', 'Hesabınız yok mu? Kayıt olun');

		setRegisterVisible(_isRegister);
		statusText.text = "";
	}

	function doSubmit():Void {
		if (_busy) return;

		var email = emailInput.text.trim();
		var pass = passInput.text;

		if (_isRegister) {
			var user = userInput.text.trim();
			if (user.length < 4) { showError(Language.getPhrase('login_err_username_short', 'Kullanıcı adı en az 4 karakter olmalı')); return; }
			if (email == "" || email.indexOf("@") == -1) { showError(Language.getPhrase('login_err_invalid_email', 'Geçerli bir e-posta girin')); return; }
			if (pass.length < 6) { showError(Language.getPhrase('login_err_password_short', 'Şifre en az 6 karakter olmalı')); return; }

			_busy = true;
			showStatus(Language.getPhrase('login_status_registering', 'Kayıt olunuyor, lütfen bekleyin...'), C_MUTED);
			setBtnBusy(true);

			AuthManager.register(email, pass, user, "Unknown", function(ok:Bool, msg:String) {
				_busy = false;
				setBtnBusy(false);
				if (ok) {
					showStatus(Language.getPhrase('login_status_register_success', 'Kayıt başarılı!'), C_GREEN);
					FlxG.sound.play(Paths.sound('confirmMenu'));
					#if ACHIEVEMENTS_ALLOWED
					backend.AchievementSync.flushQueue();
					#end
					new FlxTimer().start(0.8, function(_) { goBack(); });
				} else showError(msg);
			});
		} else {
			if (email == "") { showError(Language.getPhrase('login_err_email_empty', 'E-posta veya kullanıcı adı girin')); return; }
			if (pass.length < 1) { showError(Language.getPhrase('login_err_password_empty', 'Şifre girin')); return; }

			_busy = true;
			showStatus(Language.getPhrase('login_status_logging_in', 'Giriş yapılıyor...'), C_MUTED);
			setBtnBusy(true);

			var callback = function(success:Bool, msg:String) {
				_busy = false;
				setBtnBusy(false);
				if (success) {
					showStatus(Language.getPhrase('login_status_login_success', 'Giriş başarılı!'), C_GREEN);
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

	function showError(msg:String):Void {
		FlxG.sound.play(Paths.sound('cancelMenu'));
		showStatus(msg, C_RED);
	}

	function showStatus(msg:String, color:FlxColor):Void {
		statusText.text = msg;
		statusText.color = color;
		statusText.alpha = 0;
		FlxTween.cancelTweensOf(statusText);
		FlxTween.tween(statusText, {alpha: 1}, 0.15);
	}

	function setBtnBusy(busy:Bool):Void {
		loginBtn.color = busy ? C_FIELD : C_BTN;
		loginBtnLine.alpha = busy ? 0.2 : 0.5;
		loginBtnText.alpha = busy ? 0.5 : 1;
	}

	function goBack():Void {
		if (_busy) return;
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