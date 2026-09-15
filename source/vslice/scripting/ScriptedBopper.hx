package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.stage.Bopper { ... }` script'leri
 * için scripted sarmalayıcı (kurucu: scriptInit(cls, danceEvery)).
 */
@:hscriptClass
class ScriptedBopper extends funkin.play.stage.Bopper implements HScriptedClass implements IHScriptedEvents
{
}
