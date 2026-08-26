package states;

import flixel.FlxState;

class FurtherIntroState extends FlxState
{
	static inline var FADE_IN:Float = 0.4;
	static inline var HOLD:Float = 2.0;
	static inline var FADE_OUT:Float = 0.4;
	static inline var SKIP_FADE:Float = 0.2;

	var logo:FlxSprite;
	var closing:Bool = false;
	var holdTimer:FlxTimer;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var graphic = null;
		if (FlxG.random.bool(15))
			graphic = Paths.image('further/titlesecret');
		if (graphic == null)
			graphic = Paths.image('further/title');
		if (graphic == null)
		{
			goToTitle();
			return;
		}

		logo = new FlxSprite().loadGraphic(graphic);
		logo.setGraphicSize(FlxG.width, FlxG.height);
		logo.updateHitbox();
		logo.screenCenter();
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.alpha = 0;
		add(logo);

		FlxTween.tween(logo, {alpha: 1}, FADE_IN, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				if (closing)
					return;
				holdTimer = new FlxTimer().start(HOLD, function(__)
				{
					startFadeOut(FADE_OUT);
				});
			}
		});
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
		if (holdTimer != null)
		{
			holdTimer.cancel();
			holdTimer = null;
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
		FlxG.switchState(new TitleState());
	}
}
