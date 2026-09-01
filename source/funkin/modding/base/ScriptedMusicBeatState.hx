package funkin.modding.base;

import polymod.hscript.HScriptedClass;

/**
 * FNF uyumluluk shim'i (ScriptedMusicBeatState).
 * FNF mod script'leri `class X extends funkin.modding.base.ScriptedMusicBeatState`
 * türetir (örn. uyarı ekranı state'leri). Motor tarafı için
 * `vslice.scripting.ScriptedMusicBeatState` ayrıca mevcuttur.
 */
@:noCustomClass
@:hscriptClass
class ScriptedMusicBeatState extends funkin.ui.MusicBeatState implements HScriptedClass
{
}
