package funkin.play.song;

/**
 * V-Slice/FNF uyumluluk shim'i (Song).
 *
 * FNF script'leri `class X extends funkin.play.song.Song { function new() { super('id'); } }`
 * türetir. Further'da şarkı verisi typedef (SwagSong / PlayState.SONG) yapısında
 * aktığı için bu shim yalnızca "script taşıyıcısı"dır; chart verisine erişim
 * `states.PlayState.SONG` üzerinden yapılır (örn. onSongLoaded içinde).
 *
 * Script'in ADI şarkı id'si ile eşleşmelidir (örn. "milf" -> class Milf);
 * eşleşme VSScriptRegistry tarafından yapılır.
 */
@:noCustomClass
class Song extends backend.Song
{
	public var songId:String = '';

	public function new(?id:String)
	{
		super();
		this.songId = (id != null) ? id : '';
	}

	/* ---- v18: resmî ScriptedSong alan köprüleri ---- */

	/** Resmî FNF: song.id — şarkının kimliği (örn. 'madness-sunday'). (v21) */
	public var id(get, never):String;

	function get_id():String
	{
		if (songId != null && songId != '') return songId;
		if (states.PlayState.SONG != null) return states.PlayState.SONG.song;
		return '';
	}

	/** Resmî FNF: song.name — görünen ad (Further: id ile aynı). (v21) */
	public var name(get, never):String;

	function get_name():String return get_id();

	/** Resmî FNF: song.songName (Further: çalan şarkının id'si). */
	public var songName(get, never):String;

	function get_songName():String
	{
		if (states.PlayState.SONG != null && states.PlayState.SONG.song != null)
			return states.PlayState.SONG.song;
		return songId;
	}

	/** Resmî FNF: song.length (ms; Further: çalan müziğin uzunluğu). */
	public var length(get, never):Float;

	function get_length():Float
	{
		if (flixel.FlxG.sound != null && flixel.FlxG.sound.music != null)
			return flixel.FlxG.sound.music.length;
		return 0;
	}

	/** Resmî FNF: getSongId() */
	public function getSongId():String return songId;
}
