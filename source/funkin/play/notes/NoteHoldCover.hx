package funkin.play.notes;

import flixel.FlxSprite;

/**
 * FNF uyumluluk shim'i (NoteHoldCover) - MINIMAL.
 * FNF'de sustain notalarinin uc kaplamasidir; Further'da karsiligi yok.
 * Yalnizca import/tip cozumu icin var.
 */
@:noCustomClass
class NoteHoldCover extends FlxSprite
{
	public var parentNote:FlxSprite = null;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
	}
}
