package vslice.menus.charSelect;

import vslice.funkin.FlxAtlasSprite;

class CharSelectPlayer extends FlxAtlasSprite
{
	public var loadedChar(default, null):String = null;

	public function new(x:Float, y:Float)
	{
		super(x, y, null);

		onAnimationComplete.add(function(animLabel:String)
		{
			switch (animLabel)
			{
				case "slidein":
					if (hasAnimSafe("slidein idle point"))
						playAnimation("slidein idle point", true, false, false);
					else if (hasAnimSafe("idle"))
						playAnimation("idle", true, false, false);

				case "deselect":
					if (hasAnimSafe("deselect loop start"))
						playAnimation("deselect loop start", true, false, true);
					else if (hasAnimSafe("idle"))
						playAnimation("idle", true, false, false);

				case "slidein idle point", "cannot select Label", "unlock":
					if (hasAnimSafe("idle"))
						playAnimation("idle", true, false, false);

				case "idle":
					trace('Waiting for onBeatHit');
			}
		});
	}

	public inline function hasValidAtlasSafe():Bool
	{
		// BUG: Bu fonksiyon kendini çağırıyordu → sonsuz rekürsiyon → stack overflow
		// → sessiz çöküş (oyundan atma). FlxAtlasSprite'ın gerçek atlas kontrolünü çağır.
		return hasValidAtlas();
	}

	public inline function hasAnimSafe(id:String):Bool
	{
		return hasValidAtlasSafe() && hasAnimation(id);
	}

	public function playAnimSafe(id:String, restart:Bool = false, ignoreOther:Bool = false, loop:Bool = false, startFrame:Int = 0):Bool
	{
		if (!hasAnimSafe(id))
		{
			trace('[CharSelectPlayer] Missing animation "' + id + '" for ' + (loadedChar ?? "unknown"));
			return false;
		}

		playAnimation(id, restart, ignoreOther, loop, startFrame);
		return true;
	}

	public function onBeatHit():Void
	{
		if (hasAnimSafe("idle") && getCurrentAnimation() == "idle")
		{
			playAnimation("idle", true, false, false);
		}
	}

	public function updatePosition(str:String)
	{
		switch (str)
		{
			case "bf":
				x = 0;
				y = 0;
			case "pico":
				x = 0;
				y = 0;
			default:
		}
	}

	public function switchChar(str:String):Bool
	{
		loadedChar = null;
		visible = false;

		try
		{
			loadAtlas("charSelect/" + str + "Chill");

			if (!hasValidAtlasSafe())
			{
				trace('[CharSelectPlayer] Invalid/missing atlas for ' + str);
				return false;
			}

			loadedChar = str;
			visible = true;

			if (hasAnimSafe("slidein"))
				playAnimation("slidein", true, false, false);
			else if (hasAnimSafe("idle"))
				playAnimation("idle", true, false, false);

			updateHitbox();
			updatePosition(str);
			return true;
		}
		catch (e)
		{
			trace('[CharSelectPlayer] Failed to switch char ' + str + ': ' + e);
			visible = false;
			return false;
		}
	}
}
