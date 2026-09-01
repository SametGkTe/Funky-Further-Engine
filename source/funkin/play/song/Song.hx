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
}
