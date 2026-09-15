package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.cutscene.dialogue.DialogueBox { ... }`
 * script'leri için scripted sarmalayıcı (kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedDialogueBox extends funkin.play.cutscene.dialogue.DialogueBox implements HScriptedClass implements IHScriptedEvents
{
}
