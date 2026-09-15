package funkin.data.event;

import funkin.data.song.SongData.SongEventData;
import funkin.modding.events.ScriptEvent;
import funkin.play.event.SongEvent;

/**
 * V-Slice/FNF uyumluluk shim'i (SongEventRegistry) — v15.
 *
 * Resmî funkin v0.8.7 `funkin.data.event.SongEventRegistry` karşılığı.
 * Farklar:
 *   - ClassMacro.listSubclassesOf yerine YERLEŞİK event listesi elle yazılır
 *     (BUILTIN_EVENTS) — FFE'de ClassMacro yok.
 *   - Scripted event'ler Polymod köprüsünden (ScriptedSongEvent.listScriptClasses)
 *     gelir; VSScriptRegistry.initialize() -> loadEventCache() ile kurulur.
 *   - queryEvents/handleSkippedEvents zamanlaması Psych tarafında
 *     (eventNotes) yürüdüğü için burada sadeleştirilmiştir.
 */
@:noCustomClass
class SongEventRegistry
{
	/**
	 * FFE'de yerleşik olarak desteklenen V-Slice chart event'leri.
	 * Psych'in kendi event'leri ('Add Camera Zoom' vb.) triggerEvent
	 * switch'inde kaldığı için buraya YALNIZCA V-Slice isimleri girer.
	 */
	static final BUILTIN_EVENTS:Array<Class<SongEvent>> = [
		funkin.play.event.FocusCameraSongEvent,
		funkin.play.event.ZoomCameraSongEvent,
		funkin.play.event.PlayAnimationSongEvent,
		funkin.play.event.ScrollSpeedEvent,
		funkin.play.event.SetHealthIconSongEvent,
		funkin.play.event.SetCameraBopSongEvent,
		funkin.play.event.SetTargetBopSpeedSongEvent
	];

	/**
	 * Map of internal handlers for song events (eventKind -> handler).
	 */
	public static final eventCache:Map<String, SongEvent> = new Map<String, SongEvent>();

	/** Bu şarkıda yaşam döngüsü olayı alan handler'lar (resmî allEventHandlers). */
	static var allEventHandlers:Array<SongEvent> = [];

	public static function loadEventCache():Void
	{
		clearEventCache();
		registerBaseEvents();
		registerScriptedEvents();
	}

	static function registerBaseEvents():Void
	{
		for (eventCls in BUILTIN_EVENTS)
		{
			try
			{
				var event:SongEvent = Type.createInstance(eventCls, []);
				if (event != null)
				{
					trace('[SongEventRegistry] Yerlesik event yuklendi: ${event.id}');
					eventCache.set(event.id, event);
				}
			}
			catch (e:Dynamic)
			{
				trace('[SongEventRegistry] Yerlesik event yuklenemedi: ${Type.getClassName(eventCls)} — $e');
			}
		}
	}

	static function registerScriptedEvents():Void
	{
		#if POLYMOD_ALLOWED
		var scriptedEventClassNames:Array<String> = null;
		try
		{
			scriptedEventClassNames = funkin.play.event.ScriptedSongEvent.listScriptClasses();
		}
		catch (e:Dynamic)
		{
			trace('[SongEventRegistry] Scripted event listesi alinamadi: $e');
			return;
		}
		if (scriptedEventClassNames == null || scriptedEventClassNames.length == 0) return;

		trace('[SongEventRegistry] ${scriptedEventClassNames.length} scripted song event bulunuyor...');
		for (eventCls in scriptedEventClassNames)
		{
			try
			{
				// Resmî FNF ile aynı: scriptInit(cls, dummyId) — gerçek id'yi
				// script'in kendi constructor'ındaki super('...') çağrısı belirler.
				var event:SongEvent = funkin.play.event.ScriptedSongEvent.scriptInit(eventCls, 'UNKNOWN');
				if (event != null && event.id != null && event.id.length > 0 && event.id != 'UNKNOWN')
				{
					trace('[SongEventRegistry] Scripted event yuklendi: ${event.id} ($eventCls)');
					eventCache.set(event.id, event);
				}
				else
				{
					trace('[SongEventRegistry] Scripted event id cozulemedi: $eventCls — super("id") cagrisi eksik olabilir.');
				}
			}
			catch (e:Dynamic)
			{
				trace('[SongEventRegistry] Scripted event kurulamadi: $eventCls — $e');
			}
		}
		#end
	}

	static function clearEventCache():Void
	{
		eventCache.clear();
		allEventHandlers = [];
	}

	public static function listEventIds():Array<String>
	{
		return [for (k in eventCache.keys()) k];
	}

	public static function listEvents():Array<SongEvent>
	{
		// Haxe 4.3: Map abstract'unda values() yok (4.4'te geldi) — keys ile gez.
		var result:Array<SongEvent> = [];
		for (k in eventCache.keys())
		{
			var v:Null<SongEvent> = eventCache.get(k);
			if (v != null) result.push(v);
		}
		return result;
	}

	public static function getEvent(id:String):Null<SongEvent>
	{
		if (id == null) return null;
		return eventCache.get(id);
	}

	public static function getEventSchema(id:String):Null<SongEventSchema>
	{
		var event:Null<SongEvent> = getEvent(id);
		if (event == null) return null;
		return event.getEventSchema();
	}

	/**
	 * Bir chart event'ini uygun handler'a iletir.
	 * Handler yoksa false döner (Psych/Lua tarafı ilgilensin diye).
	 */
	public static function handleEvent(data:SongEventData):Bool
	{
		if (data == null) return false;
		var eventHandler:Null<SongEvent> = getEvent(data.eventKind);

		if (eventHandler != null)
		{
			try
			{
				eventHandler.handleEvent(data);
			}
			catch (e:Dynamic)
			{
				trace('[SongEventRegistry] handleEvent hatasi (${data.eventKind}): $e');
			}
			data.activated = true;
			return true;
		}
		return false;
	}

	/**
	 * Resmî FNF: şarkı başında bu şarkının event'leri için gereken
	 * handler'lar toplanır ve yaşam döngüsü olayları bunlara da yayılır.
	 */
	public static function resetEvents(events:Array<SongEventData>):Void
	{
		allEventHandlers = [];
		if (events == null) return;
		for (event in events)
		{
			if (event == null) continue;
			event.activated = false;
			var handler:Null<SongEvent> = getEvent(event.eventKind);
			if (handler != null && !allEventHandlers.contains(handler)) allEventHandlers.push(handler);
		}
	}

	/** Bu şarkı için kayıtlı event handler'lar (yaşam döngüsü alacak olanlar). */
	public static function getActiveHandlers():Array<SongEvent>
	{
		return allEventHandlers;
	}

	/**
	 * Resmî callEvent karşılığı: bir ScriptEvent'i tüm aktif handler'a iletir.
	 * Event tipine göre ilgili onXxx metodu çağrılır (Reflect ile — hem
	 * yerleşik no-op'ler hem scripted override'lar çalışır).
	 */
	public static function callEvent(scriptEvent:ScriptEvent):Void
	{
		if (scriptEvent == null) return;
		var funcName:Null<String> = switch (Std.string(scriptEvent.type))
		{
			case 'CREATE': 'onCreate';
			case 'STATE_CREATE': 'onCreatePost';
			case 'DESTROY': 'onDestroy';
			case 'UPDATE': 'onUpdate';
			case 'SONG_BEAT_HIT': 'onBeatHit';
			case 'SONG_STEP_HIT': 'onStepHit';
			case 'NOTE_HIT': 'onNoteHit';
			case 'NOTE_MISS': 'onNoteMiss';
			case 'NOTE_GHOST_MISS': 'onNoteGhostMiss';
			case 'SONG_EVENT': 'onSongEvent';
			case 'SONG_START': 'onSongStart';
			case 'SONG_END': 'onSongEnd';
			case 'COUNTDOWN_START': 'onCountdownStart';
			case 'COUNTDOWN_STEP': 'onCountdownStep';
			case 'COUNTDOWN_END': 'onCountdownEnd';
			case 'GAME_OVER': 'onGameOver';
			case 'PAUSE': 'onPause';
			case 'RESUME': 'onResume';
			case 'SONG_LOADED': 'onSongLoaded';
			default: null;
		}
		if (funcName == null) return;

		for (handler in allEventHandlers)
		{
			if (handler == null) continue;
			try
			{
				var fn:Dynamic = Reflect.field(handler, funcName);
				if (fn != null) Reflect.callMethod(handler, fn, [scriptEvent]);
			}
			catch (e:Dynamic)
			{
				trace('[SongEventRegistry] $funcName hatasi (${handler.id}): $e');
			}
			if (!scriptEvent.shouldPropagate) return;
		}
	}
}
