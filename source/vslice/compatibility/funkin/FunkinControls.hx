package vslice.compatibility.funkin;

class FunkinControls {
    public static function get_BAR_LEFT():Bool {
        return Controls.instance.UI_LEFT_P;
    }

    public static function get_BAR_RIGHT():Bool {
        return Controls.instance.UI_RIGHT_P;
    }
	
    public static function get_CHAR_SELECT():Bool {
        return false;
    }

    public static function get_FAVORITE():Bool {
        return false;
    }
	
	public static var SCREENSHOT(get, never):Bool;

	private static function get_SCREENSHOT():Bool
	{
		return FlxG.keys.justPressed.F12;
	}

	public static var FREEPLAY_LEFT(get, never):Bool;

	private static function get_FREEPLAY_LEFT():Bool
	{
		return FlxG.keys.justPressed.Q;
	}

	public static var FREEPLAY_RIGHT(get, never):Bool;

	private static function get_FREEPLAY_RIGHT():Bool
	{
		return FlxG.keys.justPressed.E;
	}

	public static var FREEPLAY_CHAR(get, never):Bool;

	private static function get_FREEPLAY_CHAR():Bool
	{
		return FlxG.keys.justPressed.TAB;
	}

	public static function FREEPLAY_CHAR_name():String
	{
		return "TAB";
	}
}
