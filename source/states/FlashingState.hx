package states;

import StringTools;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	static inline final DEFAULT_LANGUAGE:String = "tr";

	static inline final FONT_PATH:String = "vcr.ttf";
	static inline final FONT_SIZE_TITLE:Int = 32;
	static inline final FONT_SIZE_BUTTON:Int = 32;
	static inline final FONT_SIZE_HINT:Int = 18;
	static inline final FONT_SIZE_COUNTDOWN:Int = 16;

	static inline final SIDE_MARGIN:Float = 48;
	static inline final BUTTON_WIDTH:Float = 160;
	static inline final BUTTON_GAP:Float = 24;
	static inline final BUTTON_Y_OFFSET:Float = 30;
	static inline final SELECTOR_WIDTH:Float = 72;
	static inline final SELECTOR_HEIGHT:Int = 4;
	static inline final SELECTOR_Y_OFFSET:Float = 8;

	static inline final INTRO_Y_OFFSET:Float = 18;
	static inline final INTRO_TIME:Float = 0.35;
	static inline final BG_FADE_TIME:Float = 0.25;

	static inline final NAV_SOUND_VOLUME:Float = 0.7;
	static inline final SELECTED_ALPHA:Float = 1.0;
	static inline final UNSELECTED_ALPHA:Float = 0.55;

	static inline final AUTO_SELECT_TIME:Float = 15.0;
	static inline final CONFIRM_EXIT_DELAY:Float = 0.45;

	// -------------------------------------------------------------------------
	// Localization
	// Şimdilik compile-safe olsun diye state içinde tuttum.
	// İstersen bunu bir sonraki mesajda JSON dosyasına taşıyabilirim.
	// -------------------------------------------------------------------------

	static final LOCALIZED_TEXT:Dynamic = {
		tr: {
			warning: "Hey, Dikkat et!\n\nBu Oyun Yanıp Sönen Işıklar içeriyor, onları kapatmak istermisin?",
			yes: "Evet",
			no: "Hayır",
			hintDesktop: "[← →] Seç   [ENTER] Kabul Et   [ESC] Geri",
			hintMobile: "[SOL / SAĞ] Seç   [A] Kabul Et   [B] Geri",
			auto: "Auto-selecting YES in {0}s"
		}
	};

	var selectedIndex:Int = 0; // 0 = Yes, 1 = No
	var allowInput:Bool = false;

	var autoSelectRemaining:Float = AUTO_SELECT_TIME;
	var autoSelectActive:Bool = true;
	var autoSelectCancelled:Bool = false;
	var lastCountdownSecond:Int = -1;

	var bg:FlxSprite;
	var warnText:FlxText;
	var yesButton:FlxText;
	var noButton:FlxText;
	var selector:FlxSprite;
	var hintText:FlxText;
	var countdownText:FlxText;

	override function create()
	{
		super.create();
		leftState = false;

		createBackground();
		createTexts();
		createSelector();
		createMobilePad();

		updateSelection(true);
		updateCountdownText();

		playIntro();
	}

	override function update(elapsed:Float)
	{
		if (leftState)
		{
			super.update(elapsed);
			return;
		}

		if (allowInput)
		{
			updateAutoSelect(elapsed);
			handleInput();
		}

		super.update(elapsed);
	}

	function createBackground():Void
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		add(bg);
	}

	function createTexts():Void
	{
		final centerX = FlxG.width * 0.5;

		warnText = new FlxText(SIDE_MARGIN, 0, FlxG.width - (SIDE_MARGIN * 2), tr("warning"));
		warnText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_TITLE, FlxColor.WHITE, CENTER);
		warnText.y = FlxG.height * 0.24;
		add(warnText);

		final buttonsY = warnText.y + warnText.height + BUTTON_Y_OFFSET;
		final leftButtonX = centerX - BUTTON_WIDTH - (BUTTON_GAP * 0.5);
		final rightButtonX = centerX + (BUTTON_GAP * 0.5);

		yesButton = new FlxText(leftButtonX, buttonsY, BUTTON_WIDTH, tr("yes"));
		yesButton.setFormat(Paths.font(FONT_PATH), FONT_SIZE_BUTTON, FlxColor.WHITE, CENTER);
		add(yesButton);

		noButton = new FlxText(rightButtonX, buttonsY, BUTTON_WIDTH, tr("no"));
		noButton.setFormat(Paths.font(FONT_PATH), FONT_SIZE_BUTTON, FlxColor.WHITE, CENTER);
		add(noButton);

		hintText = new FlxText(0, FlxG.height - 86, FlxG.width, controls.mobileC ? tr("hintMobile") : tr("hintDesktop"));
		hintText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_HINT, 0xFFBFBFBF, CENTER);
		add(hintText);

		countdownText = new FlxText(0, FlxG.height - 58, FlxG.width, "");
		countdownText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_COUNTDOWN, 0xFF8F8F8F, CENTER);
		add(countdownText);
	}

	function createSelector():Void
	{
		selector = new FlxSprite().makeGraphic(Std.int(SELECTOR_WIDTH), SELECTOR_HEIGHT, FlxColor.WHITE);
		add(selector);
	}

	function createMobilePad():Void
	{
		addTouchPad("LEFT_RIGHT", "A_B");
		touchPad.alpha = 0;
	}

	function playIntro():Void
	{
		allowInput = false;

		FlxTween.tween(bg, {alpha: 1}, BG_FADE_TIME, {ease: FlxEase.quadOut});

		animateIn(warnText, 0.05);
		animateIn(yesButton, 0.15);
		animateIn(noButton, 0.23);
		animateIn(selector, 0.31);
		animateIn(hintText, 0.40);
		animateIn(countdownText, 0.48, function()
		{
			allowInput = true;
			resetAutoSelect();
		});

		FlxTween.tween(touchPad, {alpha: 1}, 0.35, {
			startDelay: 0.40,
			ease: FlxEase.quadOut
		});
	}

	function animateIn(sprite:FlxSprite, delay:Float, ?onComplete:Void->Void):Void
	{
		final targetY = sprite.y;
		sprite.y += INTRO_Y_OFFSET;
		sprite.alpha = 0;

		FlxTween.tween(sprite, {alpha: 1, y: targetY}, INTRO_TIME, {
			startDelay: delay,
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				if (onComplete != null) onComplete();
			}
		});
	}

	function handleInput():Void
	{
		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound("scrollMenu"), NAV_SOUND_VOLUME);
			selectedIndex = 1 - selectedIndex;
			updateSelection();
			cancelAutoSelect();   // <-- artık reset değil, iptal
		}

		if (controls.ACCEPT)
		{
			confirmSelection(false);
			return;
		}

		if (controls.BACK)
		{
			cancelAndExit();
			return;
		}
	}

	function cancelAutoSelect():Void
	{
		if (autoSelectCancelled) return;

		autoSelectCancelled = true;
		autoSelectActive = false;

		// countdown text'i yumuşak şekilde kaybet
		FlxTween.cancelTweensOf(countdownText);
		FlxTween.tween(countdownText, {alpha: 0, y: countdownText.y + 8}, 0.3, {
			ease: FlxEase.quadIn,
			onComplete: function(_)
			{
				countdownText.visible = false;
			}
		});
	}

	function updateSelection(?instant:Bool = false):Void
	{
		final yesSelected = selectedIndex == 0;

		yesButton.alpha = yesSelected ? SELECTED_ALPHA : UNSELECTED_ALPHA;
		noButton.alpha = yesSelected ? UNSELECTED_ALPHA : SELECTED_ALPHA;

		yesButton.color = yesSelected ? FlxColor.WHITE : 0xFF9A9A9A;
		noButton.color = yesSelected ? 0xFF9A9A9A : FlxColor.WHITE;

		moveSelectorTo(yesSelected ? yesButton : noButton, instant);
	}

	function moveSelectorTo(button:FlxText, ?instant:Bool = false):Void
	{
		final targetX = button.x + ((button.width - selector.width) * 0.5);
		final targetY = button.y + button.height + SELECTOR_Y_OFFSET;

		if (instant)
		{
			selector.setPosition(targetX, targetY);
			return;
		}

		FlxTween.cancelTweensOf(selector);
		FlxTween.tween(selector, {x: targetX, y: targetY}, 0.18, {
			ease: FlxEase.quadOut
		});
	}
	
	function resetAutoSelect():Void
	{
		autoSelectRemaining = AUTO_SELECT_TIME;
		autoSelectActive = true;
		lastCountdownSecond = -1;
		updateCountdownText();
	}

	function stopAutoSelect():Void
	{
		autoSelectActive = false;
	}
	
	function updateAutoSelect(elapsed:Float):Void
	{
		if (!autoSelectActive)
			return;

		autoSelectRemaining -= elapsed;

		if (autoSelectRemaining <= 0)
		{
			autoSelectRemaining = 0;
			updateCountdownText();
			autoSelectYes();
			return;
		}

		updateCountdownText();
	}

	function updateCountdownText():Void
	{
		final currentSecond = Std.int(Math.ceil(autoSelectRemaining));
		if (currentSecond == lastCountdownSecond)
			return;

		lastCountdownSecond = currentSecond;
		countdownText.text = tr("auto", [currentSecond]);
		countdownText.x = (FlxG.width - countdownText.width) * 0.5;
	}

	function autoSelectYes():Void
	{
		selectedIndex = 0;
		updateSelection();
		confirmSelection(true);
	}

	// -------------------------------------------------------------------------
	// Confirm / Cancel
	// -------------------------------------------------------------------------

	function confirmSelection(fromAutoSelect:Bool):Void
	{
		if (leftState) return;

		leftState = true;
		allowInput = false;
		stopAutoSelect();
		skipTransitions();

		// Yes = disable flashing
		final disableFlashing = (selectedIndex == 0);
		ClientPrefs.data.flashing = !disableFlashing;
		ClientPrefs.saveSettings();

		FlxG.sound.play(Paths.sound("confirmMenu"));

		final selectedButton = (selectedIndex == 0) ? yesButton : noButton;

		FlxFlicker.flicker(selectedButton, 0.8, 0.08, true, true, function(_)
		{
			new FlxTimer().start(CONFIRM_EXIT_DELAY, function(_)
			{
				fadeOutAndSwitch(0.25);
			});
		});
	}

	function cancelAndExit():Void
	{
		if (leftState) return;

		leftState = true;
		allowInput = false;
		stopAutoSelect();
		skipTransitions();

		FlxG.sound.play(Paths.sound("cancelMenu"));
		fadeOutAndSwitch(0.45);
	}

	function fadeOutAndSwitch(duration:Float):Void
	{
		FlxTween.tween(bg, {alpha: 0}, duration);

		for (member in getUiMembers())
			FlxTween.tween(member, {alpha: 0}, duration, {ease: FlxEase.quadOut});

		FlxTween.tween(touchPad, {alpha: 0}, duration, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				MusicBeatState.switchState(new BetaWarningState());
				// Eskisi: MusicBeatState.switchState(new TitleState());
			}
		});
	}

	function getUiMembers():Array<FlxSprite>
	{
		return [
			warnText,
			yesButton,
			noButton,
			selector,
			hintText,
			countdownText
		];
	}

	inline function skipTransitions():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
	}

	// -------------------------------------------------------------------------
	// Localization helpers
	// -------------------------------------------------------------------------

	function tr(key:String, ?args:Array<Dynamic>):String
	{
		var lang = getCurrentLanguage();
		var langTable:Dynamic = Reflect.field(LOCALIZED_TEXT, lang);

		if (langTable == null)
			langTable = Reflect.field(LOCALIZED_TEXT, DEFAULT_LANGUAGE);

		var value:Dynamic = Reflect.field(langTable, key);

		if (value == null)
			value = Reflect.field(Reflect.field(LOCALIZED_TEXT, DEFAULT_LANGUAGE), key);

		var result:String = Std.string(value);

		if (args != null)
		{
			for (i in 0...args.length)
				result = StringTools.replace(result, "{" + i + "}", Std.string(args[i]));
		}

		return result;
	}

	function getCurrentLanguage():String
	{
		if (ClientPrefs.data != null && Reflect.hasField(ClientPrefs.data, "language"))
		{
			var raw:Dynamic = Reflect.field(ClientPrefs.data, "language");
			if (raw != null)
			{
				var lang = Std.string(raw).toLowerCase();

				if (Reflect.field(LOCALIZED_TEXT, lang) != null)
					return lang;

				var shortLang = lang.split("-")[0];
				if (Reflect.field(LOCALIZED_TEXT, shortLang) != null)
					return shortLang;
			}
		}

		return DEFAULT_LANGUAGE;
	}
}