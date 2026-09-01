package funkin.play.event;

import polymod.hscript.HScriptedClass;

/**
 * FNF uyumluluk shim'i (ScriptedSongEvent).
 * FNF modları özel şarkı olaylarını `class X extends ScriptedSongEvent { ... }`
 * diye yazar; bu sarmalayıcı onları Polymod köprüsüne kaydeder.
 * Olay, mod script'leri tarafından PlayState'e `dispatchEvent`/`callEvent`
 * ile iletilebilir.
 */
@:noCustomClass
@:hscriptClass
class ScriptedSongEvent extends SongEvent implements HScriptedClass
{
}
