package funkin.ui;

/**
 * V-Slice/FNF uyumluluk shim'i (MusicBeatState).
 * FNF script'leri `class X extends funkin.ui.MusicBeatState { ... }` türetir;
 * Polymod köprüsü bunu otomatik olarak vslice.scripting.ScriptedMusicBeatState
 * üzerinden kurar. Kurulum: ScriptedMusicBeatState.scriptInit('SinifAdi').
 */
@:noCustomClass
class MusicBeatState extends backend.MusicBeatState
{
	public function new()
	{
		super();
	}
}
