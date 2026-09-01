package funkin.play;

/**
 * FNF uyumluluk shim'i (PlayStatePlaylist) - MINIMAL.
 * FNF'de PlayState'in caldigi sarkilar listesini tutar. Further'da
 * PlayState kendi listesini yonetir; import cozumu icin bos kabuk.
 */
@:noCustomClass
class PlayStatePlaylist
{
	public var songs:Array<Dynamic> = [];

	public function new() {}
}
