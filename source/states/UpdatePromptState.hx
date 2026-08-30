package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class UpdatePromptState extends MusicBeatState
{
	var pendingUpdates:Array<Dynamic> = [];
	var leftState:Bool = false;

	static inline final FONT_PATH:String = "vcr.ttf";
	static inline final SIDE_MARGIN:Float = 48;
	static inline final BUTTON_WIDTH:Float = 160;
	static inline final BUTTON_GAP:Float = 24;
	static inline final BUTTON_Y_OFFSET:Float = 40;
	static inline final SELECTOR_WIDTH:Float = 72;
	static inline final SELECTOR_HEIGHT:Int = 4;
	static inline final SELECTOR_Y_OFFSET:Float = 8;
	static inline final INTRO_Y_OFFSET:Float = 18;
	static inline final INTRO_TIME:Float = 0.35;
	static inline final NAV_SOUND_VOLUME:Float = 0.7;
	static inline final SELECTED_ALPHA:Float = 1.0;
	static inline final UNSELECTED_ALPHA:Float = 0.55;
	static inline final AUTO_SELECT_TIME:Float = 20.0;
	static inline final CONFIRM_EXIT_DELAY:Float = 0.45;

	var selectedIndex:Int = 0; // 0 = Evet, 1 = Hayır
	var allowInput:Bool = false;

	var autoSelectRemaining:Float = AUTO_SELECT_TIME;
	var autoSelectActive:Bool = true;
	var autoSelectCancelled:Bool = false;
	var lastCountdownSecond:Int = -1;

	// UI
	var bg:FlxSprite;
	var titleText:FlxText;
	var infoText:FlxText;
	var yesButton:FlxText;
	var noButton:FlxText;
	var selector:FlxSprite;
	var hintText:FlxText;
	var countdownText:FlxText;

	public function new(updates:Array<Dynamic>)
	{
		super();
		pendingUpdates = updates != null ? updates : [];
	}

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

	// ─────────────────────────────────────────────
	//  UI Oluşturma
	// ─────────────────────────────────────────────

	function createBackground():Void
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		add(bg);
	}

	function createTexts():Void
	{
		final centerX = FlxG.width * 0.5;

		titleText = new FlxText(SIDE_MARGIN, 0, FlxG.width - (SIDE_MARGIN * 2), "Modpack Güncellemesi Mevcut!", 28);
		titleText.setFormat(Paths.font(FONT_PATH), 28, 0xFF14B8A6, CENTER);
		titleText.y = FlxG.height * 0.18;
		add(titleText);

		// Bilgi
		var updateCount:Int = pendingUpdates.length;
		var totalSize:String = calculateTotalSize();
		var updateNames:String = getUpdateNames();

		var infoStr:String = '$updateCount güncelleme bulundu.\n\n'
			+ '$updateNames\n\n'
			+ 'Toplam boyut: $totalSize\n\n'
			+ 'Güncellemek ister misiniz?';

		infoText = new FlxText(SIDE_MARGIN + 20, 0, FlxG.width - (SIDE_MARGIN * 2) - 40, infoStr, 18);
		infoText.setFormat(Paths.font(FONT_PATH), 18, FlxColor.WHITE, CENTER);
		infoText.y = titleText.y + titleText.height + 24;
		add(infoText);

		// Butonlar
		final buttonsY = infoText.y + infoText.height + BUTTON_Y_OFFSET;
		final leftButtonX = centerX - BUTTON_WIDTH - (BUTTON_GAP * 0.5);
		final rightButtonX = centerX + (BUTTON_GAP * 0.5);

		yesButton = new FlxText(leftButtonX, buttonsY, BUTTON_WIDTH, "Evet", 32);
		yesButton.setFormat(Paths.font(FONT_PATH), 32, FlxColor.WHITE, CENTER);
		add(yesButton);

		noButton = new FlxText(rightButtonX, buttonsY, BUTTON_WIDTH, "Hayır", 32);
		noButton.setFormat(Paths.font(FONT_PATH), 32, FlxColor.WHITE, CENTER);
		add(noButton);

		var hintStr = controls.mobileC
			? "[SOL / SAĞ] Seç   [A] Kabul Et   [B] Atla"
			: "[← →] Seç   [ENTER] Kabul Et   [ESC] Atla";

		hintText = new FlxText(0, FlxG.height - 86, FlxG.width, hintStr, 16);
		hintText.setFormat(Paths.font(FONT_PATH), 16, 0xFFBFBFBF, CENTER);
		add(hintText);

		countdownText = new FlxText(0, FlxG.height - 58, FlxG.width, "", 14);
		countdownText.setFormat(Paths.font(FONT_PATH), 14, 0xFF8F8F8F, CENTER);
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

	// ─────────────────────────────────────────────
	//  Intro Animasyonu
	// ─────────────────────────────────────────────

	function playIntro():Void
	{
		allowInput = false;

		FlxTween.tween(bg, {alpha: 1}, 0.25, {ease: FlxEase.quadOut});

		animateIn(titleText, 0.05);
		animateIn(infoText, 0.15);
		animateIn(yesButton, 0.25);
		animateIn(noButton, 0.30);
		animateIn(selector, 0.35);
		animateIn(hintText, 0.42);
		animateIn(countdownText, 0.50, function()
		{
			allowInput = true;
			resetAutoSelect();
		});

		FlxTween.tween(touchPad, {alpha: 1}, 0.35, {
			startDelay: 0.42,
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

	// ─────────────────────────────────────────────
	//  Girdi
	// ─────────────────────────────────────────────

	function handleInput():Void
	{
		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound("scrollMenu"), NAV_SOUND_VOLUME);
			selectedIndex = 1 - selectedIndex;
			updateSelection();
			cancelAutoSelect();
		}

		if (controls.ACCEPT)
		{
			confirmSelection();
			return;
		}

		if (controls.BACK)
		{
			skipUpdates();
			return;
		}
	}

	// ─────────────────────────────────────────────
	//  Seçim
	// ─────────────────────────────────────────────

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

	// ─────────────────────────────────────────────
	//  Otomatik Seçim
	// ─────────────────────────────────────────────

	function resetAutoSelect():Void
	{
		autoSelectRemaining = AUTO_SELECT_TIME;
		autoSelectActive = true;
		lastCountdownSecond = -1;
		updateCountdownText();
	}

	function cancelAutoSelect():Void
	{
		if (autoSelectCancelled) return;

		autoSelectCancelled = true;
		autoSelectActive = false;

		FlxTween.cancelTweensOf(countdownText);
		FlxTween.tween(countdownText, {alpha: 0, y: countdownText.y + 8}, 0.3, {
			ease: FlxEase.quadIn,
			onComplete: function(_)
			{
				countdownText.visible = false;
			}
		});
	}

	function updateAutoSelect(elapsed:Float):Void
	{
		if (!autoSelectActive) return;

		autoSelectRemaining -= elapsed;

		if (autoSelectRemaining <= 0)
		{
			autoSelectRemaining = 0;
			updateCountdownText();
			// Otomatik olarak "Hayır" seç (rahatsız etmesin)
			selectedIndex = 1;
			updateSelection();
			skipUpdates();
			return;
		}

		updateCountdownText();
	}

	function updateCountdownText():Void
	{
		final currentSecond = Std.int(Math.ceil(autoSelectRemaining));
		if (currentSecond == lastCountdownSecond) return;

		lastCountdownSecond = currentSecond;
		countdownText.text = '${currentSecond} saniye sonra otomatik atlanacak';
		countdownText.x = (FlxG.width - countdownText.width) * 0.5;
	}

	// ─────────────────────────────────────────────
	//  Onay / Atlama
	// ─────────────────────────────────────────────

	function confirmSelection():Void
	{
		if (leftState) return;

		leftState = true;
		allowInput = false;
		autoSelectActive = false;

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		FlxG.sound.play(Paths.sound("confirmMenu"));

		final selectedButton = (selectedIndex == 0) ? yesButton : noButton;

		FlxFlicker.flicker(selectedButton, 0.8, 0.08, true, true, function(_)
		{
			new FlxTimer().start(CONFIRM_EXIT_DELAY, function(_)
			{
				if (selectedIndex == 0)
				{
					// Evet → UpdateState'e git
					goToUpdateState();
				}
				else
				{
					goToMainMenu();
				}
			});
		});
	}

	function skipUpdates():Void
	{
		if (leftState) return;

		leftState = true;
		allowInput = false;
		autoSelectActive = false;

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		FlxG.sound.play(Paths.sound("cancelMenu"));
		fadeOutAndGo(false);
	}

	// ─────────────────────────────────────────────
	//  Geçişler
	// ─────────────────────────────────────────────

	function goToUpdateState():Void
	{
		fadeOutAndGo(true);
	}

	function goToMainMenu():Void
	{
		fadeOutAndGo(false);
	}

	function fadeOutAndGo(toUpdate:Bool):Void
	{
		var duration:Float = 0.35;

		FlxTween.tween(bg, {alpha: 0}, duration);

		for (member in getUiMembers())
			FlxTween.tween(member, {alpha: 0}, duration, {ease: FlxEase.quadOut});

		FlxTween.tween(touchPad, {alpha: 0}, duration, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				if (toUpdate)
					MusicBeatState.switchState(new UpdateState(pendingUpdates));
				else
					MenuStyleRouter.goToMainMenu();
			}
		});
	}

	function getUiMembers():Array<FlxSprite>
	{
		return [
			titleText,
			infoText,
			yesButton,
			noButton,
			selector,
			hintText,
			countdownText
		];
	}

	// ─────────────────────────────────────────────
	//  Bilgi Yardımcıları
	// ─────────────────────────────────────────────

	function calculateTotalSize():String
	{
		var totalBytes:Float = 0;
		var hasUnknown:Bool = false;

		for (mp in pendingUpdates)
		{
			if (mp.fileSizeBytes != null && Std.parseFloat(Std.string(mp.fileSizeBytes)) > 0)
				totalBytes += Std.parseFloat(Std.string(mp.fileSizeBytes));
			else
				hasUnknown = true;
		}

		if (totalBytes <= 0 && hasUnknown)
			return "Bilinmiyor";

		if (totalBytes < 1024 * 1024)
			return '${Math.round(totalBytes / 1024)} KB';
		else if (totalBytes < 1024 * 1024 * 1024)
			return '${flixel.math.FlxMath.roundDecimal(totalBytes / (1024 * 1024), 1)} MB';
		else
			return '${flixel.math.FlxMath.roundDecimal(totalBytes / (1024 * 1024 * 1024), 2)} GB';
	}

	function getUpdateNames():String
	{
		var names:Array<String> = [];

		for (mp in pendingUpdates)
		{
			var name:String = mp.displayName != null ? mp.displayName : mp.id;
			var ver:String = mp.versionLabel != null ? mp.versionLabel : mp.version;
			var size:String = mp.fileSize != null ? mp.fileSize : "";
			var mode:String = mp.downloadMode != null ? mp.downloadMode : "direct";

			var entry:String = '• $name → $ver';
			if (size.length > 0)
				entry += ' ($size)';
			if (mode == "external")
				entry += ' [Manuel]';

			names.push(entry);
		}

		if (names.length > 5)
		{
			var shown = names.slice(0, 4);
			shown.push('... ve ${names.length - 4} tane daha');
			return shown.join("\n");
		}

		return names.join("\n");
	}
}