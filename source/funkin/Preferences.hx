package funkin;

import flixel.FlxG;

/**
 * FNF uyumluluk shim'i (Preferences) - MINIMAL.
 * FNF mod script'leri `Preferences.getPreference(...)` / `Preferences.downscroll`
 * gibi erisimler yapar. Bu shim Psych'in kayit sistemine (FlxG.save.data)
 * kopru kurar; FNF'deki yuzlerce hazir alandan yalnizca en yayginlari
 * vekil olarak tanimlidir. Diger alanlar icin get/setPreference kullanilir.
 */
@:noCustomClass
class Preferences
{
	// (NOT: inline degil final - polymod interp'i static alanlari yansimayla okur)
	public static final PREF_DOWNSCROLL:String = 'downscroll';
	public static final PREF_GHOST_TAPPING:String = 'ghostTapping';
	public static final PREF_MIDDLESCROLL:String = 'middlescroll';
	public static final PREF_BOTPLAY:String = 'botplay';

	/** FNF tarzi: Preferences.getPreference('downscroll') */
	public static function getPreference(name:String, ?defaultValue:Dynamic):Dynamic
	{
		if (FlxG.save.data == null) return defaultValue;
		var v:Dynamic = Reflect.field(FlxG.save.data, name);
		return v == null ? defaultValue : v;
	}

	/** FNF tarzi: Preferences.setPreference('downscroll', true) */
	public static function setPreference(name:String, value:Dynamic):Void
	{
		if (FlxG.save.data == null) return;
		Reflect.setField(FlxG.save.data, name, value);
	}

	/** En yaygin alanlarin vekilleri (get/set kayit sistemine bagli). */
	public static var downscroll(get, set):Bool;
	static function get_downscroll():Bool return getPreference(PREF_DOWNSCROLL, false) == true;
	static function set_downscroll(v:Bool):Bool { setPreference(PREF_DOWNSCROLL, v); return v; }

	public static var ghostTapping(get, set):Bool;
	static function get_ghostTapping():Bool return getPreference(PREF_GHOST_TAPPING, true) == true;
	static function set_ghostTapping(v:Bool):Bool { setPreference(PREF_GHOST_TAPPING, v); return v; }

	public static var middlescroll(get, set):Bool;
	static function get_middlescroll():Bool return getPreference(PREF_MIDDLESCROLL, false) == true;
	static function set_middlescroll(v:Bool):Bool { setPreference(PREF_MIDDLESCROLL, v); return v; }

	public static var botplay(get, set):Bool;
	static function get_botplay():Bool return getPreference(PREF_BOTPLAY, false) == true;
	static function set_botplay(v:Bool):Bool { setPreference(PREF_BOTPLAY, v); return v; }
}
