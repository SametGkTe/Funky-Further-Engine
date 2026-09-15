package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.notes.notekind.NoteKind { ... }`
 * script'leri için scripted sarmalayıcı (kurucu: scriptInit(cls, noteKind, ...)).
 * NoteKindManager.registerScriptedNoteKinds() bu sarmalayıcının
 * listScriptClasses()/scriptInit() statiklerini kullanır.
 */
@:hscriptClass
class ScriptedNoteKind extends funkin.play.notes.notekind.NoteKind implements HScriptedClass implements IHScriptedEvents
{
}
