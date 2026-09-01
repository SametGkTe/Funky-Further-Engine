package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.character.SparrowCharacter` script'leri
 * için scripted sarmalayıcı (id-tabanlı kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedSparrowCharacter extends funkin.play.character.SparrowCharacter implements HScriptedClass implements IHScriptedEvents
{
}
