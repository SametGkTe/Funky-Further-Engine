package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted sprite: `class X extends funkin.graphics.FunkinSprite { ... }`
 * tarzı `.hxc` script'leri için sarmalayıcı.
 * Kurulum: ScriptedFunkinSprite.scriptInit(cls, x, y)
 */
@:hscriptClass
class ScriptedFunkinSprite extends funkin.graphics.FunkinSprite implements HScriptedClass implements IHScriptedEvents
{
}
