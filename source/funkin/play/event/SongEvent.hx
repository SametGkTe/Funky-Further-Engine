package funkin.play.event;

import funkin.data.event.SongEventSchema;
import funkin.data.song.SongData.SongEventData;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HoldNoteScriptEvent;
import funkin.modding.events.ScriptEvent.GhostMissNoteScriptEvent;
import funkin.modding.events.ScriptEvent.NoteScriptEvent;
import funkin.modding.events.ScriptEvent.SongEventScriptEvent;
import funkin.modding.events.ScriptEvent.SongLoadScriptEvent;
import funkin.modding.events.ScriptEvent.SongRetryEvent;
import funkin.modding.events.ScriptEvent.SongTimeScriptEvent;
import funkin.modding.events.ScriptEvent.CountdownScriptEvent;
import funkin.modding.events.ScriptEvent.PauseScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;

/**
 * Parameters used to initialize a song event.
 */
typedef SongEventParams =
{
	/**
	 * If `true`, the song event will be handled even if it is old
	 * (starting mid-song or skipping forward past it).
	 * @default false
	 */
	?processOldEvents:Bool
}

/**
 * V-Slice/FNF uyumluluk shim'i (SongEvent) — v15.
 *
 * Resmî funkin v0.8.7 `funkin.play.event.SongEvent` API'si birebir:
 *   - new(id, ?params)
 *   - handleEvent(data:SongEventData)  <- modlar bunu override eder
 *   - getEventSchema() / getIconPath() / getTitle()
 *   - IPlayStateScriptedClass yaşam döngüsü metodları (no-op)
 *
 * Eski shim `new()` argümansızdı ve CancellableEvent'ten türüyordu;
 * Sunday gibi modlar `super('WarnCreate')` çağırdığı için imza
 * resmî FNF'ye eşitlendi.
 *
 * Script'ler bu sınıfa DOĞRUDAN `class X extends SongEvent` yazabilir
 * (Polymod v14 tam-yol extend düzeltmesi sayesinde `extends
 * funkin.play.event.SongEvent` de çalışır) veya ScriptedSongEvent
 * sarmalayıcısını kullanabilir.
 */
@:noCustomClass
class SongEvent
{
	/**
	 * These variables are used in two different events (and may be in more).
	 */
	public static final DEFAULT_EASE:String = 'linear';

	/**
	 * The default ease direction for events which use FlxEase.
	 */
	public static final DEFAULT_EASE_DIR:String = 'In';

	/**
	 * A regular expression to detect the current ease direction.
	 */
	public static final EASE_TYPE_DIR_REGEX:EReg = ~/(In|Out|InOut)$/i;

	/**
	 * The internal song event ID that this handler is responsible for.
	 */
	public var id:String;

	/**
	 * If `true`, events will always be handled, in order.
	 */
	public var processOldEvents:Bool = false;

	public function new(id:String = 'UNKNOWN', ?params:SongEventParams)
	{
		this.id = id;
		if (params != null && Reflect.field(params, 'processOldEvents') != null)
			this.processOldEvents = Reflect.field(params, 'processOldEvents');
	}

	/**
	 * Handles a song event that matches this handler's ID.
	 */
	public function handleEvent(data:SongEventData):Void
	{
		// Resmî FNF burada throw atar; Further'da mod çökmesin diye trace.
		trace('[SongEvent] handleEvent() override edilmemiş: ' + id);
	}

	/**
	 * Retrieves the chart editor schema for this song event type.
	 */
	public function getEventSchema():SongEventSchema
	{
		return null;
	}

	/**
	 * Retrieves the asset path to the icon this event type should use.
	 */
	public function getIconPath():String
	{
		return 'ui/chart-editor/events/default';
	}

	/**
	 * Retrieves the human readable title of this song event type.
	 */
	public function getTitle():String
	{
		if (id == null || id.length == 0) return '';
		return id.charAt(0).toUpperCase() + id.substr(1);
	}

	public function toString():String
	{
		return 'SongEvent(${this.id})';
	}

	/**
	 * Resmî FNF ease çözümlemesi: 'quad' + 'In' -> FlxEase.quadIn.
	 * 'CLASSIC' -> quadInOut, 'linear' -> FlxEase.linear, 'INSTANT' çağıran
	 * tarafında ele alınır. Bulunamazsa FlxEase.linear döner.
	 */
	public static function getEaseFunction(ease:String, ?easeDir:String):Float->Float
	{
		if (ease == null) ease = DEFAULT_EASE;
		if (easeDir == null) easeDir = DEFAULT_EASE_DIR;

		var lower:String = ease.toLowerCase();
		if (lower == 'classic') return flixel.tweens.FlxEase.quadInOut;
		if (lower == 'linear') return flixel.tweens.FlxEase.linear;
		if (lower == 'instant') return flixel.tweens.FlxEase.linear;

		// ease adı zaten yön içeriyorsa ('quadIn') easeDir eklenmez.
		var dir:String = (EASE_TYPE_DIR_REGEX.match(ease)) ? '' : easeDir;
		var fn:Dynamic = Reflect.field(flixel.tweens.FlxEase, lower + dir.charAt(0).toUpperCase() + dir.substr(1));
		if (fn == null) fn = Reflect.field(flixel.tweens.FlxEase, lower + dir);
		if (fn == null) return flixel.tweens.FlxEase.linear;
		return fn;
	}

	/* ---- IPlayStateScriptedClass yaşam döngüsü (resmî FNF ile aynı isimler) ---- */

	public function onScriptEvent(event:ScriptEvent) {}
	public function onCreate(event:ScriptEvent) {}
	public function onDestroy(event:ScriptEvent) {}
	public function onUpdate(event:UpdateScriptEvent) {}
	public function onStepHit(event:SongTimeScriptEvent) {}
	public function onBeatHit(event:SongTimeScriptEvent) {}
	public function onPause(event:PauseScriptEvent) {}
	public function onResume(event:ScriptEvent) {}
	public function onSongStart(event:ScriptEvent) {}
	public function onSongEnd(event:ScriptEvent) {}
	public function onGameOver(event:ScriptEvent) {}
	public function onNoteIncoming(event:NoteScriptEvent) {}
	public function onNoteHit(event:HitNoteScriptEvent) {}
	public function onNoteMiss(event:NoteScriptEvent) {}
	public function onNoteHoldDrop(event:HoldNoteScriptEvent) {}
	public function onSongEvent(event:SongEventScriptEvent) {}
	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent) {}
	public function onCountdownStart(event:CountdownScriptEvent) {}
	public function onCountdownStep(event:CountdownScriptEvent) {}
	public function onCountdownEnd(event:CountdownScriptEvent) {}
	public function onSongLoaded(event:SongLoadScriptEvent) {}
	public function onSongRetry(event:SongRetryEvent) {}

	/* ---- FFE dispatcher ek isimleri (Psych callback adları) ---- */

	public function onCreatePost(event:ScriptEvent) {}
	public function onUpdatePost(event:UpdateScriptEvent) {}
}
