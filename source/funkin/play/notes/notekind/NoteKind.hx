package funkin.play.notes.notekind;

import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.GhostMissNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.modding.events.ScriptEvent.HoldNoteScriptEvent;
import funkin.modding.events.ScriptEvent.NoteScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;

/**
 * V-Slice/FNF uyumluluk shim'i (NoteKind) — v17 (Faz 3).
 *
 * Resmî v0.8.7: chart'taki `k` (kind) alanına bağlanan nota davranış sınıfı.
 * Script'ler `class X extends NoteKind` türetip onNoteHit vb. dinleyebilir.
 * Further'da özel nota davranışları Psych event/noteTip sistemiyle yürür;
 * bu shim API yüzeyini + yaşam döngüsü no-op'larını sağlar ve
 * NoteKindManager üzerinden kaydedilip `k` değeriyle eşleştirilebilir.
 */
@:noCustomClass
class NoteKind
{
	/** Chart `k` değeri (örn. 'warn', 'mine'). */
	public var noteKind:String;
	public var description:String;
	public var noteStyleId:Null<String>;
	public var noanim:Bool = false;
	public var suffix:String = '';
	public var params:Array<NoteKindParam>;
	public var scoreable:Bool = true;

	public function new(noteKind:String, description:String = "", ?noteStyleId:String, ?params:Array<NoteKindParam>, ?noanim:Bool, ?suffix:String)
	{
		this.noteKind = noteKind;
		this.description = description;
		this.noteStyleId = noteStyleId;
		this.params = (params != null) ? params : [];
		if (noanim != null) this.noanim = noanim;
		if (suffix != null) this.suffix = suffix;
	}

	public function toString():String return 'NoteKind($noteKind)';

	/* ============ INoteScriptedClass yaşam döngüsü (no-op / super güvenliği) ============ */

	public function onScriptEvent(event:ScriptEvent):Void {}
	public function onCreate(event:ScriptEvent):Void {}
	public function onDestroy(event:ScriptEvent):Void {}
	public function onUpdate(event:UpdateScriptEvent):Void {}
	public function onNoteIncoming(event:NoteScriptEvent):Void {}
	public function onNoteHit(event:HitNoteScriptEvent):Void {}
	public function onNoteMiss(event:NoteScriptEvent):Void {}
	public function onNoteHoldDrop(event:HoldNoteScriptEvent):Void {}
	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void {}
}

/**
 * Resmî NoteKindParam: editör/chart parametre tanımı.
 */
class NoteKindParam
{
	public static final STRING:String = 'String';
	public static final INT:String = 'Int';
	public static final FLOAT:String = 'Float';
	public static final BOOL:String = 'Bool';

	public var name:String;
	public var type:String;
	public var defaultValue:Dynamic;

	public function new(name:String, type:String, ?defaultValue:Dynamic)
	{
		this.name = name;
		this.type = type;
		this.defaultValue = defaultValue;
	}
}
