package funkin.play;

/**
 * V-Slice/FNF uyumluluk shim'i (Countdown).
 *
 * Resmî FNF'de Countdown, PlayState'ten ayrı bir sınıftır; Further'da
 * countdown mantığı PlayState.startCountdown() içindedir. Bu dosya
 * yalnızca script'lerin ihtiyaç duyduğu `CountdownStep` enum'unu ve
 * isim çözümlemesi için hafif bir taşıyıcı sınıfı sağlar.
 */
@:noCustomClass
class Countdown
{
	/** Further'da countdown dispatch'i PlayState içinden yürür. */
	public static function performCountdown(?playState:Dynamic):Bool
	{
		return false;
	}
}

/**
 * The countdown step.
 * This can't be an enum abstract because scripts may need it.
 * (Resmî funkin v0.8.7 ile birebir.)
 */
enum CountdownStep
{
	BEFORE;
	THREE;
	TWO;
	ONE;
	GO;
	AFTER;
}
