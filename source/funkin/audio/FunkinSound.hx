package funkin.audio;

/**
 * FNF uyumluluk shim'i (FunkinSound).
 * FNF'de ses siniflari `playerVolume` alani tasir (ses kanali sesi);
 * Psych'in FlxSound'unda bu alan yok. Sunday'in garage script'i
 * `PlayState.instance.vocals.playerVolume = 1` yazar — bu shim o yazmayi
 * volume'a cevirir (hscript host alan yazmasi getter/setter'i cozer).
 */
@:noCustomClass
class FunkinSound extends flixel.sound.FlxSound
{
	/** FNF: playerVolume. Bizde volume'a yonlendirilir. */
	public var playerVolume(get, set):Float;
	function get_playerVolume():Float return this.volume;
	function set_playerVolume(value:Float):Float
	{
		this.volume = value;
		return value;
	}
}
