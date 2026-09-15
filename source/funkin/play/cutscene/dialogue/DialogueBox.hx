package funkin.play.cutscene.dialogue;

import flixel.group.FlxSpriteGroup;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEvent.DialogueScriptEvent;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;

/**
 * V-Slice/FNF uyumluluk shim'i (DialogueBox) — v17 (Faz 3).
 *
 * Resmî v0.8.7: `class DialogueBox extends FlxSpriteGroup
 * implements IDialogueScriptedClass`. Further'da diyalog oynatımı
 * Psych tarafında (vslice.stages.cutscenes.dialogueBox / DialogueBoxPsych)
 * yürür; bu shim resmî API YÜZEYİNİ sağlar:
 *   - `class X extends DialogueBox` script'leri yüklenebilir (ScriptedDialogueBox
 *     sarmalayıcısı üzerinden)
 *   - setText/appendText/skip/speed/typingCompleteCallback alanları çalışır
 *     (metin depolanır; oynatım motor tarafından ayrıca yönetilir)
 *   - Diyalog yaşam döngüsü metodları no-op'tur (super çağrıları güvenli)
 */
@:noCustomClass
class DialogueBox extends FlxSpriteGroup
{
	/** Kayıt id'si (resmî: dialogueBoxName). */
	public var id:String;

	public var dialogueBoxName(get, never):String;

	function get_dialogueBoxName():String return id;

	/** Resmî alanlar. */
	public var globalOffsets(default, set):Array<Float> = [0, 0];
	public var speed(default, set):Float = 1.0;

	function set_globalOffsets(value:Array<Float>):Array<Float>
	{
		if (value == null) value = [0, 0];
		return globalOffsets = value;
	}

	function set_speed(value:Float):Float return speed = value;

	/** Yazı bitince çağrılacak geri çağrı (resmî alan). */
	public var typingCompleteCallback:() -> Void;

	/** Shim depolama: son yazılan metin + geçerli animasyon adı. */
	public var currentText:String = '';
	var _currentAnimation:String = '';
	var _params:Dynamic;

	public function new(id:String, ?params:Dynamic)
	{
		super();
		this.id = id;
		this._params = params;
	}

	/* ---- Resmî metin API'si (depolar; oynatım Psych diyalog sistemine ait) ---- */

	public function setText(newText:String):Void
	{
		currentText = (newText != null) ? newText : '';
	}

	public function appendText(newText:String):Void
	{
		currentText += (newText != null) ? newText : '';
	}

	public function skip():Void
	{
		if (typingCompleteCallback != null) typingCompleteCallback();
	}

	/* ---- Resmî animasyon API'si (basit depolama) ---- */

	public function playAnimation(name:String, restart:Bool = false, reversed:Bool = false):Void
	{
		_currentAnimation = (name != null) ? name : '';
	}

	public function hasAnimation(id:String):Bool return false;
	public function getCurrentAnimation():String return _currentAnimation;
	public function isAnimationFinished():Bool return true;
	public function setAnimationOffsets(name:String, xOffset:Float, yOffset:Float):Void {}

	/* ============ IDialogueScriptedClass / IScriptedClass no-op'ları ============ */

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
