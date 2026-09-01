package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted SubState: `class X extends funkin.ui.MusicBeatSubState { ... }`
 * tarzı `.hxc` script'leri için sarmalayıcı.
 * Kurulum: ScriptedMusicBeatSubState.scriptInit('SinifAdi').
 */
@:hscriptClass
class ScriptedMusicBeatSubState extends funkin.ui.MusicBeatSubState implements HScriptedClass implements IHScriptedEvents
{
}
