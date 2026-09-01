package funkin.play.notes.notestyle;

/**
 * FNF uyumluluk shim'i (NoteStyle) - MINIMAL.
 * FNF'de nota gorunumunu tanimlar; Further'da karsiligi yok.
 * Yalnizca import/tip cozumu icin var.
 */
@:noCustomClass
class NoteStyle
{
	public var id:String = 'funkin';
	public var name:String = 'funkin';

	public function new(?id:String = 'funkin')
	{
		this.id = id;
		this.name = id;
	}
}
