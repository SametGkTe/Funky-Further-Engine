package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted FlxSprite: `class X extends flixel.FlxSprite { ... }` tarzı
 * `.hxc` script'leri için genel amaçlı sarmalayıcı.
 */
@:hscriptClass
class ScriptedFlxSprite extends flixel.FlxSprite implements HScriptedClass implements IHScriptedEvents
{
}
