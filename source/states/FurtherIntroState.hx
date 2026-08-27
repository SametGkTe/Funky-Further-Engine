package states;

import flixel.FlxState;

class FurtherIntroState extends FlxState
{
	static inline var FADE_IN:Float = 0.4;
	static inline var FIRST_LOGO_TIME:Float = 1.5;
	static inline var SECOND_LOGO_TIME:Float = 2.0;
	static inline var SECRET_LOGO_TIME:Float = 4.0;
	static inline var FADE_OUT:Float = 1.0;
	static inline var SKIP_FADE:Float = 0.2;

	var logo:FlxSprite;
	var closing:Bool = false;
	var phaseTimer:FlxTimer;
	var secretIntro:Bool = false;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		// Secret intro is still a 15% easter egg, but it plays on its own:
		// no title1 swap and no BF "yeah" sound.
		secretIntro = FlxG.random.bool(15) && Paths.fileExists('images/further/titlesecret.png', IMAGE);
		var graphic = secretIntro ? Paths.image('further/titlesecret') : Paths.image('further/title');
		if (graphic == null)
		{
			goToTitle();
			return;
		}

		logo = new FlxSprite().loadGraphic(graphic);
		fitLogoToScreen();
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.alpha = 0;
		add(logo);

		FlxTween.tween(logo, {alpha: 1}, FADE_IN, {ease: FlxEase.quadOut});

		if (secretIntro)
		{
			// 0–4 seconds: titlesecret, 4–5 seconds: fade-out.
			phaseTimer = new FlxTimer().start(SECRET_LOGO_TIME, function(_)
			{
				startFadeOut(FADE_OUT);
			});
		}
		else
		{
			// 0–2 seconds: title.png. The initial fade-in is included in this time.
			phaseTimer = new FlxTimer().start(FIRST_LOGO_TIME, function(_)
			{
				showSecondLogo();
			});
		}
	}

	function showSecondLogo():Void
	{
		if (closing || logo == null)
			return;

		if (Paths.fileExists('images/further/title1.png', IMAGE))
		{
			// Intentional instant swap at exactly two seconds.
			logo.loadGraphic(Paths.image('further/title1'));
			fitLogoToScreen();
			logo.alpha = 1;
		}
		else
			trace('[FurtherIntroState] Missing assets/shared/images/further/title1.png; keeping title.png.');

		if (Paths.fileExists('sounds/bf-yeah.${Paths.SOUND_EXT}', SOUND))
			FlxG.sound.play(Paths.sound('bf-yeah'));
		else
			trace('[FurtherIntroState] Missing assets/shared/sounds/bf-yeah.${Paths.SOUND_EXT}.');

		// 2–4 seconds: title1.png, 4–5 seconds: fade-out.
		phaseTimer = new FlxTimer().start(SECOND_LOGO_TIME, function(_)
		{
			startFadeOut(FADE_OUT);
		});
	}

	function fitLogoToScreen():Void
	{
		logo.setGraphicSize(FlxG.width, FlxG.height);
		logo.updateHitbox();
		logo.screenCenter();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (closing)
			return;

		var skip:Bool = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ESCAPE;
		if (FlxG.mouse.justPressed || TouchUtil.justPressed)
			skip = true;
		#if android
		if (FlxG.android.justReleased.BACK)
			skip = true;
		#end
		var pad = FlxG.gamepads.lastActive;
		if (pad != null && (pad.justPressed.A || pad.justPressed.START || pad.justPressed.B))
			skip = true;

		if (skip)
			startFadeOut(SKIP_FADE);
	}

	function startFadeOut(duration:Float):Void
	{
		if (closing)
			return;
		closing = true;
		if (phaseTimer != null)
		{
			phaseTimer.cancel();
			phaseTimer = null;
		}
		if (logo == null)
		{
			goToTitle();
			return;
		}
		FlxTween.cancelTweensOf(logo);
		FlxTween.tween(logo, {alpha: 0}, duration, {
			ease: FlxEase.quadIn,
			onComplete: function(_)
			{
				goToTitle();
			}
		});
	}

	function goToTitle():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		if (!ClientPrefs.data.setupWizardCompleted)
		{
			SetupWizardState.returnToWizard = false;
			FlxG.switchState(new SetupWizardState());
		}
		else
		{
			FlxG.switchState(new TitleState());
		}
	}
}