package funkin.play.event;

import polymod.hscript.HScriptedClass;
import vslice.scripting.IHScriptedEvents;

/**
 * A script that can be tied to a SongEvent.
 * Create a scripted class that extends SongEvent, then call `super('SongEventType')` to use this.
 *
 * - Override `handleEvent(data:SongEventData)` to perform your actions when the event is hit.
 * - Override `getTitle()` to return an event name that will be displayed in the editor.
 * - Override `getEventSchema()` to return a schema for the event data.
 *
 * Resmî funkin v0.8.7 ile aynı tanım + FFE farkı:
 * `implements IHScriptedEvents` — VSScriptEventDispatcher'ın bu sınıfa
 * yaşam döngüsü olaylarını (onBeatHit, onSongEvent, ...) scriptHas/scriptCall
 * üzerinden gönderebilmesi için.
 */
@:noCustomClass
@:hscriptClass
class ScriptedSongEvent extends SongEvent implements HScriptedClass implements IHScriptedEvents
{
}
