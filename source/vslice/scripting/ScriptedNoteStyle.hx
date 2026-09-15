package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.notes.notestyle.NoteStyle { ... }`
 * script'leri için scripted sarmalayıcı (kurucu: scriptInit(cls, id)).
 */
@:hscriptClass
class ScriptedNoteStyle extends funkin.play.notes.notestyle.NoteStyle implements HScriptedClass implements IHScriptedEvents
{
}
