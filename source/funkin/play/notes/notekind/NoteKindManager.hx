package funkin.play.notes.notekind;

import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventType;
import funkin.play.notes.notekind.NoteKind.NoteKindParam;
import funkin.modding.events.ScriptEvent.GhostMissNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HoldNoteScriptEvent;
import funkin.modding.events.ScriptEvent.NoteScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;
import funkin.data.song.SongData.SongNoteData;
import funkin.play.notes.notestyle.NoteStyle;

/**
 * V-Slice/FNF uyumluluk shim'i (NoteKindManager) — v17 (Faz 3, derinleştirildi).
 *
 * Resmî v0.8.7 registry'sinin FFE uyarlaması:
 *   - Scripted NoteKind sınıfları `vslice.scripting.ScriptedNoteKind`
 *     sarmalayıcısı üzerinden keşfedilir (SongEventRegistry ile aynı desen).
 *   - Chart `k` değeri → converter `note.noteType`'a yazar; PlayState
 *     vuruş/kaçırma anında `dispatchToKind(noteType, event)` çağırır.
 *   - getNoteStyle/getNoteStyleId null döner (Further nota görünümü
 *     noteSkin sistemiyle yürür).
 */
@:noCustomClass
class NoteKindManager
{
	/** kindId -> NoteKind örneği. */
	static var _cache:Map<String, NoteKind> = new Map<String, NoteKind>();

	public static function initialize():Void
	{
		registerBaseNoteKinds();
		registerScriptedNoteKinds();
	}

	/** Further'da yerleşik V-Slice note kind yok. */
	public static function registerBaseNoteKinds():Void {}

	/** Scripted NoteKind sınıflarını keşfedip kaydeder. */
	public static function registerScriptedNoteKinds():Void
	{
		#if POLYMOD_ALLOWED
		var classNames:Array<String> = null;
		try
		{
			classNames = vslice.scripting.ScriptedNoteKind.listScriptClasses();
		}
		catch (e:Dynamic)
		{
			trace('[NoteKindManager] Scripted note kind listesi alinamadi: $e');
			return;
		}
		if (classNames == null || classNames.length == 0) return;

		for (cls in classNames)
		{
			try
			{
				var kind:NoteKind = vslice.scripting.ScriptedNoteKind.scriptInit(cls, 'UNKNOWN');
				if (kind != null && kind.noteKind != null && kind.noteKind.length > 0 && kind.noteKind != 'UNKNOWN')
				{
					trace('[NoteKindManager] Scripted note kind yuklendi: ${kind.noteKind} ($cls)');
					_cache.set(kind.noteKind, kind);
				}
				else
				{
					trace('[NoteKindManager] Scripted note kind id cozulemedi: $cls — super("id") eksik olabilir.');
				}
			}
			catch (e:Dynamic)
			{
				trace('[NoteKindManager] Scripted note kind kurulamadi: $cls — $e');
			}
		}
		#end
	}

	/** Resmî: id'ye göre NoteKind (yoksa null). */
	public static function getNoteKind(?noteKind:String):Null<NoteKind>
	{
		if (noteKind == null) return null;
		return _cache.get(noteKind);
	}

	public static function listNoteKinds():Array<String>
	{
		return [for (k in _cache.keys()) k];
	}

	/**
	 * Elle kayıt (eski shim imzası korunur): NoteKind örneği VEYA
	 * noteKind alanı olan herhangi bir nesne kabul edilir.
	 */
	public static function registerNoteKind(?kind:Dynamic):Bool
	{
		if (kind == null) return false;
		if (!Std.isOfType(kind, NoteKind)) return false;
		var nk:NoteKind = cast(kind, NoteKind);
		if (nk.noteKind == null || nk.noteKind.length == 0) return false;
		_cache.set(nk.noteKind, nk);
		return true;
	}

	public static function getNoteStyle(noteKind:String, ?suffix:String):Null<NoteStyle> return null;
	public static function getNoteStyleId(noteKind:String, ?suffix:String):Null<String> return null;
	public static function listNoteStylesByNoteData(songNoteDatas:Array<SongNoteData>):Array<NoteStyle> return [];

	public static function getParams(noteKind:Null<String>):Array<NoteKindParam>
	{
		var kind:Null<NoteKind> = getNoteKind(noteKind);
		return (kind != null && kind.params != null) ? kind.params : [];
	}

	public static function clearNoteKindCache():Void
	{
		_cache.clear();
	}

	/** Resmî: olayı TÜM kayıtlı kind'lara yayınlar. */
	public static function callEvent(event:ScriptEvent):Void
	{
		for (kind in _cache)
		{
			dispatchEventToKind(kind, event);
		}
	}

	/** FFE yardımcısı: olayı yalnızca eşleşen kind'e iletir (PlayState çağırır). */
	public static function dispatchToKind(kindId:String, event:ScriptEvent):Void
	{
		if (kindId == null) return;
		var kind:Null<NoteKind> = _cache.get(kindId);
		if (kind == null) return;
		dispatchEventToKind(kind, event);
	}

	static function dispatchEventToKind(kind:NoteKind, event:ScriptEvent):Void
	{
		if (kind == null || event == null) return;
		try
		{
			kind.onScriptEvent(event);
			switch (event.type)
			{
				case ScriptEventType.NOTE_HIT:
					kind.onNoteHit(cast(event, HitNoteScriptEvent));
				case ScriptEventType.NOTE_MISS:
					kind.onNoteMiss(cast(event, NoteScriptEvent));
				case ScriptEventType.NOTE_GHOST_MISS:
					kind.onNoteGhostMiss(cast(event, GhostMissNoteScriptEvent));
				case ScriptEventType.NOTE_HOLD_DROP:
					kind.onNoteHoldDrop(cast(event, HoldNoteScriptEvent));
				case ScriptEventType.NOTE_INCOMING:
					kind.onNoteIncoming(cast(event, NoteScriptEvent));
				case ScriptEventType.UPDATE:
					kind.onUpdate(cast(event, UpdateScriptEvent));
				default:
			}
		}
		catch (e:Dynamic)
		{
			trace('[NoteKindManager] event dispatch hatasi (${kind.noteKind}): $e');
		}
	}
}
