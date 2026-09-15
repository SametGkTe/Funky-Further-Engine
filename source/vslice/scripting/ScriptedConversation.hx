package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.cutscene.dialogue.Conversation { ... }`
 * script'leri için scripted sarmalayıcı (kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedConversation extends funkin.play.cutscene.dialogue.Conversation implements HScriptedClass implements IHScriptedEvents
{
}
