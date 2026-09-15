package funkin.play.notes;

import flixel.util.FlxColor;

/**
 * V-Slice/FNF uyumluluk shim'i (NoteDirection).
 * Resmî funkin v0.8.7 `funkin.play.notes.NoteDirection` ile birebir.
 *
 * enum abstract olduğu için Polymod'un abstractClassImpls makrosu
 * sayesinde script'lerden import edilip kullanılabilir.
 */
enum abstract NoteDirection(Int) from Int to Int
{
	public var LEFT = 0;
	public var DOWN = 1;
	public var UP = 2;
	public var RIGHT = 3;

	public var name(get, never):String;
	public var nameUpper(get, never):String;
	public var color(get, never):FlxColor;
	public var colorName(get, never):String;

	@:from
	public static function fromInt(value:Int):NoteDirection
	{
		return switch (value % 4)
		{
			case 0: LEFT;
			case 1: DOWN;
			case 2: UP;
			case 3: RIGHT;
			default: LEFT;
		};
	}

	@:impl
	inline function get_name():String
	{
		return switch (this)
		{
			case LEFT: 'left';
			case DOWN: 'down';
			case UP: 'up';
			case RIGHT: 'right';
			default: 'unknown';
		};
	}

	@:impl
	inline function get_nameUpper():String
	{
		return name.toUpperCase();
	}

	@:impl
	inline function get_color():FlxColor
	{
		return switch (this)
		{
			case LEFT: 0xFFC24B92;
			case DOWN: 0xFF00FFFF;
			case UP: 0xFF12FA05;
			case RIGHT: 0xFFF9393F;
			default: 0xFFFFFFFF;
		};
	}

	@:impl
	inline function get_colorName():String
	{
		return switch (this)
		{
			case LEFT: 'magenta';
			case DOWN: 'cyan';
			case UP: 'green';
			case RIGHT: 'red';
			default: 'white';
		};
	}
}
