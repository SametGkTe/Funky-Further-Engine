package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted sahne: `class X extends backend.BaseStage { ... }` tarzı `.hxc`
 * script'leri için sarmalayıcı.
 *
 * SÖZLEŞME: script sınıfının ADI, sahne adıyla eşleşmelidir.
 * Örn. `stage: "mall"` için `class Mall extends backend.BaseStage { ... }`.
 * VSScriptRegistry.resolveStage(name) bu eşleşmeyi yapar.
 */
@:hscriptClass
class ScriptedStage extends backend.BaseStage implements HScriptedClass implements IHScriptedEvents
{
}
