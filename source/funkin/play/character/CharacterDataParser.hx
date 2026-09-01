package funkin.play.character;

/**
 * FNF uyumluluk shim'i (CharacterDataParser) - MINIMAL.
 * Further karakter JSON'larini kendi converter'lariyla okur. Bu shim
 * yalnizca import cozumu icin var.
 */
@:noCustomClass
class CharacterDataParser
{
	public static function parseCharacterData(?json:Dynamic):Dynamic
	{
		return json;
	}
}
