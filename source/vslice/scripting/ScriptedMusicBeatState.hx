package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted State: `class X extends funkin.ui.MusicBeatState { ... }` tarzı
 * `.hxc` script'leri için sarmalayıcı.
 * Kurulum: ScriptedMusicBeatState.scriptInit('SinifAdi')
 * (FNF'deki ScriptedMusicBeatState ile aynı ad ve amaç.)
 */
@:hscriptClass
class ScriptedMusicBeatState extends funkin.ui.MusicBeatState implements HScriptedClass implements IHScriptedEvents
{
}
