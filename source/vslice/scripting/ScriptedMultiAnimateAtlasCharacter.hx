package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.character.MultiAnimateAtlasCharacter`
 * script'leri için scripted sarmalayıcı (id-tabanlı kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedMultiAnimateAtlasCharacter extends funkin.play.character.MultiAnimateAtlasCharacter implements HScriptedClass implements IHScriptedEvents
{
}
