package backend.further;

import flixel.util.FlxColor;

/**
 * Global tema renkleri — Texture Pack yığınının en üstündeki theme.json
 * tarafından belirlenir (kural: tema her zaman yığının en üstü kazanır).
 * Menüler renkleri buradan okur; paket yoksa motor varsayılanları kalır.
 */
class Theme
{
	public static inline var DEFAULT_ACCENT:FlxColor = 0xFFFF2E63;
	public static inline var DEFAULT_BG:FlxColor = 0xFF0A0A0C;
	public static inline var DEFAULT_PANEL:FlxColor = 0xFF0E0E12;
	public static inline var DEFAULT_CARD:FlxColor = 0xFF141419;
	public static inline var DEFAULT_LINE:FlxColor = 0xFF232330;
	public static inline var DEFAULT_TEXT:FlxColor = 0xFFF2F2F5;
	public static inline var DEFAULT_DIM:FlxColor = 0xFF9A9AAB;

	public static var accent(default, null):FlxColor = DEFAULT_ACCENT;
	public static var background(default, null):FlxColor = DEFAULT_BG;
	public static var panel(default, null):FlxColor = DEFAULT_PANEL;
	public static var card(default, null):FlxColor = DEFAULT_CARD;
	public static var line(default, null):FlxColor = DEFAULT_LINE;
	public static var text(default, null):FlxColor = DEFAULT_TEXT;
	public static var dim(default, null):FlxColor = DEFAULT_DIM;

	/** null kanallar varsayılana döner. */
	public static function set(?accentCol:FlxColor, ?bgCol:FlxColor, ?textCol:FlxColor):Void
	{
		accent = (accentCol != null) ? accentCol : DEFAULT_ACCENT;
		background = (bgCol != null) ? bgCol : DEFAULT_BG;
		text = (textCol != null) ? textCol : DEFAULT_TEXT;
	}

	public static function reset():Void
	{
		set(null, null, null);
	}
}
