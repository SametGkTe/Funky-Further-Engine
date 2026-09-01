package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted Module: `class X extends funkin.modding.module.Module { ... }`
 * tarzı `.hxc` script'leri için sarmalayıcı. Module'ler state'ler arası
 * yaşar; startup'ta VSScriptRegistry tarafından kurulur ve tüm
 * PlayState olaylarını alır (active = false ise atlanır).
 */
@:hscriptClass
class ScriptedModule extends funkin.modding.module.Module implements HScriptedClass implements IHScriptedEvents
{
}
