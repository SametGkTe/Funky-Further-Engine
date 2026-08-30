package backend;

import flixel.FlxG;
import flixel.FlxState;

class MenuStyleRouter
{

	public static function getMainMenu():FlxState
	{
		if (isNewStyle())
		{
			var state = new vslice.menus.states.MainMenuState();
			return cast state;
		}
		return new states.MainMenuState();
	}
	
	public static function getFreeplay():FlxState
	{
		if (isNewStyle())
		{
			return cast new vslice.menus.freeplay.FreeplayHostState();
		}
		return new states.FreeplayState();
	}

	public static function getStoryMode():FlxState
	{
		if (isNewStyle())
		{
			var state = new vslice.menus.states.StoryMenuState();
			return cast state;
		}
		return new states.StoryMenuState();
	}

	public static function getOptions():FlxState
	{
		return new options.OptionsState();
	}

	public static function getCredits():FlxState
	{
		if (isNewStyle())
		{
			var state = new vslice.menus.states.CreditsState();
			return cast state;
		}
		return new states.CreditsState();
	}

	public static function getMods():FlxState
	{
		if (isNewStyle())
		{
			var state = new vslice.menus.states.ModsMenuState();
			return cast state;
		}
		return new states.ModsMenuState();
	}

	public static var lastMenuSwitchSeconds:Float = 0;

	public static function goToMainMenu():Void
	{
		var useLoading:Bool = isNewStyle() && lastMenuSwitchSeconds >= 2;
		#if sys
		var t0:Float = Sys.time();
		#end
		if (useLoading)
			states.LoadingState.loadAndSwitchState(getMainMenu(), false, true);
		else
			MusicBeatState.switchState(getMainMenu());
		#if sys
		lastMenuSwitchSeconds = Sys.time() - t0;
		#end
	}

	public static function goToMainMenuFromResults():Void
	{
		// Results -> menu can hitch on V-Slice. Force loading if last switch was slow.
		if (isNewStyle() || lastMenuSwitchSeconds >= 2)
			states.LoadingState.loadAndSwitchState(getMainMenu(), true, true);
		else
			goToMainMenu();
	}

	inline public static function goToFreeplay():Void
		MusicBeatState.switchState(getFreeplay());

	inline public static function goToStoryMode():Void
		MusicBeatState.switchState(getStoryMode());

	inline public static function goToOptions():Void
		MusicBeatState.switchState(getOptions());

	inline public static function goToCredits():Void
		MusicBeatState.switchState(getCredits());

	inline public static function goToMods():Void
		MusicBeatState.switchState(getMods());

	inline public static function isNewStyle():Bool
		return ClientPrefs.data.menuStyle == 'Yeni';

	inline public static function isOriginalStyle():Bool
		return ClientPrefs.data.menuStyle != 'Yeni';
}

/*
* MenuStyleRouter.goToMainMenu();
* MenuStyleRouter.goToFreeplay();
* MenuStyleRouter.goToStoryMode();
* MenuStyleRouter.goToOptions();
* MenuStyleRouter.goToCredits();
* MenuStyleRouter.goToMods();
*/
