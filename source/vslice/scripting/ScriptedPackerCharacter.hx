package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.character.PackerCharacter` script'leri
 * için scripted sarmalayıcı (id-tabanlı kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedPackerCharacter extends funkin.play.character.PackerCharacter implements HScriptedClass implements IHScriptedEvents
{
}
