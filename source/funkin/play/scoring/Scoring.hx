package funkin.play.scoring;

/**
 * FNF uyumluluk shim'i (Scoring) - MINIMAL.
 * Further skoru kendi sistemiyle hesaplar; bu shim yalnizca import cozumu
 * ve cok temel statik cagrilar icin var.
 */
@:noCustomClass
class Scoring
{
	public static function calculateScore(?noteData:Dynamic):Dynamic
	{
		return {score: 0, rating: 'sick'};
	}

	public static function calculateRating(?noteData:Dynamic):String
	{
		return 'sick';
	}
}
