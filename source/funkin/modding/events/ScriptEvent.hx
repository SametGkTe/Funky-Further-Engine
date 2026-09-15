package funkin.modding.events;

import flixel.FlxState;
import flixel.FlxSubState;
import funkin.data.song.SongData.SongEventData;
import funkin.play.Countdown.CountdownStep;
import funkin.play.notes.NoteDirection;

/**
 * V-Slice/FNF uyumluluk shim'i (ScriptEvent ailesi) — v15.
 *
 * Resmî funkin v0.8.7 `funkin.modding/events/ScriptEvent.hx` içindeki TÜM
 * olay sınıfları burada birebir (alan adları + kurucu imzaları) taşınmıştır.
 * Tip farkları:
 *   - NoteSprite        -> objects.Note        (Psych karşılığı)
 *   - SustainTrail      -> Dynamic             (Psych'te ayrı sınıf yok)
 *   - Conversation      -> Dynamic             (diyalog sistemi köprüsü henüz yok)
 *   - KeyboardEvent     -> Dynamic             (flash klavye olayı taşınmaz)
 *   - SongNoteData      -> shim (funkin.data.song.SongData)
 *
 * EK GERİYE-UYUMLULUK (eski FFE script'leri bozulmasın diye):
 *   - `data:Dynamic`      : eski isimsiz olay nesnesindeki ham yük
 *   - `eventName:String`  : Psych callback adı ('onBeatHit' gibi)
 *   - `cancelled`         : `eventCanceled` için okunur/YAZILIR takma ad
 *                           (eski kod `event.cancelled = true` yapıyordu)
 *
 * NOT: @:noCustomClass — CNE ClassExtendMacro gölgelemesine karşı koruma
 * (bkz. OKUBENI v13.2).
 */
@:noCustomClass
class ScriptEvent
{
	/**
	 * Whether the event is cancelable by scripts.
	 */
	public var cancelable(default, null):Bool = false;

	/**
	 * The type of the event.
	 */
	public var type(default, null):ScriptEventType;

	/**
	 * Whether the event should be passed to the next scripted class.
	 */
	public var shouldPropagate(default, null):Bool = true;

	/**
	 * Whether the event has been canceled by a scripted class.
	 */
	public var eventCanceled(default, null):Bool = false;

	/* ---- FFE geriye-uyumluluk alanları ---- */

	/** Eski isimsiz olay objesindeki ham yük (nota, beat sayısı, elapsed...). */
	public var data:Dynamic = null;

	/** Psych callback adı: 'onBeatHit', 'onNoteHit', ... */
	public var eventName:String = null;

	/** `eventCanceled` takma adı (eski script'ler `event.cancelled = true` yapabiliyordu). */
	public var cancelled(get, set):Bool;

	function get_cancelled():Bool
		return eventCanceled;

	function set_cancelled(value:Bool):Bool
	{
		eventCanceled = value;
		return value;
	}

	public function new(type:ScriptEventType, cancelable:Bool = false):Void
	{
		this.type = type;
		this.cancelable = cancelable;
	}

	/**
	 * Cancel the event, if it is cancelable.
	 */
	public function cancelEvent():Void
	{
		if (cancelable) eventCanceled = true;
	}

	/**
	 * Cancel the event, if it is cancelable. (FNF script kısayolu)
	 */
	public function cancel():Void
	{
		cancelEvent();
	}

	/**
	 * Stop the event from being passed to the next scripted class.
	 */
	public function stopPropagation():Void
	{
		shouldPropagate = false;
	}

	public function toString():String
	{
		return 'ScriptEvent(type=' + type + ')';
	}
}

/**
 * An event that is fired when a note is hit or missed.
 */
@:noCustomClass
class NoteScriptEvent extends ScriptEvent
{
	/**
	 * The note that is being referenced.
	 */
	public var note(default, null):objects.Note;

	/**
	 * How many combo notes have been hit in a row.
	 */
	public var comboCount(default, null):Int = 0;

	/**
	 * Whether the game should play a sound for the event.
	 */
	public var playSound(default, default):Bool = true;

	/**
	 * How much the event will change the player's health.
	 */
	public var healthChange:Float = 0;

	public function new(type:ScriptEventType, note:objects.Note, healthChange:Float, comboCount:Int = 0, cancelable:Bool = false):Void
	{
		super(type, cancelable);
		this.note = note;
		this.healthChange = healthChange;
		this.comboCount = comboCount;
	}

	override public function toString():String
	{
		return 'NoteScriptEvent(type=' + type + ', note=' + note + ')';
	}
}

/**
 * An event that is fired when a note has been hit.
 */
@:noCustomClass
class HitNoteScriptEvent extends NoteScriptEvent
{
	/**
	 * The judgement the note received.
	 */
	public var judgement:String = 'good';

	/**
	 * The score gained from hitting the note.
	 */
	public var score:Float = 0;

	/**
	 * Whether the note hit should break the combo.
	 */
	public var isComboBreak:Bool = false;

	/**
	 * The difference between the note's time and the time it was hit.
	 */
	public var hitDiff:Float = 0;

	/**
	 * Whether the note should spawn a note splash.
	 */
	public var doesNotesplash:Bool = false;

	public function new(note:objects.Note, healthChange:Float, score:Float, judgement:String, isComboBreak:Bool, comboCount:Int = 0, hitDiff:Float = 0,
			doesNotesplash:Bool = false):Void
	{
		super(NOTE_HIT, note, healthChange, comboCount, true);
		this.score = score;
		this.judgement = judgement;
		this.isComboBreak = isComboBreak;
		this.doesNotesplash = doesNotesplash;
		this.hitDiff = hitDiff;
	}

	override public function toString():String
	{
		return 'HitNoteScriptEvent(note=' + note + ', judgement=' + judgement + ', score=' + score + ', hitDiff=' + hitDiff + ')';
	}
}

/**
 * An event that is fired when a note has been ghost-missed.
 */
@:noCustomClass
class GhostMissNoteScriptEvent extends ScriptEvent
{
	/**
	 * The direction of the note that was ghost-missed.
	 */
	public var dir(default, null):NoteDirection;

	/**
	 * Whether there was a possible note that could have been hit.
	 */
	public var hasPossibleNotes(default, null):Bool;

	/**
	 * How much this will change the player's health.
	 */
	public var healthChange(default, default):Float;

	/**
	 * How much this will change the player's score.
	 */
	public var scoreChange(default, default):Float;

	/**
	 * Whether the game should play a sound for the event.
	 */
	public var playSound(default, default):Bool = true;

	/**
	 * Whether the character should play a miss animation.
	 */
	public var playAnim(default, default):Bool = true;

	public function new(dir:NoteDirection, hasPossibleNotes:Bool, healthChange:Float, scoreChange:Float):Void
	{
		super(NOTE_GHOST_MISS, true);
		this.dir = dir;
		this.hasPossibleNotes = hasPossibleNotes;
		this.healthChange = healthChange;
		this.scoreChange = scoreChange;
	}

	override public function toString():String
	{
		return 'GhostMissNoteScriptEvent(dir=' + dir + ', hasPossibleNotes=' + hasPossibleNotes + ')';
	}
}

/**
 * An event that is fired when a hold note is dropped.
 */
@:noCustomClass
class HoldNoteScriptEvent extends NoteScriptEvent
{
	/**
	 * The hold note trail that is being referenced.
	 */
	public var holdNote:Dynamic;

	/**
	 * The score gained from holding the note.
	 */
	public var score:Float = 0;

	/**
	 * Whether the combo should break.
	 */
	public var isComboBreak:Bool = false;

	/**
	 * The difference between the note's time and the time it was dropped.
	 */
	public var hitDiff:Float = 0;

	/**
	 * Whether to spawn a note splash.
	 */
	public var doesNotesplash:Bool = false;

	public function new(type:ScriptEventType, holdNote:Dynamic, healthChange:Float, score:Float, isComboBreak:Bool, comboCount:Int = 0, hitDiff:Float = 0,
			doesNotesplash:Bool = false):Void
	{
		super(type, null, healthChange, comboCount, true);
		this.holdNote = holdNote;
		this.score = score;
		this.isComboBreak = isComboBreak;
		this.hitDiff = hitDiff;
		this.doesNotesplash = doesNotesplash;
	}
}

/**
 * An event that is fired when a song event is hit.
 */
@:noCustomClass
class SongEventScriptEvent extends ScriptEvent
{
	/**
	 * The song event data.
	 */
	public var eventData(default, null):SongEventData;

	public function new(eventData:SongEventData):Void
	{
		super(SONG_EVENT, false);
		this.eventData = eventData;
	}

	override public function toString():String
	{
		return 'SongEventScriptEvent(eventKind=' + eventData.eventKind + ')';
	}
}

/**
 * An event that is fired once per frame.
 */
@:noCustomClass
class UpdateScriptEvent extends ScriptEvent
{
	/**
	 * The time elapsed since the last frame.
	 */
	public var elapsed(default, null):Float;

	public function new(elapsed:Float):Void
	{
		super(UPDATE, false);
		this.elapsed = elapsed;
	}

	override public function toString():String
	{
		return 'UpdateScriptEvent(elapsed=' + elapsed + ')';
	}
}

/**
 * An event that is fired regularly during the song.
 * May be on beat or on step.
 */
@:noCustomClass
class SongTimeScriptEvent extends ScriptEvent
{
	/**
	 * The current beat of the song.
	 */
	public var beat(default, null):Int = 0;

	/**
	 * The current step of the song.
	 */
	public var step(default, null):Int = 0;

	public function new(type:ScriptEventType, beat:Int, step:Int):Void
	{
		super(type, false);
		this.beat = beat;
		this.step = step;
	}

	override public function toString():String
	{
		return 'SongTimeScriptEvent(type=' + type + ', beat=' + beat + ', step=' + step + ')';
	}
}

/**
 * An event that is fired during the countdown.
 */
@:noCustomClass
class CountdownScriptEvent extends ScriptEvent
{
	/**
	 * The current step of the countdown.
	 */
	public var step(default, null):CountdownStep;

	public function new(type:ScriptEventType, step:CountdownStep, cancelable:Bool = true):Void
	{
		super(type, cancelable);
		this.step = step;
	}

	override public function toString():String
	{
		return 'CountdownScriptEvent(type=' + type + ', step=' + step + ')';
	}
}

/**
 * An event that is fired during a dialogue.
 */
@:noCustomClass
class DialogueScriptEvent extends ScriptEvent
{
	/**
	 * The dialogue being referenced by the event.
	 */
	public var conversation(default, null):Dynamic;

	public function new(type:ScriptEventType, conversation:Dynamic, cancelable:Bool = true):Void
	{
		super(type, cancelable);
		this.conversation = conversation;
	}

	override public function toString():String
	{
		return 'DialogueScriptEvent(type=$type, conversation=$conversation)';
	}
}

/**
 * An event that is fired when the player presses a key.
 */
@:noCustomClass
class KeyboardInputScriptEvent extends ScriptEvent
{
	/**
	 * The associated keyboard event.
	 */
	public var event(default, null):Dynamic;

	public function new(type:ScriptEventType, event:Dynamic):Void
	{
		super(type, false);
		this.event = event;
	}

	override public function toString():String
	{
		return 'KeyboardInputScriptEvent(type=' + type + ', event=' + event + ')';
	}
}

/**
 * An event that is fired once the song's chart has been parsed.
 *
 * FFE FARKI: notes = Psych SwagSection dizisi (SONG.notes),
 *            events = Psych EventNote dizisi (PlayState.eventNotes).
 * Resmî FNF'deki SongNoteData/SongEventData dizileri yerine dönüştürülmüş
 * Psych yapıları gelir; düzenleme (mutasyon) yine şarkıya yansır.
 */
@:noCustomClass
class SongLoadScriptEvent extends ScriptEvent
{
	/**
	 * The note data for the song that just loaded.
	 */
	public var notes(default, set):Array<Dynamic>;

	/**
	 * The event data for the song that just loaded.
	 */
	public var events(default, set):Array<Dynamic>;

	/**
	 * The ID of the song that just loaded.
	 */
	public var id(default, null):String;

	/**
	 * The difficulty of the song that just loaded.
	 */
	public var difficulty(default, null):String;

	function set_notes(notes:Array<Dynamic>):Array<Dynamic>
	{
		this.notes = notes;
		return this.notes;
	}

	function set_events(events:Array<Dynamic>):Array<Dynamic>
	{
		this.events = events;
		return this.events;
	}

	public function new(id:String, difficulty:String, notes:Array<Dynamic>, events:Array<Dynamic>):Void
	{
		super(SONG_LOADED, false);
		this.id = id;
		this.difficulty = difficulty;
		this.notes = notes;
		this.events = events;
	}

	override public function toString():String
	{
		var noteStr = notes == null ? 'null' : 'Array(' + notes.length + ')';
		var eventStr = events == null ? 'null' : 'Array(' + events.length + ')';
		return 'SongLoadScriptEvent(notes=$noteStr, events=$eventStr, id=$id, difficulty=$difficulty)';
	}
}

/**
 * An event that is fired when the player retries the song.
 */
@:noCustomClass
class SongRetryEvent extends ScriptEvent
{
	/**
	 * The new difficulty of the song.
	 */
	public var difficulty(default, null):String;

	public function new(difficulty:String):Void
	{
		super(SONG_RETRY, false);
		this.difficulty = difficulty;
	}

	override public function toString():String
	{
		return 'SongRetryEvent(difficulty=' + difficulty + ')';
	}
}

/**
 * An event that is fired when the state is changing.
 */
@:noCustomClass
class StateChangeScriptEvent extends ScriptEvent
{
	/**
	 * The state we are transitioning to.
	 */
	public var targetState(default, null):FlxState;

	public function new(type:ScriptEventType, targetState:FlxState, cancelable:Bool = false):Void
	{
		super(type, cancelable);
		this.targetState = targetState;
	}

	override public function toString():String
	{
		return 'StateChangeScriptEvent(type=' + type + ', targetState=' + targetState + ')';
	}
}

/**
 * An event that is fired when the game window gains or loses focus.
 */
@:noCustomClass
class FocusScriptEvent extends ScriptEvent
{
	public function new(type:ScriptEventType):Void
	{
		super(type, false);
	}

	override public function toString():String
	{
		return 'FocusScriptEvent(type=' + type + ')';
	}
}

/**
 * An event that is fired when a capsule is selected in Freeplay.
 */
@:noCustomClass
class CapsuleScriptEvent extends ScriptEvent
{
	/**
	 * The capsule being referenced (vslice SongMenuItem).
	 */
	public var capsule(default, null):Dynamic;

	/**
	 * The difficulty of the song being referenced.
	 */
	public var difficultyId(default, null):String;

	/**
	 * The variation of the song being referenced.
	 */
	public var variationId(default, null):String;

	public function new(type:ScriptEventType, capsule:Dynamic, difficultyId:String, variationId:String):Void
	{
		super(type, false);
		this.capsule = capsule;
		this.difficultyId = difficultyId;
		this.variationId = variationId;
	}

	override public function toString():String
	{
		return 'CapsuleScriptEvent(type=' + type + ', difficultyId=' + difficultyId + ', variationId=' + variationId + ')';
	}
}

/**
 * An event that is fired in the Freeplay menu.
 */
@:noCustomClass
class FreeplayScriptEvent extends ScriptEvent
{
	public function new(type:ScriptEventType):Void
	{
		super(type, false);
	}

	override public function toString():String
	{
		return 'FreeplayScriptEvent(type=' + type + ')';
	}
}

/**
 * An event that is fired in Character Select.
 */
@:noCustomClass
class CharacterSelectScriptEvent extends ScriptEvent
{
	/**
	 * The character being referenced.
	 */
	public var characterId(default, null):String;

	public function new(type:ScriptEventType, characterId:String):Void
	{
		super(type, false);
		this.characterId = characterId;
	}

	override public function toString():String
	{
		return 'CharacterSelectScriptEvent(type=' + type + ', characterId=' + characterId + ')';
	}
}

/**
 * An event that is fired when a substate is opening/closing.
 */
@:noCustomClass
class SubStateScriptEvent extends ScriptEvent
{
	/**
	 * The substate being referenced.
	 */
	public var targetState(default, null):FlxSubState;

	public function new(type:ScriptEventType, targetState:FlxSubState, cancelable:Bool = false):Void
	{
		super(type, cancelable);
		this.targetState = targetState;
	}

	override public function toString():String
	{
		return 'SubStateScriptEvent(type=' + type + ', targetState=' + targetState + ')';
	}
}

/**
 * An event that is fired when the game is paused.
 */
@:noCustomClass
class PauseScriptEvent extends ScriptEvent
{
	/**
	 * Whether the player is transitioning to the Gitaroo Pause screen.
	 */
	public var gitaroo(default, default):Bool;

	public function new(gitaroo:Bool):Void
	{
		super(PAUSE, true);
		this.gitaroo = gitaroo;
	}

	override public function toString():String
	{
		return 'PauseScriptEvent(gitaroo=' + gitaroo + ')';
	}
}
