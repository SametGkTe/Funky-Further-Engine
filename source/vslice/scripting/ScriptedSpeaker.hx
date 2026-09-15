package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.cutscene.dialogue.Speaker { ... }`
 * script'leri için scripted sarmalayıcı (kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedSpeaker extends funkin.play.cutscene.dialogue.Speaker implements HScriptedClass implements IHScriptedEvents
{
}
