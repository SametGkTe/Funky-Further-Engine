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

class HelloState extends MusicBeatState
{
	public static var ENABLED:Bool = true;
	public static var PERSON_NAME:String = "Eternal Sugar"; // igilybtnsmt really
	public static var SHOW_EVERY_LAUNCH:Bool = false;

	static final MESSAGE_TR:String =
		"Merhaba {0}! Peak biri olduğun için bu sürüm senin için yapıldı KDHJFGKDHGKDHGKJDHJG";

	public static var leftState:Bool = false;

	static inline final FONT_PATH:String = "vcr.ttf";
	static inline final FONT_SIZE_TITLE:Int = 32;
	static inline final FONT_SIZE_BUTTON:Int = 32;
	static inline final FONT_SIZE_HINT:Int = 18;

	static inline final SIDE_MARGIN:Float = 48;
	static inline final BUTTON_WIDTH:Float = 220;
	static inline final SELECTOR_WIDTH:Float = 72;
	static inline final SELECTOR_HEIGHT:Int = 4;
	static inline final SELECTOR_Y_OFFSET:Float = 8;

	static inline final INTRO_Y_OFFSET:Float = 18;
	static inline final INTRO_TIME:Float = 0.35;
	static inline final BG_FADE_TIME:Float = 0.25;

	static inline final NAV_SOUND_VOLUME:Float = 0.7;
	static inline final CONFIRM_EXIT_DELAY:Float = 0.45;

	var allowInput:Bool = false;

	var bg:FlxSprite;
	var helloText:FlxText;
	var continueButton:FlxText;
	var selector:FlxSprite;
	var hintText:FlxText;

	public static function shouldShow():Bool
	{
		if (!ENABLED || leftState)
			return false;
		if (SHOW_EVERY_LAUNCH)
			return true;
		return FlxG.save.data == null || FlxG.save.data.helloShown != true;
	}

	override function create()
	{
		super.create();
		leftState = false;

		createBackground();
		createTexts();
		createSelector();
		createMobilePad();

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
			handleInput();

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

		helloText = new FlxText(SIDE_MARGIN, 0, FlxG.width - (SIDE_MARGIN * 2),
			StringTools.replace(MESSAGE_TR, "{0}", PERSON_NAME));
		helloText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_TITLE, FlxColor.WHITE, CENTER);
		helloText.y = FlxG.height * 0.28;
		add(helloText);

		final buttonsY = helloText.y + helloText.height + 40;

		continueButton = new FlxText(centerX - (BUTTON_WIDTH * 0.5), buttonsY, BUTTON_WIDTH, "Devam Et");
		continueButton.setFormat(Paths.font(FONT_PATH), FONT_SIZE_BUTTON, FlxColor.WHITE, CENTER);
		add(continueButton);

		hintText = new FlxText(0, FlxG.height - 86, FlxG.width,
			controls.mobileC ? "[ENTER] Devam Et" : "[A] Devam Et");
		hintText.setFormat(Paths.font(FONT_PATH), FONT_SIZE_HINT, 0xFFBFBFBF, CENTER);
		add(hintText);
	}

	function createSelector():Void
	{
		selector = new FlxSprite().makeGraphic(Std.int(SELECTOR_WIDTH), SELECTOR_HEIGHT, FlxColor.WHITE);
		selector.x = continueButton.x + ((continueButton.width - selector.width) * 0.5);
		selector.y = continueButton.y + continueButton.height + SELECTOR_Y_OFFSET;
		add(selector);
	}

	function createMobilePad():Void
	{
		addTouchPad("NONE", "A");
		if (touchPad != null)
			touchPad.alpha = 0;
	}

	function playIntro():Void
	{
		allowInput = false;

		FlxTween.tween(bg, {alpha: 1}, BG_FADE_TIME, {ease: FlxEase.quadOut});

		animateIn(helloText, 0.05);
		animateIn(continueButton, 0.15);
		animateIn(selector, 0.23);
		animateIn(hintText, 0.32, function()
		{
			allowInput = true;
		});

		if (touchPad != null)
		{
			FlxTween.tween(touchPad, {alpha: 1}, 0.35, {
				startDelay: 0.32,
				ease: FlxEase.quadOut
			});
		}
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
		if (controls.ACCEPT)
			confirmContinue();
	}

	function confirmContinue():Void
	{
		if (leftState) return;

		leftState = true;
		allowInput = false;
		skipTransitions();

		if (!SHOW_EVERY_LAUNCH)
		{
			FlxG.save.data.helloShown = true;
			FlxG.save.flush();
		}

		FlxG.sound.play(Paths.sound("confirmMenu"));

		FlxFlicker.flicker(continueButton, 0.8, 0.08, true, true, function(_)
		{
			new FlxTimer().start(CONFIRM_EXIT_DELAY, function(_)
			{
				fadeOutAndSwitch(0.25);
			});
		});
	}

	function fadeOutAndSwitch(duration:Float):Void
	{
		FlxTween.tween(bg, {alpha: 0}, duration);

		for (member in getUiMembers())
			FlxTween.tween(member, {alpha: 0}, duration, {ease: FlxEase.quadOut});

		var finish = function()
		{
			MusicBeatState.switchState(new TitleState());
		};

		if (touchPad != null)
		{
			FlxTween.tween(touchPad, {alpha: 0}, duration, {
				ease: FlxEase.quadOut,
				onComplete: function(_)
				{
					finish();
				}
			});
		}
		else
		{
			new FlxTimer().start(duration, function(_)
			{
				finish();
			});
		}
	}

	function getUiMembers():Array<FlxSprite>
	{
		return [helloText, continueButton, selector, hintText];
	}

	inline function skipTransitions():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
	}
}
