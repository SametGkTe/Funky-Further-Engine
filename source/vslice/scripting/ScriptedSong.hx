package vslice.scripting;

import polymod.hscript.HScriptedClass;

/**
 * Scripted şarkı: `class X extends funkin.play.song.Song` tarzı `.hxc`
 * script'leri için sarmalayıcı.
 *
 * SÖZLEŞME: script sınıfının ADI şarkı id'si ile eşleşmelidir.
 * Örn. "milf" şarkısı için `class Milf extends funkin.play.song.Song { ... }`.
 * VSScriptRegistry.resolveSong(id) eşleşmeyi yapar.
 */
@:hscriptClass
class ScriptedSong extends funkin.play.song.Song implements HScriptedClass implements IHScriptedEvents
{
}
