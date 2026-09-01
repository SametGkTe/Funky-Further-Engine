package funkin.play.notes;

import flixel.FlxSprite;

/**
 * FNF uyumluluk shim'i (Strumline) - MINIMAL.
 * Further'in mania sistemi kendi strumline duzenini kullanir
 * (bak: docs/MANIA_SUPPORT.md); bu shim yalnizca import/tip cozumu icin var.
 * Not: FNF'deki gibi `strumline.characters`/`members` yapisi YOKTUR.
 */
@:noCustomClass
class Strumline extends FlxSprite
{
	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
	}
}
