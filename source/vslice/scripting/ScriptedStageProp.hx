package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * FNF tarzı `class X extends funkin.play.stage.StageProp { ... }` script'leri
 * için scripted sarmalayıcı (kurucu argümansız: scriptInit(cls)).
 */
@:hscriptClass
class ScriptedStageProp extends funkin.play.stage.StageProp implements HScriptedClass implements IHScriptedEvents
{
}
