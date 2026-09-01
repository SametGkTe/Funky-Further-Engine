package funkin.util;

import flixel.util.FlxColor;

/**
 * FNF uyumluluk shim'i (Constants) - MINIMAL.
 * FNF'deki buyuk sabit kumesinden en sik kullanilanlar vekil olarak var.
 * (Tam FNF Constants'i GitCommit/HaxelibVersions makrolarina ve SongData
 * tiplerine baglidir; burada bagimsiz tutuldu.)
 */
@:noCustomClass
class Constants
{
	public static final TITLE:String = 'Further Engine';
	public static var VERSION(get, never):String;
	static function get_VERSION():String return '1.7.0';

	// Renkler (FNF'deki gibi)
	public static final COLOR_HEALTH_BAR_RED:FlxColor = 0xFFFF0000;
	public static final COLOR_HEALTH_BAR_GREEN:FlxColor = 0xFF66FF33;
	public static var COLOR_NOTES:Array<FlxColor> = [
		0xFFFF22AA, // left  (0)
		0xFF00EEFF, // down  (1)
		0xFF00CC00, // up    (2)
		0xFFCC1111  // right (3)
	];

	// Varsayilanlar
	public static final DEFAULT_DIFFICULTY:String = 'normal';
	public static final DEFAULT_DIFFICULTY_LIST:Array<String> = ['easy', 'normal', 'hard'];
	public static final DEFAULT_CHARACTER:String = 'bf';
	public static final DEFAULT_HEALTH_ICON:String = 'face';
	public static final DEFAULT_STAGE:String = 'stage';
	public static final DEFAULT_SONG:String = 'tutorial';
	public static final DEFAULT_BPM:Float = 100.0;
	public static final DEFAULT_NOTE_STYLE:String = 'funkin';
	public static final DEFAULT_PIXEL_NOTE_STYLE:String = 'pixel';
	public static final DEFAULT_SONGNAME:String = 'Unknown';
	public static final DEFAULT_ARTIST:String = 'Unknown';
	public static final DEFAULT_CHARTER:String = 'Unknown';
	public static final DEFAULT_BOP_INTENSITY:Float = 1.015;
	public static final DEFAULT_ZOOM_RATE:Int = 4;
	public static final DEFAULT_PROP_RATE:Int = 1;
}
