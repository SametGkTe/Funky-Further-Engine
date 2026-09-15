package funkin.play.cutscene.dialogue;

import flixel.group.FlxSpriteGroup;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.DialogueScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;

/**
 * V-Slice/FNF uyumluluk shim'i (Conversation) — v18 (Faz 4).
 *
 * Resmî v0.8.7: diyalog kutusu + konuşmacıları yöneten sohbet akışı.
 * Further'da oynatım DialogueBoxPsych ile yürür; bu shim import/tip
 * çözümü ve `class X extends Conversation` script'leri içindir.
 */
@:noCustomClass
class Conversation extends FlxSpriteGroup
{
	public var id:String;

	/** Resmî alan: diyalog bitince çağrılır. */
	public var completeCallback:Null<Void->Void> = null;

	/** Shim depolama: dialogue JSON satırları (oynatılmaz). */
	public var dialogue:Array<Dynamic> = [];

	var _params:Dynamic;

	public function new(id:String, ?params:Dynamic)
	{
		super();
		this.id = id;
		this._params = params;
	}

	/** Resmî: konuşmayı sonlandırır (shim: completeCallback çağırır). */
	public function skip():Void
	{
		if (completeCallback != null) completeCallback();
	}

	/* IDialogueScriptedClass / IScriptedClass no-op'ları (super güvenliği). */
	public function onDialogueStart(event:DialogueScriptEvent):Void {}
	public function onDialogueCompleteLine(event:DialogueScriptEvent):Void {}
	public function onDialogueLine(event:DialogueScriptEvent):Void {}
	public function onDialogueSkip(event:DialogueScriptEvent):Void {}
	public function onDialogueEnd(event:DialogueScriptEvent):Void {}

	public function onScriptEvent(event:ScriptEvent):Void {}
	public function onCreate(event:ScriptEvent):Void {}
	public function onDestroy(event:ScriptEvent):Void {}
	public function onUpdate(event:UpdateScriptEvent):Void {}
}
