package funkin.play.cutscene.dialogue;

import flixel.FlxSprite;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.DialogueScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;

/**
 * V-Slice/FNF uyumluluk shim'i (Speaker) — v18 (Faz 4).
 *
 * Resmî v0.8.7: diyalog konuşmacısı (sprite + isim + renk).
 * Further'da diyalog oynatımı DialogueBoxPsych ile yürür; bu shim
 * import/tip çözümü ve `class X extends Speaker` script'leri içindir.
 */
@:noCustomClass
class Speaker extends FlxSprite
{
	public var id:String;

	public var speakerName(get, never):String;

	function get_speakerName():String return id;

	public var globalOffsets(default, set):Array<Float> = [0, 0];

	function set_globalOffsets(value:Array<Float>):Array<Float>
	{
		if (value == null) value = [0, 0];
		return globalOffsets = value;
	}

	var _params:Dynamic;

	public function new(id:String, ?params:Dynamic)
	{
		super();
		this.id = id;
		this._params = params;
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
