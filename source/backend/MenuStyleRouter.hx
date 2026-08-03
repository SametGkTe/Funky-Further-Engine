package backend;

import flixel.FlxG;
import flixel.FlxState;

class MenuStyleRouter
{

	public static function getMainMenu():FlxState
	{
		if (isNewStyle())
		{
			var state = new mikolka.vslice.states.MainMenuState();
			return cast state;
		}
		return new states.MainMenuState();
	}
	
	public static function getFreeplay():FlxState
	{
		if (isNewStyle())
		{
			return cast new mikolka.vslice.freeplay.FreeplayHostState();
		}
		return new states.FreeplayState();
	}

	public static function getStoryMode():FlxState
	{
		if (isNewStyle())
		{
			var state = new mikolka.vslice.states.StoryMenuState();
			return cast state;
		}
		return new states.StoryMenuState();
	}

	public static function getOptions():FlxState
	{
		if (isNewStyle())
		{
			var state = new mikolka.vslice.states.OptionsState();
			return cast state;
		}
		return new options.OptionsState();
	}

	public static function getCredits():FlxState
	{
		if (isNewStyle())
		{
			var state = new mikolka.vslice.states.CreditsState();
			return cast state;
		}
		return new states.CreditsState();
	}

	public static function getMods():FlxState
	{
		if (isNewStyle())
		{
			var state = new mikolka.vslice.states.ModsMenuState();
			return cast state;
		}
		return new states.ModsMenuState();
	}

	// ===== KISAYOL FONKSİYONLARI =====

	inline public static function goToMainMenu():Void
		MusicBeatState.switchState(getMainMenu());

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

	// ===== DURUM KONTROLLERİ =====

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