package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * V-Slice tarzı class-tabanlı `.hxc` script'leri için scripted karakter sarmalayıcısı.
 *
 * Bir script `class X extends objects.Character { ... }` yazdığında Polymod bunu
 * otomatik olarak ScriptedCharacter üzerinden kurar; script'teki override'lar
 * (dance, playAnim, update, beatHit...) gerçek çağrıları yakalar.
 * Kurucu imzası objects.Character ile aynıdır: (x, y, character, isPlayer).
 *
 * Kullanım (motor tarafı): ScriptedCharacter.scriptInit('SinifAdi', x, y, char, isPlayer)
 */
@:hscriptClass
class ScriptedCharacter extends objects.Character implements HScriptedClass implements IHScriptedEvents
{
}
