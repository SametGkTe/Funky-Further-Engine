package mobile;

import haxe.ds.Map;
import flixel.group.FlxSpriteGroup;

enum ButtonsStates
{
	PRESSED;
	JUST_PRESSED;
	RELEASED;
	JUST_RELEASED;
}

/**
 * A handler for MobileButton.
 * If you don't know what are you doing, do not touch here.
 *
 * @author KralOyuncu 2010x (ArkoseLabs) / adapted for Further Engine
 */
class MobileInputHandler extends FlxTypedSpriteGroup<MobileButton>
{
	public var trackedButtons:Map<String, MobileButton> = new Map<String, MobileButton>();

	public function new()
	{
		super();
		updateTrackedButtons();
	}

	public function buttonPressed(button:Dynamic):Bool
		return checkButtonsState(button, PRESSED);

	public function buttonJustPressed(button:Dynamic):Bool
		return checkButtonsState(button, JUST_PRESSED);

	public function buttonJustReleased(button:Dynamic):Bool
		return checkButtonsState(button, JUST_RELEASED);

	public function buttonReleased(button:Dynamic):Bool
		return checkButtonsState(button, RELEASED);

	function checkButtonsState(Buttons:Dynamic, state:ButtonsStates = JUST_PRESSED):Bool
	{
		if (Buttons == null)
			return false;

		if (!Std.isOfType(Buttons, Array))
			Buttons = [Buttons];

		for (button in (cast Buttons : Array<String>))
		{
			if (trackedButtons.exists(button))
			{
				var btn:MobileButton = trackedButtons.get(button);
				if (state == JUST_RELEASED && btn.justReleased ||
				   state == RELEASED && btn.released ||
				   state == PRESSED && btn.pressed ||
				   state == JUST_PRESSED && btn.justPressed)
				{
					return true;
				}
			}
		}

		return false;
	}


	public function updateTrackedButtons()
	{
		trackedButtons.clear();
		forEachExists(function(button:MobileButton)
		{
			if (button.IDs != null)
			{
				for (id in button.IDs)
				{
					if (!trackedButtons.exists(id))
						trackedButtons.set(id, button);
				}
			}
		});
	}
}
