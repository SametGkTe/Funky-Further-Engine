package funkin.play.cutscene;

import flixel.FlxSprite;

/**
 * FNF uyumluluk shim'i (VideoCutscene) - MINIMAL.
 * Further'da V-Slice video cutscene'leri ayri altyapiyla calisir; bu shim
 * yalnizca import cozumu icin var (script'ler genelde tip olarak kullanir).
 */
@:noCustomClass
class VideoCutscene extends FlxSprite
{
	public var videoPath:String = '';

	public function new(?x:Float = 0, ?y:Float = 0, ?videoPath:String = '')
	{
		super(x, y);
		this.videoPath = videoPath;
	}
}
