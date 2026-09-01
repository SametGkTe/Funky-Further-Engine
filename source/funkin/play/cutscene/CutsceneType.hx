package funkin.play.cutscene;

/**
 * FNF uyumluluk shim'i (CutsceneType) - MINIMAL.
 * Script'ler `cutscene.type == CutsceneType.DIALOGUE` gibi karsilastirmalar
 * yapar. Polymod enum abstract'lari otomatik destekler.
 */
enum abstract CutsceneType(String) from String to String
{
	var DIALOGUE = 'dialogue';
	var VIDEO = 'video';
	var SCRIPTED = 'scripted';

	public function toString():String
	{
		return this;
	}
}
