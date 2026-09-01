package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.character.MultiSparrowCharacter`
 * script'leri için scripted sarmalayıcı (id-tabanlı kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedMultiSparrowCharacter extends funkin.play.character.MultiSparrowCharacter implements HScriptedClass implements IHScriptedEvents
{
}
