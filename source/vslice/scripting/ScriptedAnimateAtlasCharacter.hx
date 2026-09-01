package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.character.AnimateAtlasCharacter`
 * script'leri için scripted sarmalayıcı (id-tabanlı kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedAnimateAtlasCharacter extends funkin.play.character.AnimateAtlasCharacter implements HScriptedClass implements IHScriptedEvents
{
}
