package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.character.BaseCharacter` script'leri
 * için scripted sarmalayıcı (id-tabanlı kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedBaseCharacter extends funkin.play.character.BaseCharacter implements HScriptedClass implements IHScriptedEvents
{
}
