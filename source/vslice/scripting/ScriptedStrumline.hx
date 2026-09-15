package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.notes.Strumline { ... }` script'leri
 * için scripted sarmalayıcı (kurucu: scriptInit(cls, x, y)).
 */
@:hscriptClass
class ScriptedStrumline extends funkin.play.notes.Strumline implements HScriptedClass implements IHScriptedEvents
{
}
